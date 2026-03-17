#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: suma.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: gpt-5.1-codex-mini
# FECHA: 17/Marzo/2026
# DESCRIPCION: Suma dos números reales con máximo dos decimales y
#              registra el proceso en STDERR.
#
# REQUERIMIENTOS: Ejecutable desde un shell compatible con Bash 4.x.
# USO: ./suma.sh [-d] <número1> <número2>
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACIÓN INICIAL
# -----------------------------------------------------------------------------

# Determinar directorio del script y raíz del workspace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Cargar logger
if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    # shellcheck source=/home/carlos/workspace/_proyectos_/bash_scripts/lib/logger.sh
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

# Los logs deben emitirse por STDERR explícitamente
log_info()
{
    echo -e "${G}[INFO] ${1}${N}" >&2
}

log_warn()
{
    echo -e "${Y}[WARN] ${1}${N}" >&2
}

: "${DEBUG:=FALSE}"

# -----------------------------------------------------------------------------
# 2. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

cleanup()
{
    if [[ "${DEBUG}" != "TRUE" ]]; then
        log_info "Finalizando suma.sh y liberando recursos (si aplica)."
    fi
}
trap cleanup EXIT ERR INT TERM

#------+---------+---------+---------+---------+---------+---------+---------+

usage()
{
    local script_name
    script_name="$(basename "${0}")"

    cat <<EOF >&2
Uso:
  ./${script_name} [-d] <número1> <número2>

Descripción:
  Suma dos valores reales con hasta dos decimales y muestra el resultado
  formateado en STDOUT. Los logs y errores se escriben por STDERR.

Opciones:
  -d      Activa modo debug (set -x).
  -h      Muestra esta ayuda y sale.

Argumentos:
  El script requiere exactamente dos números reales (signo opcional) con punto
  decimal y máximo dos dígitos fraccionales.
EOF
}

#------+---------+---------+---------+---------+---------+---------+---------+

confirm_or_exit()
{
    # No se requiere confirmación para este script, pero dejamos el stub en caso
    :
}

# -----------------------------------------------------------------------------
# 3. VALIDACIONES Y CONVERSIÓN
# -----------------------------------------------------------------------------

validate_input()
{
    local value="$1"
    local regex='^-?[0-9]+(\.[0-9]+)?$'

    if [[ ! "${value}" =~ ${regex} ]]; then
        log_error "Argumento inválido '${value}'. Debe ser un número real con punto y hasta dos decimales."
        return 1
    fi

    local fractional_part
    fractional_part="${value#*.}"

    if [[ "${value}" != *.* ]]; then
        fractional_part=""
    fi

    if [[ -n "${fractional_part}" && ${#fractional_part} -gt 2 ]]; then
        log_error "El número '${value}' tiene más de dos decimales."
        return 1
    fi

    return 0
}

convert_to_cents()
{
    local raw="$1"
    local sign=1

    if [[ "${raw}" == -* ]]; then
        sign=-1
        raw="${raw:1}"
    fi

    local integer_part fractional_part

    if [[ "${raw}" == *.* ]]; then
        integer_part="${raw%%.*}"
        fractional_part="${raw#*.}"
    else
        integer_part="${raw}"
        fractional_part=""
    fi

    fractional_part="${fractional_part}00"
    fractional_part="${fractional_part:0:2}"

    local integer_value
    integer_value=$((10#${integer_part}))
    local fraction_value
    fraction_value=$((10#${fractional_part}))

    local cents
    cents=$((integer_value * 100 + fraction_value))

    echo $((sign * cents))
}

format_result()
{
    local cents="$1"
    local abs_cents="${cents#-}"
    local sign=""

    if [[ "${cents}" == -* ]]; then
        sign="-"
    fi

    local integer_part
    integer_part=$((abs_cents / 100))
    local fractional_part
    fractional_part=$((abs_cents % 100))

    printf "%s%d.%02d" "${sign}" "${integer_part}" "${fractional_part}"
}

# -----------------------------------------------------------------------------
# 4. PARSEO Y LÓGICA PRINCIPAL
# -----------------------------------------------------------------------------

parse_arguments()
{
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -d)
                DEBUG="TRUE"
                shift
                ;;
            -h)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                break
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ "$#" -ne 2 ]]; then
        log_error "Se requieren exactamente 2 argumentos posicionales."
        usage
        exit 1
    fi

    NUMBERS=("$1" "$2")
}

# -----------------------------------------------------------------------------
# 5. FUNCIÓN PRINCIPAL MAIN
# -----------------------------------------------------------------------------

main()
{
    parse_arguments "$@"

    if [[ "${DEBUG}" == "TRUE" ]]; then
        set -x
    else
        set +x
    fi

    log_info "Se iniciará la suma de '${NUMBERS[0]}' y '${NUMBERS[1]}'."

    for value in "${NUMBERS[@]}"; do
        if ! validate_input "${value}"; then
            exit 1
        fi
    done

    local left_cents
    left_cents=$(convert_to_cents "${NUMBERS[0]}")
    local right_cents
    right_cents=$(convert_to_cents "${NUMBERS[1]}")

    local total_cents
    total_cents=$((left_cents + right_cents))
    local result
    result=$(format_result "${total_cents}")

    log_info "Suma completada: ${NUMBERS[0]} + ${NUMBERS[1]} = ${result}."
    echo "Resultado: ${result}"
}

main "$@"
