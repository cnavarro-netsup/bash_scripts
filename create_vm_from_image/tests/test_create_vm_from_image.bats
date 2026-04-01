#!/usr/bin/env bats

setup()
{
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/create_vm_from_image.sh"
    export TEST_TMP="$(mktemp -d)"
    export MOCK_DIR="${TEST_TMP}/bin"
    mkdir -p "${MOCK_DIR}"

    export PATH="${MOCK_DIR}:$PATH"
    export XMLSTARLET_ED_LOG="${TEST_TMP}/xmlstarlet_ed.log"

    cat <<'EOF' > "${MOCK_DIR}/virsh"
#!/usr/bin/env bash
case "$1" in
    dominfo)
        if [ "${VM_EXISTS:-0}" = "1" ]; then
            exit 0
        fi
        exit 1
        ;;
    net-info)
        if [ "${NETWORK_EXISTS:-1}" = "1" ]; then
            exit 0
        fi
        exit 1
        ;;
    define)
        if [ "${DEFINE_FAIL:-0}" = "1" ]; then
            exit 1
        fi
        exit 0
        ;;
    start)
        if [ "${START_FAIL:-0}" = "1" ]; then
            exit 1
        fi
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "${MOCK_DIR}/virsh"

    cat <<'EOF' > "${MOCK_DIR}/xmlstarlet"
#!/usr/bin/env bash
if [ "$1" = "sel" ]; then
    full_cmd="$*"
    case "${full_cmd}" in
        *"/domain/name"*)
            printf '%s' "${MOCK_VM_NAME:-demo01}"
            exit 0
            ;;
        *"/domain/vcpu"*)
            printf '%s' "${MOCK_VCPU:-2}"
            exit 0
            ;;
        *"/domain/memory"*"@unit"*)
            printf '%s' "${MOCK_MEMORY_UNIT:-KiB}"
            exit 0
            ;;
        *"count(/domain/currentMemory)"*)
            printf '%s' "${MOCK_CURRENT_MEMORY_COUNT:-1}"
            exit 0
            ;;
        *"/domain/memory"*)
            printf '%s' "${MOCK_MEMORY:-2097152}"
            exit 0
            ;;
        *"count(/domain/devices/disk[@device='disk'])"*)
            printf '%s' "${MOCK_DISK_COUNT:-1}"
            exit 0
            ;;
        *"count(/domain/devices/interface)"*)
            printf '%s' "${MOCK_INTERFACE_COUNT:-1}"
            exit 0
            ;;
    esac
fi

if [ "$1" = "ed" ]; then
    if [ "${XML_EDIT_FAIL:-0}" = "1" ]; then
        exit 1
    fi
    printf '%s\n' "$*" >> "${XMLSTARLET_ED_LOG}"
    exit 0
fi

exit 1
EOF
    chmod +x "${MOCK_DIR}/xmlstarlet"

    cat <<'EOF' > "${MOCK_DIR}/virt-xml-validate"
#!/usr/bin/env bash
if [ "${XML_INVALID:-0}" = "1" ]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${MOCK_DIR}/virt-xml-validate"

    cat <<'EOF' > "${MOCK_DIR}/realpath"
#!/usr/bin/env bash
if [[ "$1" = /* ]]; then
    printf '%s\n' "$1"
else
    printf '%s/%s\n' "$PWD" "$1"
fi
EOF
    chmod +x "${MOCK_DIR}/realpath"

    cat <<'EOF' > "${TEST_TMP}/demo01-01042026.xml"
<domain type='kvm'>
  <name>demo01</name>
  <devices>
    <disk type='file' device='disk'>
      <source file='/tmp/original.img'/>
    </disk>
    <interface type='bridge'>
      <source bridge='br0'/>
    </interface>
  </devices>
</domain>
EOF

    touch "${TEST_TMP}/lv_demo01_os_snap-01042026"
    touch "${TEST_TMP}/lv_demo02_os_snap-01042026"
}

teardown()
{
    rm -rf "${TEST_TMP}"
}

@test "AC-001: -h muestra ayuda" {
    run bash "${SCRIPT_PATH}" -h
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Uso:"* ]]
}

@test "AC-002: falla cuando falta -i" {
    run bash "${SCRIPT_PATH}" -c "${TEST_TMP}/demo01-01042026.xml"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Debe proveer la imagen"* ]]
}

@test "AC-003: falla cuando falta -c" {
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Debe proveer el XML"* ]]
}

@test "AC-004: falla cuando la imagen no existe" {
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/no_existe" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"No existe la imagen indicada"* ]]
}

@test "AC-005: falla cuando imagen y XML pertenecen a VMs distintas" {
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo02_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"La imagen corresponde a 'demo02' pero el XML define 'demo01'"* ]]
}

@test "AC-006: falla cuando la VM ya existe" {
    export VM_EXISTS=1
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"ya existe en el libvirt local"* ]]
}

@test "AC-007: informa las vCPU y RAM originales aunque superen los recursos finales" {
    export MOCK_VCPU=4
    export MOCK_MEMORY=3145728
    export MOCK_MEMORY_UNIT=KiB
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"vCPU indicadas en el XML original: 4"* ]]
    [[ "${output}" == *"RAM indicada en el XML original: 3145728 KiB"* ]]
    [[ "${output}" == *"La VM temporal se creara con 3 vCPU y 2097152 KiB de RAM"* ]]
}

@test "AC-008: fuerza 3 vCPU y 2097152 KiB en el XML temporal" {
    export MOCK_VCPU=8
    export MOCK_MEMORY=8388608
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 0 ]
    [[ "$(cat "${XMLSTARLET_ED_LOG}")" == *"-u /domain/vcpu -v 3"* ]]
    [[ "$(cat "${XMLSTARLET_ED_LOG}")" == *"-u /domain/memory -v 2097152"* ]]
    [[ "$(cat "${XMLSTARLET_ED_LOG}")" == *"-u /domain/memory/@unit -v KiB"* ]]
}

@test "AC-009: falla cuando la network dumb no existe" {
    export NETWORK_EXISTS=0
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"La network libvirt 'dumb' no existe"* ]]
}

@test "AC-010: falla cuando el XML temporal no valida" {
    export XML_INVALID=1
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"XML temporal no es compatible"* ]]
}

@test "AC-011: falla cuando virsh define falla" {
    export DEFINE_FAIL=1
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"No se pudo definir la VM 'demo01'"* ]]
}

@test "AC-012: falla cuando virsh start falla" {
    export START_FAIL=1
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"No se pudo arrancar la VM 'demo01'"* ]]
}

@test "AC-013/AC-014: caso exitoso arranca la VM e imprime el comando de consola" {
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"virt-viewer -c qemu+ssh://{usuario}@nas03/system demo01"* ]]
}

@test "AC-015: dry-run no crea la VM y muestra el comando esperado" {
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -D
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[DRY-RUN] Simulacion concluida"* ]]
    [[ "${output}" == *"virt-viewer -c qemu+ssh://{usuario}@nas03/system demo01"* ]]
}

@test "XML invalido: falla cuando falta /domain/vcpu" {
    export MOCK_VCPU="invalido"
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"El XML no contiene una cantidad valida de vCPU"* ]]
}

@test "XML invalido: falla cuando falta /domain/memory" {
    export MOCK_MEMORY="invalida"
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"El XML no contiene una cantidad valida de RAM"* ]]
}

@test "Acepta cualquier recurso original y conserva el XML de copia intacto" {
    export MOCK_VCPU=12
    export MOCK_MEMORY=16777216
    export MOCK_MEMORY_UNIT=KiB
    run bash "${SCRIPT_PATH}" -i "${TEST_TMP}/lv_demo01_os_snap-01042026" -c "${TEST_TMP}/demo01-01042026.xml" -y
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"virt-viewer -c qemu+ssh://{usuario}@nas03/system demo01"* ]]
    [[ "$(cat "${TEST_TMP}/demo01-01042026.xml")" == *"<name>demo01</name>"* ]]
    [[ "$(cat "${TEST_TMP}/demo01-01042026.xml")" == *"<source file='/tmp/original.img'/>"* ]]
}
