#!/usr/bin/env bash
set -euo pipefail
#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: cp_vm_rrhh_datos.sh
# VERSION: 1.0.0
# AUTOR: CPN
# MODELO: Kiro
# FECHA: 31/Marzo/2026
# DESCRIPCION: Copia dos LV de RRHH desde snapshots LVM de vm017 al NAS.
#
# REQUERIMIENTOS: SSH por llave a root@vm017, LVM remoto y escritura en
#                 /srv/bk_vm.
# USO: ./cp_vm_rrhh_datos.sh [-y] [-D] [-d] [-h]
# ESTADO: desarrollo
#------+---------+---------+---------+---------+---------+---------+---------+
# 1. LIBRERIAS Y CONFIGURACION
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"
if [[ -f "${project_root}/lib/logger.sh" ]]; then
    # shellcheck disable=SC1091 # Ruta calculada desde la ubicacion del script.
    source "${project_root}/lib/logger.sh"
else
    echo "Error critico: No se encontro logger.sh en ${project_root}/lib/." >&2
    exit 1
fi
readonly remote_host="root@vm017" volume_group="vg_vm"
readonly snapshot_name="snap" snapshot_size="1G" backup_dir="/srv/bk_vm"
readonly snapshot_path="/dev/${volume_group}/${snapshot_name}"
readonly -a logical_volumes=("lv_rrhh_data1" "lv_rrhh_data2")
readonly -a ssh_options=(-o BatchMode=yes -o StrictHostKeyChecking=yes)
assume_yes="FALSE" dry_run="FALSE" debug="FALSE"
run_date="" snapshot_created="FALSE" active_partial=""
# -----------------------------------------------------------------------------
# 2. FUNCIONES
# -----------------------------------------------------------------------------
# Retira únicamente los recursos temporales marcados como propios.
cleanup()
{
    set +e
    if [ -n "${active_partial}" ] && [ -e "${active_partial}" ]; then
        rm -f -- "${active_partial}"
    fi
    if [ "${snapshot_created}" = "TRUE" ]; then
        # shellcheck disable=SC2029 # La ruta remota se expande localmente de forma intencionada.
        ssh "${ssh_options[@]}" "${remote_host}" \
            "lvremove -f '${snapshot_path}'" >/dev/null 2>&1
        snapshot_created="FALSE"
    fi
}
trap cleanup EXIT ERR INT TERM
#--------------------------------------
# Muestra la interfaz admitida.
usage()
{
    local script_name="${0##*/}"
    cat <<EOF
Uso: ./${script_name} [opciones]
Copia secuencialmente lv_rrhh_data1 y lv_rrhh_data2 desde snapshots de 1G.
Opciones:
  -y  Omitir confirmacion y bloque de variables de ejecucion
  -D  Mostrar el plan sin crear snapshots ni archivos
  -d  Activar trazas de depuracion
  -h  Mostrar esta ayuda
EOF
}
#--------------------------------------
# Solicita confirmación salvo en modo batch.
confirm_or_exit()
{
    if [ "${assume_yes}" = "TRUE" ]; then
        return 0
    fi
    local confirm
    read -r -p "¿Continuar? (s/N): " confirm
    case "${confirm:-}" in
        s|S|si|SI|Si) return 0 ;;
        *) die "Cancelado por el usuario." 1 ;;
    esac
}
#--------------------------------------
# Comprueba que una dependencia local esté disponible.
require_command()
{
    local command_name="$1"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        die "Dependencia local ausente: ${command_name}" 1
    fi
}
#--------------------------------------
# Ejecuta SSH sin interacción y con comprobación estricta de huella.
remote()
{
    # shellcheck disable=SC2029 # Los argumentos remotos se construyen localmente de forma intencionada.
    ssh "${ssh_options[@]}" "${remote_host}" "$@"
}
#--------------------------------------
# Construye el destino final de un volumen.
destination_for()
{
    printf '%s/%s_snap-%s' "${backup_dir}" "$1" "${run_date}"
}
#--------------------------------------
# Construye el temporal local de un volumen.
partial_for()
{
    printf '%s/.%s_snap-%s.partial' "${backup_dir}" "$1" "${run_date}"
}
#--------------------------------------
# Valida dependencias, acceso y ausencia de recursos previstos.
validate_preconditions()
{
    local command_name logical_volume logical_volume_path destination partial
    for command_name in ssh dd pv date mv rm; do
        require_command "${command_name}"
    done
    if [ ! -d "${backup_dir}" ]; then die "No existe el directorio de backups: ${backup_dir}" 1; fi
    if [ ! -w "${backup_dir}" ]; then die "El directorio de backups no es escribible: ${backup_dir}" 1; fi
    if ! remote "true" >/dev/null; then die "No se pudo acceder por SSH a ${remote_host}." 1; fi
    if ! remote "command -v lvcreate >/dev/null && command -v lvremove >/dev/null && command -v lvs >/dev/null && command -v dd >/dev/null"; then
        die "Faltan dependencias remotas LVM o dd en ${remote_host}." 1
    fi
    if remote "test -e '${snapshot_path}'"; then
        die "Ya existe el snapshot remoto ${snapshot_path}; no se eliminara." 1
    fi
    for logical_volume in "${logical_volumes[@]}"; do
        logical_volume_path="/dev/${volume_group}/${logical_volume}"
        if ! remote "lvs '${logical_volume_path}' >/dev/null 2>&1"; then
            die "No existe el LV remoto ${logical_volume_path}." 1
        fi
        destination="$(destination_for "${logical_volume}")"
        partial="$(partial_for "${logical_volume}")"
        if [ -e "${destination}" ]; then
            die "El destino ya existe y no se sobrescribira: ${destination}" 1
        fi
        if [ -e "${partial}" ]; then
            die "El temporal ya existe y no se sobrescribira: ${partial}" 1
        fi
    done
}
#--------------------------------------
# Presenta el orden y los recursos afectados.
show_plan()
{
    local logical_volume
    echo "Plan de ejecucion:"
    for logical_volume in "${logical_volumes[@]}"; do
        echo "  ${logical_volume}:"
        echo "    crear ${snapshot_path} de ${snapshot_size}"
        echo "    copiar a $(partial_for "${logical_volume}")"
        echo "    eliminar ${snapshot_path}"
        echo "    publicar $(destination_for "${logical_volume}")"
    done
}
#--------------------------------------
# Muestra el contexto de una ejecución interactiva.
show_execution_context()
{
    echo -e "${G} Variables de Ejecucion ${N}"
    echo "REMOTE_HOST   : ${remote_host}"
    echo "BACKUP_DIR    : ${backup_dir}"
    echo "SNAPSHOT      : ${snapshot_path}"
    echo "SNAPSHOT_SIZE : ${snapshot_size}"
    echo "RUN_DATE      : ${run_date}"
    echo "DEBUG         : ${debug}"
    echo "DRY_RUN       : ${dry_run}"
}
#--------------------------------------
# Crea el snapshot y marca su propiedad solo tras el éxito.
create_snapshot()
{
    local logical_volume_path="/dev/${volume_group}/$1"
    log_info "Creando ${snapshot_path} para ${logical_volume_path}."
    if ! remote "lvcreate -L ${snapshot_size} -s -n '${snapshot_name}' '${logical_volume_path}'" >/dev/null; then
        die "No se pudo crear el snapshot para ${logical_volume_path}." 1
    fi
    snapshot_created="TRUE"
}
#--------------------------------------
# Copia el snapshot al temporal propagando fallos del pipeline.
copy_snapshot()
{
    local logical_volume="$1"
    active_partial="$(partial_for "${logical_volume}")"
    log_info "Copiando ${snapshot_path} a ${active_partial}."
    if ! remote "dd if='${snapshot_path}' bs=4M status=none" \
        | pv \
        | dd of="${active_partial}" bs=4M conv=fsync status=none; then
        die "Fallo la copia del snapshot de ${logical_volume}." 1
    fi
}
#--------------------------------------
# Elimina el snapshot propio antes de continuar.
remove_snapshot()
{
    if ! remote "lvremove -f '${snapshot_path}'" >/dev/null; then
        die "No se pudo eliminar el snapshot propio ${snapshot_path}." 1
    fi
    snapshot_created="FALSE"
}
#--------------------------------------
# Procesa un volumen y publica el temporal de forma atómica.
process_volume()
{
    local logical_volume="$1"
    local destination
    destination="$(destination_for "${logical_volume}")"
    create_snapshot "${logical_volume}"
    copy_snapshot "${logical_volume}"
    remove_snapshot
    if ! mv -- "${active_partial}" "${destination}"; then
        die "No se pudo publicar el backup ${destination}." 1
    fi
    active_partial=""
    log_info "Backup publicado: ${destination}"
}
# -----------------------------------------------------------------------------
# 3. MAIN
# -----------------------------------------------------------------------------
# Parsea opciones y ejecuta ambos volúmenes en orden fijo.
main()
{
    local opt logical_volume
    while getopts ":yDdh" opt; do
        case "${opt}" in
            y) assume_yes="TRUE" ;;
            D) dry_run="TRUE" ;;
            d) debug="TRUE" ;;
            h) usage; exit 0 ;;
            :) log_error "Error: -${OPTARG} requiere un argumento."; usage; exit 2 ;;
            \?) log_error "Error: opcion invalida -${OPTARG}."; usage; exit 2 ;;
        esac
    done
    shift $((OPTIND - 1))
    if [ "$#" -ne 0 ]; then log_error "No se permiten argumentos posicionales."; usage; exit 2; fi
    if [ "${debug}" = "TRUE" ]; then set -x; else set +x; fi
    run_date="$(date +%d%m%Y)"
    validate_preconditions
    show_plan
    if [ "${dry_run}" = "TRUE" ]; then
        log_info "Dry-run finalizado sin cambios."
        exit 0
    fi
    if [ "${assume_yes}" != "TRUE" ]; then show_execution_context; fi
    confirm_or_exit
    for logical_volume in "${logical_volumes[@]}"; do
        process_volume "${logical_volume}"
    done
    log_info "Copias de RRHH finalizadas con exito."
}
main "$@"
