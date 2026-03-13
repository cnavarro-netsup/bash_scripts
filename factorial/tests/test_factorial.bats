#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
    export SCRIPT="./scripts/factorial.sh"
    # Bypass confirmation prompt during tests
    export ASSUME_YES="TRUE"
}

@test "AC-001: Ejecución con -n 5 (5! = 120)" {
    run "$SCRIPT" -n 5
    assert_success
    assert_output --partial "5! = 120"
}

@test "AC-002: Ejecución con -n 1 (Límite inferior)" {
    run "$SCRIPT" -n 1
    assert_success
    assert_output --partial "1! = 1"
}

@test "AC-003: Ejecución con -n 19 (Límite superior)" {
    run "$SCRIPT" -n 19
    assert_success
    assert_output --partial "19! = 121645100408832000"
}

@test "AC-004: Ejecución con -n 0 falla" {
    run "$SCRIPT" -n 0
    assert_failure
    assert_output --partial "El número debe ser mayor que cero."
}

@test "AC-005: Ejecución con -n 20 falla" {
    run "$SCRIPT" -n 20
    assert_failure
    assert_output --partial "El número debe ser menor que 20."
}

@test "AC-006: Ejecución con número negativo falla" {
    run "$SCRIPT" -n -3
    assert_failure
    assert_output --partial "El argumento debe ser un número entero."
}

@test "AC-007: Ejecución con valor no entero falla (abc)" {
    run "$SCRIPT" -n abc
    assert_failure
    assert_output --partial "El argumento debe ser un número entero."
}

@test "AC-008: Ejecución sin argumentos muestra usage y falla" {
    run "$SCRIPT"
    assert_failure
    assert_output --partial "Debe proveer un número argumentando -n <numero>"
}

@test "AC-009: Ejecución con --dry-run y -n 7 (Simulación)" {
    run "$SCRIPT" -n 7 --dry-run
    assert_success
    assert_output --partial "[DRY-RUN] Se calcularía: 7!"
    refute_output --partial "7! = 5040"
}

@test "AC-010: Ejecución con -d (debug)" {
    # Cuando ejecutamos con -d, set -x imprime en stderr o stdout dependiendo de la versión
    run "$SCRIPT" -n 4 -d
    assert_success
    # Al menos debería imprimir el string Variables de Ejecución y la salida normal
    assert_output --partial "Variables de Ejecución"
    assert_output --partial "4! = 24"
}
