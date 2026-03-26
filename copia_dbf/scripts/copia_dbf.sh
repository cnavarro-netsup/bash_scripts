#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: copia_dbf.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: OpenAI gpt-5.4
# FECHA: 26/Marzo/2026
# DESCRIPCION: Copia archivos .DBF desde un Windows Server hacia un server
#              Linux publico usando un jump host en dos etapas con rsync.
#
# REQUERIMIENTOS: Ejecucion como root, conectividad SSH operativa y acceso a
#                 /root/.ssh/copia_dbf para el segundo salto.
# USO: ./copia_dbf.sh -h
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACION INICIAL
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

: "${DEBUG:=FALSE}"
: "${SHOW_HELP:=FALSE}"
: "${LOG_FILE:=/var/log/copia_dbf.log}"
: "${LOG_STDOUT:=FALSE}"
: "${LOG_TO_STDERR:=FALSE}"

readonly WINDOWS_SOURCE="Administrador@txs02:/cygdrive/d/Aplicaciones/FoxApp/Planif/*.DBF"
readonly LOCAL_TARGET_DIR="/tmp"
readonly REMOTE_TARGET="admingc@planif.gigot.com.ar:/tmp"
readonly SSH_KEY_PATH="/root/.ssh/copia_dbf"

if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck source=lib/logger.sh
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Critical error: logger.sh was not found in ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. FUNCIONES
# -----------------------------------------------------------------------------
cleanup()
{
    :
}
trap cleanup EXIT ERR INT TERM
#--------------------------------------
usage()
{
    local script_name
    script_name="${0##*/}"

    cat <<EOF
Usage:
  ./${script_name} [-d]
  ./${script_name} -h

Description:
  Copy uppercase .DBF files from txs02 to the jump host and then forward them
  to planif.gigot.com.ar using rsync.

Options:
  -d  Enable debug mode (set -x)
  -h  Show this help and exit

Notes:
  - Only files matching *.DBF are considered valid.
  - The normal execution flow is silent on the console.
  - Logs are written to /var/log/copia_dbf.log.
EOF
}
#--------------------------------------
log_rsync_files()
{
    local stage_name="$1"
    local rsync_output="$2"
    local found_files="FALSE"
    local line=""

    while IFS= read -r line; do
        case "${line}" in
            *.DBF)
                found_files="TRUE"
                log_info "${stage_name}: ${line}"
                ;;
        esac
    done <<EOF
${rsync_output}
EOF

    if [ "${stage_name}" = "Stage 2 transferred file" ] && [ "${found_files}" = "FALSE" ]; then
        log_info "No new DBF files transferred to remote host."
    fi
}
#--------------------------------------
ensure_log_file()
{
    : >> "${LOG_FILE}"
}
#--------------------------------------
validate_usage_constraints()
{
    if [ "${SHOW_HELP}" = "TRUE" ] && [ "${DEBUG}" = "TRUE" ]; then
        echo "Error: -h cannot be combined with -d." >&2
        exit 1
    fi
}
#--------------------------------------
check_remote_source_files()
{
    if ! ssh "Administrador@txs02" 'compgen -G "/cygdrive/d/Aplicaciones/FoxApp/Planif/*.DBF" > /dev/null' >/dev/null 2>&1; then
        log_error "No uppercase DBF files found on remote source host."
        exit 1
    fi
}
#--------------------------------------
check_local_source_files()
{
    local dbf_matches=()

    shopt -s nullglob
    dbf_matches=("${LOCAL_TARGET_DIR}"/*.DBF)
    shopt -u nullglob

    if [ "${#dbf_matches[@]}" -eq 0 ]; then
        log_error "No uppercase DBF files found on local staging directory."
        exit 1
    fi
}
#--------------------------------------
run_first_stage()
{
    local rsync_output=""

    if ! rsync_output=$(rsync -avz "${WINDOWS_SOURCE}" "${LOCAL_TARGET_DIR}" 2>&1); then
        log_error "Stage 1 rsync failed."
        log_error "${rsync_output}"
        exit 1
    fi

    log_info "Stage 1 completed successfully."
    log_rsync_files "Stage 1 copied file" "${rsync_output}"
}
#--------------------------------------
run_second_stage()
{
    local rsync_output=""

    if ! rsync_output=$(rsync -avz --chmod=F600,D700 -e "ssh -i ${SSH_KEY_PATH} -o BatchMode=yes -o StrictHostKeyChecking=yes" "${LOCAL_TARGET_DIR}"/*.DBF "${REMOTE_TARGET}" 2>&1); then
        log_error "Stage 2 rsync failed."
        log_error "${rsync_output}"
        exit 1
    fi

    log_info "Stage 2 completed successfully."
    log_rsync_files "Stage 2 transferred file" "${rsync_output}"
}

# -----------------------------------------------------------------------------
# 3. MAIN
# -----------------------------------------------------------------------------
main()
{
    while getopts ":dh" opt; do
        case "${opt}" in
            d) DEBUG="TRUE" ;;
            h) SHOW_HELP="TRUE" ;;
            \?)
                echo "Error: invalid option -${OPTARG}" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ "$#" -ne 0 ]; then
        echo "Error: positional arguments are not allowed." >&2
        usage >&2
        exit 1
    fi

    validate_usage_constraints

    if [ "${SHOW_HELP}" = "TRUE" ]; then
        usage
        exit 0
    fi

    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    ensure_log_file
    log_info "Starting DBF copy workflow."

    check_remote_source_files
    run_first_stage
    check_local_source_files
    run_second_stage

    log_info "DBF copy workflow finished successfully."
}

main "$@"
