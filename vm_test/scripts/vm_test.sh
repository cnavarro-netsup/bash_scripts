#!/usr/bin/env bash

set -euo pipefail

#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: vm_test.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: Antigravity
# FECHA: 2026-03-25
# DESCRIPCION: Toma una imagen en crudo de una VM, monta la particion root 
#              tras verificar su consistencia e imprime el hostname.
#
# REQUERIMIENTOS: Ejecución como root
# USO: ./vm_test.sh <vm_image_file>
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+

# -----------------------------------------------------------------------------
# 1. LIBRERIAS Y CONFIGURACIÓN INICIAL
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Se incluye por estándar del repositorio (aunque stderr/stdout están restringidos)
if [[ -f "${PROJECT_ROOT}/lib/logger.sh" ]]; then
# shellcheck disable=SC1091
    source "${PROJECT_ROOT}/lib/logger.sh"
else
    echo "Error crítico: No se encontró logger.sh en ${PROJECT_ROOT}/lib/." >&2
    exit 1
fi

: "${DEBUG:=FALSE}"

# Variables de estado interno para el cleanup
KPARTX_MAPPED="FALSE"
VG_ACTIVATED="FALSE"
TEMP_MNT=""

# -----------------------------------------------------------------------------
# 3. FUNCIONES BASE OBLIGATORIAS
# -----------------------------------------------------------------------------

cleanup()
{
    # Desactivar fallos temporales en cleanup
    set +e
    
    if [ -n "${TEMP_MNT}" ] && mountpoint -q "${TEMP_MNT}"; then
        umount "${TEMP_MNT}" >/dev/null 2>&1
    fi
    if [ -n "${TEMP_MNT}" ] && [ -d "${TEMP_MNT}" ]; then
        rm -rf "${TEMP_MNT}" >/dev/null 2>&1
    fi

    if [ "${VG_ACTIVATED}" = "TRUE" ]; then
        vgchange -a n vg_os >/dev/null 2>&1
    fi

    if [ "${KPARTX_MAPPED}" = "TRUE" ] && [ -n "${IMAGE_FILE:-}" ]; then
        kpartx -dv "${IMAGE_FILE}" >/dev/null 2>&1
    fi
}
trap cleanup EXIT ERR INT TERM
#--------------------------------------
usage()
{
    cat <<EOF
Usage:
  vm_test.sh <image_file>

Description:
  Valida una imagen cruda (raw) de VM comprobando la integridad de su partición root.
  Si está consistente, imprime /etc/hostname en salida estándar.

Options:
  -h, --help    Show this help message.
EOF
}

# -----------------------------------------------------------------------------
# 4. FUNCIÓN PRINCIPAL MAIN (PARSEO Y LÓGICA)
# -----------------------------------------------------------------------------
main()
{
    if [ "${DEBUG}" = "TRUE" ]; then
        set -x
    else
        set +x
    fi

    if [ "$#" -ne 1 ]; then
        exit 1
    fi

    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi

    local raw_path="$1"
    
    if [ ! -f "${raw_path}" ]; then
        exit 1
    fi
    
    IMAGE_FILE="$(realpath "${raw_path}")"

    # 1. Mapeo de particiones
    kpartx -av "${IMAGE_FILE}" >/dev/null 2>&1 || exit 1
    KPARTX_MAPPED="TRUE"

    # Pausa para la creación de los devices loop por udev
    sleep 1

    # 2. Activación del Volume Group
    vgchange -ay vg_os >/dev/null 2>&1 || exit 1
    VG_ACTIVATED="TRUE"

    sleep 1

    local lv_path="/dev/vg_os/lv_root"
    if [ ! -e "${lv_path}" ]; then
        lv_path="/dev/mapper/vg_os-lv_root"
    fi

    # 3. Diagnóstico read-only
    if ! fsck -n "${lv_path}" 2>&1; then
        echo "ERROR al ejecutar fsck"
        exit 1
    fi

    # 4. Montaje read-only
    TEMP_MNT=$(mktemp -d)
    mount -o ro "${lv_path}" "${TEMP_MNT}" >/dev/null 2>&1 || exit 1

    # 5. Obtener hostname
    if [ -f "${TEMP_MNT}/etc/hostname" ]; then
        cat "${TEMP_MNT}/etc/hostname"
    else
        exit 1
    fi

    exit 0
}

main "$@"
