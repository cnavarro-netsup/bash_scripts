#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/scripts/cp_vm.sh"
    TEST_ROOT="$(mktemp -d)"
    BACKUP_DIR="${TEST_ROOT}/backups"
    MAP_FILE="${TEST_ROOT}/vm_hypervisor.map"
    BIN_DIR="${TEST_ROOT}/bin"
    mkdir -p "${BACKUP_DIR}" "${BIN_DIR}"

    export SSH_LOG="${TEST_ROOT}/ssh.log"
    export PV_LOG="${TEST_ROOT}/pv.log"
    export DD_LOG="${TEST_ROOT}/dd.log"
    export DF_AVAIL="5000"
    export LV_SIZE="1000"
    export DD_STDOUT_CONTENT="STREAMDATA"
    export XML_EXISTS="TRUE"
    export XML_CONTENT="<domain type='kvm'><name>txs03</name></domain>"
    export DATE_FIXED="31032026"
    export ASSUME_YES="TRUE"

    cat > "${MAP_FILE}" <<EOF
txs03 hypervisor-a
ldap01 hypervisor-b
EOF

    cat > "${BIN_DIR}/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
host="$1"
shift
cmd="$*"
printf '%s|%s\n' "${host}" "${cmd}" >> "${SSH_LOG}"

case "${cmd}" in
    *"lvs --noheadings --units b --nosuffix -o lv_size '/dev/"*)
        printf '%s\n' "${LV_SIZE}"
        ;;
    *"test -f '/etc/libvirt/qemu/"*" && cat '/etc/libvirt/qemu/"*)
        if [ "${XML_EXISTS}" = "TRUE" ]; then
            printf '%s\n' "${XML_CONTENT}"
            exit 0
        fi
        exit 1
        ;;
    *"dd if='"*)
        printf '%s' "${DD_STDOUT_CONTENT}"
        ;;
    *"lvcreate -L "*)
        exit 0
        ;;
    *"lvremove -f '/dev/"*)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF

    cat > "${BIN_DIR}/pv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${PV_LOG}"
cat
EOF

    cat > "${BIN_DIR}/dd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${DD_LOG}"
outfile=""

for arg in "$@"; do
    case "${arg}" in
        of=*) outfile="${arg#of=}" ;;
    esac
done

if [ -n "${outfile}" ]; then
    cat > "${outfile}"
else
    cat
fi
EOF

    cat > "${BIN_DIR}/df" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'Avail\n%s\n' "${DF_AVAIL}"
EOF

    cat > "${BIN_DIR}/date" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = "+%d%m%Y" ]; then
    printf '%s\n' "${DATE_FIXED}"
    exit 0
fi
exec /usr/bin/date "$@"
EOF

    chmod +x "${BIN_DIR}/ssh" "${BIN_DIR}/pv" "${BIN_DIR}/dd" "${BIN_DIR}/df" "${BIN_DIR}/date"
    export PATH="${BIN_DIR}:${PATH}"
}

teardown()
{
    rm -rf "${TEST_ROOT}"
}

@test "AC-001: Muestra ayuda con -h" {
    run "${SCRIPT}" -h
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Uso:"* ]]
    [[ "${output}" == *"-v  Nombre de la VM"* ]]
    [[ "${output}" == *"/srv/bk-vm"* ]]
}

@test "AC-002: Falla si falta -v" {
    run "${SCRIPT}" -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Debe proveer una VM usando -v <vm>."* ]]
}

@test "AC-003: Falla con tipo invalido" {
    run "${SCRIPT}" -v txs03 -t invalido -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"El tipo de backup debe ser 'snap' o 'lv'."* ]]
}

@test "AC-004: Resuelve correctamente el hypervisor del mapa" {
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}" -D
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"HYPERVISOR        : hypervisor-a"* ]]
}

@test "AC-005: Falla si la VM no existe en el mapa" {
    run "${SCRIPT}" -v inexistente -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"No existe un hypervisor mapeado para la VM inexistente."* ]]
}

@test "AC-006: Tipo snap arma snapshot, copia y cleanup" {
    run "${SCRIPT}" -v txs03 -t snap -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 0 ]
    [ -f "${BACKUP_DIR}/txs03-31032026.xml" ]
    [ -f "${BACKUP_DIR}/lv_txs03_os_snap-31032026" ]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" == *"test -f '/etc/libvirt/qemu/txs03.xml' && cat '/etc/libvirt/qemu/txs03.xml'"* ]]
    [[ "${ssh_calls}" == *"lvcreate -L 1G -s -n 'snap' '/dev/vg_vm/lv_txs03_os'"* ]]
    [[ "${ssh_calls}" == *"dd if='/dev/vg_vm/snap' bs=4M status=none"* ]]
    [[ "${ssh_calls}" == *"lvremove -f '/dev/vg_vm/snap'"* ]]
}

@test "AC-007: Tipo lv copia sin snapshot" {
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 0 ]
    [ -f "${BACKUP_DIR}/lv_txs03_os-31032026" ]
    ssh_calls="$(<"${SSH_LOG}")"
    [[ "${ssh_calls}" == *"dd if='/dev/vg_vm/lv_txs03_os' bs=4M status=none"* ]]
    [[ "${ssh_calls}" != *"lvcreate -L 1G"* ]]
}

@test "AC-008: Dry-run muestra plan y no crea archivo" {
    run "${SCRIPT}" -v txs03 -t snap -m "${MAP_FILE}" -b "${BACKUP_DIR}" -D
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[DRY-RUN] ssh hypervisor-a \"test -f '/etc/libvirt/qemu/txs03.xml' && cat '/etc/libvirt/qemu/txs03.xml'\" > \"${BACKUP_DIR}/txs03-31032026.xml\""* ]]
    [[ "${output}" == *"[DRY-RUN] ssh hypervisor-a \"lvcreate -L 1G -s -n 'snap' '/dev/vg_vm/lv_txs03_os'\""* ]]
    [ ! -e "${BACKUP_DIR}/lv_txs03_os_snap-31032026" ]
}

@test "AC-009: Falla con espacio insuficiente" {
    export DF_AVAIL="1049"
    export LV_SIZE="1000"
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Error: espacio insuficiente"* ]]
    [[ "${output}" == *"Espacio requerido  : 1050"* ]]
    [[ "${output}" == *"Espacio disponible : 1049"* ]]
}

@test "AC-010: Falla si el destino ya existe" {
    : > "${BACKUP_DIR}/lv_txs03_os-31032026"
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"El archivo destino ya existe"* ]]
}

@test "AC-011: Falla si el XML destino ya existe" {
    : > "${BACKUP_DIR}/txs03-31032026.xml"
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"El archivo XML destino ya existe"* ]]
}

@test "AC-012: Si falla el XML remoto emite warning y continua con el disco" {
    export XML_EXISTS="FALSE"
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"No se pudo copiar la configuracion XML remota /etc/libvirt/qemu/txs03.xml. El backup del disco continuara igualmente."* ]]
    [[ "${output}" == *"El backup del disco finalizo correctamente, pero la configuracion XML no pudo copiarse."* ]]
    [ ! -e "${BACKUP_DIR}/txs03-31032026.xml" ]
    [ -f "${BACKUP_DIR}/lv_txs03_os-31032026" ]
}

@test "Usa dd local con conv=fsync y status=none" {
    run "${SCRIPT}" -v txs03 -t lv -m "${MAP_FILE}" -b "${BACKUP_DIR}"
    [ "${status}" -eq 0 ]
    dd_calls="$(<"${DD_LOG}")"
    [[ "${dd_calls}" == *"of=${BACKUP_DIR}/lv_txs03_os-31032026 bs=4M conv=fsync status=none"* ]]
}
