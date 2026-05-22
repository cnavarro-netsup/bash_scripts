#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: clean_sent_to_todos.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: GPT-5.4
# FECHA: 22/Mayo/2026
# DESCRIPCION: Identifica mails enviados a grp_todos y los mueve a un destino
#              filtrando por remitente, Maildir y anio de analisis.
#
# REQUERIMIENTOS: Lectura sobre /srv/mail y escritura sobre el directorio destino.
# USO: ./clean_sent_to_todos.sh -h
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. CONFIGURACION INICIAL
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC2034
readonly R="\033[0;31m"
readonly G="\033[0;32m"
# shellcheck disable=SC2034
readonly Y="\033[0;33m"
# shellcheck disable=SC2034
readonly B="\033[0;34m"
readonly C="\033[0;36m"
readonly N="\033[0m"

# -----------------------------------------------------------------------------
# 2. VARIABLES DE EJECUCION
# -----------------------------------------------------------------------------
: "${DEBUG:=FALSE}"
: "${ASSUME_YES:=FALSE}"
: "${DEST_DIR:=}"
: "${FROM_USER:=}"
: "${YEAR:=}"
: "${SINGLE_USER:=}"
: "${DRY_RUN:=FALSE}"

readonly MAIL_BASE="/srv/mail"
readonly MAILDIR_SUFFIX="Maildir"
readonly ENVELOPE_TO="grp_todos@gigot.com.ar"

FILES_MATCHED=0
FILES_MOVED=0
FILES_FAILED=0

SUMMARY_ENABLED="FALSE"
CLEANUP_DONE="FALSE"

# -----------------------------------------------------------------------------
# 3. FUNCIONES
# -----------------------------------------------------------------------------
# Ejecuta un resumen final seguro una sola vez cuando el script termina.
cleanup()
{
    local exit_code=$?

    if [ "${CLEANUP_DONE}" = "TRUE" ]; then
        return 0
    fi

    CLEANUP_DONE="TRUE"

    if [ "${SUMMARY_ENABLED}" = "TRUE" ]; then
        {
            echo -e "${C}Resumen de Ejecucion${N}"
            echo "FILES_MATCHED : ${FILES_MATCHED}"
            echo "FILES_MOVED   : ${FILES_MOVED}"
            echo "FILES_FAILED  : ${FILES_FAILED}"
            echo "EXIT_CODE     : ${exit_code}"
        } >&2
    fi
}
trap cleanup EXIT ERR INT TERM
#--------------------------------------
# Imprime la ayuda operativa y los ejemplos de invocacion.
usage()
{
    local script_name
    script_name=$(basename "${0}")

    cat <<EOF
Uso:
  ./${script_name} -d <destino> -f <usuario> -Y <anio> [opciones]

Descripcion:
  Busca mails dentro de Maildir cuyo header From coincida con
  <usuario>@gigot.com.ar y cuyo Envelope-to sea grp_todos@gigot.com.ar.
  El filtro temporal se define exclusivamente por mtime del archivo.

Obligatorios:
  -d <destino>  Directorio destino existente para mover los mails
  -f <usuario>  Usuario remitente sin dominio
  -Y <anio>     Anio a analizar (1970-2099)

Opcionales:
  -u <usuario>  Restringe el analisis a /srv/mail/<usuario>/Maildir
  -r            Dry-run: lista los archivos sin moverlos
  -y            Asume confirmacion y omite Variables de Ejecucion
  -h            Muestra esta ayuda y sale

Variables de Entorno:
  DEBUG=TRUE        Activa set -x
  ASSUME_YES=TRUE   Equivalente a -y

Ejemplos:
  ./${script_name} -d /backup/todos -f cuenta_operativa -Y 2024
  ./${script_name} -d /backup/todos -f cuenta_operativa -Y 2024 -u usuario1 -r
  ./${script_name} -d /backup/todos -f cuenta_operativa -Y 2024 -y
EOF
}
#--------------------------------------
# Pide confirmacion interactiva salvo que el modo batch ya este habilitado.
confirm_or_exit()
{
    if [ "${ASSUME_YES}" = "TRUE" ]; then
        return 0
    fi

    local confirm
    read -r -p "¿Continuar? (s/N): " confirm

    case "${confirm:-}" in
        s|S|si|SI|Si)
            return 0
            ;;
        *)
            echo -e "${R}Cancelado por el usuario.${N}" >&2
            exit 1
            ;;
    esac
}
#--------------------------------------
# Resalta errores de invocacion para separarlos visualmente del usage.
print_error_red()
{
    local message="$1"
    echo -e "${R}${message}${N}" >&2
}
#--------------------------------------
# Emite la ruta del mail matcheado junto con su header Date si existe.
print_match_info()
{
    local mail_file="$1"
    local date_value="$2"

    printf '%s | Date: %s\n' "${mail_file}" "${date_value}"
}
#--------------------------------------
# Verifica presencia de los flags obligatorios antes de operar.
validate_args()
{
    if [ -z "${DEST_DIR}" ]; then
        print_error_red "Error: falta el flag obligatorio -d."
        usage >&2
        exit 1
    fi

    if [ -z "${FROM_USER}" ]; then
        print_error_red "Error: falta el flag obligatorio -f."
        usage >&2
        exit 1
    fi

    if [ -z "${YEAR}" ]; then
        print_error_red "Error: falta el flag obligatorio -Y."
        usage >&2
        exit 1
    fi
}
#--------------------------------------
# Valida formato y rango permitido del anio de analisis.
validate_year()
{
    if ! [[ "${YEAR}" =~ ^[0-9]{4}$ ]]; then
        print_error_red "Error: el anio debe tener exactamente 4 digitos."
        exit 1
    fi

    if (( YEAR < 1970 || YEAR > 2099 )); then
        print_error_red "Error: el anio debe estar entre 1970 y 2099."
        exit 1
    fi
}
#--------------------------------------
# Confirma que el directorio destino exista antes de mover archivos.
validate_dest_dir()
{
    if [ ! -d "${DEST_DIR}" ]; then
        print_error_red "Error: el directorio destino no existe: ${DEST_DIR}"
        exit 1
    fi
}
#--------------------------------------
# Verifica que el Maildir del usuario solicitado exista cuando se usa -u.
validate_maildir()
{
    local base_path="$1"

    if [ ! -d "${base_path}" ]; then
        print_error_red "Error: el Maildir del usuario no existe: ${base_path}"
        exit 1
    fi
}
#--------------------------------------
# Muestra el contexto de ejecucion salvo en modo batch silencioso.
print_execution_variables()
{
    if [ "${ASSUME_YES}" = "TRUE" ]; then
        return 0
    fi

    echo -e "${G}Variables de Ejecucion${N}"
    echo "DEST_DIR    : ${DEST_DIR}"
    echo "FROM_USER   : ${FROM_USER}"
    echo "YEAR        : ${YEAR}"
    echo "SINGLE_USER : ${SINGLE_USER:-<todos>}"
    echo "DRY_RUN     : ${DRY_RUN}"
    echo "DEBUG       : ${DEBUG}"
}
#--------------------------------------
# Recorre el Maildir, filtra candidatos y mueve o lista las coincidencias.
process_maildir()
{
    local search_path="$1"
    local expected_from="${FROM_USER}@gigot.com.ar"
    local mail_file=""
    local from_header=""
    local return_path_header=""
    local env_header=""
    local from_value=""
    local return_path_value=""
    local date_header=""
    local date_value=""
    local env_addr=""
    local found_regular_file="FALSE"

    if [ -n "$(find "${search_path}" -path "*/${MAILDIR_SUFFIX}/*" -type f -print -quit 2>/dev/null)" ]; then
        found_regular_file="TRUE"
    fi

    if [ "${found_regular_file}" != "TRUE" ]; then
        echo "Error: no se encontraron archivos regulares bajo los Maildir analizados." >&2
        return 1
    fi

    while IFS= read -r -d '' mail_file; do
        from_header=$(grep -m 1 '^From:' "${mail_file}" 2>/dev/null || true)
        return_path_header=$(grep -m 1 '^Return-path:' "${mail_file}" 2>/dev/null || true)
        env_header=$(grep -m 1 '^Envelope-to:' "${mail_file}" 2>/dev/null || true)
        date_header=$(grep -m 1 '^Date:' "${mail_file}" 2>/dev/null || true)

        if { [ -z "${from_header}" ] && [ -z "${return_path_header}" ]; } || [ -z "${env_header}" ]; then
            echo "[WARN] Headers ausentes: ${mail_file}" >&2
            continue
        fi

        from_value=${from_header#From: }
        return_path_value=${return_path_header#Return-path: }
        env_addr=${env_header#Envelope-to: }
        date_value=${date_header#Date: }

        if [ -z "${date_header}" ]; then
            date_value="Date header ausente"
        fi

        if [ -n "${from_header}" ]; then
            case "${from_value}" in
                "${expected_from}")
                    ;;
                "Conectados Gigot Cosméticos <${expected_from}>")
                    ;;
                *"<${expected_from}>")
                    ;;
                *)
                    if [ -n "${return_path_header}" ]; then
                        case "${return_path_value}" in
                            "<${expected_from}>")
                                ;;
                            *)
                                continue
                                ;;
                        esac
                    else
                        continue
                    fi
                    ;;
            esac
        else
            case "${return_path_value}" in
                "<${expected_from}>")
                    ;;
                *)
                    continue
                    ;;
            esac
        fi

        if [ "${env_addr}" != "${ENVELOPE_TO}" ]; then
            continue
        fi

        FILES_MATCHED=$((FILES_MATCHED + 1))

        if [ "${DRY_RUN}" = "TRUE" ]; then
            print_match_info "${mail_file}" "${date_value}"
            continue
        fi

        if mv "${mail_file}" "${DEST_DIR}/" 2>/dev/null; then
            print_match_info "${mail_file}" "${date_value}"
            FILES_MOVED=$((FILES_MOVED + 1))
        else
            echo "[ERROR] No se pudo mover: ${mail_file}" >&2
            FILES_FAILED=$((FILES_FAILED + 1))
        fi
    done < <(
        find "${search_path}" \
            -path "*/${MAILDIR_SUFFIX}/*" \
            ! -path "*/${MAILDIR_SUFFIX}/.Sent/*" \
            ! -path "*/${MAILDIR_SUFFIX}/.Template/*" \
            -type f \
            ! -name 'dovecot*' \
            -newermt "${YEAR}-01-01" \
            ! -newermt "$((YEAR + 1))-01-01" \
            -print0 2>/dev/null
    )

    if [ "${FILES_MATCHED}" -eq 0 ]; then
        echo "Error: no se encontraron archivos que coincidan con los criterios solicitados." >&2
        return 1
    fi

    if [ "${DRY_RUN}" != "TRUE" ] && [ "${FILES_MOVED}" -eq 0 ] && [ "${FILES_FAILED}" -gt 0 ]; then
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# 4. MAIN
# -----------------------------------------------------------------------------
# Orquesta parseo, validaciones, confirmacion y procesamiento principal.
main()
{
    local opt=""
    local search_path="${MAIL_BASE}"

    while getopts ":d:f:Y:u:ryh" opt; do
        case "${opt}" in
            d)
                DEST_DIR="${OPTARG}"
                ;;
            f)
                FROM_USER="${OPTARG}"
                ;;
            Y)
                YEAR="${OPTARG}"
                ;;
            u)
                SINGLE_USER="${OPTARG}"
                ;;
            r)
                DRY_RUN="TRUE"
                ;;
            y)
                ASSUME_YES="TRUE"
                ;;
            h)
                usage
                exit 0
                ;;
            :)
                print_error_red "Error: la opcion -${OPTARG} requiere un argumento."
                usage >&2
                exit 1
                ;;
            \?)
                print_error_red "Error: opcion desconocida -${OPTARG}."
                usage >&2
                exit 1
                ;;
        esac
    done

    shift $((OPTIND - 1))

    if [ "$#" -gt 0 ]; then
        print_error_red "Error: no se admiten argumentos posicionales extra."
        usage >&2
        exit 1
    fi

    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    validate_args
    validate_year
    validate_dest_dir

    if [ -n "${SINGLE_USER}" ]; then
        search_path="${MAIL_BASE}/${SINGLE_USER}/${MAILDIR_SUFFIX}"
        validate_maildir "${search_path}"
    fi

    SUMMARY_ENABLED="TRUE"

    print_execution_variables
    confirm_or_exit
    process_maildir "${search_path}"
}

# -----------------------------------------------------------------------------
# 5. INVOCACION
# -----------------------------------------------------------------------------
main "$@"
