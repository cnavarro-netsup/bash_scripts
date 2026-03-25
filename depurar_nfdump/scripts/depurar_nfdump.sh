#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: depurar_nfdump.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: OpenCode / gpt-5.4
# FECHA: 2026-03-18
# DESCRIPCION: Elimina archivos directos de /var/cache/nfdump de forma segura.
# USO: ./scripts/depurar_nfdump.sh [-y|--yes] [--dry-run]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

readonly DEFAULT_TARGET_DIR="/var/cache/nfdump"
: "${NFDUMP_TARGET_DIR:=${DEFAULT_TARGET_DIR}}"
: "${ASSUME_YES:=FALSE}"
: "${DRY_RUN:=FALSE}"

LOG_STDOUT="FALSE"
LOG_TO_STDERR="TRUE"
LOG_TO_SYSLOG="TRUE"
LOG_SYSLOG_TAG="depurar_nfdump"
LOG_SYSLOG_FACILITY="user"

if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    printf '[ERROR] Missing logger library: %s\n' "${PROJECT_ROOT}/lib/logger.sh" >&2
    exit 1
fi
#--------------------------------------
usage()
{
    local script_name
    script_name="$(basename "$0")"

    cat >&2 <<EOF
Usage:
  ./${script_name} [-y|--yes] [--dry-run]

Description:
  Deletes regular files located directly under ${DEFAULT_TARGET_DIR}.

Options:
  -y, --yes    Run without interactive confirmation.
  --dry-run    Show what would be deleted without removing files.
  -h, --help   Show this help and exit.
EOF
}
#--------------------------------------
print_context()
{
    printf 'Execution Context\n' >&2
    printf 'TARGET_DIR : %s\n' "${NFDUMP_TARGET_DIR}" >&2
    printf 'ASSUME_YES : %s\n' "${ASSUME_YES}" >&2
    printf 'DRY_RUN    : %s\n' "${DRY_RUN}" >&2
}
#--------------------------------------onfirm_or_exit()
{
    local confirm

    if [[ "${ASSUME_YES}" = "TRUE" ]]; then
        return 0
    fi

    printf 'Proceed with deletion? (y/N): ' >&2
    read -r confirm

    case "${confirm:-}" in
        y|Y|yes|YES|Yes)
            return 0
            ;;
        *)
            log_error "Operation cancelled by user."
            exit 1
            ;;
    esac
}
#--------------------------------------
parse_arguments()
{
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                ASSUME_YES="TRUE"
                shift
                ;;
            --dry-run)
                DRY_RUN="TRUE"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -* )
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
            *)
                log_error "Positional arguments are not allowed: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ "$#" -gt 0 ]]; then
        log_error "Unexpected arguments were provided."
        usage
        exit 1
    fi
}
#--------------------------------------
validate_runtime()
{
    if ! logger_validate_backend; then
        exit 1
    fi

    if [[ ! -d "${NFDUMP_TARGET_DIR}" ]]; then
        log_error "Target directory does not exist: ${NFDUMP_TARGET_DIR}"
        exit 1
    fi
}
#--------------------------------------
collect_entries()
{
    local entry

    shopt -s nullglob
    ENTRIES=("${NFDUMP_TARGET_DIR}"/*)
    shopt -u nullglob

    if [[ "${#ENTRIES[@]}" -eq 0 ]]; then
        log_error "Target directory is empty: ${NFDUMP_TARGET_DIR}"
        exit 1
    fi

    for entry in "${ENTRIES[@]}"; do
        if [[ ! -f "${entry}" ]]; then
            log_error "Corrupted structure detected: non-regular entry '${entry}'"
            exit 1
        fi
    done
}
#--------------------------------------
run_dry_run()
{
    local entry
    local total=0

    for entry in "${ENTRIES[@]}"; do
        total=$((total + 1))
        log_info "[DRY-RUN] File would be deleted: ${entry}"
    done

    printf 'Total files to delete: %d\n' "${total}" >&2
    log_info "Dry-run completed. Total files to delete: ${total}"
}
#--------------------------------------
delete_entries()
{
    local entry
    local total=0

    for entry in "${ENTRIES[@]}"; do
        if ! rm -f -- "${entry}"; then
            log_error "Failed to delete file: ${entry}"
            exit 1
        fi
        total=$((total + 1))
    done

    printf 'Total deleted files: %d\n' "${total}" >&2
    log_info "Deletion completed successfully. Total deleted files: ${total}"
}
#--------------------------------------
main()
{
    parse_arguments "$@"
    validate_runtime
    print_context
    collect_entries
    confirm_or_exit

    if [[ "${DRY_RUN}" = "TRUE" ]]; then
        run_dry_run
        exit 0
    fi

    delete_entries
}
#--------------------------------------
main "$@"
