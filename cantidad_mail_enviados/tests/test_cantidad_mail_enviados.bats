#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/cantidad_mail_enviados/cantidad_mail_enviados.sh"
    TEST_TMPDIR="$(mktemp -d)"

    cat <<'EOF' > "${TEST_TMPDIR}/main.log"
2026-04-01 10:00:00 1abc <= ana@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=1
2026-04-01 10:05:00 1abd <= ana@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=2
2026-04-01 11:00:00 1abe <= beto@gigot.com.ar H=(host2) [10.0.0.2] P=esmtp S=100 id=3
2026-04-02 09:00:00 1abf <= ana@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=4
2026-04-02 09:05:00 1abg => externo@example.com R=dnslookup T=remote_smtp H=mx.example.com [1.1.1.1]
EOF

    cat <<'EOF' > "${TEST_TMPDIR}/main.log-20260412"
2026-04-01 12:00:00 1abh <= beto@gigot.com.ar H=(host2) [10.0.0.2] P=esmtp S=100 id=5
2026-04-03 08:00:00 1abi <= admin@gigot.com.ar H=(host3) [10.0.0.3] P=esmtp S=100 id=6
2026-04-03 08:05:00 1abj <= admin@gigot.com.ar H=(host3) [10.0.0.3] P=esmtp S=100 id=7
EOF
}

teardown()
{
    rm -rf "${TEST_TMPDIR}"
}

@test "Usa main.log por default" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2"' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Patrón de log      : main.log"* ]]
    [[ "${output}" == *"Tabla: cantidad de mails enviados por fecha y cuenta"* ]]
    [[ "${output}" == *"conteo   fecha        cuenta de mail"* ]]
    [[ "${output}" == *"2        2026-04-01   ana@gigot.com.ar"* ]]
}

@test "Acumula múltiples logs usando patron con metacaracter" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l "main.log*" -n 10' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Patrón de log      : main.log*"* ]]
    [[ "${output}" == *"${TEST_TMPDIR}/main.log"* ]]
    [[ "${output}" == *"${TEST_TMPDIR}/main.log-20260412"* ]]
    [[ "${output}" == *"2        2026-04-01   ana@gigot.com.ar"* ]]
    [[ "${output}" == *"2        2026-04-01   beto@gigot.com.ar"* ]]
    [[ "${output}" == *"2        2026-04-03   admin@gigot.com.ar"* ]]
    [[ "${output}" == *"1        2026-04-02   ana@gigot.com.ar"* ]]
}

@test "Acepta un archivo de log puntual con -l" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l main.log-20260412' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Patrón de log      : main.log-20260412"* ]]
    [[ "${output}" == *"2        2026-04-03   admin@gigot.com.ar"* ]]
    [[ "${output}" == *"1        2026-04-01   beto@gigot.com.ar"* ]]
}

@test "Respeta la cantidad solicitada con -n" {
    run bash -c 'printf "s\n" | EXIM_LOG_DIR="$1" "$2" -l "main.log*" -n 2' bash "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"2        2026-04-01   ana@gigot.com.ar"* ]]
    [[ "${output}" == *"2        2026-04-01   beto@gigot.com.ar"* ]]
    [[ "${output}" != *"2        2026-04-03   admin@gigot.com.ar"* ]]
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
