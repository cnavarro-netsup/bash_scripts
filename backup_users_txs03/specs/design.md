# Design - backup_users_txs03

## Arquitectura

El proyecto contiene un único script principal en `scripts/backup_users_txs03.sh`
y una suite de tests en `tests/test_backup_users_txs03.bats`.

El script no importa librerías externas (`logger.sh` no aplica aquí). Todo el
logging se acumula en una variable o archivo temporal y se envía por mail al
finalizar.

## Flujo principal

```
1. Inicializar modo estricto Bash y variables de configuración.
2. Preparar archivo de log temporal (mktemp).
3. Registrar trap cleanup para EXIT ERR INT TERM.
4. Verificar dependencias: sshfs, rsync, rdiff-backup, mail (o sendmail).
5. Verificar que /mnt/txs03 esté montado; si no, montarlo en modo read-only.
6. Verificar existencia y permisos del directorio de staging.
7. Para cada perfil en /mnt/txs03/*:
   a. Verificar que el subdirectorio sea un directorio.
   b. Para cada uno de [Desktop, Documents, Downloads]:
      - Si existe, ejecutar rsync hacia staging/<perfil>/<dir>.
      - Si no existe, registrar WARNING en log y continuar.
   c. Registrar resultado de la copia en log.
8. Ejecutar rdiff-backup desde staging hacia destino definitivo.
9. Ejecutar rdiff-backup --remove-older-than para mantener 10 incrementos.
10. En cleanup:
    a. Desmontar /mnt/txs03 si fue montado por este script.
    b. Eliminar log temporal.
    c. Enviar mail con el log a infraestructura@gigot.com.ar.
```

## Estrategia de logging

Dado que la ejecución es no interactiva (cron), toda la salida se redirige
a un archivo temporal creado con `mktemp`. Al finalizar (en `cleanup`), el
contenido de ese archivo se envía por mail. El script no imprime nada a stdout.

Los errores no fatales (ej.: un directorio faltante en un perfil) se registran
como `[WARN]` en el log y la ejecución continúa. Los errores fatales
(montaje fallido, rdiff-backup fallido) se registran como `[ERROR]` y el
script termina con código 1.

## Estrategia de montaje

El script verifica si `/mnt/txs03` ya está montado consultando `/proc/mounts`.
- Si ya está montado: continúa sin volver a montarlo.
- Si no está montado: lo monta.

En ambos casos, el `cleanup` **siempre desmonta** `/mnt/txs03` al finalizar,
independientemente de si fue este script quien lo montó.

El montaje usa `sshfs -o ro,BatchMode=yes,ConnectTimeout=10`.

## Estructura de staging

```
/srv/tmp/txs03-user-staging/
  <usuario1>/
    Desktop/
    Documents/
    Downloads/
  <usuario2>/
    ...
```

## Opciones de rsync

```bash
rsync -a --no-perms --no-owner --no-group \
      --iconv=UTF-8-MAC,UTF-8 \
      --exclude='*.tmp' \
      --log-file="${LOG_TMP}" \
      "${src}/" "${dst}/"
```

- `-a`: modo archive (recursivo, preserva timestamps).
- `--no-perms --no-owner --no-group`: ignora metadatos de permisos Windows.
- `--iconv`: convierte encodings para evitar problemas con caracteres especiales.
- `--exclude='*.tmp'`: excluye archivos temporales de Windows.

## Opciones de rdiff-backup

rdiff-backup versión 2.0.5 (nueva sintaxis con subcomandos):

```bash
# Copia incremental
rdiff-backup backup \
    --exclude-special-files \
    "${STAGING_DIR}/" "${DEST_DIR}/"

# Purga de incrementos antiguos (mantiene 10)
rdiff-backup --remove-older-than ${MAX_INCREMENTS}B --force "${DEST_DIR}/"
```

## Variables de configuración

```bash
SSHFS_SRC="Administrador@txs03:.."   # recurso remoto Windows
MOUNT_POINT="/mnt/txs03"             # punto de montaje local
STAGING_DIR="/srv/tmp/txs03-user-staging"
DEST_DIR="/srv/bk-daily/txs03-users"
MAX_INCREMENTS=10                    # incrementos a conservar
MAIL_TO="infraestructura@gigot.com.ar"
MAIL_FROM="root"
SUBDIRS=("Desktop" "Documents" "Downloads")
```

## Función cleanup

```
cleanup()
{
    # 1. Desmontar /mnt/txs03 siempre (con fusermount -u o umount como fallback).
    # 2. Enviar mail con el contenido de LOG_TMP.
    # 3. Eliminar LOG_TMP.
}
```

El cleanup se ejecuta siempre vía `trap cleanup EXIT ERR INT TERM`.

El desmontaje usa `fusermount -u "${MOUNT_POINT}" 2>/dev/null || umount "${MOUNT_POINT}"`.
Si el desmontaje falla, se registra `[WARN]` en el log (no es un error fatal
porque el backup ya fue realizado).

## Manejo de errores por perfil

El error en la copia de un perfil individual no aborta el script. Se
registra en log con `[WARN]` y se incrementa un contador de errores
(`ERRORS=0`). Al final, si `ERRORS > 0`, el script termina con código 1.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Paths con caracteres no-ASCII de Windows | `--iconv` en rsync, comillas en todos los paths |
| rdiff-backup falla por repositorio inconsistente | Detectar código de salida != 0 y registrar error |
| sshfs ya montado por proceso externo | Verificar `/proc/mounts` antes de montar; no desmontar si no fue este script |
| Espacio insuficiente en staging | rsync falla con código != 0; se captura el error |
| mail no disponible | Intentar `sendmail` como fallback; registrar en stderr si ambos fallan |
| Interrupciones a mitad del flujo | trap cleanup garantiza desmontaje y envío de log parcial |

## Envío de mail

Se usa el comando `mail` para enviar el log al finalizar:

```bash
mail -s "backup_users_txs03: ${STATUS}" \
     -r "${MAIL_FROM}" \
     "${MAIL_TO}" < "${LOG_TMP}"
```

Donde `STATUS` es `OK` o `FAILED` según el resultado de la ejecución.
Si `mail` no está disponible o falla, se registra el error en stderr
(`>&2`) ya que el log temporal ya no puede enviarse por otro canal.

- Bash 5.2+ (Ubuntu 24.04).
- Herramientas requeridas: `sshfs`, `rsync`, `rdiff-backup`, `mail` o `sendmail`, `fusermount`.
- No requiere librerías del repositorio.
- Diseñado para ejecución como root en cron (no interactivo).
