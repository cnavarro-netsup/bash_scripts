# Tareas - copia_dbf.sh

## Fase 4: Implementacion

- [x] Task 1 - Crear `scripts/copia_dbf.sh` a partir de la plantilla base.
- [x] Task 2 - Ajustar header, `PROJECT_ROOT` e import de `logger.sh`.
- [x] Task 3 - Implementar parseo de `-h` y `-d` con rechazo de combinaciones invalidas (ref: AC-001, AC-005).
- [x] Task 4 - Implementar verificacion remota de `*.DBF` en mayusculas mediante `ssh` (ref: AC-003, AC-006).
- [x] Task 5 - Implementar primera copia con `rsync` y logging de archivos recibidos (ref: AC-002).
- [x] Task 6 - Implementar segunda copia con `rsync`, logging de archivos enviados y caso “sin novedades” (ref: AC-004).
- [x] Task 7 - Otorgar permisos de ejecucion al script.

## Fase 5: Verificacion y Tests

- [x] Task 8 - Crear `tests/test_copia_dbf.bats` con mocks de `ssh` y `rsync`.
- [x] Task 9 - Cubrir help, debug, flags invalidos y combinacion `-d -h` (ref: AC-001, AC-005).
- [x] Task 10 - Cubrir ausencia de `*.DBF` en origen y presencia exclusiva de `*.dbf` (ref: AC-003, AC-006).
- [x] Task 11 - Cubrir exito completo y exito sin archivos nuevos en la segunda etapa (ref: AC-002, AC-004).
- [x] Task 12 - Ejecutar `shellcheck` y la validacion puntual del proyecto.
