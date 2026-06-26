#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: backup_users_txs03.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: Claude Sonnet 4.6
# FECHA: 2026-06-23
# DESCRIPCION: Copia de seguridad incremental de perfiles de usuario Windows
#              (Desktop, Documents, Downloads) desde txs03 hacia un NAS Linux.
#              Usa sshfs (ro) + rsync (staging) + rdiff-backup (destino final).
#
# REQUERIMIENTOS: Ejecutar como root. Clave SSH desplegada para Administrador@txs03.
#                 Dependencias: sshfs, rsync, rdiff-backup (2.0.5+), mail, fusermount.
# USO: ./backup_users_txs03.sh
#      DEBUG=TRUE ./backup_users_txs03.sh
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# =============================================================================
# 1. CONFIGURACION
# =============================================================================

# Variables de configuración con defaults
: "${DEBUG:=FALSE}"
: "${SSHFS_SRC:=Administrador@txs03:..}"
: "${MOUNT_POINT:=/mnt/txs03}"
: "${STAGING_DIR:=/srv/tmp/txs03-user-staging}"
: "${DEST_DIR:=/srv/bk-daily/txs03-users}"
: "${MAX_INCREMENTS:=10}"
: "${MAIL_TO:=infraestructura@gigot.com.ar}"
: "${MAIL_FROM:=root}"
: "${LOG_FILE:=/var/log/backup_users_txs03.log}"

# Directorios de perfil a copiar
SUBDIRS=("Desktop" "Documents" "Downloads")

# Archivo de log temporal y contador de errores
LOG_TMP=""
ERRORS=0
EXIT_STATUS=0

# =============================================================================
# 2. FUNCIONES
# =============================================================================

#--------------------------------------
# Devuelve 0 si el directorio dado está actualmente montado.
is_mounted()
{
    local dir="$1"
    grep -qs " ${dir} " /proc/mounts
}
log_msg()
{
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    # Solo escribe si el archivo de log ya fue creado
    if [ -n "${LOG_TMP}" ] && [ -f "${LOG_TMP}" ]; then
        echo "[${timestamp}] [${level}] ${msg}" >> "${LOG_TMP}"
    fi
}

#--------------------------------------
# Registra un mensaje informativo.
log_info()
{
    log_msg "INFO" "$1"
}

#--------------------------------------
# Registra una advertencia no fatal.
log_warn()
{
    log_msg "WARN" "$1"
}

#--------------------------------------
# Registra un error y marca el flag de errores.
log_error()
{
    log_msg "ERROR" "$1"
    ERRORS=$(( ERRORS + 1 ))
}

#--------------------------------------
# Desmonta el punto de montaje sshfs y envía el log por mail; se ejecuta siempre.
cleanup()
{
    # Desactivar el trap dentro de cleanup para evitar re-entrada recursiva
    trap - EXIT ERR INT TERM

    local status_label

    # Determinar label para el asunto del mail
    if [ "${EXIT_STATUS}" -eq 0 ] && [ "${ERRORS}" -eq 0 ]; then
        status_label="OK"
    else
        status_label="FAILED"
    fi

    log_info "--- cleanup started ---"

    # Desmontar siempre /mnt/txs03
    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        log_info "Unmounting ${MOUNT_POINT}"
        if fusermount -u "${MOUNT_POINT}" 2>/dev/null || umount "${MOUNT_POINT}" 2>/dev/null; then
            log_info "Unmounted ${MOUNT_POINT} successfully"
        else
            log_warn "Could not unmount ${MOUNT_POINT} — manual check required"
        fi
    else
        log_info "${MOUNT_POINT} is not mounted, skipping unmount"
    fi

    # Enviar log por mail
    if [ -s "${LOG_TMP}" ]; then
        if command -v mail > /dev/null 2>&1; then
            mail -s "backup_users_txs03: ${status_label}" \
                 -r "${MAIL_FROM}" \
                 "${MAIL_TO}" < "${LOG_TMP}" \
                 || echo "[ERROR] mail command failed — log not sent to ${MAIL_TO}" >&2
        else
            echo "[ERROR] 'mail' not available — log not sent to ${MAIL_TO}" >&2
        fi
    fi

    # Eliminar log temporal
    [ -n "${LOG_TMP}" ] && rm -f "${LOG_TMP}"
}

trap cleanup EXIT ERR INT TERM

#--------------------------------------
# Verifica que todos los comandos requeridos estén disponibles.
check_dependencies()
{
    local deps=("sshfs" "rsync" "rdiff-backup" "mail" "fusermount" "mountpoint")
    local missing=0

    for cmd in "${deps[@]}"; do
        if ! command -v "${cmd}" > /dev/null 2>&1; then
            log_error "Required command not found: ${cmd}"
            missing=$(( missing + 1 ))
        fi
    done

    if [ "${missing}" -gt 0 ]; then
        log_error "Aborting: ${missing} required command(s) missing"
        exit 1
    fi

    log_info "All dependencies satisfied"
}

#--------------------------------------
# Monta el recurso sshfs en modo read-only si no está ya montado.
mount_source()
{
    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        log_info "${MOUNT_POINT} already mounted, reusing"
        return 0
    fi

    log_info "Mounting ${SSHFS_SRC} on ${MOUNT_POINT} (read-only)"
    if ! sshfs -o ro,BatchMode=yes,ConnectTimeout=10 \
               "${SSHFS_SRC}" "${MOUNT_POINT}"; then
        log_error "Failed to mount ${SSHFS_SRC} on ${MOUNT_POINT}"
        exit 1
    fi

    log_info "Mounted ${MOUNT_POINT} successfully"
}

#--------------------------------------
# Copia los subdirectorios de un perfil al staging mediante rsync.
sync_profile()
{
    local profile_dir="$1"
    local profile_name
    profile_name="$(basename "${profile_dir}")"
    local profile_errors=0

    log_info "Processing profile: ${profile_name}"

    for subdir in "${SUBDIRS[@]}"; do
        local src="${profile_dir}/${subdir}"
        local dst="${STAGING_DIR}/${profile_name}/${subdir}"

        if [ ! -d "${src}" ]; then
            log_warn "  [${profile_name}] Directory not found, skipping: ${subdir}"
            continue
        fi

        log_info "  [${profile_name}] rsync ${subdir} → staging"

        if ! mkdir -p "${dst}"; then
            log_error "  [${profile_name}] Failed to create staging dir: ${dst}"
            profile_errors=$(( profile_errors + 1 ))
            continue
        fi

        if ! rsync -a --no-perms --no-owner --no-group \
                   --exclude='*.tmp' \
                   --exclude='desktop.ini' \
                   "${src}/" "${dst}/"; then
            log_error "  [${profile_name}] rsync failed for: ${subdir}"
            profile_errors=$(( profile_errors + 1 ))
        else
            log_info "  [${profile_name}] ${subdir} synced successfully"
        fi
    done

    return "${profile_errors}"
}

#--------------------------------------
# Itera sobre todos los perfiles y llama a sync_profile para cada uno.
sync_all_profiles()
{
    local profile_count=0
    local failed_profiles=0

    # Crear el directorio de staging si no existe
    if [ ! -d "${STAGING_DIR}" ]; then
        log_info "Staging directory does not exist, creating: ${STAGING_DIR}"
        if ! mkdir -p "${STAGING_DIR}"; then
            log_error "Failed to create staging directory: ${STAGING_DIR}"
            exit 1
        fi
    fi

    log_info "Starting rsync staging phase: ${MOUNT_POINT}/* → ${STAGING_DIR}"

    for profile_dir in "${MOUNT_POINT}"/*/; do
        # Ignorar entradas que no sean directorios reales
        [ -d "${profile_dir}" ] || continue

        profile_count=$(( profile_count + 1 ))

        if ! sync_profile "${profile_dir}"; then
            failed_profiles=$(( failed_profiles + 1 ))
        fi
    done

    if [ "${profile_count}" -eq 0 ]; then
        log_error "No user profiles found in ${MOUNT_POINT}"
        exit 1
    fi

    log_info "rsync phase complete: ${profile_count} profile(s) processed, ${failed_profiles} with errors"
}

#--------------------------------------
# Ejecuta rdiff-backup desde staging al destino definitivo.
run_rdiff_backup()
{
    # Crear el directorio destino si no existe (primera ejecución)
    if [ ! -d "${DEST_DIR}" ]; then
        log_info "Destination directory does not exist, creating: ${DEST_DIR}"
        if ! mkdir -p "${DEST_DIR}"; then
            log_error "Failed to create destination directory: ${DEST_DIR}"
            exit 1
        fi
    fi

    log_info "Starting rdiff-backup: ${STAGING_DIR} → ${DEST_DIR}"

    if ! rdiff-backup --exclude-special-files \
            "${STAGING_DIR}/" "${DEST_DIR}" >> "${LOG_TMP}" 2>&1; then
        log_error "rdiff-backup backup phase failed"
        exit 1
    fi

    log_info "rdiff-backup backup completed successfully"

    log_info "Removing increments older than ${MAX_INCREMENTS} (keeping ${MAX_INCREMENTS})"

    if ! rdiff-backup --remove-older-than "${MAX_INCREMENTS}B" \
            --force "${DEST_DIR}" >> "${LOG_TMP}" 2>&1; then
        log_warn "rdiff-backup remove increments returned non-zero (check manually)"
    else
        log_info "Old increments removed successfully"
    fi
}

# =============================================================================
# 3. MAIN
# =============================================================================

main()
{
    # Modo debug
    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    # Crear log temporal
    LOG_TMP="$(mktemp /tmp/backup_users_txs03_XXXXXX.log)"

    log_info "========== backup_users_txs03 started =========="
    log_info "SSHFS_SRC        : ${SSHFS_SRC}"
    log_info "MOUNT_POINT      : ${MOUNT_POINT}"
    log_info "STAGING_DIR      : ${STAGING_DIR}"
    log_info "DEST_DIR         : ${DEST_DIR}"
    log_info "MAX_INCREMENTS   : ${MAX_INCREMENTS}"
    log_info "MAIL_TO          : ${MAIL_TO}"

    check_dependencies
    mount_source
    sync_all_profiles
    run_rdiff_backup

    log_info "========== backup_users_txs03 finished =========="

    if [ "${ERRORS}" -gt 0 ]; then
        log_info "Completed with ${ERRORS} error(s) — exit status 1"
        EXIT_STATUS=1
        exit 1
    fi

    EXIT_STATUS=0
    exit 0
}

main "$@"
