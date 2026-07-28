#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/scripts/depurar_nfdump.sh"
    TEST_ROOT="$(mktemp -d)"
    export NFDUMP_TARGET_DIR="${TEST_ROOT}/nfdump"
    mkdir -p "${NFDUMP_TARGET_DIR}"

    TEST_BIN="${TEST_ROOT}/bin"
    mkdir -p "${TEST_BIN}"
    cat > "${TEST_BIN}/logger" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${TEST_BIN}/logger"
    export PATH="${TEST_BIN}:${PATH}"
}

teardown()
{
    rm -rf "${TEST_ROOT}"
}

@test "Muestra ayuda con -h" {
    run "${SCRIPT}" -h
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
}

@test "Falla con argumento desconocido" {
    run "${SCRIPT}" --invalid
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Unknown argument"* ]]
}

@test "Falla con directorio inexistente" {
    rm -rf "${NFDUMP_TARGET_DIR}"
    run "${SCRIPT}" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Target directory does not exist"* ]]
}

@test "Falla con directorio vacio" {
    run "${SCRIPT}" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Target directory is empty"* ]]
}

@test "Dry-run informa cantidad y no borra archivos" {
    : > "${NFDUMP_TARGET_DIR}/a.nfcapd"
    : > "${NFDUMP_TARGET_DIR}/b file.nfcapd"

    run "${SCRIPT}" --dry-run <<'EOF'
y
EOF
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Total files to delete: 2"* ]]
    [ -f "${NFDUMP_TARGET_DIR}/a.nfcapd" ]
    [ -f "${NFDUMP_TARGET_DIR}/b file.nfcapd" ]
}

@test "Cancela si el usuario no confirma" {
    : > "${NFDUMP_TARGET_DIR}/a.nfcapd"

    run "${SCRIPT}" <<'EOF'
n
EOF
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Operation cancelled by user"* ]]
    [ -f "${NFDUMP_TARGET_DIR}/a.nfcapd" ]
}

@test "Elimina archivos con -y" {
    : > "${NFDUMP_TARGET_DIR}/a.nfcapd"
    : > "${NFDUMP_TARGET_DIR}/b.nfcapd"

    run "${SCRIPT}" -y
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Total deleted files: 2"* ]]
    [ ! -e "${NFDUMP_TARGET_DIR}/a.nfcapd" ]
    [ ! -e "${NFDUMP_TARGET_DIR}/b.nfcapd" ]
}

@test "Elimina archivos con --yes" {
    : > "${NFDUMP_TARGET_DIR}/only.nfcapd"

    run "${SCRIPT}" --yes
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Total deleted files: 1"* ]]
    [ ! -e "${NFDUMP_TARGET_DIR}/only.nfcapd" ]
}

@test "Preserva nfcapd.current.* y borra el resto con -y" {
    : > "${NFDUMP_TARGET_DIR}/nfcapd.202607281305"
    : > "${NFDUMP_TARGET_DIR}/nfcapd.202607281310"
    : > "${NFDUMP_TARGET_DIR}/nfcapd.current.3905561"

    run "${SCRIPT}" -y
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Total deleted files: 2"* ]]
    [ ! -e "${NFDUMP_TARGET_DIR}/nfcapd.202607281305" ]
    [ ! -e "${NFDUMP_TARGET_DIR}/nfcapd.202607281310" ]
    [ -f "${NFDUMP_TARGET_DIR}/nfcapd.current.3905561" ]
}

@test "Solo current presente no borra nada y sale 0" {
    : > "${NFDUMP_TARGET_DIR}/nfcapd.current.3905561"

    run "${SCRIPT}" -y
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Total deleted files: 0"* ]]
    [ -f "${NFDUMP_TARGET_DIR}/nfcapd.current.3905561" ]
}

@test "Falla con estructura corrupta por subdirectorio" {
    mkdir -p "${NFDUMP_TARGET_DIR}/nested"

    run "${SCRIPT}" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Corrupted structure detected"* ]]
}
