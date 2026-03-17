#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/scripts/suma.sh"
}

@test "Suma dos decimales válidos" {
    run "${SCRIPT}" 3.45 1.55
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Resultado: 5.00"* ]]
}

@test "Suma con valores negativos" {
    run "${SCRIPT}" -3.5 2.25
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Resultado: -1.25"* ]]
}

@test "Suma enteros sin parte decimal" {
    run "${SCRIPT}" 5 2
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Resultado: 7.00"* ]]
}

@test "Falla con cantidad incorrecta de argumentos" {
    run "${SCRIPT}" 1 2 3
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"exactamente 2 argumentos"* ]]
}

@test "Falla con argumento no numérico" {
    run "${SCRIPT}" abc 1
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Argumento inválido"* ]]
}

@test "Falla con más de dos decimales" {
    run "${SCRIPT}" 1.234 2
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"más de dos decimales"* ]]
}
