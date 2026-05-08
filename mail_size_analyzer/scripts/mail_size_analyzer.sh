#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: mail_size_analyzer.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: gpt-5.4
# FECHA: 08/mayo/2026
# DESCRIPCION: Analiza mails en Maildir y calcula su distribucion por tamano.
# REQUERIMIENTOS: Bash 4.2+, GNU find y permisos de lectura sobre /srv/mail.
# USO: ./mail_size_analyzer.sh [-h] [-c] [-u usuario]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. CONFIGURACION INICIAL
# -----------------------------------------------------------------------------

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
if [[ "${SCRIPT_SOURCE}" == */* ]]; then
    SCRIPT_DIR="$(cd "${SCRIPT_SOURCE%/*}" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
: "${SCRIPT_DIR}" "${PROJECT_ROOT}"

readonly BYTES_PER_MB=1048576
readonly DEFAULT_MAIL_ROOT_DIR="/srv/mail"
: "${MAIL_ROOT_DIR:=${DEFAULT_MAIL_ROOT_DIR}}"
compact_output="FALSE"
target_user=""
total_mail_count=0
bucket_counts=(0 0 0 0 0 0 0 0 0 0 0)
maildir_paths=()

# -----------------------------------------------------------------------------
# 2. FUNCIONES
# -----------------------------------------------------------------------------

#--------------------------------------
# Muestra la ayuda del script y describe flags y alcance de analisis.
usage()
{
    local script_name
    script_name="${0##*/}"

    cat <<EOF
Usage:
  ./${script_name} [-h] [-c] [-u usuario]

Description:
  Analyze mail files under ${MAIL_ROOT_DIR}/*/Maildir, or under a specific user
  Maildir when -u is provided, and print the size
  distribution in 11 buckets plus the total number of analyzed mails.

Options:
  -c  Print the 11 bucket counters and total in one line.
  -h  Show this help and exit.
  -u  Analyze only the specified user.
EOF
}

#--------------------------------------
# Imprime un mensaje de error uniforme por stderr.
print_error()
{
    printf 'Error: %s\n' "$1" >&2
}

#--------------------------------------
# Interpreta flags, rechaza argumentos posicionales y deriva validaciones asociadas.
parse_arguments()
{
    local option

    while getopts ":hcu:" option; do
        case "${option}" in
            h)
                usage
                exit 0
                ;;
            c)
                compact_output="TRUE"
                ;;
            u)
                target_user="${OPTARG}"
                ;;
            :)
                print_error "Option -${OPTARG} requires an argument."
                exit 1
                ;;
            \?)
                print_error "Invalid option: -${OPTARG}."
                exit 1
                ;;
        esac
    done

    shift $((OPTIND - 1))

    if [ "$#" -ne 0 ]; then
        print_error "Positional arguments are not supported."
        exit 1
    fi

    validate_target_user
}

#--------------------------------------
# Valida el nombre recibido con -u para evitar rutas o caracteres inseguros.
validate_target_user()
{
    if [ -z "${target_user}" ]; then
        return 0
    fi

    if [[ "${target_user}" == */* ]]; then
        print_error "User names must not contain '/'."
        exit 1
    fi

    if [[ ! "${target_user}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        print_error "Invalid user name: ${target_user}."
        exit 1
    fi
}

#--------------------------------------
# Verifica que el directorio base de correo exista y sea accesible.
validate_mail_root()
{
    if [ ! -d "${MAIL_ROOT_DIR}" ]; then
        print_error "Mail root directory not found: ${MAIL_ROOT_DIR}."
        exit 1
    fi

    if [ ! -r "${MAIL_ROOT_DIR}" ] || [ ! -x "${MAIL_ROOT_DIR}" ]; then
        print_error "Mail root directory is not accessible: ${MAIL_ROOT_DIR}."
        exit 1
    fi
}

#--------------------------------------
# Resuelve los Maildir objetivo para todos los usuarios o para uno puntual.
collect_maildirs()
{
    local line=""
    local find_status=""
    local target_maildir=""

    maildir_paths=()

    if [ -n "${target_user}" ]; then
        target_maildir="${MAIL_ROOT_DIR}/${target_user}/Maildir"

        if [ ! -d "${target_maildir}" ]; then
            print_error "Maildir directory not found for user: ${target_user}."
            exit 1
        fi

        if [ ! -r "${target_maildir}" ] || [ ! -x "${target_maildir}" ]; then
            print_error "Maildir directory is not accessible for user: ${target_user}."
            exit 1
        fi

        maildir_paths=( "${target_maildir}" )
        return 0
    fi

    while IFS= read -r line; do
        case "${line}" in
            __FIND_STATUS:*)
                find_status="${line#__FIND_STATUS:}"
                ;;
            *)
                if [ -n "${line}" ]; then
                    maildir_paths+=( "${line}" )
                fi
                ;;
        esac
    done < <(find "${MAIL_ROOT_DIR}" -mindepth 2 -maxdepth 2 -type d -name Maildir -print 2>/dev/null; printf '__FIND_STATUS:%s\n' "$?")

    if [ "${find_status:-1}" -ne 0 ]; then
        print_error "Failed to inspect the Maildir structure under ${MAIL_ROOT_DIR}."
        exit 1
    fi

    if [ "${#maildir_paths[@]}" -eq 0 ]; then
        print_error "Empty mail structure: no Maildir directories found under ${MAIL_ROOT_DIR}."
        exit 1
    fi
}

#--------------------------------------
# Extrae el nombre de usuario a partir de la ruta absoluta del Maildir.
user_name_from_maildir()
{
    local maildir_path="$1"
    local user_path=""

    user_path="${maildir_path%/Maildir}"
    printf '%s\n' "${user_path##*/}"
}

#--------------------------------------
# Muestra el usuario activo solo cuando la salida no esta en modo compacto.
print_active_user()
{
    local maildir_path="$1"

    if [ "${compact_output}" = "TRUE" ]; then
        return 0
    fi

    user_name_from_maildir "${maildir_path}"
}

#--------------------------------------
# Convierte bytes a MB truncados y devuelve el indice del nicho correspondiente.
bucket_index_from_bytes()
{
    local mail_size_bytes="$1"
    local mail_size_mb=0

    mail_size_mb=$((mail_size_bytes / BYTES_PER_MB))

    if [ "${mail_size_mb}" -gt 100 ]; then
        printf '10\n'
        return 0
    fi

    if [ "${mail_size_mb}" -eq 100 ]; then
        printf '9\n'
        return 0
    fi

    printf '%s\n' "$((mail_size_mb / 10))"
}

#--------------------------------------
# Acumula un mail analizado en su nicho y actualiza el total general.
register_mail_size()
{
    local mail_size_bytes="$1"
    local bucket_index=0

    bucket_index="$(bucket_index_from_bytes "${mail_size_bytes}")"
    bucket_counts[bucket_index]=$((bucket_counts[bucket_index] + 1))
    total_mail_count=$((total_mail_count + 1))
}

#--------------------------------------
# Recorre un Maildir, lee tamanos con find y registra cada archivo regular.
analyze_maildir()
{
    local maildir_path="$1"
    local line=""
    local find_status=""

    while IFS= read -r line; do
        case "${line}" in
            __FIND_STATUS:*)
                find_status="${line#__FIND_STATUS:}"
                ;;
            *)
                if [[ ! "${line}" =~ ^[0-9]+$ ]]; then
                    print_error "Corrupt mail structure detected while reading ${maildir_path}."
                    exit 1
                fi
                register_mail_size "${line}"
                ;;
        esac
    done < <(find "${maildir_path}" -type f -printf '%s\n' 2>/dev/null; printf '__FIND_STATUS:%s\n' "$?")

    if [ "${find_status:-1}" -ne 0 ]; then
        print_error "Corrupt mail structure: failed to read ${maildir_path}."
        exit 1
    fi
}

#--------------------------------------
# Procesa todos los Maildir resueltos y detecta estructuras sin mails analizables.
analyze_maildirs()
{
    local maildir_path=""

    for maildir_path in "${maildir_paths[@]}"; do
        print_active_user "${maildir_path}"
        analyze_maildir "${maildir_path}"
    done

    if [ "${total_mail_count}" -eq 0 ]; then
        print_error "Empty mail structure: no regular files found under ${MAIL_ROOT_DIR}."
        exit 1
    fi
}

#--------------------------------------
# Imprime la salida expandida: usuarios ya mostrados, nichos y total final.
print_multiline_output()
{
    local bucket_index=0
    local range_start=0
    local range_end=0

    while [ "${bucket_index}" -lt 10 ]; do
        range_start=$((bucket_index * 10))
        range_end=$((range_start + 10))
        printf '%s-%s -> %s\n' "${range_start}" "${range_end}" "${bucket_counts[${bucket_index}]}"
        bucket_index=$((bucket_index + 1))
    done

    printf '+100 -> %s\n' "${bucket_counts[10]}"
    printf 'TOTAL -> %s\n' "${total_mail_count}"
}

#--------------------------------------
# Imprime todos los contadores y el total en una sola linea.
print_compact_output()
{
    local bucket_index=0

    while [ "${bucket_index}" -lt 11 ]; do
        if [ "${bucket_index}" -gt 0 ]; then
            printf ' '
        fi
        printf '%s' "${bucket_counts[${bucket_index}]}"
        bucket_index=$((bucket_index + 1))
    done

    printf ' %s\n' "${total_mail_count}"
}

#--------------------------------------
# Selecciona el formato final de salida segun el flag -c.
print_results()
{
    if [ "${compact_output}" = "TRUE" ]; then
        print_compact_output
        return 0
    fi

    print_multiline_output
}

# -----------------------------------------------------------------------------
# 3. MAIN
# -----------------------------------------------------------------------------

# Coordina parseo, validaciones, analisis y emision del resultado final.
main()
{
    parse_arguments "$@"
    validate_mail_root
    collect_maildirs
    analyze_maildirs
    print_results
}

main "$@"
