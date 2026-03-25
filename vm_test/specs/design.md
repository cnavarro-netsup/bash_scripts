# Diseño: vm_test

## 1. Arquitectura del Script
El script `vm_test.sh` se ejecutará secuencialmente en un único archivo, conteniendo configuración de "traps" para clean-up seguro que garantice la desconexión de kpartx y volúmenes lógicos independientemente de dónde aborte el código.

## 2. Componentes / Estructura del Proceso
- **Main Block:** Evalúa `$1` e invoca el proceso.
- **`cleanup()` Function:** Ligada al hook de `EXIT`, `INT`, `ERR`.
  - Verifica si existe directorio temporal de montaje para hacer un `umount`.
  - Si aplicó un `vgchange -ay`, procede a ejecutar `vgchange -a n vg_os`.
  - Si aplicó mapeo dev, corre `kpartx -dv "$IMAGE_FILE"`.
- **Ejecución Central:**
  1. `kpartx -av "$IMAGE_FILE"`
  2. `vgchange -ay vg_os`
  3. Comprobación `fsck -n /dev/vg_os/root`
  4. Crear punto temporal `/tmp/vm_test_mnt_XXXXX`  
  5. `mount -o ro /dev/vg_os/root /tmp/...`
  6. Recolectar hostname: `cat /tmp/.../etc/hostname`

## 3. Riesgos, Mitigaciones y Validaciones
| Riesgo | Mitigación |
| ------ | ---------- |
| **Residuos en el OS Host:** Si el script crashea a mitad de camino sin un manejo adecuado, el LVM de la VM quedará "pegado" al anfitrión o los block loop devices colgarán ocupados. | Se implementara un `trap cleanup EXIT ERR INT TERM` sólido considerando estado para limpiar solo lo que se asignó. |
| **Volúmenes con nombres aleatorios/diferentes:** Fallo si el VG no es `vg_os`. | Se aceptará el fallback o se tirará un error que atrapará el hook de cleanup para desregistrar los bloques. |
| **Operación Destructiva por Error:** `fsck` mutando bits inconsistentes. | Obligatorio el paso de bandera explícita `-n` para validación "Dry-Run" a la partición ext4/xfs. |

## 4. Estrategia de Testing (Verificación)
Debido a que el script requiere interacción con el subsistema `kpartx` e interactuar como `root`, los Unit Tests (Bats) en **FASE 5** deberán mockear `kpartx`, `vgchange`, `fsck` y `mount`, para comprobar que la lógica de parseo invoca correctamentes los sub-comandos sin ensuciar la máquina local del desarrollador en un pipeline CI.
