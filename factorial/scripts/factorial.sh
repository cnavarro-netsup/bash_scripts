#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: factorial.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: Gemini 3.1 Pro
# FECHA: 13/marzo/2026
# DESCRIPCION: Script que calcula el factorial de un número mediante iteración.
#
# REQUERIMIENTOS: Ejecución estándar, sin permisos especiales.
# USO: ./factorial.sh -n <numero> [opciones]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACIÓN INICIAL
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Cargar la librería estándar de logs
if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró la librería logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. DEFINICIÓN DE VARIABLES DE EJECUCIÓN CON DEFAULT FALLBACKS
# -----------------------------------------------------------------------------

: "${DEBUG:=FALSE}"
: "${ASSUME_YES:=FALSE}"
: "${DRY_RUN:=FALSE}"
: "${NUMBER:=""}"



# -----------------------------------------------------------------------------
# 3. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

cleanup()
{
    if [ "${ASSUME_YES}" != "TRUE" ]; then
        log_info "Ejecutando cleanup (limpieza de entorno)..."
    fi
}
trap cleanup EXIT ERR INT TERM

#------+---------+---------+---------+---------+---------+---------+---------+

usage()
{
    local script_name
    script_name=$(basename "${0}")

    cat <<EOF
Uso:
  ./${script_name} -n <numero> [opciones]

Descripción:
  Calcula el factorial de un número entero positivo (1-19) mediante iteración.

Obligatorios:
  -n, --number  Número entero positivo

Opciones:
  -d, --debug    Debug (activa trazas de log extra)
  -y, --yes      Asumir "sí" a las confirmaciones
  -D, --dry-run  Mostrar lo que se ejecutaría sin hacer cambios (Dry-run)
  -h, --help     Mostrar esta ayuda y salir

Ejemplos:
  ./${script_name} -n 5
  ./${script_name} -n 19 --dry-run
EOF
}

#------+---------+---------+---------+---------+---------+---------+---------+

confirm_or_exit()
{
    if [ "${ASSUME_YES}" = "TRUE" ]; then
        return 0
    fi

    local confirm
    read -r -p "¿Continuar? (s/N): " confirm
    case "${confirm:-}" in
        s|S|si|SI|Si) return 0 ;;
        *) 
            echo -e "${R} ✖ Cancelado por el usuario. ${N}"
            exit 1 
            ;;
    esac
}

#------+---------+---------+---------+---------+---------+---------+---------+

validate_input()
{
    local n="$1"

    if [[ -z "$n" ]]; then
        log_error "Debe proveer un número argumentando -n <numero>."
        usage
        exit 1
    fi

    if [[ ! "$n" =~ ^[0-9]+$ ]]; then
        log_error "El argumento debe ser un número entero."
        exit 1
    fi

    if (( n == 0 )); then
        log_error "El número debe ser mayor que cero."
        exit 1
    fi

    if (( n >= 20 )); then
        log_error "El número debe ser menor que 20."
        exit 1
    fi
}

#------+---------+---------+---------+---------+---------+---------+---------+

calculate_factorial()
{
    local n="$1"
    local iter
    local result=1

    for (( iter=1; iter<=n; iter++ )); do
        result=$(( result * iter ))
    done

    if [ "${ASSUME_YES}" = "TRUE" ]; then
        echo "${result}"
    else
        echo "${n}! = ${result}"
    fi
}

# -----------------------------------------------------------------------------
# 4. FUNCIÓN PRINCIPAL MAIN (PARSEO Y LÓGICA)
# -----------------------------------------------------------------------------

main()
{
    # ---------------------------------------------------------------
    # 4.1 Parseo de argumentos
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -n|--number)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    NUMBER="$2"
                    shift 2
                else
                    log_error "-n/--number requiere un argumento."
                    usage
                    exit 2
                fi
                ;;
            -d|--debug) DEBUG="TRUE"; shift ;;
            -y|--yes) ASSUME_YES="TRUE"; shift ;;
            -D|--dry-run) DRY_RUN="TRUE"; shift ;;
            -h|--help) usage; exit 1 ;;
            *)
                log_error "Argumento no reconocido: '$1'"
                usage
                exit 1
                ;;
        esac
    done

    if [ "${ASSUME_YES}" = "TRUE" ]; then
        log_info() { :; }
        log_error() { :; }
        usage() { :; }
    fi

    if [[ -z "$NUMBER" ]]; then
        usage
        exit 1
    fi

    # ---------------------------------------------------------------
    # 4.3 Setup del nivel de log / ejecución
    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    # ---------------------------------------------------------------
    # 4.4 Resumen de contexto
    if [ "${ASSUME_YES}" != "TRUE" ]; then
        echo -e "${G} Variables de Ejecución ${N}"
        echo "NUMBER      : ${NUMBER}"
        echo "DEBUG       : ${DEBUG}"
        echo "DRY_RUN     : ${DRY_RUN}"
    fi
    
    validate_input "${NUMBER}"

    # ---------------------------------------------------------------
    # 4.5 Puntos de confirmación o simulacro
    confirm_or_exit

    if [ "${DRY_RUN}" = "TRUE" ]; then
        log_info "[DRY-RUN] Se calcularía: ${NUMBER}!"
        exit 0
    fi

    # ---------------------------------------------------------------
    # 4.6 Lógica principal
    log_info "Iniciando cálculo para n=${NUMBER}"
    
    local resultado
    resultado=$(calculate_factorial "${NUMBER}")
    
    if [ "${ASSUME_YES}" = "TRUE" ]; then
        echo "${resultado}"
    else
        echo -e "${C}${resultado}${N}"
    fi
    
    log_info "Ejecución finalizada con éxito."
}

# -----------------------------------------------------------------------------
# 5. INVOCACIÓN
# -----------------------------------------------------------------------------

main "$@"
