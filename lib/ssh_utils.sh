#!/usr/bin/env bash

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: ssh_utils.sh
# VERSION: 1.0.0
# AUTOR: CPN + ChatGPT
# FECHA: 12/Marzo/2026
# DESCRIPCION: Librería estándar para gestionar conexiones SSH de forma segura,
#              desatendida (BatchMode) y con timeouts configurables.
# USO: source ssh_utils.sh
#      test_ssh_connection "192.168.1.10"
#      run_remote_cmd "192.168.1.10" "ls -la /tmp"
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: ssh_utils.sh es una librería. Usa 'source ssh_utils.sh'." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. CONFIGURACIÓN GLOBALES DE SSH
# -----------------------------------------------------------------------------

# Parámetros por defecto para conexiones (pueden ser sobreescritos por env vars)
: "${SSH_USER:="root"}"
: "${SSH_PORT:="22"}"
: "${SSH_TIMEOUT:="5"}"

# Opciones base de SSH para operación DESATENDIDA síncrona
# -q: Quiet mode
# -o BatchMode=yes: Impide que el cliente pregunte contraseñas si falla la key
# -o StrictHostKeyChecking=accept-new: Acepta nuevas huellas sin preguntar, pero falla si cambian
# -o ConnectTimeout: Fija un límite de tiempo si la máquina está apagada/inaccesible
readonly SSH_BASE_OPTIONS=(
    "-q"
    "-o" "BatchMode=yes"
    "-o" "StrictHostKeyChecking=accept-new"
    "-o" "ConnectTimeout=${SSH_TIMEOUT}"
    "-p" "${SSH_PORT}"
)

# -----------------------------------------------------------------------------
# 2. FUNCIONES DE API PÚBLICA
# -----------------------------------------------------------------------------

# Ejecuta un comando en un servidor remoto mediante SSH.
# Uso: run_remote_cmd <IP_DESTINO> <COMANDO_A_EJECUTAR>
# Devuelve: El código de salida del comando en el servidor remoto
run_remote_cmd()
{
    local target="$1"
    local command="$2"

    if [[ -z "${target}" || -z "${command}" ]]; then
        log_error "[SSH] run_remote_cmd: Faltan argumentos (IP o CMD)."
        return 1
    fi

    # log_info "[SSH] Ejecutando '${command}' en ${SSH_USER}@${target}..."
    ssh "${SSH_BASE_OPTIONS[@]}" "${SSH_USER}@${target}" "${command}"
    
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "[SSH] Comando falló con código ${exit_code} en ${target}."
    fi
    
    return "${exit_code}"
}

# Realiza una comprobación ligera para verificar si un servidor acepta SSH.
# Uso: test_ssh_connection <IP_DESTINO>
# Devuelve: 0 si la conexión es exitosa, 1 si falla
test_ssh_connection()
{
    local target="$1"

    if [[ -z "${target}" ]]; then
        log_error "[SSH] test_ssh_connection: Falta IP de destino."
        return 1
    fi

    log_info "[SSH] Probando conexión a ${target}..."
    
    # Hacemos una prueba tonta (echo "OK") en lugar de abrir shell completo
    # Ocultamos toda salida para no ensuciar consolas de usuario
    if ssh "${SSH_BASE_OPTIONS[@]}" "${SSH_USER}@${target}" "echo 'OK'" >/dev/null 2>&1; then
        log_info "[SSH] Conexión estable con ${target}."
        return 0
    else
        log_error "[SSH] Imposible conectar a ${target} (Timeout, rechazo de llave o máquina caída)."
        return 1
    fi
}

# Transfiere un archivo de local a remoto.
# Uso: copy_to_remote <ARCHIVO_LOCAL> <IP_DESTINO> <RUTA_REMOTA>
copy_to_remote()
{
    local local_file="$1"
    local target="$2"
    local remote_path="$3"

    if [[ ! -f "${local_file}" ]]; then
        log_error "[SCP] Archivo local no existe: ${local_file}"
        return 1
    fi

    log_info "[SCP] Enviando ${local_file} a ${target}:${remote_path}..."
    scp "${SSH_BASE_OPTIONS[@]}" "${local_file}" "${SSH_USER}@${target}:${remote_path}"
    
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "[SCP] Fallo transfiriendo a ${target}."
    fi
    
    return "${exit_code}"
}