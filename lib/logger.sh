#!/usr/bin/env bash

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: logger.sh
# VERSION: 1.0.0
# AUTOR: CPN + ChatGPT
# FECHA: 12/Marzo/2026
# DESCRIPCION: Librería estándar para el manejo estructurado de logs y
#              excepciones (errores). Imprime con colores en pantalla,
#              puede escribir a archivo y opcionalmente a syslog.
# USO: source logger.sh
#      log_info "Operación iniciada."
#      log_error "No se encontró el archivo."
#      die "Fallo crítico recuperable." 2
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# Guard: Verificar que el script está siendo "sourced" y no ejecutado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: logger.sh es una librería. Usa 'source logger.sh' en lugar de ejecutarlo directamente." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. CONFIGURACIÓN Y COLORES
# -----------------------------------------------------------------------------
readonly R="\033[0;31m"  # Rojo
readonly G="\033[0;32m"  # Verde
readonly Y="\033[0;33m"  # Amarillo
readonly B="\033[0;34m"  # Azul
readonly C="\033[0;36m"  # Cian
readonly N="\033[0m"     # Normal (sin color)

# LOG_FILE permite enviar una copia de los logs a un archivo (sin colores).
# Si está vacío, solo se loguea por consola.
: "${LOG_FILE:=}"

# Si LOG_STDOUT es FALSE, la librería trabaja en modo silencioso por consola
: "${LOG_STDOUT:="TRUE"}"

# Si LOG_TO_STDERR es TRUE, todos los niveles se envían por stderr.
: "${LOG_TO_STDERR:="FALSE"}"

# Si LOG_TO_SYSLOG es TRUE, además se envían mensajes a syslog con `logger`.
: "${LOG_TO_SYSLOG:="FALSE"}"
: "${LOG_SYSLOG_TAG:="bash_script"}"
: "${LOG_SYSLOG_FACILITY:="user"}"

# FUNCIONES
#--------------------------------------
logger_is_available()
{
    command -v logger >/dev/null 2>&1
}
#--------------------------------------
logger_validate_backend()
{
    if [ "${LOG_TO_SYSLOG}" = "TRUE" ] && ! logger_is_available; then
        echo "Error: LOG_TO_SYSLOG=TRUE pero el comando 'logger' no esta disponible." >&2
        return 1
    fi

    return 0
}
#--------------------------------------
_syslog_priority()
{
    local level_name="$1"

    case "${level_name}" in
        INFO) printf '%s' "${LOG_SYSLOG_FACILITY}.info" ;;
        WARN) printf '%s' "${LOG_SYSLOG_FACILITY}.warning" ;;
        ERROR|FATAL) printf '%s' "${LOG_SYSLOG_FACILITY}.err" ;;
        *) printf '%s' "${LOG_SYSLOG_FACILITY}.notice" ;;
    esac
}

# -----------------------------------------------------------------------------
# 2. MOTOR DE LOG INTERNO
# -----------------------------------------------------------------------------
_log()
{
    local level_color="$1"
    local level_name="$2"
    local message="$3"
    
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local prefix="${timestamp} [${level_name}]"
    
    # 2.1 Salida a Consola (stdout/stderr)
    if [ "${LOG_TO_STDERR}" = "TRUE" ]; then
        echo -e "${level_color}${prefix}${N} ${message}" >&2
    elif [ "${LOG_STDOUT}" = "TRUE" ]; then
        if [ "${level_name}" = "ERROR" ] || [ "${level_name}" = "FATAL" ]; then
            echo -e "${level_color}${prefix}${N} ${message}" >&2
        else
            echo -e "${level_color}${prefix}${N} ${message}"
        fi
    fi

    # 2.2 Salida a Archivo
    if [ -n "${LOG_FILE}" ]; then
        # Escribimos el sufijo sin secuencias de escape de color Bash
        echo "${prefix} ${message}" >> "${LOG_FILE}"
    fi

    # 2.3 Salida a Syslog
    if [ "${LOG_TO_SYSLOG}" = "TRUE" ]; then
        local priority
        priority=$(_syslog_priority "${level_name}")
        logger -p "${priority}" -t "${LOG_SYSLOG_TAG}" -- "${prefix} ${message}"
    fi
}

# -----------------------------------------------------------------------------
# 3. INTERFAZ PÚBLICA (API)
# -----------------------------------------------------------------------------

log_info()
{
    _log "${G}" "INFO" "$1"
}
#--------------------------------------
log_warn()
{
    _log "${Y}" "WARN" "$1"
}
#--------------------------------------
log_error()
{
    _log "${R}" "ERROR" "$1"
}

# die() imprime un log FATAL y detiene completamente la ejecución
# Recibe el mensaje (obligatorio) y el código de salida (opcional, default: 1)
die()
{
    local message="$1"
    local exit_code="${2:-1}"
    _log "${R}" "FATAL" "${message}"
    exit "${exit_code}"
}
