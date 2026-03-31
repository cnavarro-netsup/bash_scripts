# Proyecto: cp_vm

## Descripcion General

`cp_vm.sh` corre desde un NAS Linux y copia el almacenamiento de una VM alojada en un hypervisor remoto hacia un archivo local. El origen puede ser el LV nativo de la VM o un snapshot LVM temporal creado por el propio script. Antes del backup del disco intenta copiar tambien la configuracion libvirt remota de la VM.

La transferencia usa `ssh`, `pv` y `dd` en ambos extremos. El tamano del LV remoto se consulta previamente para que `pv` pueda mostrar progreso, ETA y tasa de transferencia. En el extremo local, `dd` usa `conv=fsync` para asegurar el flush del archivo al finalizar.

## Uso

```bash
./scripts/cp_vm.sh -v <vm> [-t snap|lv] [opciones]
./scripts/cp_vm.sh -h
```

## Opciones

- `-v`: nombre de la VM. Obligatorio.
- `-t`: tipo de backup. Valores permitidos: `snap` o `lv`. Default: `snap`.
- `-m`: archivo de mapeo VM->hypervisor. Default: `/etc/vm_hypervisor.map`.
- `-b`: directorio local donde se almacenan las copias. Default: `/srv/bk-vm`.
- `-g`: nombre del volume group remoto. Default: `vg_vm`.
- `-s`: nombre del snapshot remoto. Default: `snap`.
- `-d`: activa modo debug (`set -x`).
- `-y`: asume confirmacion positiva.
- `-D`: dry-run. Muestra los comandos planeados y no ejecuta cambios.
- `-h`: muestra la ayuda.

## Formato del mapa

El archivo de mapeo debe contener una VM por linea con este formato:

```text
ldap01 hypervisor-a
txs03 hypervisor-b
```

La normalizacion de este archivo es responsabilidad de quien administra los backups y su inventario asociado.

## Contrato operativo del mapa

- Cada linea debe usar exactamente el formato `<vm> <hypervisor>`.
- Debe existir un unico espacio entre ambos campos.
- No deben usarse tabs ni separadores alternativos.
- No deben existir entradas duplicadas para la misma VM.
- Si el archivo no cumple este contrato, el comportamiento del script queda fuera del alcance soportado.

## Nombres de archivos generados

- Backup tipo `lv`: `lv_<vm>_os-ddmmYYYY`
- Backup tipo `snap`: `lv_<vm>_os_snap-ddmmYYYY`
- Backup XML de configuracion: `<vm>-ddmmYYYY.xml`

Ejemplos:

```text
lv_txs03_os-31032026
lv_txs03_os_snap-31032026
txs03-31032026.xml
```

## Flujo operativo

1. Resuelve el hypervisor a partir del mapa.
2. Construye el LV remoto `/dev/vg_vm/lv_<vm>_os`.
3. Consulta el tamano remoto del LV.
4. Valida que el filesystem local tenga al menos 105% del tamano origen.
5. Falla si el archivo destino del disco o del XML ya existe.
6. Muestra el contexto de ejecucion y espera confirmacion.
7. Intenta copiar `/etc/libvirt/qemu/<vm>.xml` como `<vm>-ddmmYYYY.xml`.
8. Si la copia del XML falla, emite warning y continua con el backup del disco.
9. Si el tipo es `snap`, crea `lvcreate -L 1G -s -n snap /dev/vg_vm/lv_<vm>_os`.
10. Ejecuta la copia del disco:

```bash
ssh "${hypervisor}" "dd if='${source_lv}' bs=4M status=none" \
    | pv --progress --timer --eta --rate --average-rate --size "${size_bytes}" \
    | dd of="${dest_file}" bs=4M conv=fsync status=none
```

11. Si el tipo es `snap`, remueve el snapshot remoto al finalizar o ante error.

## Restricciones y guardrails

- Si el destino ya existe, el script aborta.
- Si el XML remoto no puede copiarse, el script lo informa como warning y continua con el disco.
- Si el espacio libre disponible es menor al 105% del tamano de la copia, el script aborta con detalle de causa.
- El snapshot remoto siempre usa tamano fijo `1G`.
- Las entradas duplicadas o invalidas para la VM buscada en el mapa hacen fallar la ejecucion.

## Ejemplos

```bash
./scripts/cp_vm.sh -v ldap01
./scripts/cp_vm.sh -v txs03 -t lv
./scripts/cp_vm.sh -v txs03 -t snap -D
./scripts/cp_vm.sh -v txs03 -m /etc/vm_hypervisor.map -b /srv/bk-vm
```

## Codigos de salida

- `0`: ejecucion correcta o dry-run valido.
- `1`: error funcional o de validacion.
- `2`: error de uso de parametros.
