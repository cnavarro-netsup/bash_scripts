#!/usr/bin/env bash

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: sqlite_utils.sh
# VERSION: 1.0.0
# AUTOR: CPN + ChatGPT
# FECHA: 12/Marzo/2026
# DESCRIPCION: Librería estándar para interactuar con bases de datos SQLite3.
#              Maneja de forma transparente comandos DDL/DML y consultas SELECT 
#              para la capa de persistencia de los scripts Bash.
# USO: source sqlite_utils.sh
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: sqlite_utils.sh es una librería. Usa 'source sqlite_utils.sh'." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. CONFIGURACIÓN GLOBAL DE SQLITE
# -----------------------------------------------------------------------------

# Por defecto, la base de datos se guarda en el mismo directorio temporal para evitar ensuciar el CWD
: "${DB_PATH:="$(pwd)/database.db"}"

# Timeout de espera (en milisegundos) si la BD está bloqueada por otro proceso escribiendo
: "${DB_TIMEOUT:="5000"}"

# -----------------------------------------------------------------------------
# 2. FUNCIONES DE API PÚBLICA
# -----------------------------------------------------------------------------

# Comprueba si el binario de sqlite3 está instalado en el sistema
check_sqlite_binary()
{
    if ! command -v sqlite3 >/dev/null 2>&1; then
        die "[SQLite] Dependencia ausente. El comando 'sqlite3' no está instalado. Por favor instale el paquete (apt get install sqlite3)." 1
    fi
}

# Inicializa la base de datos y crea la estructura de tablas a partir de un esquema.
# Automáticamente comprueba el binario antes de la ejecución.
# Uso: db_init "CREATE TABLE IF NOT EXISTS audit_log (id INTEGER PRIMARY KEY, msg TEXT);"
db_init()
{
    local schema="$1"
    
    if [[ -z "${schema}" ]]; then
        log_error "[SQLite] db_init requiere la sentencia del SCHEMA."
        return 1
    fi
    
    check_sqlite_binary
    
    if sqlite3 -cmd ".timeout ${DB_TIMEOUT}" "${DB_PATH}" "${schema}"; then
        log_info "[SQLite] Esquema de base de datos listo en: ${DB_PATH}"
        return 0
    else
        log_error "[SQLite] Fallo al inicializar el esquema. Asegurese de que el SQLite sea válido o compruebe permisos de escritura."
        return 1
    fi
}

# Ejecuta una sentencia DML (INSERT, UPDATE, DELETE) que altera la BD.
# Uso: db_query "INSERT INTO audit_log (msg) VALUES ('Operacion X');"
db_query()
{
    local sql="$1"
    
    if [[ -z "${sql}" ]]; then
        log_error "[SQLite] db_query requiere la sentencia SQL."
        return 1
    fi
    
    check_sqlite_binary
    
    sqlite3 -cmd ".timeout ${DB_TIMEOUT}" "${DB_PATH}" "${sql}"
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "[SQLite] Error intentando inyectar query: ${sql}"
    fi
    
    return "${exit_code}"
}

# Ejecuta un comando SELECT y vuelca los valores en STDOUT de modo plano (ideal para Bash vars).
# El delimitador por defecto es el carácter pipe (|).
# Uso: resultado=$(db_select "SELECT * FROM audit_log LIMIT 5;")
db_select()
{
    local sql="$1"
    
    if [[ -z "${sql}" ]]; then
        log_error "[SQLite] db_select requiere de la sentencia SQL a realizar (SELECT)."
        return 1
    fi
    
    check_sqlite_binary
    
    sqlite3 -batch -cmd ".timeout ${DB_TIMEOUT}" "${DB_PATH}" "${sql}"
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "[SQLite] Error extrayendo datos con el comando SELECT: ${sql}"
    fi
    
    return "${exit_code}"
}
