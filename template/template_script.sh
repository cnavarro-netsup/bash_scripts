#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: template_script.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: <Nombre del Modelo AI>
# FECHA: <fecha>
# DESCRIPCION: Script base a utilizar como plantilla para nuevos desarrollos.
#              (Reemplazar esta descripción con el objetivo real del script)
#
# REQUERIMIENTOS: <los permisos necesarios en la estructura de ejecución>
# USO: ./template_script.sh -h
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACIÓN INICIAL
# -----------------------------------------------------------------------------

# Determinar el directorio donde se ubica este script y la raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Asumiendo que este script vivirá dentro de la carpeta del proyecto (ej: proyecto_x/mi_script.sh)
# Y que las librerías "lib/" viven en el directorio padre absoluto de donde clones tus proyectos.
# Por lo que subimos un nivel para llegar a "bash_scripts". Ajustar si es necesario.
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar la librería estándar de logs
if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró la librería logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

# Cargar la librería SSH obligatoria para alcance en red
if [[ -f "${PROJECT_ROOT}/lib/ssh_utils.sh" ]]; then
    source "${PROJECT_ROOT}/lib/ssh_utils.sh"
else
    log_warn "Opcional: No se encontró ssh_utils.sh en lib/, las func. SSH no estarán disp."
fi

# Cargar la librería SQLite opcional para persistencia de datos
if [[ -f "${PROJECT_ROOT}/lib/sqlite_utils.sh" ]]; then
    source "${PROJECT_ROOT}/lib/sqlite_utils.sh"
    # export DB_PATH="${SCRIPT_DIR}/proyecto.db"
fi

# (Opcional) Guardar logs físicos del script actual
# LOG_FILE="${SCRIPT_DIR}/ejecucion.log"

# -----------------------------------------------------------------------------
# 2. DEFINICIÓN DE VARIABLES DE EJECUCIÓN CON DEFAULT FALLBACKS
# -----------------------------------------------------------------------------

: "${DEBUG:=FALSE}"
: "${ASSUME_YES:=FALSE}"
# : "${DRY_RUN:=FALSE}" # Opcional: Descomentar si existen operaciones destructivas
: "${TARGET_NAME:="default_target"}"
: "${OPERATION_TYPE:="LV"}"
: "${TIME_LIMIT:=30}"

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
#--------------------------------------
usage()
{
    local script_name
    script_name=$(basename "${0}")

    cat <<EOF
Uso:
  ./${script_name} -v <nombre> [opciones]

Descripción:
  Breve descripción de lo que hace el script principal.
  Por favor, adapte esta sección al propósito de su herramienta.

Obligatorios:
  -v, --vm    Nombre de la VM / Recurso

Opciones:
  -t, --type  Tipo de operación: SNAP o LV (default: ${OPERATION_TYPE})
  -l, --limit Límite de tiempo en segundos (default: ${TIME_LIMIT})
  -d, --debug Debug (activa trazas de log extra)
  -y, --yes   Asumir "sí" a las confirmaciones
  # -D, --dry-run Mostrar lo que se ejecutaría sin hacer cambios (Opcional, solo ops destructivas)
  -h, --help  Mostrar esta ayuda y salir

Variables de Entorno:
  Las opciones pueden inyectarse por entorno. Ejemplo:
    TARGET_NAME="server1" OPERATION_TYPE="SNAP" DEBUG="TRUE" ./${script_name}

Ejemplos:
  ./${script_name} -v webserver01
  ./${script_name} -v webserver01 -t LV --dry-run
EOF
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
# -----------------------------------------------------------------------------
# 4. FUNCIÓN PRINCIPAL MAIN (PARSEO Y LÓGICA)
# -----------------------------------------------------------------------------
main()
{
    # ---------------------------------------------------------------
    # 4.1 Parseo de argumentos mixto (opciones cortas y largas)
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -v|--vm)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    TARGET_NAME="$2"
                    shift 2
                else
                    log_error "-v/--vm requiere un argumento."
                    usage
                    exit 2
                fi
                ;;
            -t|--type)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    OPERATION_TYPE="$2"
                    shift 2
                else
                    log_error "-t/--type requiere un argumento."
                    usage
                    exit 2
                fi
                ;;
            -l|--limit)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    TIME_LIMIT="$2"
                    shift 2
                else
                    log_error "-l/--limit requiere un argumento."
                    usage
                    exit 2
                fi
                ;;
            -d|--debug) DEBUG="TRUE"; shift ;;
            -y|--yes) ASSUME_YES="TRUE"; shift ;;
            # -D|--dry-run) DRY_RUN="TRUE"; shift ;; # Opcional (ops destructivas)
            -h|--help) usage; exit 0 ;;
            *)
                log_error "Argumento no reconocido: '$1'"
                usage
                exit 2
                ;;
        esac
    done

    # ---------------------------------------------------------------
    # 4.2 Configuración de modo silencioso (Batch/Cron)
    if [ "${ASSUME_YES}" = "TRUE" ]; then
        log_info() { :; }
        log_error() { :; }
        log_warn() { :; }
        usage() { :; }
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
    # En modo batch/cron (-y) no se imprimen variables de ejecución.
    if [ "${ASSUME_YES}" != "TRUE" ]; then
        echo -e "\033[0;32m Variables de Ejecución \033[0m"
        echo "TARGET_NAME : ${TARGET_NAME}"
        echo "TYPE        : ${OPERATION_TYPE}"
        echo "LIMIT       : ${TIME_LIMIT}"
        echo "DEBUG       : ${DEBUG}"
        # echo "DRY_RUN     : ${DRY_RUN}"
    fi
    
    # ---------------------------------------------------------------
    # 4.5 Puntos de confirmación o simulacro
    confirm_or_exit

    # if [ "${DRY_RUN}" = "TRUE" ]; then
    #     log_info "[DRY-RUN] Simulación concluida. No se ejecutarán cambios reales."
    #     exit 0
    # fi

    # ---------------------------------------------------------------
    # 4.6 Lógica del script en sí...
    log_info "Iniciando código operacional para el objetivo: ${TARGET_NAME}"
    
    # ---------------------------------------------------------
    # EJEMPLO LIBRERÍA SQLITE
    # ---------------------------------------------------------
    # db_init "CREATE TABLE IF NOT EXISTS status_log (id INTEGER, status TEXT);"
    # db_query "INSERT INTO status_log VALUES (1, 'OK');"
    
    # ---------------------------------------------------------
    # EJEMPLO LIBRERÍA SSH
    # ---------------------------------------------------------
    # if test_ssh_connection "${TARGET_NAME}"; then
    #     run_remote_cmd "${TARGET_NAME}" "uptime"
    # fi
    
    log_info "Ejecución finalizada con éxito."
}

# -----------------------------------------------------------------------------
# 5. INVOCACIÓN
# -----------------------------------------------------------------------------

main "$@"
