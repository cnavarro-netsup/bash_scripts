#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: cantidad_autenticaciones.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: gpt-5.4
# FECHA: 06/Abril/2026
# DESCRIPCION: Cuenta autenticaciones Exim por fecha y usuario usando el patron
#              A=login:<cuenta_de_usuario> y muestra un ranking tabulado.
# REQUERIMIENTOS: Bash 4.x+, awk y sort. Acceso de lectura a logs de Exim.
# USO: ./cantidad_autenticaciones.sh [-l patron_log] [-n cantidad] [-d]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACION INICIAL
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck source=/home/carlos/workspace/_proyectos_/bash_scripts/lib/logger.sh
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

: "${DEBUG:=FALSE}"
: "${EXIM_LOG_DIR:=/var/log/exim}"

readonly DEFAULT_LOG_PATTERN="main.log"
readonly DEFAULT_TOP_N="10"

log_pattern="${DEFAULT_LOG_PATTERN}"
top_n="${DEFAULT_TOP_N}"
matched_logs=()
explicit_log_names=()
use_explicit_log_names="FALSE"

# -----------------------------------------------------------------------------
# 2. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

#--------------------------------------
usage()
{
    local script_name
    script_name="$(basename "$0")"

    cat <<EOF
Uso:
  ./${script_name} [-l patron_log] [-n cantidad] [-d]

Descripcion:
  Lee uno o mas logs de Exim dentro de ${EXIM_LOG_DIR} y cuenta autenticaciones
  detectadas por el patron A=login:<cuenta_de_usuario>, agrupadas por fecha y
  cuenta de usuario.

Opciones:
  -l patron_log  Patron de log dentro de ${EXIM_LOG_DIR}. Default: main.log.
                 Ejemplos validos: main.log, main.log*, main.log-20260412.
  -n cantidad    Cantidad maxima de filas a mostrar. Default: 10.
  -d             Activa modo debug (set -x).
  -h             Muestra esta ayuda y sale.
EOF
}

#--------------------------------------
validate_dependencies()
{
    local dependency

    for dependency in awk sort; do
        if ! command -v "${dependency}" >/dev/null 2>&1; then
            die "No se encontró la dependencia requerida: ${dependency}." 1
        fi
    done
}

#--------------------------------------
validate_log_pattern()
{
    local requested_pattern="$1"

    if [[ -z "${requested_pattern}" ]]; then
        die "El patrón de log no puede estar vacío." 1
    fi

    if [[ "${requested_pattern}" == */* ]]; then
        die "El patrón de log debe ser un nombre simple, sin rutas." 1
    fi

    if [[ ! "${requested_pattern}" =~ ^[A-Za-z0-9._*?-]+$ ]]; then
        die "El patrón de log contiene caracteres no permitidos: ${requested_pattern}." 1
    fi
}

#--------------------------------------
validate_top_n()
{
    if [[ ! "${top_n}" =~ ^[1-9][0-9]*$ ]]; then
        die "La cantidad de usuarios (-n) debe ser un entero positivo mayor que cero." 1
    fi
}

#--------------------------------------
parse_arguments()
{
    explicit_log_names=()
    use_explicit_log_names="FALSE"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -h)
                usage
                exit 0
                ;;
            -d)
                DEBUG="TRUE"
                shift
                ;;
            -n)
                if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
                    die "La opción -n requiere un valor." 1
                fi

                top_n="$2"
                shift 2
                ;;
            -l)
                if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
                    die "La opción -l requiere un valor." 1
                fi

                log_pattern="$2"
                explicit_log_names=( "${log_pattern}" )
                use_explicit_log_names="TRUE"
                shift 2

                while [[ "$#" -gt 0 && "$1" != -* ]]; do
                    explicit_log_names+=( "$1" )
                    shift
                done
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "Opción inválida: $1." 1
                ;;
            *)
                die "No se admiten argumentos posicionales. Use -l y -n." 1
                ;;
        esac
    done

    if [[ "$#" -ne 0 ]]; then
        die "No se admiten argumentos posicionales. Use -l y -n." 1
    fi

    validate_log_pattern "${log_pattern}"

    if [[ "${use_explicit_log_names}" = "TRUE" ]]; then
        local explicit_name=""

        if [[ "${explicit_log_names[0]}" == *[*?]* ]]; then
            explicit_log_names=()
            use_explicit_log_names="FALSE"
        fi

        if [[ "${use_explicit_log_names}" = "TRUE" ]]; then
            for explicit_name in "${explicit_log_names[@]}"; do
                validate_log_pattern "${explicit_name}"
            done
        fi
    fi

    validate_top_n
}

#--------------------------------------
resolve_log_matches()
{
    local -a matches=()
    local log_path=""

    if [[ ! -d "${EXIM_LOG_DIR}" ]]; then
        die "El directorio de logs no existe: ${EXIM_LOG_DIR}." 1
    fi

    if [[ "${use_explicit_log_names}" = "TRUE" ]]; then
        matches=()

        for log_path in "${explicit_log_names[@]}"; do
            matches+=( "${EXIM_LOG_DIR}/${log_path}" )
        done
    else
        mapfile -t matches < <(compgen -G "${EXIM_LOG_DIR}/${log_pattern}" | sort)
    fi

    if [[ "${#matches[@]}" -eq 0 ]]; then
        die "No se encontraron logs para el patrón '${log_pattern}' en ${EXIM_LOG_DIR}." 1
    fi

    for log_path in "${matches[@]}"; do
        if [[ ! -f "${log_path}" ]]; then
            die "La coincidencia no es un archivo regular: ${log_path}." 1
        fi

        if [[ ! -r "${log_path}" ]]; then
            die "No se puede leer el log indicado: ${log_path}." 1
        fi
    done

    matched_logs=( "${matches[@]}" )
}

#--------------------------------------
show_execution_plan()
{
    local log_path=""

    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    echo -e "${G}Variables de Ejecución${N}"
    echo "EXIM_LOG_DIR      : ${EXIM_LOG_DIR}"
    echo "LOG_PATTERN       : ${log_pattern}"
    echo "TOP_N             : ${top_n}"
    echo "DEBUG             : ${DEBUG}"
    echo "ARCHIVOS_RESUELTOS:"

    for log_path in "${matched_logs[@]}"; do
        echo "  ${log_path}"
    done
}

#--------------------------------------
confirm_or_exit()
{
    local confirm

    read -r -p "¿Continuar? [s/N]: " confirm

    case "${confirm:-}" in
        s) return 0 ;;
        *) die "Operación cancelada por el usuario." 1 ;;
    esac
}

#--------------------------------------
count_authentications()
{
    awk '
        {
            date = $1
            for (i = 1; i <= NF; i++) {
                if (index($i, "A=login:") == 1) {
                    user = substr($i, 9)
                    if (user != "") {
                        count[date, user]++
                    }
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
    ' "${matched_logs[@]}" | sort -k1,1nr -k2,2 -k3,3 | awk -v max_rows="${top_n}" 'NR <= max_rows { print }'
}

#--------------------------------------
print_results_table()
{
    local count=""
    local date=""
    local user_account=""

    printf '\nTabla: cantidad de autenticaciones por fecha y cuenta\n\n'
    printf '%-8s %-12s %-40s\n' 'conteo' 'fecha' 'cuenta de usuario'
    printf '%-8s %-12s %-40s\n' '------' '----------' '----------------------------------------'

    while IFS=' ' read -r count date user_account; do
        printf '%-8s %-12s %-40s\n' "${count}" "${date}" "${user_account}"
    done
}

# -----------------------------------------------------------------------------
# 3. FUNCION PRINCIPAL MAIN
# -----------------------------------------------------------------------------

main()
{
    validate_dependencies
    parse_arguments "$@"
    resolve_log_matches
    show_execution_plan
    confirm_or_exit
    count_authentications | print_results_table
}

main "$@"
