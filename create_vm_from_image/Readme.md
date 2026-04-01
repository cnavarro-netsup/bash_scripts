# Proyecto: create_vm_from_image

Este directorio contiene el script `create_vm_from_image.sh`, orientado a levantar una VM temporal local en `nas03` a partir de una imagen de disco ya respaldada y su XML de libvirt asociado.

## Objetivo

El script toma una imagen de backup y un XML de dominio, verifica que ambos correspondan a la misma VM, informa las vCPU y la RAM declaradas en el XML original, adapta un XML temporal para usar la imagen local recibida, fuerza la primera interfaz de red a la network aislada `dumb` y define siempre la VM temporal con `3` vCPU y `2097152 KiB` de RAM. Luego valida el XML resultante, define la VM con `virsh`, la arranca y deja impreso el comando que debe ejecutar el operador desde otra maquina para abrir la consola con `virt-viewer`.

La eliminacion de la VM temporal no forma parte del flujo: queda a cargo del operador que realiza la verificacion funcional.

El XML original obtenido por la copia no se modifica. Todos los cambios de recursos y red se aplican solo sobre un XML temporal derivado.

## Dependencias y requerimientos

- Acceso funcional a libvirt/KVM local en `nas03`.
- Binarios locales: `virsh`, `xmlstarlet`, `virt-xml-validate`, `realpath`.
- La network libvirt `dumb` debe existir en el host.
- La imagen debe seguir el patron `lv_<vm>_os-ddmmYYYY` o `lv_<vm>_os_snap-ddmmYYYY`.
- La VM temporal se creara siempre con `3` vCPU y `2097152 KiB` de RAM.

## Uso

```bash
./scripts/create_vm_from_image.sh -i <ruta_imagen> -c <ruta_xml> [opciones]
```

### Parametros obligatorios

- `-i`: ruta local de la imagen de disco respaldada.
- `-c`: ruta local del XML de libvirt respaldado.

### Opciones

- `-d`: activa modo debug (`set -x`).
- `-y`: omite la confirmacion interactiva.
- `-D`: muestra el plan de ejecucion sin definir ni arrancar la VM.
- `-h`: muestra la ayuda.

## Flujo resumido

1. Valida dependencias y rutas.
2. Extrae el nombre de la VM desde el XML.
3. Deduye el nombre de la VM desde la imagen y exige que coincidan.
4. Falla si el dominio ya existe en el libvirt local.
5. Informa las vCPU y la RAM detectadas en el XML original.
6. Crea un XML temporal que:
   - apunta el primer disco a la imagen indicada.
   - conecta la primera interfaz a la network `dumb`.
   - fija `3` vCPU.
   - fija `2097152 KiB` de RAM.
7. Valida el XML temporal con `virt-xml-validate`.
8. Define y arranca la VM con `virsh`.
9. Imprime el comando de consola remota.

## Salida esperada

En un caso exitoso, el script deja impreso al final un comando con este formato:

```bash
virt-viewer -c qemu+ssh://{usuario}@nas03/system <vm>
```

El placeholder `{usuario}` se muestra de forma generica. Quien ejecuta el procedimiento debe reemplazarlo por un usuario valido para conectarse por SSH a `nas03` desde una maquina con entorno grafico.

## Ejemplos

```bash
./scripts/create_vm_from_image.sh \
  -i /srv/bk-vm/lv_txs03_os_snap-01042026 \
  -c /srv/bk-vm/txs03-01042026.xml
```

```bash
./scripts/create_vm_from_image.sh \
  -i /srv/bk-vm/lv_txs03_os-01042026 \
  -c /srv/bk-vm/txs03-01042026.xml \
  -D
```

## Limites definidos

- Solo adapta el primer disco `device='disk'` y la primera interfaz de red del XML.
- Fuerza siempre `3` vCPU y `2097152 KiB` en el XML temporal.
- No modifica UUID ni MAC.
- No modifica el XML original respaldado.
- No elimina la VM luego de la prueba.
- Si `virsh define` tiene exito pero `virsh start` falla, el dominio queda definido para revision manual.
