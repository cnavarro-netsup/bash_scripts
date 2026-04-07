#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/cantidad_autenticaciones/scripts/cantidad_autenticaciones.sh"
    TEST_TMPDIR="$(mktemp -d)"

    cat <<'EOF' > "${TEST_TMPDIR}/main.log"
2026-04-01 10:00:00 1abc H=host [10.0.0.1] P=esmtpsa A=login:ana S=100 id=1
2026-04-01 10:05:00 1abd H=host [10.0.0.1] P=esmtpsa A=login:ana S=100 id=2
2026-04-01 11:00:00 1abe H=host [10.0.0.1] P=esmtpsa A=login:beto S=100 id=3
2026-04-02 09:00:00 1abf H=host [10.0.0.1] P=esmtpsa A=login:ana S=100 id=4
2026-04-02 09:05:00 1abg H=host [10.0.0.1] P=esmtpsa P=local
EOF

    cat <<'EOF' > "${TEST_TMPDIR}/main.log-20260412"
2026-04-01 12:00:00 1abh H=host [10.0.0.2] P=esmtpsa A=login:beto S=100 id=5
2026-04-03 08:00:00 1abi H=host [10.0.0.3] P=esmtpsa A=login:admin S=100 id=6
2026-04-03 08:05:00 1abj H=host [10.0.0.3] P=esmtpsa A=login:admin S=100 id=7
EOF
}

teardown()
{
    rm -rf "${TEST_TMPDIR}"
}

@test "Usa main.log por default" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2"' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"LOG_PATTERN       : main.log"* ]]
    [[ "${output}" == *"Tabla: cantidad de autenticaciones por fecha y cuenta"* ]]
    [[ "${output}" == *"conteo   fecha        cuenta de usuario"* ]]
    [[ "${output}" == *"2        2026-04-01   ana"* ]]
}

@test "Acumula múltiples logs usando patron con metacaracter" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l "main.log*" -n 10' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"LOG_PATTERN       : main.log*"* ]]
    [[ "${output}" == *"${TEST_TMPDIR}/main.log"* ]]
    [[ "${output}" == *"${TEST_TMPDIR}/main.log-20260412"* ]]
    [[ "${output}" == *"2        2026-04-01   ana"* ]]
    [[ "${output}" == *"2        2026-04-01   beto"* ]]
    [[ "${output}" == *"2        2026-04-03   admin"* ]]
    [[ "${output}" == *"1        2026-04-02   ana"* ]]
}

@test "Tolera expansion del shell luego de -l sin comillas" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l main.log main.log-20260412 -n 10' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"LOG_PATTERN       : main.log"* ]]
    [[ "${output}" == *"${TEST_TMPDIR}/main.log"* ]]
    [[ "${output}" == *"${TEST_TMPDIR}/main.log-20260412"* ]]
    [[ "${output}" == *"2        2026-04-03   admin"* ]]
}

@test "Acepta un archivo de log puntual con -l" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l main.log-20260412' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"LOG_PATTERN       : main.log-20260412"* ]]
    [[ "${output}" == *"2        2026-04-03   admin"* ]]
    [[ "${output}" == *"1        2026-04-01   beto"* ]]
}

@test "Respeta la cantidad solicitada con -n" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l "main.log*" -n 2' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"2        2026-04-01   ana"* ]]
    [[ "${output}" == *"2        2026-04-01   beto"* ]]
    [[ "${output}" != *"2        2026-04-03   admin"* ]]
}

@test "Cancela la ejecucion si no se confirma" {
    run bash -c 'printf "\n" | EXIM_LOG_DIR="$1" "$2" -l main.log' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Operación cancelada por el usuario"* ]]
}

@test "Falla si no hay coincidencias para el patron" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l "otro.log*"' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"No se encontraron logs para el patrón"* ]]
}

@test "Falla si -n no es entero positivo" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -n 0' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"entero positivo"* ]]
}

@test "Falla si el patron incluye rutas" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l ../main.log' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"sin rutas"* ]]
}
