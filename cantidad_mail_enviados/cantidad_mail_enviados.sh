#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: cantidad_mail_enviados.sh
# VERSION: 1.2.0
# AUTOR: CPN
# MODELO: gpt-5.4
# FECHA: 06/Abril/2026
# DESCRIPCION: Cuenta correos enviados por usuario a partir de logs de Exim,
#              agrupados por fecha y ordenados por cantidad descendente.
# REQUERIMIENTOS: Bash 4.x+, awk, sort y head.
# USO: ./cantidad_mail_enviados.sh [-l patron_log] [-n cantidad]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export LOG_TO_STDERR="TRUE"
if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck source=/home/carlos/workspace/_proyectos_/bash_scripts/lib/logger.sh
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

readonly DEFAULT_LOG_PATTERN="main.log"
readonly DEFAULT_TOP_N="10"
: "${EXIM_LOG_DIR:=/var/log/exim}"

LOG_PATTERN="${DEFAULT_LOG_PATTERN}"
TOP_N="${DEFAULT_TOP_N}"
MATCHED_LOGS=()

usage()
{
    local script_name
    script_name="$(basename "$0")"

    cat <<EOF
Uso:
  ./${script_name} [-l patron_log] [-n cantidad]

Descripción:
  Lee uno o más logs de Exim dentro de ${EXIM_LOG_DIR} y muestra los usuarios
  con más correos enviados, agrupados por fecha y usuario.

Opciones:
  -l patron_log  Patrón de log dentro de ${EXIM_LOG_DIR}. Default: main.log.
                 Ejemplos válidos: main.log, main.log*, main.log-20260412.
  -n cantidad    Cantidad máxima de usuarios a mostrar. Default: 10.
  -h             Muestra esta ayuda y sale.
EOF
}

validate_dependencies()
{
    local dependency
    for dependency in awk sort head; do
        if ! command -v "${dependency}" >/dev/null 2>&1; then
            die "No se encontró la dependencia requerida: ${dependency}." 1
        fi
    done
}

validate_log_pattern()
{
    local log_pattern="$1"

    if [[ -z "${log_pattern}" ]]; then
        die "El patrón de log no puede estar vacío." 1
    fi

    if [[ "${log_pattern}" == */* ]]; then
        die "El patrón de log debe ser un nombre simple, sin rutas." 1
    fi

    if [[ ! "${log_pattern}" =~ ^[A-Za-z0-9._*?-]+$ ]]; then
        die "El patrón de log contiene caracteres no permitidos: ${log_pattern}." 1
    fi
}

validate_top_n()
{
    if [[ ! "${TOP_N}" =~ ^[1-9][0-9]*$ ]]; then
        die "La cantidad de usuarios (-n) debe ser un entero positivo mayor que cero." 1
    fi
}

resolve_log_matches()
{
    local -a matches=()

    if [[ ! -d "${EXIM_LOG_DIR}" ]]; then
        die "El directorio de logs no existe: ${EXIM_LOG_DIR}." 1
    fi

    mapfile -t matches < <(compgen -G "${EXIM_LOG_DIR}/${LOG_PATTERN}" | sort)

    if [[ "${#matches[@]}" -eq 0 ]]; then
        die "No se encontraron logs para el patrón '${LOG_PATTERN}' en ${EXIM_LOG_DIR}." 1
    fi

    local log_path
    for log_path in "${matches[@]}"; do
        if [[ ! -f "${log_path}" ]]; then
            die "La coincidencia no es un archivo regular: ${log_path}." 1
        fi

        if [[ ! -r "${log_path}" ]]; then
            die "No se puede leer el log indicado: ${log_path}." 1
        fi
    done

    MATCHED_LOGS=( "${matches[@]}" )
}

parse_arguments()
{
    while getopts ":hl:n:" option; do
        case "${option}" in
            h)
                usage
                exit 0
                ;;
            l)
                LOG_PATTERN="${OPTARG}"
                ;;
            n)
                TOP_N="${OPTARG}"
                ;;
            :)
                die "La opción -${OPTARG} requiere un valor." 1
                ;;
            \?)
                die "Opción inválida: -${OPTARG}." 1
                ;;
        esac
    done

    shift $((OPTIND - 1))

    if [[ "$#" -ne 0 ]]; then
        die "No se admiten argumentos posicionales. Use -l y -n." 1
    fi

    validate_log_pattern "${LOG_PATTERN}"
    validate_top_n
}

show_execution_plan()
{
    local log_path

    printf 'Variables de ejecución:\n'
    printf '  Directorio de logs : %s\n' "${EXIM_LOG_DIR}"
    printf '  Patrón de log      : %s\n' "${LOG_PATTERN}"
    printf '  Cantidad usuarios  : %s\n' "${TOP_N}"
    printf '  Archivos resueltos :\n'

    for log_path in "${MATCHED_LOGS[@]}"; do
        printf '    %s\n' "${log_path}"
    done
}

confirm_execution()
{
    local answer

    read -r -p "¿Continuar? [s/N]: " answer

    if [[ "${answer}" != "s" ]]; then
        die "Operación cancelada por el usuario." 1
    fi
}

count_sent_mail()
{
    awk '
        /<= [a-zA-Z0-9._%+-]+@gigot\.com\.ar/ {
            date = $1
            for (i = 1; i <= NF; i++) {
                if ($i == "<=") {
                    user = $(i + 1)
                    count[date, user]++
                    break
                }
            }
        }
        END {
            for (key in count) {
                split(key, parts, SUBSEP)
                printf "%d %s %s\n", count[key], parts[1], parts[2]
            }
        }
    ' "${MATCHED_LOGS[@]}" | sort -k1,1nr -k2,2 -k3,3 | awk -v top_n="${TOP_N}" 'NR <= top_n { print }'
}

print_results_table()
{
    local count=""
    local date=""
    local mail_account=""

    printf '\nTabla: cantidad de mails enviados por fecha y cuenta\n\n'
    printf '%-8s %-12s %-40s\n' 'conteo' 'fecha' 'cuenta de mail'
    printf '%-8s %-12s %-40s\n' '------' '----------' '----------------------------------------'

    while IFS=' ' read -r count date mail_account; do
        printf '%-8s %-12s %-40s\n' "${count}" "${date}" "${mail_account}"
    done
}

main()
{
    validate_dependencies
    parse_arguments "$@"
    resolve_log_matches
    show_execution_plan
    confirm_execution
    count_sent_mail | print_results_table
}

main "$@"
