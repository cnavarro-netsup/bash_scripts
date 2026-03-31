# Diseno: cp_vm

## Arquitectura General

`cp_vm.sh` es un script monolitico que corre en el NAS y coordina cinco responsabilidades:

1. Resolver parametros y defaults de ejecucion.
2. Validar contexto local y remoto antes de copiar.
3. Resolver y copiar la configuracion XML de libvirt de forma no bloqueante.
4. Preparar el origen remoto (`lv` o `snap`).
5. Ejecutar la transferencia binaria y limpiar recursos transitorios.

El script depende de `lib/logger.sh` para logging consistente y usa `trap cleanup EXIT ERR INT TERM` para remover el snapshot remoto si fue creado.

## Flujo Principal

1. Parsear `-v`, `-t`, `-m`, `-b`, `-g`, `-s`, `-d`, `-y`, `-D`, `-h`.
2. Activar `set -x` si `DEBUG=TRUE`.
3. Validar dependencias locales (`ssh`, `pv`, `dd`, `df`, `realpath`, `awk`, `date`).
4. Resolver `map_file` y `backup_dir` con `realpath`.
5. Leer el archivo de mapeo para resolver el hypervisor de la VM.
6. Construir el LV remoto nativo `/dev/<vg>/lv_<vm>_os`.
7. Obtener el tamano del LV remoto mediante `ssh <hypervisor> lvs ...`.
8. Verificar que el filesystem local tenga al menos `105%` del tamano del origen.
9. Generar los archivos destino con fecha `ddmmYYYY` para XML y disco.
10. Mostrar variables de ejecucion y pedir confirmacion.
11. Si `-D`, informar los comandos y salir sin ejecutar cambios.
12. Intentar copiar el XML remoto `/etc/libvirt/qemu/<vm>.xml` antes del disco.
13. Si la copia del XML falla, eliminar cualquier archivo parcial, emitir warning y continuar.
14. Si `-t snap`, crear snapshot remoto de `1G` y copiar desde `/dev/<vg>/<snap>`.
15. Si `-t lv`, copiar directamente desde `/dev/<vg>/lv_<vm>_os`.
16. Ejecutar la transferencia robusta con `dd | pv | dd`.
17. Limpiar snapshot si existe.

## Algoritmo de Mapeo VM -> Hypervisor

- Leer linea por linea ignorando vacios y comentarios (`#`).
- Separar en `mapped_vm` y `mapped_hypervisor`.
- Rechazar lineas con mas de dos columnas para la VM buscada.
- Detectar duplicados para la misma VM y abortar.
- Si no hay coincidencia, abortar con error claro.

## Validacion de Espacio Libre

- Obtener `size_bytes` remoto con `lvs --noheadings --units b --nosuffix -o lv_size <lv>`.
- Obtener `available_bytes` local con `df --output=avail -B1 <backup_dir>`.
- Calcular `required_bytes=$(( (size_bytes * 105 + 99) / 100 ))` para redondeo entero seguro.
- Abortar si `available_bytes < required_bytes`.

## Comandos Remotos

### Snapshot

```bash
lvcreate -L 1G -s -n snap /dev/vg_vm/lv_<vm>_os
dd if=/dev/vg_vm/snap bs=4M status=none
lvremove -f /dev/vg_vm/snap
```

### LV nativo

```bash
dd if=/dev/vg_vm/lv_<vm>_os bs=4M status=none
```

### Configuracion XML

```bash
test -f /etc/libvirt/qemu/<vm>.xml && cat /etc/libvirt/qemu/<vm>.xml
```

### Copia local completa

```bash
ssh "${hypervisor}" "dd if='${source_lv}' bs=4M status=none" \
    | pv --progress --timer --eta --rate --average-rate --size "${size_bytes}" \
    | dd of="${dest_file}" bs=4M conv=fsync status=none
```

## Riesgos y Mitigaciones

- Snapshot huercfano tras fallo: mitigado con `trap cleanup` y bandera `SNAP_CREATED`.
- Archivo destino parcial por corte de energia: mitigado parcialmente usando `dd conv=fsync` en el extremo local.
- Copia incompleta por espacio insuficiente: mitigado con chequeo previo de `105%`.
- Mapeo ambiguo: mitigado rechazando duplicados y lineas mal formadas.
- XML remoto ausente: mitigado tratandolo como warning y eliminando el archivo local parcial si existiera.

## Compatibilidad

- Bash 4.x o superior.
- Ubuntu 24.04+ en el NAS.
- Hypervisor remoto con LVM y acceso SSH operativo.
