# Proyecto: vm_test

Este directorio contiene el script `vm_test.sh`, diseñado para verificar automáticamente la consistencia de una imagen cruda (raw) de una Máquina Virtual obtenida mediante `dd`, sin realizar operaciones destructivas sobre ella.

## Objetivo
El script localiza y mapea automáticamente particiones e internos LVM de la imagen. A continuación, verifica el sistema de archivos de forma pasiva (`fsck -n`). Si certifica que la imagen es consistente, la monta en solo-lectura (`ro`) y extrae el hostname de `/etc/hostname` hacia la salida estándar (STDOUT).

## Interfaz de Uso

### Dependencias y Requerimientos
- **Permisos**: Requiere ejecución con privilegios elevados (`root`) debido a dependencias con loop devices y `mount`.
- **Binarios**: `kpartx`, `fsck`, `mount`, `vgchange`.

### Ejecución
Se invoca pasando como su único argumento posicional la ruta al archivo crudo de la VM.

```bash
./scripts/vm_test.sh <ruta_al_archivo.raw>
```

#### Ejemplos
```bash
# Validar imagen y obtener hostname
./scripts/vm_test.sh /path/to/lv_vpn01_os_snap-0107231752.raw
# Salida esperada en STDOUT (si es consistente):
# vpn01-host

# Mostrar ayuda
./scripts/vm_test.sh -h
```

### Resultados y Códigos de Salida (Exit Codes)
- **STDOUT**: Imprime estrictamente el contenido de `/etc/hostname` si la imagen es válida. No emite ninguna otra salida a través de loggers locales.
- **Exit `0`**: La validación fue exitosa y se obtuvieron los datos solicitados.
- **Exit `1`**: Error general. Puede darse si el archivo no existe, tiene errores inconsistentes en el sistema de archivos (`fsck` fallido), los dispositivos no pudieron mapearse, o no posee `/etc/hostname`.

## Ciclo de Vida del Clean-up
El script incorpora rutinas mediante `trap` (señales `EXIT`, `INT`, `ERR`, `TERM`) asegurando que los siguientes bloques sean desacoplados sin importar por qué terminara el script:
1. Desmontaje temporal de carpetas `umount`.
2. Supresión y desvinculación `vgchange -a n vg_os`.
3. Cierre del mapa de bits LVM `kpartx -d`.
