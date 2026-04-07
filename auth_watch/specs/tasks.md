# Tareas — auth_watch.sh

## Fase 1 a 3: Definición

- [x] Task 1 - Crear directorios `specs/`, `scripts/` y `tests/` dentro de `auth_watch/`.
- [x] Task 2 - Redactar `specs/requirements.md` con alcance, restricciones, edge cases y AC.
- [x] Task 3 - Redactar `specs/design.md` con arquitectura, algoritmo, validaciones y riesgos.
- [x] Task 4 - Redactar `specs/tasks.md` con pasos ejecutables referenciando los AC.

## Fase 4: Implementación

- [x] Task 5 - Crear `scripts/auth_watch.sh` a partir del template del repositorio.
- [x] Task 6 - Ajustar header, `PROJECT_ROOT` e importación de `logger.sh`.
- [x] Task 7 - Implementar parseo `-l`, `-t`, `-r`, `-d`, `-y`, `-h` con `getopts` (AC-001, AC-002, AC-003, AC-013).
- [x] Task 8 - Validar patrón de log, umbral, destinatario, directorio y archivos resueltos (AC-011, AC-012).
- [x] Task 9 - Implementar detección de backend de mail `sendmail`/`mailx` (AC-012).
- [x] Task 10 - Implementar conteo de autenticaciones del día actual por `fecha + cuenta` (AC-004, AC-005).
- [x] Task 11 - Implementar filtro por umbral y envío de un mail por cuenta excedida (AC-006, AC-007, AC-008, AC-009, AC-010).
- [x] Task 12 - Otorgar permisos de ejecución a `scripts/auth_watch.sh`.

## Fase 5: Verificación y Tests

- [x] Task 13 - Crear `tests/test_auth_watch.bats`.
- [x] Task 14 - Escribir pruebas para cuentas por debajo del umbral y sin alertas (AC-006).
- [x] Task 15 - Escribir pruebas para cuentas en o sobre el umbral y múltiples cuentas excedidas (AC-007, AC-008).
- [x] Task 16 - Escribir pruebas para filtrado por fecha actual y reenvío entre corridas (AC-004, AC-009).
- [x] Task 17 - Escribir pruebas para errores de validación y ausencia de backend de correo (AC-011, AC-012).
- [x] Task 18 - Ejecutar `shellcheck` sobre `scripts/auth_watch.sh`.
- [x] Task 19 - Ejecutar `./ci/run_checks.sh -p auth_watch`.

## Fase 6: Documentación

- [x] Task 20 - Crear `auth_watch/Readme.md` con descripción, flags, ejemplos y cron.
- [x] Task 21 - Actualizar `Readme.md` principal del repositorio con el nuevo script.
