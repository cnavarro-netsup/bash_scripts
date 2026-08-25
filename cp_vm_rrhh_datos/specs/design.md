# Diseño de `cp_vm_rrhh_datos`

## Enfoque

Un único script Bash, adaptado de `cp_vm.sh`, ejecutado en el NAS con `set -euo pipefail`.
Procesará los dos LV en orden fijo y no aceptará configuración externa ni selectores de volumen.
Reutilizará `lib/logger.sh` para `log_info`, `log_warn`, `log_error` y `die`.
No usará `ssh_utils.sh`, porque su `StrictHostKeyChecking=accept-new` contradice la huella previamente conocida exigida.

## Constantes

- `remote_host="root@vm017"`
- `volume_group="vg_vm"`, `snapshot_name="snap"`, `snapshot_size="1G"`
- `backup_dir="/srv/bk_vm"`
- `logical_volumes=("lv_rrhh_data1" "lv_rrhh_data2")`
- `run_date="$(date +%d%m%Y)"`
- Opciones SSH fijas: `BatchMode=yes` y `StrictHostKeyChecking=yes`.

Para cada LV, el destino será `/srv/bk_vm/<lv>_snap-<fecha>` y el temporal
`/srv/bk_vm/.<lv>_snap-<fecha>.partial`, siempre en el mismo filesystem.

## Funciones esenciales

- `usage`: documenta `-y`, `-D`, `-d` y `-h`.
- `confirm_or_exit`: confirma la ejecución salvo con `-y`.
- `require_command`: valida dependencias locales.
- `remote`: ejecuta SSH con las opciones fijas.
- `validate_preconditions`: comprueba `ssh`, `dd`, `pv`, `date` y `mv`; acceso SSH;
  comandos remotos LVM y `dd`; ambos LV; directorio existente y escribible; ausencia de
  `snap`, de los dos destinos y de sus temporales. No calcula ni valida espacio libre.
- `show_plan`: muestra orden, snapshots, temporales y destinos; con `-D` termina sin cambios.
- `create_snapshot`: ejecuta `lvcreate -L 1G -s -n snap <lv>` y solo tras éxito marca
  `snapshot_created=TRUE`.
- `copy_snapshot`: ejecuta `ssh ... "dd if=/dev/vg_vm/snap bs=4M status=none" |
  pv | dd of=<temporal> bs=4M conv=fsync status=none`; `pipefail` propaga cualquier fallo.
- `remove_snapshot`: elimina `/dev/vg_vm/snap` y después marca `snapshot_created=FALSE`.
- `cleanup`: con errores ignorados, elimina solo el temporal activo creado por esta ejecución
  e intenta retirar `snap` únicamente cuando `snapshot_created=TRUE`.
- `process_volume`: crea snapshot, copia al temporal, elimina snapshot y publica con `mv`.

## Algoritmo

1. Parsear opciones con `getopts`; `-d` activa `set -x` y `-h` finaliza tras la ayuda.
2. Instalar `trap cleanup EXIT ERR INT TERM` y validar todas las precondiciones.
3. Mostrar el plan; si no se usó `-y`, mostrar variables y solicitar confirmación.
4. Con `-D`, finalizar correctamente sin crear snapshots, temporales ni destinos.
5. Ejecutar `process_volume` para `lv_rrhh_data1` y luego para `lv_rrhh_data2`.
6. Registrar el éxito solo cuando ambos destinos hayan sido publicados.

## Errores y publicación

Cualquier fallo aborta con un mensaje claro mediante `logger.sh`. El destino final nunca se
escribe directamente: el pipeline escribe el temporal y `mv` lo publica únicamente después
de completar la copia y retirar el snapshot. La limpieza no elimina destinos preexistentes,
no retira snapshots no marcados como propios y descarta el temporal activo incompleto.
