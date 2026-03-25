# Requerimientos: vm_test

## 1. Descripción del problema
El script `vm_test.sh` tiene como objetivo procesar una imagen raw de una Máquina Virtual (obtenida previamente mediante `dd` desde el hypervisor). Debe verificar la consistencia de la imagen y, si es consistente, extraer el nombre del host (hostname). El proceso involucra detectar particiones, verificar el sistema de archivos (read-only) y montar en modo lectura para obtener `/etc/hostname`.

## 2. Alcance
- **Lo que hace:**
  - Toma el nombre de un archivo de imagen raw como único argumento posicional.
  - Genera mapeos de dispositivos (loop devices / particiones) usando `kpartx`.
  - Activa los volúmenes lógicos correspondientes al VG esperado (`vg_os`).
  - Verifica la integridad del sistema de archivos del volumen lógico `root` mediante `fsck -n` (sin modificar).
  - Si es consistente, monta la partición `root` (envoltorio LVM) en read-only y reporta el contenido de `/etc/hostname` por salida estándar (stdout).
  - Desmonta y elimina los mapeos de `kpartx` (incluyendo `vgchange -a n vg_os`) al finalizar o en caso de error.
- **Lo que NO hace:**
  - NO ejecuta acciones destructivas de ningún tipo (no cambia ni borra archivos del sistema anfitrión ni de la imagen de la VM).
  - NO corrige errores encontrados por `fsck`.
  - NO usa la red o comandos `ssh`.
  - NO valida si el usuario es `root` (se asume como responsabilidad del usuario).
  - NO usa `--dry-run` ni modo silencioso (`-y`).

## 3. Supuestos
- Entorno de ejecución: Ubuntu 24.01.1 con GNU Bash (version 5.2, POSIX compatible).
- El usuario cuenta con privilegios de `root`.
- El esquema LVM interno suele llamarse `vg_os`.
- Dentro de ese Volume Group, el volumen lógico a examinar se denominará invariablemente `root` (ej. `/dev/vg_os/root`).
- Los comandos externos permitidos son: `fsck`, `kpartx`, `lvs`, y `vgchange`.

## 4. Restricciones
- El script será escrito en Bash y seguirá el estándar de codificación (`set -euo pipefail`).
- Los mensajes de salida y/o errores estarán en inglés.
- Salida (Exit Codes): 
  - `0`: Ejecución exitosa.
  - `1`: Cualquier error en validación, mapeo o consistencia de disco.
- No utiliza las librerías `logger.sh` ni otras. La salida al usuario será cruda con `echo`.

## 5. Criterios de Aceptación (Acceptance Criteria)
- **AC-001**: El script debe fallar (Exit 1) si no se provee exactamente 1 argumento o el archivo no existe.
- **AC-002**: El script no debe realizar modificaciones en la imagen (`fsck -n` usado explícitamente y montaje en `ro`).
- **AC-003**: Si la imagen falla en `fsck`, se debe invocar la limpieza (`trap` o similar), desconectar los LVs y kpartx, y terminar en Exit 1 sin salida extra.
- **AC-004**: Si es consistente, emitirá en stdout *únicamente* `/etc/hostname`, liberará recursos y acabará en Exit 0.
- **AC-005**: Mapeo completo mediante `kpartx` -> `vgchange -ay` -> inspección, seguido de desmontaje y limpieza `vgchange -a n` -> `kpartx -d`.
