# Requerimientos — clean_sent_to_todos.sh

## 1. Descripción del Problema

En un sistema de correo local con MTA Exim, los mails enviados por una cuenta
determinada al grupo `grp_todos` (que representa ~300 usuarios) generan copias
individuales en cada Maildir de destino, con efecto multiplicativo en el
almacenamiento. El script `clean_sent_to_todos.sh` identifica y mueve esos
mails —filtrando por remitente, destinatario y año— desde sus ubicaciones
originales bajo `/srv/mail/*/Maildir` hacia un directorio de destino indicado
por el operador.

El año se determina a partir de la **fecha de última modificación del archivo**
(`mtime`), usando `find` con un rango de fechas que acota el año completo
(`-newermt "{año}-01-01" -not -newermt "{año+1}-01-01"`). Los archivos de mail
se escriben una sola vez y no se modifican, por lo que `mtime` es equivalente
a la fecha de recepción. No se parsea el nombre del archivo ni el header
`Date:` del mensaje.

---

## 2. Alcance

- Recorre `/srv/mail/*/Maildir` (todos los usuarios) o, con `-u`, solo
  `/srv/mail/{usuario}/Maildir`.
- Filtra archivos regulares cuya **fecha de última modificación** (`mtime`)
  corresponda al año indicado con `-Y`, usando `find -newermt "{año}-01-01"
  -not -newermt "{año+1}-01-01"`.
- Dentro de cada archivo filtrado, verifica:
  - Header `From:` igual a `{usuario}@gigot.com.ar` o `Nombre <{usuario}@gigot.com.ar>` (flag `-f`).
  - Header `Return-path:` igual a `<{usuario}@gigot.com.ar>` como fallback cuando `From:` no coincide o no está presente.
  - Header `Envelope-to:` igual a `grp_todos@gigot.com.ar`.
- Mueve los archivos coincidentes al directorio de destino indicado con `-d`.
- Soporta modo dry-run (`-r`): lista los archivos que se moverían sin ejecutar
  ningún `mv`.
- Muestra las variables de ejecución y solicita confirmación `s/N` antes de
  operar. Si se ejecuta con `-y`, asume confirmación, no muestra el bloque de
  variables y opera en modo silencioso según la convención del repo.
- Emite cada archivo movido (o que se movería) en stdout junto con el valor completo del header `Date:` si existe.

---

## 3. Supuestos

- El script se ejecuta como root; el script **no verifica** este requisito.
- CentOS 7, Bash 4.2.46.
- Los Maildirs siguen la estructura estándar Maildir (subdirectorios `cur`,
  `new`, `tmp` y subdirectorios con prefijo `.`).
- Los archivos de mail se escriben una sola vez y no se modifican; por lo
  tanto, `mtime` es equivalente a la fecha de recepción/entrega.
- El filtro de año se implementa con `find -newermt "{año}-01-01" -not -newermt "{año+1}-01-01"`.
  No se parsea el nombre del archivo ni el header `Date:`.
- Los headers `From:` y `Envelope-to:` están presentes en todos los archivos
  de mail válidos. `From:` puede venir como `usuario@gigot.com.ar` o como
  `Nombre Visible <usuario@gigot.com.ar>`. `Envelope-to:` tiene el formato
  `grp_todos@gigot.com.ar`.
- Si `From:` no permite validar el remitente, el script puede usar
  `Return-path: <usuario@gigot.com.ar>` como respaldo.
- El directorio de destino (`-d`) existe y es escribible; el script no lo crea.
- Se admiten las variables de entorno `DEBUG`, `ASSUME_YES`, `DEST_DIR`,
  `FROM_USER`, `YEAR`, `SINGLE_USER` y `DRY_RUN` como mecanismo auxiliar de
  precarga, aunque el uso principal es mediante flags.
- Los comandos externos disponibles son: `mv`, `ls`, `find`, `grep`, `date`.
  Queda **prohibido** cualquier comando que
  modifique o borre archivos salvo `mv`.

---

## 4. Restricciones

| #    | Restricción |
|------|-------------|
| R-01 | Flags obligatorios: `-d`, `-f`, `-Y`. Sin alguno de ellos → usage + exit 1. |
| R-02 | El año (`-Y`) debe ser un entero de 4 dígitos (1970–2099). |
| R-03 | El usuario remitente (`-f`) no puede ser una cadena vacía. |
| R-04 | El directorio de destino (`-d`) debe existir en el momento de la ejecución. |
| R-05 | El año se determina exclusivamente desde el `mtime` del archivo, usando `find` con rango de fechas. No se parsea el nombre del archivo ni el header `Date:`. |
| R-06 | Prohibido usar `rm`, `shred`, `truncate` u otro comando destructivo distinto de `mv`. |
| R-07 | Flag desconocido o argumento posicional extra → exit 1. |
| R-08 | El script debe respetar el estilo definido en `estilo-seguridad.md` (strict mode, header, getopts, colores, confirm_or_exit). |
| R-09 | No se requiere ni se verifica que el ejecutor sea root. |
| R-10 | El script no crea el directorio de destino; debe existir previamente. |
| R-11 | Deben excluirse del análisis las rutas bajo `.Sent`, `.Template` y los archivos cuyo nombre comience con `dovecot`. |

---

## 5. Criterios de Aceptación

| ID     | Descripción | Resultado esperado |
|--------|-------------|-------------------|
| AC-001 | Ejecución con `-d`, `-f` y `-Y` válidos, con archivos coincidentes | Mueve los archivos y lista cada ruta en stdout junto con el header `Date:`; exit 0 |
| AC-002 | Ejecución con `-r` (dry-run) y archivos coincidentes | Lista los archivos que se moverían en stdout junto con el header `Date:` sin ejecutar ningún `mv`; exit 0 |
| AC-003 | Ejecución con `-u {usuario}` válido | Restringe el análisis a `/srv/mail/{usuario}/Maildir`; solo mueve/lista archivos de ese usuario |
| AC-004 | Ejecución sin `-d`, sin `-f` o sin `-Y` | Muestra usage en stderr y sale con exit 1 |
| AC-005 | Ejecución con `-h` | Muestra el help en stdout y sale con exit 0 |
| AC-006 | Flag desconocido (ej. `-z`) o argumento posicional extra | Muestra error en stderr y sale con exit 1 |
| AC-007 | No existen archivos que coincidan con los criterios | Emite mensaje de error en stderr y sale con exit 1 |
| AC-008 | El año se determina desde el `mtime` del archivo vía `find` con rango de fechas | Un archivo con `mtime` en 2021 es incluido con `-Y 2021` e ignorado con `-Y 2020` |
| AC-009 | No existe ningún archivo regular bajo `/srv/mail/*/Maildir` (estructura vacía) | Emite error en stderr y sale con exit 1 |
| AC-010 | El directorio de destino (`-d`) no existe | Emite error en stderr y sale con exit 1 |
| AC-011 | El usuario indicado con `-u` no tiene Maildir (`/srv/mail/{usuario}/Maildir` no existe) | Emite error en stderr y sale con exit 1 |
| AC-012 | Confirmación `s/N`: el operador responde `N` | Imprime mensaje de cancelación y sale con exit 1 sin ejecutar ningún `mv` |
| AC-013 | Ejecución con `-Y` con valor no numérico o fuera de rango (ej. `-Y abc`, `-Y 1800`) | Emite error en stderr y sale con exit 1 |
| AC-014 | Ejecución con `-y` | Omite confirmación interactiva y no imprime el bloque "Variables de Ejecución"; mantiene el comportamiento funcional del modo real o dry-run |
| AC-015 | Archivo dentro de `.Sent`, `.Template` o con nombre `dovecot*` | Se excluye del análisis aunque cumpla el resto de criterios |
| AC-016 | `From:` no coincide o está ausente, pero `Return-path:` es `<usuario@gigot.com.ar>` | El archivo se considera coincidencia si `Envelope-to:` y el resto de condiciones también coinciden |

---

## 6. Edge Cases identificados

- **Archivos en el límite del año**: `find` con `-newermt "2020-01-01" -not -newermt "2021-01-01"` usa la hora local del sistema. Si el servidor está en UTC-3, un archivo con `mtime` 2020-12-31 21:00 UTC (= 2021-01-01 00:00 ART) podría quedar fuera del rango. Debe documentarse que el filtro opera en la zona horaria local del servidor.

- **Subdirectorios anidados en Maildir**: la estructura puede incluir carpetas
  como `.Sent`, `.Trash`, `.INBOX.Subfolder`, etc. El script debe recorrer
  **todos** los subdirectorios recursivamente, no solo `cur/` y `new/`, excepto
  `.Sent` y `.Template` que deben quedar explícitamente fuera del análisis.

- **Archivos sin `mtime` legible**: si `find` no puede leer el `mtime` de un
  archivo (permisos, sistema de archivos corrupto), debe ignorarlo y continuar.

- **Headers ausentes o malformados**: si un archivo no contiene `Envelope-to:` o
  no contiene ni `From:` ni `Return-path:`, debe ignorarse sin abortar la ejecución.

- **Colisión de nombres en destino**: si ya existe un archivo con el mismo
  nombre en el directorio de destino, `mv` fallará. El script debe emitir un
  error en stderr para ese archivo y continuar con los demás (no abortar toda
  la ejecución).

- **Directorio de destino igual a la ubicación de origen**: si `-d` apunta a
  un directorio que ya contiene alguno de los archivos a mover, `mv` podría
  fallar o ser un no-op. Debe documentarse como comportamiento no soportado.

- **Usuario con `-u` que no tiene mails coincidentes**: distinto de "Maildir
  inexistente" (AC-011); el Maildir existe pero ningún archivo cumple los
  criterios → AC-007 aplica.

- **Nombre de usuario con caracteres especiales en `-f` o `-u`**: el valor se
  usa en un path y en un grep; debe tratarse como literal, no como expresión
  regular.

- **Múltiples archivos con el mismo nombre en distintos Maildirs**: cada uno
  se trata de forma independiente; la colisión en destino se maneja por
  archivo (ver punto de colisión de nombres).
