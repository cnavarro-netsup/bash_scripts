# Diseño — n_mail_watch.sh

## 1. Arquitectura del Script

- El proyecto tendrá un único script principal en `scripts/n_mail_watch.sh` y una
  suite Bats en `tests/`.
- El script parte de la estructura de `auth_watch` y ajusta `PROJECT_ROOT` a
  `${SCRIPT_DIR}/../..` porque vive dentro de `scripts/`.
- Se importará obligatoriamente `lib/logger.sh`.
- No se usarán `ssh_utils.sh` ni `sqlite_utils.sh` porque no hay acceso remoto ni
  persistencia local requerida.
- El flujo está orientado a batch/cron sobre un host Linux con Exim.

## 2. Flujo Principal

1. Inicializar modo estricto Bash y cargar librerías.
2. Parsear `-l`, `-t`, `-r`, `-d`, `-y` y `-h` con `getopts`.
3. Validar dependencias requeridas: `awk`, `sort`, `date`, `realpath` y un
   backend de correo disponible (`sendmail` o `mailx`).
4. Validar el patrón de logs, el umbral y la lista de destinatarios.
5. Resolver `EXIM_LOG_DIR` con `realpath` y expandir coincidencias mediante
   `compgen -G`.
6. Obtener la fecha actual del servidor con `date +%F`.
7. Procesar todos los logs con `awk` y contar solo mails enviados del día actual,
   agrupados por `fecha + usuario`.
8. Filtrar los registros cuyo conteo sea mayor o igual al umbral.
9. Enviar un mail por cada cuenta excedida encontrada en la corrida.
10. Informar por log cuántas alertas se emitieron y terminar con código 0 si no
    hubo errores operativos.

## 3. Extracción del Patrón

- La detección debe ser la misma que en `cantidad_mail_enviados`.
- Solo se consideran líneas que contengan `<=` y un remitente con dominio
  `@gigot.com.ar`.
- Si `$1` coincide con la fecha actual, se recorre la línea token por token.
- Cuando un campo sea `<=`, se toma `$(i + 1)` como la cuenta emisora y se
  incrementa `count[fecha, usuario]`.
- Al finalizar, `awk` imprime filas con formato: `conteo fecha usuario`.

## 4. Envío de Correo

- Backend preferido: `sendmail`.
- Fallback: `mailx` si `sendmail` no está disponible.
- Si no existe ninguno, el script falla antes de procesar logs.
- Los destinatarios se manejan como una lista separada por comas.
- Por cada cuenta excedida se genera un asunto y cuerpo simples y operativos.
- El cuerpo del mail incluye:
  - cuenta de mail
  - fecha
  - cantidad de mails enviados
  - límite configurado

## 5. Validaciones

- `-l` no puede estar vacío.
- `-l` no puede contener `/`.
- `-l` solo acepta `[A-Za-z0-9._*?-]`.
- `-t` debe ser entero positivo mayor a cero.
- `-r` debe aceptar una lista de mails separados por coma y cada elemento debe
  tener formato básico `local@dominio`.
- `EXIM_LOG_DIR` debe existir y resolverse con `realpath`.
- Cada archivo resuelto debe ser regular y legible.

## 6. Salida Operativa

- En modo normal se muestran variables de ejecución:
  - `EXIM_LOG_DIR`
  - `RESOLVED_LOG_DIR`
  - `LOG_PATTERN`
  - `THRESHOLD`
  - `RECIPIENT`
  - `CURRENT_DATE`
  - `MAIL_BACKEND`
  - `DEBUG`
  - `ASSUME_YES`
- Si `-y` está activo, no se pide confirmación y el flujo sigue directo.
- Si no hay cuentas excedidas, el script informa que no hubo alertas para la
  fecha actual.

## 7. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Rotación de logs con fechas viejas | Filtrar estrictamente por la fecha actual del sistema antes de contar. |
| Patrón inseguro o expansión fuera del directorio esperado | No aceptar rutas, resolver el directorio con `realpath` y prefijar siempre `EXIM_LOG_DIR`. |
| Falta de backend de correo | Verificar `sendmail`/`mailx` al inicio y abortar con mensaje claro. |
| Ruido excesivo en cron | Soportar `-y` para ejecución batch sin interacción. |
| Cambios futuros en formato de log | Centralizar la lógica de detección en una única función `awk`. |

## 8. Compatibilidad

- Bash 4.x o superior.
- Linux con Exim y logs legibles por el usuario que ejecute el cron.
- Herramientas requeridas: `awk`, `sort`, `date`, `realpath` y `sendmail` o
  `mailx`.
