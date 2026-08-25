#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    BIN_DIR="${TEST_ROOT}/bin"
    BACKUP_DIR="${TEST_ROOT}/backup"
    SCRIPT="${TEST_ROOT}/cp_vm_rrhh_datos.sh"
    mkdir -p "${BIN_DIR}" "${BACKUP_DIR}"

    sed \
        -e "s|^project_root=.*$|project_root=\"${PROJECT_ROOT}\"|" \
        -e "s|backup_dir=\"/srv/bk_vm\"|backup_dir=\"${BACKUP_DIR}\"|" \
        "${PROJECT_ROOT}/cp_vm_rrhh_datos/scripts/cp_vm_rrhh_datos.sh" > "${SCRIPT}"

    export SSH_LOG="${TEST_ROOT}/ssh.log"
    export SNAP_PREEXIST="FALSE"
    export FAIL_LOCAL_DD="FALSE"
    export RUN_DATE_FIXED="01011970"
    : > "${SSH_LOG}"

    cat > "${BIN_DIR}/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'ARGS|%s\n' "$*" >> "${SSH_LOG}"
while [ "${1:-}" = "-o" ]; do
    shift 2
done
host="$1"
shift
command_text="$*"
printf '%s|%s\n' "${host}" "${command_text}" >> "${SSH_LOG}"
case "${command_text}" in
    "test -e '/dev/vg_vm/snap'")
        [ "${SNAP_PREEXIST}" = "TRUE" ]
        ;;
    "dd if='/dev/vg_vm/snap' bs=4M status=none")
        printf 'snapshot-data'
        ;;
    *) exit 0 ;;
esac
EOF

    cat > "${BIN_DIR}/pv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat
EOF

    cat > "${BIN_DIR}/dd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
for argument in "$@"; do
    case "${argument}" in
        of=*) output="${argument#of=}" ;;
    esac
done
if [ -n "${output}" ]; then
    cat > "${output}"
    if [ "${FAIL_LOCAL_DD}" = "TRUE" ]; then
        exit 1
    fi
else
    cat
fi
EOF

    cat > "${BIN_DIR}/date" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "+%d%m%Y" ]; then
    printf '%s\n' "${RUN_DATE_FIXED}"
else
    printf '1970-01-01 00:00:00\n'
fi
EOF

    chmod +x "${SCRIPT}" "${BIN_DIR}/ssh" "${BIN_DIR}/pv" \
        "${BIN_DIR}/dd" "${BIN_DIR}/date"
    export PATH="${BIN_DIR}:${PATH}"
}

teardown()
{
    rm -rf "${TEST_ROOT}"
}

@test "muestra ayuda y rechaza argumentos no admitidos" {
    run "${SCRIPT}" -h
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Uso:"* ]]
    [[ "${output}" == *"-D  Mostrar el plan"* ]]

    run "${SCRIPT}" -z
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"opcion invalida -z"* ]]

    run "${SCRIPT}" argumento
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"No se permiten argumentos posicionales"* ]]
}

@test "dry-run muestra ambos volúmenes sin crear recursos" {
    run "${SCRIPT}" -D
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"lv_rrhh_data1"* ]]
    [[ "${output}" == *"lv_rrhh_data2"* ]]
    [[ "${output}" == *"Dry-run finalizado sin cambios"* ]]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" != *"lvcreate -L 1G"* ]]
    [ ! -e "${BACKUP_DIR}/lv_rrhh_data1_snap-01011970" ]
    [ ! -e "${BACKUP_DIR}/lv_rrhh_data2_snap-01011970" ]
}

@test "procesa data1 y data2 secuencialmente con SSH estricto" {
    run "${SCRIPT}" -y
    [ "${status}" -eq 0 ]
    [ "$(<"${BACKUP_DIR}/lv_rrhh_data1_snap-01011970")" = "snapshot-data" ]
    [ "$(<"${BACKUP_DIR}/lv_rrhh_data2_snap-01011970")" = "snapshot-data" ]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" == *"lvcreate -L 1G -s -n 'snap' '/dev/vg_vm/lv_rrhh_data1'"*"dd if='/dev/vg_vm/snap'"*"lvremove -f '/dev/vg_vm/snap'"*"lvcreate -L 1G -s -n 'snap' '/dev/vg_vm/lv_rrhh_data2'"* ]]
    [[ "${ssh_calls}" == *"-o BatchMode=yes -o StrictHostKeyChecking=yes root@vm017"* ]]
    [[ "${output}" != *"Variables de Ejecucion"* ]]
}

@test "aborta sin retirar un snapshot preexistente" {
    export SNAP_PREEXIST="TRUE"
    run "${SCRIPT}" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Ya existe el snapshot remoto"* ]]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" != *"lvremove -f"* ]]
}

@test "aborta sin sobrescribir un destino preexistente" {
    printf 'existente' > "${BACKUP_DIR}/lv_rrhh_data1_snap-01011970"
    run "${SCRIPT}" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"El destino ya existe"* ]]
    [ "$(<"${BACKUP_DIR}/lv_rrhh_data1_snap-01011970")" = "existente" ]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" != *"lvcreate -L 1G"* ]]
}

@test "ante fallo descarta temporal y retira solo el snapshot propio" {
    export FAIL_LOCAL_DD="TRUE"
    run "${SCRIPT}" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Fallo la copia del snapshot de lv_rrhh_data1"* ]]
    [ ! -e "${BACKUP_DIR}/.lv_rrhh_data1_snap-01011970.partial" ]
    [ ! -e "${BACKUP_DIR}/lv_rrhh_data1_snap-01011970" ]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" == *"lvcreate -L 1G"* ]]
    [[ "${ssh_calls}" == *"lvremove -f '/dev/vg_vm/snap'"* ]]
}
