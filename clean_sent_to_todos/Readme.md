# Proyecto: clean_sent_to_todos

## Descripcion General

`clean_sent_to_todos.sh` localiza mails almacenados en estructuras Maildir que
fueron enviados por una cuenta puntual hacia `grp_todos@gigot.com.ar` y los
mueve a un directorio destino indicado por el operador.

El filtro temporal se define exclusivamente por la fecha de ultima modificacion
del archivo (`mtime`). No parsea el nombre del archivo ni el header `Date:` del
mensaje.

## Uso

```bash
./scripts/clean_sent_to_todos.sh -d <destino> -f <usuario> -Y <anio> [opciones]
```

## Opciones

- `-d <destino>`: Directorio destino existente donde se moveran los mails.
- `-f <usuario>`: Usuario remitente sin dominio. El script compara contra
  `From: <usuario>@gigot.com.ar`, `From: Nombre Visible <usuario@gigot.com.ar>`
  y `Return-path: <usuario@gigot.com.ar>`.
- `-Y <anio>`: Anio a analizar. Debe estar entre `1970` y `2099`.
- `-u <usuario>`: Restringe el analisis a `/srv/mail/<usuario>/Maildir`.
- `-r`: Modo dry-run. Lista los archivos coincidentes sin ejecutar `mv`.
- `-y`: Asume confirmacion, omite el prompt interactivo y no imprime el bloque
  `Variables de Ejecucion`.
- `-h`: Muestra ayuda y finaliza.

## Variables de Entorno

- `DEBUG=TRUE`: activa `set -x`.
- `ASSUME_YES=TRUE`: equivale a usar `-y`.
- `DEST_DIR`, `FROM_USER`, `YEAR`, `SINGLE_USER`, `DRY_RUN`: pueden
  precargarse por entorno, aunque la operacion habitual usa flags.

## Comportamiento

- Recorre `/srv/mail/*/Maildir` de forma recursiva.
- Con `-u`, solo inspecciona `/srv/mail/<usuario>/Maildir`.
- Solo considera archivos regulares bajo paths que coincidan con `*/Maildir/*`.
- Excluye del analisis las carpetas `.Sent` y `.Template`.
- Excluye archivos cuyo nombre comience con `dovecot`.
- Filtra por `mtime` usando `find` con este criterio:

```bash
find "$search_path" \
    -path "*/Maildir/*" \
    ! -path "*/Maildir/.Sent/*" \
    ! -path "*/Maildir/.Template/*" \
    -type f \
    ! -name 'dovecot*' \
    -newermt "${YEAR}-01-01" \
    ! -newermt "$((YEAR + 1))-01-01"
```

- Para cada archivo filtrado valida estos headers:
  - `From: <usuario>@gigot.com.ar`
  - `From: Nombre Visible <usuario@gigot.com.ar>`
  - `Return-path: <usuario@gigot.com.ar>` como fallback si `From:` no coincide
  - `Envelope-to: grp_todos@gigot.com.ar`
- Si el remitente y `Envelope-to:` coinciden:
  - en modo real, mueve el archivo a `DEST_DIR/`
  - en modo dry-run, solo imprime la ruta y la fecha
- Cada archivo movido o candidato a mover se imprime en `stdout` con este
  formato:

```text
/ruta/del/mail | Date: Tue, 12 May 2026 15:56:07 -0300
```

- Si el mensaje no trae header `Date:`, la salida usa `Date header ausente`.
- Los mensajes operativos, advertencias, errores y resumen final se imprimen en
  `stderr`.

## Funciones Principales

- `cleanup()`: imprime el resumen final de la corrida una sola vez al salir.
- `usage()`: muestra la ayuda, flags y ejemplos de ejecucion.
- `confirm_or_exit()`: pide confirmacion `s/N` salvo que `-y` o `ASSUME_YES=TRUE`
  ya esten activos.
- `print_error_red()`: muestra errores de invocacion en rojo para separarlos del
  bloque de ayuda.
- `print_match_info()`: imprime cada coincidencia junto con el valor del header
  `Date:`.
- `validate_args()`: exige `-d`, `-f` y `-Y`.
- `validate_year()`: valida formato y rango del anio.
- `validate_dest_dir()`: confirma que el directorio destino exista.
- `validate_maildir()`: confirma que el Maildir exista cuando se usa `-u`.
- `print_execution_variables()`: muestra el contexto de ejecucion cuando no se
  usa modo batch.
- `process_maildir()`: ejecuta el `find`, aplica exclusiones, valida headers y
  mueve o lista los archivos coincidentes, aceptando fallback por `Return-path:`.
- `main()`: orquesta parseo, validaciones, confirmacion y procesamiento.

## Limites y Consideraciones

- El script no crea el directorio destino. Debe existir antes de ejecutar.
- El script no verifica que el ejecutor sea `root`, aunque el caso de uso
  previsto asume permisos suficientes sobre `/srv/mail`.
- Los headers ausentes o malformados no abortan la corrida: el archivo se omite
  con advertencia.
- Si `From:` no coincide o no existe, pero `Return-path:` coincide con el
  remitente esperado, el archivo se considera valido.
- Los errores de invocacion se muestran en rojo antes del `usage` para resaltar
  el motivo de rechazo.
- Si `mv` falla para un archivo individual, el script reporta el error y sigue
  con el resto.
- Si no hay coincidencias, finaliza con exit `1`.
- Si no existe ningun archivo regular bajo los Maildir analizados, finaliza con
  exit `1`.
- Si el destino ya contiene un archivo con el mismo nombre, `mv` puede fallar.
  Ese caso se informa por archivo y no detiene toda la corrida.
- No se soporta de forma especial el caso donde `-d` apunte al mismo directorio
  origen del archivo.

## Nota de Zona Horaria

El filtro de anio usa `find -newermt`, que interpreta las fechas en la zona
horaria local del servidor. En archivos ubicados justo en el limite del cambio
de anio, la inclusion o exclusion depende de la TZ efectiva del sistema.

## Ejemplos

Mover mails de 2024 enviados por `cuenta_operativa` hacia un directorio de
resguardo:

```bash
./scripts/clean_sent_to_todos.sh -d /backup/todos -f cuenta_operativa -Y 2024
```

Probar sin mover archivos:

```bash
./scripts/clean_sent_to_todos.sh -d /backup/todos -f cuenta_operativa -Y 2024 -r
```

Restringir la busqueda al Maildir de un usuario puntual:

```bash
./scripts/clean_sent_to_todos.sh -d /backup/todos -f cuenta_operativa -Y 2024 -u usuario1
```

Ejecutar en modo batch sin confirmacion interactiva:

```bash
./scripts/clean_sent_to_todos.sh -d /backup/todos -f cuenta_operativa -Y 2024 -y
```

## Validacion Local

```bash
shellcheck clean_sent_to_todos/scripts/clean_sent_to_todos.sh
bats clean_sent_to_todos/tests
./ci/run_checks.sh -p clean_sent_to_todos
```
