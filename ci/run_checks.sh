#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: run_checks.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: gpt-5.4
# FECHA: 18/Marzo/2026
# DESCRIPCION: Ejecuta shellcheck y bats sobre los proyectos del repo,
#              y registra el resultado en tmp/checks/.
#
# REQUERIMIENTOS: Bash 4.x+, shellcheck y bats instalados en el sistema.
# USO: ./ci/run_checks.sh [-d] [-p <proyecto>]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck source=/home/carlos/workspace/_proyectos_/bash_scripts/lib/logger.sh
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

: "${DEBUG:=FALSE}"
: "${TARGET_PROJECT:=all}"

r_color="\033[0;31m"
g_color="\033[0;32m"
y_color="\033[0;33m"
b_color="\033[0;34m"
c_color="\033[0;36m"
n_color="\033[0m"

RUN_TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
RESULTS_DIR="${PROJECT_ROOT}/tmp/checks"
RESULTS_FILE="${RESULTS_DIR}/checks_${RUN_TIMESTAMP}.log"
LATEST_FILE="${RESULTS_DIR}/latest.log"

cleanup()
{
    :
}
trap cleanup EXIT ERR INT TERM

#------+---------+---------+---------+---------+---------+---------+---------+

usage()
{
    cat <<EOF
Uso:
  ./ci/run_checks.sh [-d] [-p <proyecto>]

Opciones:
  -d  Activa modo debug.
  -p  Ejecuta shellcheck y bats solo sobre el proyecto indicado.
  -h  Muestra esta ayuda.

Resultados:
  Cada ejecución guarda un log en tmp/checks/checks_YYYYMMDD_HHMMSS.log
  y actualiza tmp/checks/latest.log.

Ejemplos:
  ./ci/run_checks.sh
  ./ci/run_checks.sh -p suma
  ./ci/run_checks.sh -d -p factorial
EOF
}

#------+---------+---------+---------+---------+---------+---------+---------+

log_info_stderr()
{
    echo -e "${g_color}[INFO]${n_color} $1" >&2
}

#------+---------+---------+---------+---------+---------+---------+---------+

log_warn_stderr()
{
    echo -e "${y_color}[WARN]${n_color} $1" >&2
}

#------+---------+---------+---------+---------+---------+---------+---------+

log_error_stderr()
{
    echo -e "${r_color}[ERROR]${n_color} $1" >&2
}

#------+---------+---------+---------+---------+---------+---------+---------+

check_dependency()
{
    local binary_name="$1"

    if ! command -v "${binary_name}" >/dev/null 2>&1; then
        log_error_stderr "Dependencia ausente: ${binary_name}"
        return 1
    fi
}

#------+---------+---------+---------+---------+---------+---------+---------+

collect_projects()
{
    local project_name

    if [[ "${TARGET_PROJECT}" != "all" ]]; then
        if [[ -d "${PROJECT_ROOT}/${TARGET_PROJECT}" ]]; then
            printf '%s\n' "${TARGET_PROJECT}"
            return 0
        fi

        log_error_stderr "No existe el proyecto '${TARGET_PROJECT}'."
        return 1
    fi

    for project_name in "${PROJECT_ROOT}"/*; do
        if [[ -d "${project_name}/scripts" || -d "${project_name}/tests" ]]; then
            basename "${project_name}"
        fi
    done
}

#------+---------+---------+---------+---------+---------+---------+---------+

run_shellcheck_for_project()
{
    local project_name="$1"
    local script_found="FALSE"
    local script_path

    while IFS= read -r script_path; do
        script_found="TRUE"
        shellcheck -x "${script_path}"
    done < <(find "${PROJECT_ROOT}/${project_name}/scripts" -type f -name "*.sh" 2>/dev/null | sort)

    if [[ "${script_found}" = "FALSE" ]]; then
        log_warn_stderr "${project_name}: no se encontraron scripts para shellcheck."
    fi
}

#------+---------+---------+---------+---------+---------+---------+---------+

run_bats_for_project()
{
    local project_name="$1"

    if [[ ! -d "${PROJECT_ROOT}/${project_name}/tests" ]]; then
        log_warn_stderr "${project_name}: no existe directorio tests/."
        return 0
    fi

    bats "${PROJECT_ROOT}/${project_name}/tests"
}

#------+---------+---------+---------+---------+---------+---------+---------+

main()
{
    while getopts ":dp:h" opt; do
        case "${opt}" in
            d) DEBUG="TRUE" ;;
            p) TARGET_PROJECT="${OPTARG}" ;;
            h) usage; exit 0 ;;
            :) log_error_stderr "Error: -${OPTARG} requiere un argumento."; usage; exit 2 ;;
            \?) log_error_stderr "Error: opción inválida -${OPTARG}"; usage; exit 2 ;;
        esac
    done
    shift $((OPTIND - 1))

    if [[ "${DEBUG}" = "TRUE" ]]; then
        set -x
    else
        set +x
    fi

    mkdir -p "${RESULTS_DIR}"

    echo -e "${g_color} Variables de Ejecución ${n_color}"
    echo "TARGET_PROJECT : ${TARGET_PROJECT}"
    echo "RESULTS_FILE   : ${RESULTS_FILE}"
    echo "DEBUG          : ${DEBUG}"
    echo -e "${b_color}Iniciando shellcheck + bats${n_color}"
    echo -e "${c_color}Registro persistente en tmp/checks/${n_color}"

    check_dependency "shellcheck"
    check_dependency "bats"

    log_info_stderr "Registrando resultados en ${RESULTS_FILE}"

    {
        printf 'Run timestamp: %s\n' "${RUN_TIMESTAMP}"
        printf 'Target project: %s\n' "${TARGET_PROJECT}"
        printf 'Working tree  : %s\n\n' "${PROJECT_ROOT}"

        while IFS= read -r project_name; do
            printf '==> Project: %s\n' "${project_name}"
            printf '[shellcheck]\n'
            run_shellcheck_for_project "${project_name}"
            printf '\n[bats]\n'
            run_bats_for_project "${project_name}"
            printf '\n'
        done < <(collect_projects)
    } 2>&1 | tee "${RESULTS_FILE}"

    cp "${RESULTS_FILE}" "${LATEST_FILE}"
    log_info_stderr "Validación finalizada. Último resultado: ${LATEST_FILE}"
}

main "$@"
