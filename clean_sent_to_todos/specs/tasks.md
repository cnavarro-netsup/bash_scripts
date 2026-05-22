# Tareas — clean_sent_to_todos.sh

## Fase 4: Implementación

- [x] Task 1 - Crear directorios `scripts/` y `tests/` dentro de `clean_sent_to_todos/`.
- [x] Task 2 - Crear `scripts/clean_sent_to_todos.sh` a partir del template base con header actualizado (nombre, fecha, descripción, uso).
- [x] Task 3 - Ajustar `PROJECT_ROOT` a `${SCRIPT_DIR}/../..`. No cargar librerías externas; definir variables de color (`R`, `G`, `Y`, `B`, `C`, `N`) directamente en el script.
- [x] Task 4 - Definir variables globales con defaults: `DEST_DIR`, `FROM_USER`, `YEAR`, `SINGLE_USER`, `DRY_RUN`, `MAIL_BASE`, `ENVELOPE_TO`, contadores `FILES_MATCHED`, `FILES_MOVED`, `FILES_FAILED`.
- [x] Task 5 - Implementar `usage()` documentando flags `-d`, `-f`, `-Y` (obligatorios), `-u`, `-r`, `-y`, `-h` (opcionales) con ejemplos.
- [x] Task 6 - Implementar `cleanup()` con `trap cleanup EXIT ERR INT TERM` que emite resumen de archivos procesados/movidos/fallidos.
- [x] Task 7 - Implementar `confirm_or_exit()` con prompt `s/N` y bypass con `ASSUME_YES=TRUE` / `-y` (ref: AC-012, AC-014).
- [x] Task 8 - Implementar `validate_args()`: verificar que `DEST_DIR`, `FROM_USER` y `YEAR` no estén vacíos (ref: AC-004, R-01).
- [x] Task 9 - Implementar `validate_year()`: regex `^[0-9]{4}$` + rango 1970–2099 (ref: AC-013, R-02).
- [x] Task 10 - Implementar `validate_dest_dir()`: verificar que `DEST_DIR` exista como directorio (ref: AC-010, R-04).
- [x] Task 11 - Implementar `validate_maildir()`: verificar que el Maildir del usuario `-u` exista (ref: AC-011).
- [x] Task 12 - Implementar `process_maildir()`: `find` con `-path "*/Maildir/*"`, exclusión de `.Sent`, `.Template` y `dovecot*`, filtro `-newermt "${YEAR}-01-01" -not -newermt "$((YEAR+1))-01-01"`, loop con `while IFS= read -r -d ''`, lectura de headers `From:`, `Envelope-to:` y `Date:` con `grep -m 1`, match de `From:` en formato simple o con nombre visible, `mv` o dry-run, contadores (ref: AC-001, AC-002, AC-007, AC-008, AC-009, AC-015).
- [x] Task 13 - Implementar `main()`: parseo con `getopts` para `-d`, `-f`, `-Y`, `-u`, `-r`, `-y`, `-h`; rechazo de flags desconocidos y argumentos posicionales extra; construcción de `SEARCH_PATH`; orquestación del flujo completo (ref: AC-003, AC-004, AC-005, AC-006, AC-014).
- [x] Task 14 - Dar permisos de ejecución: `chmod +x scripts/clean_sent_to_todos.sh`.

## Fase 5: Verificación y Tests

- [x] Task 15 - Crear `tests/test_clean_sent_to_todos.bats` con setup/teardown que construya un Maildir sintético bajo `$BATS_TMPDIR` con archivos de mail de prueba y `mtime` controlado con `touch -t`.
- [x] Task 16 - Escribir test: `-h` imprime help y sale con exit 0 (ref: AC-005).
- [x] Task 17 - Escribir tests: cada flag obligatorio ausente (`-d`, `-f`, `-Y`) produce exit 1 (ref: AC-004).
- [x] Task 18 - Escribir test: flag desconocido y argumento posicional extra producen exit 1 (ref: AC-006).
- [x] Task 19 - Escribir tests: valores de año inválidos para `-Y` (`abc`, `1800`, `2100`, `99`) producen exit 1 (ref: AC-013).
- [x] Task 20 - Escribir test: directorio destino inexistente produce exit 1 (ref: AC-010).
- [x] Task 21 - Escribir test: Maildir de usuario inexistente con `-u` produce exit 1 (ref: AC-011).
- [x] Task 22 - Escribir test: ejecución real con archivos coincidentes mueve los archivos y los lista en stdout junto con `Date:`; exit 0 (ref: AC-001).
- [x] Task 23 - Escribir test: dry-run lista archivos sin ejecutar `mv` y mostrando `Date:`; exit 0 (ref: AC-002).
- [x] Task 24 - Escribir test: `-u` restringe el análisis al Maildir del usuario indicado (ref: AC-003).
- [x] Task 25 - Escribir test: sin archivos coincidentes emite error en stderr y sale con exit 1 (ref: AC-007).
- [x] Task 26 - Escribir test: filtro de año por `mtime` incluye archivos del año correcto e ignora los de otros años (ref: AC-008).
- [x] Task 27 - Escribir test: confirmación `N` cancela sin ejecutar ningún `mv` (ref: AC-012).
- [x] Task 27b - Escribir test: `-y` omite confirmación interactiva y no imprime el bloque de variables (ref: AC-014).
- [x] Task 28 - Ejecutar `shellcheck scripts/clean_sent_to_todos.sh` y corregir warnings.
- [x] Task 29 - Ejecutar `./ci/run_checks.sh -p clean_sent_to_todos` y verificar que shellcheck + bats pasen.

## Fase 6: Documentación

- [x] Task 30 - Crear `clean_sent_to_todos/Readme.md` con descripción, uso, flags, límites, nota de zona horaria y ejemplos.
- [x] Task 31 - Actualizar `Readme.md` raíz del repositorio agregando `clean_sent_to_todos` a la lista de scripts disponibles.
