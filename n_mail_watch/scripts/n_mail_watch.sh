#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: n_mail_watch.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: gpt-5.4
# FECHA: 07/Abril/2026
# DESCRIPCION: Detecta cuentas de correo que superan un umbral diario de mails
#              enviados y envia una alerta por mail por cuenta excedida.
# REQUERIMIENTOS: Bash 4.x+, awk, sort, date, realpath y sendmail o mailx.
#                 Lectura de logs Exim y acceso al backend de correo local.
# USO: ./n_mail_watch.sh [-l patron_log] [-t limite] [-r destinatario] [-d] [-y]
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
: "${ASSUME_YES:=FALSE}"
: "${EXIM_LOG_DIR:=/var/log/exim}"
: "${MAIL_RECIPIENT:=infraestructura@gigot.com.ar,cnavarro@gigot.com.ar}"

readonly DEFAULT_LOG_PATTERN="main.log"
readonly DEFAULT_THRESHOLD="100"
readonly DEFAULT_SUBJECT_PREFIX="Alerta n_mail_watch"
readonly MAIL_FROM="mail_watch@gigot.com.ar"

log_pattern="${DEFAULT_LOG_PATTERN}"
threshold="${DEFAULT_THRESHOLD}"
recipient="${MAIL_RECIPIENT}"
current_date=""
mail_backend=""
resolved_log_dir=""
matched_logs=()

# -----------------------------------------------------------------------------
# 2. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

#--------------------------------------
cleanup()
{
    :
}
trap cleanup EXIT ERR INT TERM

#--------------------------------------
usage()
{
    local script_name
    script_name="$(basename "$0")"

    cat <<EOF
Uso:
  ./${script_name} [-l patron_log] [-t limite] [-r destinatario] [-d] [-y]

Descripcion:
  Lee uno o mas logs de Exim dentro de EXIM_LOG_DIR, cuenta mails enviados del
  dia actual detectados con la misma regla de cantidad_mail_enviados y envia una
  alerta por mail por cada cuenta que alcance o supere el umbral configurado.

Opciones:
  -l patron_log   Patron de log dentro de EXIM_LOG_DIR. Default: ${DEFAULT_LOG_PATTERN}.
  -t limite       Umbral diario de mails enviados. Default: ${DEFAULT_THRESHOLD}.
  -r destinatario Casilla que recibe las alertas. Default: ${MAIL_RECIPIENT}.
  -d              Activa modo debug (set -x).
  -y              Modo batch/cron: omite confirmacion interactiva.
  -h              Muestra esta ayuda y sale.
EOF
}

#--------------------------------------
validate_dependencies()
{
    local dependency=""

    for dependency in awk sort date realpath; do
        if ! command -v "${dependency}" >/dev/null 2>&1; then
            die "No se encontró la dependencia requerida: ${dependency}." 1
        fi
    done
}

#--------------------------------------
configure_debug_mode()
{
    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi
}

#--------------------------------------
detect_mail_backend()
{
    if command -v sendmail >/dev/null 2>&1; then
        mail_backend="sendmail"
        return 0
    fi

    if command -v mailx >/dev/null 2>&1; then
        mail_backend="mailx"
        return 0
    fi

    die "No se encontró un backend de correo disponible: se requiere sendmail o mailx." 1
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
validate_threshold()
{
    if [[ ! "${threshold}" =~ ^[1-9][0-9]*$ ]]; then
        die "El límite diario (-t) debe ser un entero positivo mayor que cero." 1
    fi
}

#--------------------------------------
validate_recipients()
{
    local recipient_item=""
    local -a recipient_list=()

    IFS=',' read -r -a recipient_list <<< "${recipient}"

    if [[ "${#recipient_list[@]}" -eq 0 ]]; then
        die "Debe existir al menos un destinatario de alerta." 1
    fi

    for recipient_item in "${recipient_list[@]}"; do
        if [[ -z "${recipient_item}" ]]; then
            die "La lista de destinatarios contiene un valor vacío." 1
        fi

        if [[ ! "${recipient_item}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            die "El destinatario no tiene un formato de mail válido: ${recipient_item}." 1
        fi
    done
}

#--------------------------------------
validate_log_directory()
{
    if [[ ! -d "${EXIM_LOG_DIR}" ]]; then
        die "El directorio de logs no existe: ${EXIM_LOG_DIR}." 1
    fi

    if ! resolved_log_dir="$(realpath "${EXIM_LOG_DIR}")"; then
        die "No se pudo resolver EXIM_LOG_DIR con realpath: ${EXIM_LOG_DIR}." 1
    fi

    if [[ ! -d "${resolved_log_dir}" ]]; then
        die "La ruta resuelta de logs no es un directorio válido: ${resolved_log_dir}." 1
    fi
}

#--------------------------------------
parse_arguments()
{
    while getopts ":hl:t:r:dy" option; do
        case "${option}" in
            h)
                usage
                exit 0
                ;;
            l)
                log_pattern="${OPTARG}"
                ;;
            t)
                threshold="${OPTARG}"
                ;;
            r)
                recipient="${OPTARG}"
                ;;
            d)
                DEBUG="TRUE"
                ;;
            y)
                ASSUME_YES="TRUE"
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
        die "No se admiten argumentos posicionales." 1
    fi

    validate_log_pattern "${log_pattern}"
    validate_threshold
    validate_recipients
}

#--------------------------------------
resolve_log_matches()
{
    local -a matches=()
    local log_path=""

    mapfile -t matches < <(compgen -G "${resolved_log_dir}/${log_pattern}" | sort)

    if [[ "${#matches[@]}" -eq 0 ]]; then
        die "No se encontraron logs para el patrón '${log_pattern}' en ${resolved_log_dir}." 1
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

    if [ "${ASSUME_YES}" = "TRUE" ]; then
        return 0
    fi

    echo -e "${G} Variables de Ejecución ${N}"
    echo "EXIM_LOG_DIR     : ${EXIM_LOG_DIR}"
    echo "RESOLVED_LOG_DIR : ${resolved_log_dir}"
    echo "LOG_PATTERN      : ${log_pattern}"
    echo "THRESHOLD        : ${threshold}"
    echo "RECIPIENT        : ${recipient}"
    echo "CURRENT_DATE     : ${current_date}"
    echo "MAIL_BACKEND     : ${mail_backend}"
    echo "DEBUG            : ${DEBUG}"
    echo "ASSUME_YES       : ${ASSUME_YES}"
    echo "ARCHIVOS         :"

    for log_path in "${matched_logs[@]}"; do
        echo "  ${log_path}"
    done
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
        *) die "Cancelado por el usuario." 1 ;;
    esac
}

#--------------------------------------
collect_exceeded_accounts()
{
    awk -v today="${current_date}" -v min_threshold="${threshold}" '
        $1 == today && /<= [a-zA-Z0-9._%+-]+@gigot\.com\.ar/ {
            for (i = 1; i <= NF; i++) {
                if ($i == "<=") {
                    user = $(i + 1)
                    if (user != "") {
                        count[$1, user]++
                    }
                    break
                }
            }
        }
        END {
            for (key in count) {
                if (count[key] >= min_threshold) {
                    split(key, parts, SUBSEP)
                    printf "%d %s %s\n", count[key], parts[1], parts[2]
                }
            }
        }
    ' "${matched_logs[@]}" | sort -k2,2 -k3,3
}

#--------------------------------------
send_mail_alert()
{
    local sent_count="$1"
    local sent_date="$2"
    local mail_account="$3"
    local subject="${DEFAULT_SUBJECT_PREFIX}: mails enviados excedidos para ${mail_account}"
    local host_name=""
    local body=""
    local -a recipient_list=()

    host_name="$(hostname -f 2>/dev/null || hostname)"
    IFS=',' read -r -a recipient_list <<< "${recipient}"
    body="Cuenta de mail: ${mail_account}
Fecha: ${sent_date}
Mails enviados: ${sent_count}
Limite: ${threshold}
Host: ${host_name}
"

    case "${mail_backend}" in
        sendmail)
            printf 'From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s\n' \
                "${MAIL_FROM}" "${recipient}" "${subject}" "${body}" | sendmail -t
            ;;
        mailx)
            printf '%s\n' "${body}" | mailx -s "${subject}" "${recipient_list[@]}"
            ;;
        *)
            die "Backend de correo no soportado: ${mail_backend}." 1
            ;;
    esac

    log_info "Alerta enviada para ${mail_account} (${sent_count} mails enviados en ${sent_date})."
}

#--------------------------------------
process_alerts()
{
    local alert_count="0"
    local sent_count=""
    local sent_date=""
    local mail_account=""
    local exceeded_accounts=""

    exceeded_accounts="$(collect_exceeded_accounts)"

    if [[ -z "${exceeded_accounts}" ]]; then
        log_info "No se detectaron cuentas con mails enviados por encima del límite para ${current_date}."
        return 0
    fi

    while IFS=' ' read -r sent_count sent_date mail_account; do
        if [[ -z "${sent_count}" || -z "${sent_date}" || -z "${mail_account}" ]]; then
            continue
        fi

        send_mail_alert "${sent_count}" "${sent_date}" "${mail_account}"
        alert_count="$((alert_count + 1))"
    done <<< "${exceeded_accounts}"

    log_info "Se emitieron ${alert_count} alerta(s) para ${current_date}."
}

# -----------------------------------------------------------------------------
# 3. FUNCION PRINCIPAL MAIN
# -----------------------------------------------------------------------------

main()
{
    validate_dependencies
    parse_arguments "$@"
    configure_debug_mode
    detect_mail_backend
    validate_log_directory
    resolve_log_matches
    current_date="$(date +%F)"
    show_execution_plan
    confirm_or_exit
    process_alerts
}

main "$@"
