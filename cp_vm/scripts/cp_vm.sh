#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: cp_vm.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: OpenAI gpt-5.4
# FECHA: 31/Marzo/2026
# DESCRIPCION: Copia el almacenamiento de una VM remota hacia un NAS local
#              desde un snapshot LVM o desde el LV nativo usando SSH, pv y dd.
#
# REQUERIMIENTOS: SSH con llave publica operativo, acceso a LVM remoto y
#                 permisos de escritura en el directorio local de backups.
# USO: ./cp_vm.sh -v <vm> [-t snap|lv] [opciones]
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
: "${VM_NAME:=}"
: "${BACKUP_TYPE:=snap}"
: "${MAP_FILE:=/etc/vm_hypervisor.map}"
: "${BACKUP_DIR:=/srv/bk-vm}"
: "${VG_NAME:=vg_vm}"
: "${SNAP_NAME:=snap}"
: "${SNAP_SIZE:=1G}"
: "${REMOTE_VM_CONFIG_DIR:=/etc/libvirt/qemu}"

RESOLVED_MAP_FILE=""
RESOLVED_BACKUP_DIR=""
HYPERVISOR=""
LV_NAME=""
LV_PATH=""
SOURCE_LV=""
SIZE_BYTES=""
AVAILABLE_BYTES=""
REQUIRED_BYTES=""
DEST_FILE=""
DEST_FILENAME=""
CONFIG_SOURCE_FILE=""
CONFIG_DEST_FILE=""
SNAP_CREATED="FALSE"
XML_COPY_FAILED="FALSE"

# -----------------------------------------------------------------------------
# 3. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

cleanup()
{
    set +e

    if [ "${SNAP_CREATED}" = "TRUE" ] && [ "${DRY_RUN}" != "TRUE" ] && [ -n "${HYPERVISOR}" ]; then
        # shellcheck disable=SC2029
        ssh "${HYPERVISOR}" "lvremove -f '/dev/${VG_NAME}/${SNAP_NAME}'" >/dev/null 2>&1
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
  ./${script_name} -v <vm> [-t snap|lv] [opciones]

Obligatorios:
  -v  Nombre de la VM

Opciones:
  -t  Tipo de backup: snap o lv (default: ${BACKUP_TYPE})
  -m  Archivo de mapeo VM->Hypervisor (default: ${MAP_FILE})
  -b  Directorio local de backups (default: ${BACKUP_DIR})
  -g  Nombre del VG remoto (default: ${VG_NAME})
  -s  Nombre del snapshot remoto (default: ${SNAP_NAME})
  -d  Debug (activa trazas de log extra)
  -y  Asumir "si" a las confirmaciones
  -D  Mostrar lo que se ejecutaria sin ejecutar cambios
  -h  Mostrar esta ayuda

Ejemplos:
  ./${script_name} -v ldap01
  ./${script_name} -v txs03 -t lv -b /srv/bk-vm
  ./${script_name} -v txs03 -t snap -D
EOF
}

#--------------------------------------
confirm_or_exit()
{
    if [ "${ASSUME_YES}" = "TRUE" ]; then
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
    require_command "ssh"
    require_command "pv"
    require_command "dd"
    require_command "df"
    require_command "realpath"
    require_command "awk"
    require_command "date"
}

#--------------------------------------
resolve_paths()
{
    if [ ! -f "${MAP_FILE}" ]; then
        die "No existe el archivo de mapeo: ${MAP_FILE}" 1
    fi

    if [ ! -d "${BACKUP_DIR}" ]; then
        die "No existe el directorio de backups: ${BACKUP_DIR}" 1
    fi

    RESOLVED_MAP_FILE="$(realpath "${MAP_FILE}")"
    RESOLVED_BACKUP_DIR="$(realpath "${BACKUP_DIR}")"
}

#--------------------------------------
validate_args()
{
    if [ -z "${VM_NAME}" ]; then
        log_error "Debe proveer una VM usando -v <vm>."
        usage
        exit 1
    fi

    case "${BACKUP_TYPE}" in
        snap|lv) ;;
        *)
            die "El tipo de backup debe ser 'snap' o 'lv'." 1
            ;;
    esac
}

#--------------------------------------
resolve_hypervisor()
{
    local mapped_vm=""
    local mapped_hypervisor=""
    local extra_field=""
    local matches=0

    while IFS=' ' read -r mapped_vm mapped_hypervisor extra_field; do
        if [[ -z "${mapped_vm}" || "${mapped_vm}" == \#* ]]; then
            continue
        fi

        if [ "${mapped_vm}" = "${VM_NAME}" ]; then
            if [ -n "${extra_field}" ] || [ -z "${mapped_hypervisor}" ]; then
                die "Entrada invalida en ${RESOLVED_MAP_FILE} para la VM ${VM_NAME}." 1
            fi

            matches=$(( matches + 1 ))
            HYPERVISOR="${mapped_hypervisor}"
        fi
    done < "${RESOLVED_MAP_FILE}"

    if [ "${matches}" -eq 0 ]; then
        die "No existe un hypervisor mapeado para la VM ${VM_NAME}." 1
    fi

    if [ "${matches}" -gt 1 ]; then
        die "Se encontraron multiples hypervisores para la VM ${VM_NAME}." 1
    fi
}

#--------------------------------------
prepare_volume_names()
{
    LV_NAME="lv_${VM_NAME}_os"
    LV_PATH="/dev/${VG_NAME}/${LV_NAME}"
    CONFIG_SOURCE_FILE="${REMOTE_VM_CONFIG_DIR}/${VM_NAME}.xml"
    CONFIG_DEST_FILE="${RESOLVED_BACKUP_DIR}/${VM_NAME}-$(date +%d%m%Y).xml"

    if [ "${BACKUP_TYPE}" = "snap" ]; then
        SOURCE_LV="/dev/${VG_NAME}/${SNAP_NAME}"
        DEST_FILENAME="${LV_NAME}_snap-$(date +%d%m%Y)"
    else
        SOURCE_LV="${LV_PATH}"
        DEST_FILENAME="${LV_NAME}-$(date +%d%m%Y)"
    fi

    DEST_FILE="${RESOLVED_BACKUP_DIR}/${DEST_FILENAME}"
}

#--------------------------------------
fetch_remote_lv_size()
{
    # shellcheck disable=SC2029
    SIZE_BYTES="$(ssh "${HYPERVISOR}" "lvs --noheadings --units b --nosuffix -o lv_size '${LV_PATH}' | tr -d '[:space:]'" 2>/dev/null || true)"

    if [[ ! "${SIZE_BYTES}" =~ ^[0-9]+$ ]]; then
        die "No se pudo obtener un tamano valido para el LV remoto ${LV_PATH}." 1
    fi
}

#--------------------------------------
fetch_available_space()
{
    AVAILABLE_BYTES="$(df --output=avail -B1 "${RESOLVED_BACKUP_DIR}" | awk 'NR==2 {print $1}')"

    if [[ ! "${AVAILABLE_BYTES}" =~ ^[0-9]+$ ]]; then
        die "No se pudo obtener el espacio libre del filesystem destino." 1
    fi
}

#--------------------------------------
validate_free_space()
{
    REQUIRED_BYTES=$(( (SIZE_BYTES * 105 + 99) / 100 ))

    if [ "${AVAILABLE_BYTES}" -lt "${REQUIRED_BYTES}" ]; then
        log_error "Error: espacio insuficiente en ${RESOLVED_BACKUP_DIR}."
        log_error "Motivo: la copia requiere al menos 105% del tamano origen."
        log_error "Tamano origen      : ${SIZE_BYTES}"
        log_error "Espacio requerido  : ${REQUIRED_BYTES}"
        log_error "Espacio disponible : ${AVAILABLE_BYTES}"
        exit 1
    fi
}

#--------------------------------------
validate_destinations()
{
    if [ -e "${DEST_FILE}" ]; then
        die "El archivo destino ya existe: ${DEST_FILE}" 1
    fi

    if [ -e "${CONFIG_DEST_FILE}" ]; then
        die "El archivo XML destino ya existe: ${CONFIG_DEST_FILE}" 1
    fi
}

#--------------------------------------
print_execution_context()
{
    echo -e "${G} Variables de Ejecucion ${N}"
    echo "VM_NAME           : ${VM_NAME}"
    echo "HYPERVISOR        : ${HYPERVISOR}"
    echo "BACKUP_TYPE       : ${BACKUP_TYPE}"
    echo "MAP_FILE          : ${RESOLVED_MAP_FILE}"
    echo "BACKUP_DIR        : ${RESOLVED_BACKUP_DIR}"
    echo "CONFIG_SOURCE     : ${CONFIG_SOURCE_FILE}"
    echo "CONFIG_DEST       : ${CONFIG_DEST_FILE}"
    echo "LV_PATH           : ${LV_PATH}"
    echo "SOURCE_LV         : ${SOURCE_LV}"
    echo "DEST_FILE         : ${DEST_FILE}"
    echo "SIZE_BYTES        : ${SIZE_BYTES}"
    echo "REQUIRED_BYTES    : ${REQUIRED_BYTES}"
    echo "AVAILABLE_BYTES   : ${AVAILABLE_BYTES}"
    echo "DEBUG             : ${DEBUG}"
    echo "DRY_RUN           : ${DRY_RUN}"
}

#--------------------------------------
create_snapshot()
{
    log_info "Creando snapshot remoto ${SOURCE_LV}."
    # shellcheck disable=SC2029
    ssh "${HYPERVISOR}" "lvcreate -L ${SNAP_SIZE} -s -n '${SNAP_NAME}' '${LV_PATH}'" >/dev/null
    SNAP_CREATED="TRUE"
}

#--------------------------------------
copy_vm_config()
{
    log_info "Intentando copiar configuracion XML remota ${CONFIG_SOURCE_FILE}."

    # shellcheck disable=SC2029
    if ssh "${HYPERVISOR}" "test -f '${CONFIG_SOURCE_FILE}' && cat '${CONFIG_SOURCE_FILE}'" > "${CONFIG_DEST_FILE}"; then
        log_info "Configuracion XML copiada con exito: ${CONFIG_DEST_FILE}"
        return 0
    fi

    rm -f "${CONFIG_DEST_FILE}"
    XML_COPY_FAILED="TRUE"
    log_warn "No se pudo copiar la configuracion XML remota ${CONFIG_SOURCE_FILE}. El backup del disco continuara igualmente."
    return 0
}

#--------------------------------------
show_dry_run_plan()
{
    echo "[DRY-RUN] ssh ${HYPERVISOR} \"test -f '${CONFIG_SOURCE_FILE}' && cat '${CONFIG_SOURCE_FILE}'\" > \"${CONFIG_DEST_FILE}\""

    if [ "${BACKUP_TYPE}" = "snap" ]; then
        echo "[DRY-RUN] ssh ${HYPERVISOR} \"lvcreate -L ${SNAP_SIZE} -s -n '${SNAP_NAME}' '${LV_PATH}'\""
    fi

    echo "[DRY-RUN] ssh ${HYPERVISOR} \"dd if='${SOURCE_LV}' bs=4M status=none\" | pv --progress --timer --eta --rate --average-rate --size \"${SIZE_BYTES}\" | dd of=\"${DEST_FILE}\" bs=4M conv=fsync status=none"

    if [ "${BACKUP_TYPE}" = "snap" ]; then
        echo "[DRY-RUN] ssh ${HYPERVISOR} \"lvremove -f '/dev/${VG_NAME}/${SNAP_NAME}'\""
    fi
}

#--------------------------------------
run_copy()
{
    log_info "Iniciando copia remota desde ${SOURCE_LV}."

    # shellcheck disable=SC2029
    ssh "${HYPERVISOR}" "dd if='${SOURCE_LV}' bs=4M status=none" \
        | pv --progress --timer --eta --rate --average-rate --size "${SIZE_BYTES}" \
        | dd of="${DEST_FILE}" bs=4M conv=fsync status=none
}

# -----------------------------------------------------------------------------
# 4. FUNCION PRINCIPAL MAIN (PARSEO Y LOGICA)
# -----------------------------------------------------------------------------

main()
{
    while getopts ":v:t:m:b:g:s:dyDh" opt; do
        case "${opt}" in
            v) VM_NAME="${OPTARG}" ;;
            t) BACKUP_TYPE="${OPTARG}" ;;
            m) MAP_FILE="${OPTARG}" ;;
            b) BACKUP_DIR="${OPTARG}" ;;
            g) VG_NAME="${OPTARG}" ;;
            s) SNAP_NAME="${OPTARG}" ;;
            d) DEBUG="TRUE" ;;
            y) ASSUME_YES="TRUE" ;;
            D) DRY_RUN="TRUE" ;;
            h) usage; exit 0 ;;
            :) log_error "Error: -${OPTARG} requiere un argumento."; usage; exit 2 ;;
            \?) log_error "Error: opcion invalida -${OPTARG}"; usage; exit 2 ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ "$#" -ne 0 ]; then
        die "No se permiten argumentos posicionales." 1
    fi

    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    validate_environment
    validate_args
    resolve_paths
    resolve_hypervisor
    prepare_volume_names
    fetch_remote_lv_size
    fetch_available_space
    validate_free_space
    validate_destinations
    print_execution_context
    confirm_or_exit

    if [ "${DRY_RUN}" = "TRUE" ]; then
        show_dry_run_plan
        exit 0
    fi

    copy_vm_config

    if [ "${BACKUP_TYPE}" = "snap" ]; then
        create_snapshot
    fi

    run_copy

    if [ "${XML_COPY_FAILED}" = "TRUE" ]; then
        log_warn "El backup del disco finalizo correctamente, pero la configuracion XML no pudo copiarse."
    fi

    log_info "Copia finalizada con exito: ${DEST_FILE}"
}

# -----------------------------------------------------------------------------
# 5. INVOCACION
# -----------------------------------------------------------------------------

main "$@"
