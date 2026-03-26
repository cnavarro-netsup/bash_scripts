#!/usr/bin/env bats

setup()
{
    export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export SCRIPT_PATH="${PROJECT_ROOT}/scripts/copia_dbf.sh"
    export MOCK_DIR="$(mktemp -d)"
    export TEST_LOG_FILE="${MOCK_DIR}/copia_dbf.log"

    export PATH="${MOCK_DIR}:$PATH"
    export LOG_FILE="${TEST_LOG_FILE}"

    cat <<'EOF' > "${MOCK_DIR}/ssh"
#!/usr/bin/env bash
if [ "${MOCK_SSH_FAIL:-0}" = "1" ]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${MOCK_DIR}/ssh"

    cat <<'EOF' > "${MOCK_DIR}/rsync"
#!/usr/bin/env bash
if [ "$1" = "-avz" ] && [ "${2:-}" = "Administrador@txs02:/cygdrive/d/Aplicaciones/FoxApp/Planif/*.DBF" ]; then
    if [ "${MOCK_STAGE1_FAIL:-0}" = "1" ]; then
        printf 'stage1 failed\n' >&2
        exit 1
    fi

    printf 'sending incremental file list\n'
    if [ "${MOCK_ONLY_LOWERCASE_SOURCE:-0}" = "1" ]; then
        printf '\n'
    else
        printf 'PLANIF_A.DBF\n'
        printf 'PLANIF_B.DBF\n'
        : > /tmp/PLANIF_A.DBF
        : > /tmp/PLANIF_B.DBF
    fi
    printf '\nsent 100 bytes  received 20 bytes  total size 0\n'
    exit 0
fi

if [ "$1" = "-avz" ] && [ "${2:-}" = "--chmod=F600,D700" ]; then
    if [ "${MOCK_STAGE2_FAIL:-0}" = "1" ]; then
        printf 'stage2 failed\n' >&2
        exit 1
    fi

    printf 'sending incremental file list\n'
    if [ "${MOCK_STAGE2_NO_NEW_FILES:-0}" = "1" ]; then
        printf '\n'
    else
        printf 'PLANIF_A.DBF\n'
        printf 'PLANIF_B.DBF\n'
    fi
    printf '\nsent 120 bytes  received 30 bytes  total size 0\n'
    exit 0
fi

printf 'unexpected rsync invocation\n' >&2
exit 1
EOF
    chmod +x "${MOCK_DIR}/rsync"

    rm -f /tmp/PLANIF_A.DBF /tmp/PLANIF_B.DBF /tmp/planif_c.dbf
}

teardown()
{
    rm -f /tmp/PLANIF_A.DBF /tmp/PLANIF_B.DBF /tmp/planif_c.dbf
    rm -rf "${MOCK_DIR}"
}

@test "AC-001: -h shows help" {
    run bash "${SCRIPT_PATH}" -h
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
}

@test "AC-005: invalid option fails" {
    run bash "${SCRIPT_PATH}" -x
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"invalid option"* ]]
}

@test "AC-005: -d and -h together fail" {
    run bash "${SCRIPT_PATH}" -d -h
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"cannot be combined"* ]]
}

@test "AC-003: no remote uppercase DBF files fails" {
    export MOCK_SSH_FAIL=1
    run bash "${SCRIPT_PATH}"
    [ "${status}" -eq 1 ]
    [[ ! -s "${TEST_LOG_FILE}" || "$(<"${TEST_LOG_FILE}")" == *"No uppercase DBF files found on remote source host."* ]]
}

@test "AC-006: lowercase dbf files are ignored" {
    export MOCK_SSH_FAIL=1
    : > /tmp/planif_c.dbf
    run bash "${SCRIPT_PATH}"
    [ "${status}" -eq 1 ]
    [[ ! -e /tmp/PLANIF_A.DBF ]]
}

@test "AC-002: debug mode completes both stages" {
    run bash "${SCRIPT_PATH}" -d
    [ "${status}" -eq 0 ]
    [ -f "${TEST_LOG_FILE}" ]
    [[ "$(<"${TEST_LOG_FILE}")" == *"Stage 1 copied file: PLANIF_A.DBF"* ]]
    [[ "$(<"${TEST_LOG_FILE}")" == *"Stage 2 transferred file: PLANIF_B.DBF"* ]]
}

@test "AC-004: no new remote files still succeeds" {
    export MOCK_STAGE2_NO_NEW_FILES=1
    run bash "${SCRIPT_PATH}"
    [ "${status}" -eq 0 ]
    [[ "$(<"${TEST_LOG_FILE}")" == *"No new DBF files transferred to remote host."* ]]
}
