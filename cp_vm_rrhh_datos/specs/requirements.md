# Requisitos de `cp_vm_rrhh_datos`

## Problema y objetivo

El **Script** es el único programa Bash solicitado. Un **LV** es un volumen lógico LVM alojado en `vm017`. Un **Snapshot** es la instantánea LVM temporal denominada `snap`. Un **Backup** es el archivo local resultante de copiar un Snapshot.

Se requiere copiar al NAS los datos de `/dev/vg_vm/lv_rrhh_data1` y `/dev/vg_vm/lv_rrhh_data2` sin leer directamente los LV durante la transferencia. El objetivo es ejecutar una copia secuencial, comprensible y razonablemente segura mediante snapshots temporales en `root@vm017`.

## Alcance incluido y excluido

Incluye un único Script Bash monolítico ejecutado en un NAS Ubuntu 24.04; conexión SSH por llave pública a `root@vm017`; creación y eliminación secuencial de un Snapshot `snap` de `1G`; transferencia mediante `ssh`, `dd` y `pv`; archivos `/srv/bk_vm/lv_rrhh_data1_snap-<fecha>` y `/srv/bk_vm/lv_rrhh_data2_snap-<fecha>`; confirmación, dry-run, debug, ayuda, registro con `logger.sh` y limpieza segura.

Excluye arquitectura multiarchivo, servicios, daemon, cron, colas, base de datos, persistencia, configuración dinámica, selectores de LV, hashes, cifrado, compresión, retención, rotación, restauración, reanudación, monitorización COW, `fsfreeze`, coordinación con aplicaciones y copia de XML de libvirt. El Script no calculará tamaños ni validará suficiencia de espacio.

## Flujo operativo simple

1. Validar dependencias, acceso SSH, existencia y escritura de `/srv/bk_vm`, ausencia del Snapshot `snap` y ausencia de los dos destinos.
2. Mostrar el plan y solicitar confirmación, salvo con `-y`; con `-D`, mostrar el plan y finalizar sin cambios.
3. Crear `snap` para `/dev/vg_vm/lv_rrhh_data1`, copiar el Snapshot al primer destino y eliminar `snap`.
4. Repetir secuencialmente el paso anterior para `/dev/vg_vm/lv_rrhh_data2`.
5. Ante un error, abortar con un mensaje claro, descartar cualquier archivo incompleto e intentar eliminar únicamente el Snapshot creado por la ejecución actual.

## Interfaz propuesta

- `-y`: omitir la confirmación y el bloque de variables de ejecución.
- `-D`: mostrar el plan sin crear snapshots ni archivos.
- `-d`: activar trazas de depuración.
- `-h`: mostrar ayuda y finalizar.

## Supuestos esenciales

- El NAS y `vm017` ejecutan Ubuntu 24.04; `ssh`, `dd`, `pv` y LVM están disponibles donde corresponda.
- La llave pública y la huella de `vm017` ya están configuradas para `root@vm017`.
- El operador garantiza espacio suficiente antes de ejecutar el Script.
- `<fecha>` representa la fecha de ejecución en formato `ddmmyyyy`.

## Restricciones de simplicidad y seguridad

- El Script usará `set -euo pipefail`, reutilizará `logger.sh` y tendrá un máximo absoluto de 300 líneas, con objetivo de 200 a 250.
- El host, los LV, el nombre y tamaño del Snapshot y `/srv/bk_vm` serán constantes; no se aceptarán variables de entorno para configurarlos.
- SSH usará `BatchMode=yes` y comprobación estricta de una huella ya conocida, sin credenciales embebidas ni aceptación automática de nuevas huellas.
- El Script abortará ante destinos preexistentes, un Snapshot `snap` preexistente o escenarios no previstos; el Script no sobrescribirá destinos ni eliminará snapshots ajenos.
- El Script comprobará solamente que `/srv/bk_vm` exista y sea escribible; la suficiencia de espacio será responsabilidad del operador.
- La copia no se publicará como Backup final si falla cualquier componente del pipeline.

## Criterios de aceptación

1. WHEN comienza una ejecución real, THE Script SHALL comprobar las precondiciones esenciales antes de crear el primer Snapshot.
2. WHEN el operador confirma o usa `-y`, THE Script SHALL procesar primero `lv_rrhh_data1` y después `lv_rrhh_data2`.
3. WHEN procesa un LV, THE Script SHALL crear `snap` con tamaño `1G` en `vm017`.
4. WHEN existe el Snapshot del LV actual, THE Script SHALL transferir los datos mediante un pipeline `ssh`, `dd` y `pv` al destino fechado correspondiente.
5. WHEN finaliza correctamente la copia de un LV, THE Script SHALL eliminar el Snapshot creado para ese LV antes de continuar.
6. IF existe `snap` antes de su creación o existe un destino previsto, THEN THE Script SHALL abortar con un error claro sin eliminar ni sobrescribir el recurso preexistente.
7. IF falla una operación después de crear `snap`, THEN THE Script SHALL abortar, eliminar cualquier archivo incompleto e intentar retirar únicamente el Snapshot creado por la ejecución actual.
8. WHERE el operador usa `-D`, THE Script SHALL mostrar las operaciones previstas sin crear snapshots ni archivos.
9. WHERE el operador usa `-h`, THE Script SHALL mostrar la ayuda y finalizar.
10. WHERE el operador usa `-d`, THE Script SHALL activar trazas de depuración.

## Decisiones pendientes

No hay decisiones pendientes.
