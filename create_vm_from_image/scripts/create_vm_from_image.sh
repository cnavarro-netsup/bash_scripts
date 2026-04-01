#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: create_vm_from_image.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: OpenAI gpt-5.4
# FECHA: 01/Abril/2026
# DESCRIPCION: Crea y arranca una VM temporal local desde una imagen de backup
#              y un XML de libvirt, aislando su red y mostrando el comando de consola.
#
# REQUERIMIENTOS: Acceso operativo a libvirt/KVM local en nas03 y utilidades
#                 virsh, xmlstarlet, virt-xml-validate y realpath instaladas.
# USO: ./create_vm_from_image.sh -i <imagen> -c <xml> [opciones]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACION INICIAL
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck source=lib/logger.sh
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error critico: No se encontro logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. DEFINICION DE VARIABLES DE EJECUCION CON DEFAULT FALLBACKS
# -----------------------------------------------------------------------------

: "${DEBUG:=FALSE}"
: "${ASSUME_YES:=FALSE}"
: "${DRY_RUN:=FALSE}"
: "${IMAGE_FILE:=}"
: "${CONFIG_FILE:=}"
: "${ISOLATED_NETWORK:=dumb}"

readonly VIEWER_HOST="nas03"
readonly MAX_VCPU="3"
readonly FORCED_MEMORY_KIB="2097152"

RESOLVED_IMAGE_FILE=""
RESOLVED_CONFIG_FILE=""
TEMP_XML=""
XML_VM_NAME=""
IMAGE_VM_NAME=""
XML_VCPU=""
XML_MEMORY=""
XML_MEMORY_UNIT=""

# -----------------------------------------------------------------------------
# 3. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

cleanup()
{
    set +e

    if [ -n "${TEMP_XML}" ] && [ -f "${TEMP_XML}" ]; then
        rm -f "${TEMP_XML}" >/dev/null 2>&1
    fi
}
trap cleanup EXIT ERR INT TERM

#--------------------------------------
usage()
{
    local script_name
    script_name="${0##*/}"

    cat <<EOF
Uso:
  ./${script_name} -i <imagen> -c <xml> [opciones]

Obligatorios:
  -i  Ruta local de la imagen de disco respaldada
  -c  Ruta local del XML de libvirt respaldado

Opciones:
  -d  Debug (activa trazas de log extra)
  -y  Asumir "si" a las confirmaciones
  -D  Mostrar el plan de ejecucion sin definir ni arrancar la VM
  -h  Mostrar esta ayuda

Ejemplos:
  ./${script_name} -i /srv/bk-vm/lv_txs03_os_snap-01042026 -c /srv/bk-vm/txs03-01042026.xml
  ./${script_name} -i /srv/bk-vm/lv_txs03_os-01042026 -c /srv/bk-vm/txs03-01042026.xml -D
EOF
}

#--------------------------------------
confirm_or_exit()
{
    if [ "${ASSUME_YES}" = "TRUE" ] || [ "${DRY_RUN}" = "TRUE" ]; then
        return 0
    fi

    local confirm
    read -r -p "¿Continuar? (s/N): " confirm
    case "${confirm:-}" in
        s|S|si|SI|Si) return 0 ;;
        *) echo -e "${R}Cancelado por el usuario.${N}"; exit 1 ;;
    esac
}

#--------------------------------------
require_command()
{
    local binary_name="$1"

    if ! command -v "${binary_name}" >/dev/null 2>&1; then
        die "Dependencia local ausente: ${binary_name}" 1
    fi
}

#--------------------------------------
validate_environment()
{
    require_command "virsh"
    require_command "xmlstarlet"
    require_command "virt-xml-validate"
    require_command "realpath"
    require_command "mktemp"
    require_command "cp"
    require_command "basename"
    require_command "date"
}

#--------------------------------------
validate_args()
{
    if [ -z "${IMAGE_FILE}" ]; then
        log_error "Debe proveer la imagen con -i <imagen>."
        usage
        exit 1
    fi

    if [ -z "${CONFIG_FILE}" ]; then
        log_error "Debe proveer el XML con -c <xml>."
        usage
        exit 1
    fi
}

#--------------------------------------
resolve_paths()
{
    if [ ! -f "${IMAGE_FILE}" ]; then
        die "No existe la imagen indicada: ${IMAGE_FILE}" 1
    fi

    if [ ! -f "${CONFIG_FILE}" ]; then
        die "No existe el XML indicado: ${CONFIG_FILE}" 1
    fi

    RESOLVED_IMAGE_FILE="$(realpath "${IMAGE_FILE}")"
    RESOLVED_CONFIG_FILE="$(realpath "${CONFIG_FILE}")"
}

#--------------------------------------
extract_vm_name_from_xml()
{
    XML_VM_NAME="$(xmlstarlet sel -t -v '/domain/name' "${RESOLVED_CONFIG_FILE}" 2>/dev/null || true)"

    if [ -z "${XML_VM_NAME}" ]; then
        die "No se pudo extraer /domain/name desde el XML: ${RESOLVED_CONFIG_FILE}" 1
    fi
}

#--------------------------------------
extract_resource_requirements_from_xml()
{
    XML_VCPU="$(xmlstarlet sel -t -v '/domain/vcpu' "${RESOLVED_CONFIG_FILE}" 2>/dev/null || true)"
    XML_MEMORY="$(xmlstarlet sel -t -v '/domain/memory' "${RESOLVED_CONFIG_FILE}" 2>/dev/null || true)"
    XML_MEMORY_UNIT="$(xmlstarlet sel -t -v 'string(/domain/memory/@unit)' "${RESOLVED_CONFIG_FILE}" 2>/dev/null || true)"

    if [[ ! "${XML_VCPU}" =~ ^[0-9]+$ ]] || [ "${XML_VCPU}" -le 0 ]; then
        die "El XML no contiene una cantidad valida de vCPU en /domain/vcpu." 1
    fi

    if [[ ! "${XML_MEMORY}" =~ ^[0-9]+$ ]] || [ "${XML_MEMORY}" -le 0 ]; then
        die "El XML no contiene una cantidad valida de RAM en /domain/memory." 1
    fi

    if [ -z "${XML_MEMORY_UNIT}" ]; then
        XML_MEMORY_UNIT="KiB"
    fi
}

extract_vm_name_from_image()
{
    local image_basename
    image_basename="$(basename "${RESOLVED_IMAGE_FILE}")"

    if [[ "${image_basename}" =~ ^lv_(.+)_os(_snap)?-[0-9]{8}$ ]]; then
        IMAGE_VM_NAME="${BASH_REMATCH[1]}"
        return 0
    fi

    die "No se pudo deducir el nombre de VM desde la imagen: ${image_basename}" 1
}

#--------------------------------------
validate_vm_identity()
{
    if [ "${IMAGE_VM_NAME}" != "${XML_VM_NAME}" ]; then
        die "La imagen corresponde a '${IMAGE_VM_NAME}' pero el XML define '${XML_VM_NAME}'." 1
    fi
}

#--------------------------------------
validate_libvirt_targets()
{
    if virsh dominfo "${XML_VM_NAME}" >/dev/null 2>&1; then
        die "La VM '${XML_VM_NAME}' ya existe en el libvirt local." 1
    fi

    if ! virsh net-info "${ISOLATED_NETWORK}" >/dev/null 2>&1; then
        die "La network libvirt '${ISOLATED_NETWORK}' no existe en el host local." 1
    fi
}

#--------------------------------------
prepare_temp_xml()
{
    local disk_count
    local interface_count

    TEMP_XML="$(mktemp "${TMPDIR:-/tmp}/create_vm_from_image.XXXXXX.xml")"
    cp "${RESOLVED_CONFIG_FILE}" "${TEMP_XML}"

    disk_count="$(xmlstarlet sel -t -v "count(/domain/devices/disk[@device='disk'])" "${TEMP_XML}" 2>/dev/null || true)"
    interface_count="$(xmlstarlet sel -t -v 'count(/domain/devices/interface)' "${TEMP_XML}" 2>/dev/null || true)"

    if [ "${disk_count}" = "0" ] || [ -z "${disk_count}" ]; then
        die "El XML no contiene un disco principal reutilizable." 1
    fi

    if [ "${interface_count}" = "0" ] || [ -z "${interface_count}" ]; then
        die "El XML no contiene una interfaz de red reutilizable." 1
    fi
}

#--------------------------------------
rewrite_temp_xml()
{
    local current_memory_count

    current_memory_count="$(xmlstarlet sel -t -v 'count(/domain/currentMemory)' "${TEMP_XML}" 2>/dev/null || true)"

    if ! xmlstarlet ed --inplace \
        -u "/domain/devices/disk[@device='disk'][1]/@type" -v "file" \
        -d "/domain/devices/disk[@device='disk'][1]/source" \
        -s "/domain/devices/disk[@device='disk'][1]" -t elem -n "source_tmp_disk" -v "" \
        -i "/domain/devices/disk[@device='disk'][1]/source_tmp_disk" -t attr -n "file" -v "${RESOLVED_IMAGE_FILE}" \
        -r "/domain/devices/disk[@device='disk'][1]/source_tmp_disk" -v "source" \
        -u "/domain/devices/interface[1]/@type" -v "network" \
        -d "/domain/devices/interface[1]/source" \
        -s "/domain/devices/interface[1]" -t elem -n "source_tmp_network" -v "" \
        -i "/domain/devices/interface[1]/source_tmp_network" -t attr -n "network" -v "${ISOLATED_NETWORK}" \
        -r "/domain/devices/interface[1]/source_tmp_network" -v "source" \
        -u "/domain/vcpu" -v "${MAX_VCPU}" \
        -u "/domain/memory" -v "${FORCED_MEMORY_KIB}" \
        -u "/domain/memory/@unit" -v "KiB" \
        -d "/domain/cpu/topology" \
        "${TEMP_XML}" >/dev/null 2>&1; then
        die "No se pudo adaptar el XML temporal para la imagen y red aislada." 1
    fi

    if [ "${current_memory_count}" != "0" ]; then
        if ! xmlstarlet ed --inplace \
            -u "/domain/currentMemory" -v "${FORCED_MEMORY_KIB}" \
            -u "/domain/currentMemory/@unit" -v "KiB" \
            "${TEMP_XML}" >/dev/null 2>&1; then
            die "No se pudo fijar currentMemory en el XML temporal." 1
        fi
    fi
}

#--------------------------------------
validate_temp_xml()
{
    if ! virt-xml-validate "${TEMP_XML}" domain >/dev/null 2>&1; then
        die "El XML temporal no es compatible con la validacion local de libvirt/KVM." 1
    fi
}

#--------------------------------------
print_execution_context()
{
    echo -e "${G} Variables de Ejecucion ${N}"
    echo "IMAGE_FILE       : ${RESOLVED_IMAGE_FILE}"
    echo "CONFIG_FILE      : ${RESOLVED_CONFIG_FILE}"
    echo "VM_NAME          : ${XML_VM_NAME}"
    echo "XML_VCPU         : ${XML_VCPU}"
    echo "XML_MEMORY       : ${XML_MEMORY} ${XML_MEMORY_UNIT}"
    echo "FORCED_VCPU      : ${MAX_VCPU}"
    echo "FORCED_MEMORY    : ${FORCED_MEMORY_KIB} KiB"
    echo "ISOLATED_NETWORK : ${ISOLATED_NETWORK}"
    echo "TEMP_XML         : ${TEMP_XML}"
    echo "VIEWER_HOST      : ${VIEWER_HOST}"
    echo "DEBUG            : ${DEBUG}"
    echo "DRY_RUN          : ${DRY_RUN}"
}

#--------------------------------------
print_original_resource_messages()
{
    log_info "vCPU indicadas en el XML original: ${XML_VCPU}"
    log_info "RAM indicada en el XML original: ${XML_MEMORY} ${XML_MEMORY_UNIT}"
    log_info "La VM temporal se creara con ${MAX_VCPU} vCPU y ${FORCED_MEMORY_KIB} KiB de RAM"
}

#--------------------------------------
define_vm()
{
    log_info "Definiendo VM temporal ${XML_VM_NAME}."

    if ! virsh define "${TEMP_XML}" >/dev/null 2>&1; then
        die "No se pudo definir la VM '${XML_VM_NAME}' con el XML transformado." 1
    fi
}

#--------------------------------------
start_vm()
{
    log_info "Arrancando VM temporal ${XML_VM_NAME}."

    if ! virsh start "${XML_VM_NAME}" >/dev/null 2>&1; then
        die "No se pudo arrancar la VM '${XML_VM_NAME}'." 1
    fi
}

#--------------------------------------
print_console_command()
{
    echo "virt-viewer -c qemu+ssh://{usuario}@${VIEWER_HOST}/system ${XML_VM_NAME}"
}

# -----------------------------------------------------------------------------
# 4. FUNCION PRINCIPAL MAIN (PARSEO Y LOGICA)
# -----------------------------------------------------------------------------

main()
{
    while getopts ":i:c:dyDh" opt; do
        case "${opt}" in
            i) IMAGE_FILE="${OPTARG}" ;;
            c) CONFIG_FILE="${OPTARG}" ;;
            d) DEBUG="TRUE" ;;
            y) ASSUME_YES="TRUE" ;;
            D) DRY_RUN="TRUE" ;;
            h) usage; exit 0 ;;
            :) log_error "Error: -${OPTARG} requiere un argumento."; usage; exit 2 ;;
            \?) log_error "Error: opcion invalida -${OPTARG}"; usage; exit 2 ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    validate_args
    validate_environment
    resolve_paths
    extract_vm_name_from_xml
    extract_resource_requirements_from_xml
    print_original_resource_messages
    extract_vm_name_from_image
    validate_vm_identity
    validate_libvirt_targets
    prepare_temp_xml
    rewrite_temp_xml
    validate_temp_xml
    print_execution_context
    confirm_or_exit

    if [ "${DRY_RUN}" = "TRUE" ]; then
        log_info "[DRY-RUN] Simulacion concluida. No se definio ni arranco ninguna VM."
        print_console_command
        exit 0
    fi

    define_vm
    start_vm
    print_console_command
}

main "$@"
