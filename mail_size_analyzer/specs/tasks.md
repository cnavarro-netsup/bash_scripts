# Tareas - mail_size_analyzer.sh

## Fase 1 a 3: Definicion

- [x] Task 1 - Crear directorios `specs/`, `scripts/` y `tests/` dentro de `mail_size_analyzer`.
- [x] Task 2 - Redactar `specs/requirements.md` con alcance, restricciones, AC y edge cases.
- [x] Task 3 - Redactar `specs/design.md` con arquitectura, algoritmo, validaciones y mitigaciones.
- [x] Task 4 - Redactar `specs/tasks.md` con pasos ejecutables referenciando los AC.

## Fase 4: Implementacion

- [x] Task 5 - Crear `scripts/mail_size_analyzer.sh` con header estandar y `PROJECT_ROOT` ajustado para `scripts/`.
- [x] Task 6 - Implementar parseo `-h`, `-c` y `-u` con `getopts`, rechazando argumentos posicionales y flags invalidos (AC-001, AC-009).
- [x] Task 7 - Implementar descubrimiento de `Maildir` para todos los usuarios o uno puntual, y validacion del directorio base (AC-004, AC-007, AC-008, AC-010).
- [x] Task 8 - Implementar lectura de tamanos en bytes y conversion a MB truncados (AC-002, AC-006).
- [x] Task 9 - Implementar clasificacion en 11 nichos y contador total (AC-002, AC-003, AC-004, AC-005, AC-006).
- [x] Task 10 - Implementar salida de usuarios en modo normal, salida compacta y errores por `stderr` (AC-002, AC-003, AC-004, AC-005, AC-007, AC-008, AC-009, AC-010).
- [x] Task 11 - Otorgar permisos de ejecucion al script principal.

## Fase 5: Verificacion y Tests

- [x] Task 12 - Actualizar `tests/test_mail_size_analyzer.bats`.
- [x] Task 13 - Escribir pruebas para `-h`, salida normal con multiples usuarios y salida compacta (AC-001, AC-002, AC-003).
- [x] Task 14 - Escribir pruebas para `-u`, `-u -c` y limites de clasificacion (AC-004, AC-005, AC-006).
- [x] Task 15 - Escribir pruebas para estructura vacia o corrupta, usuario inexistente y argumentos invalidos (AC-007, AC-008, AC-009, AC-010).
- [x] Task 16 - Ejecutar `shellcheck` sobre `scripts/mail_size_analyzer.sh`.
- [x] Task 17 - Ejecutar `./ci/run_checks.sh -p mail_size_analyzer` (AC-011).

## Fase 6: Documentacion

- [x] Task 18 - Actualizar `mail_size_analyzer/Readme.md` con `-u`, salida por usuario y ejemplos.
- [x] Task 19 - Actualizar `Readme.md` principal del repositorio con el nuevo alcance del script.
