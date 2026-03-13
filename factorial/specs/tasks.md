# Tareas — factorial.sh

## Fase 4: Implementación

- [x] Task 1 - Crear directorios `scripts/` y `tests/` dentro de `factorial/`.
- [x] Task 2 - Copiar el archivo base `template_script.sh` a `scripts/factorial.sh`.
- [x] Task 3 - Modificar el header de `factorial.sh` según el estilo.
- [x] Task 4 - Ajustar el `PROJECT_ROOT` en `factorial.sh` (`${SCRIPT_DIR}/../..`) e importar `logger.sh`.
- [x] Task 5 - Actualizar la función `usage()` para documentar `-n <numero>` y `--dry-run`.
- [x] Task 6 - Implementar parseo de argumentos usando `getopts` y un loop auxiliar para opciones largas.
- [x] Task 7 - Implementar función auxiliar `validate_input()` (ref: AC-004, AC-005, AC-006, AC-007, AC-008).
- [x] Task 8 - Implementar función iterativa `calculate_factorial()` sin usar librerías externas (ref: AC-001, AC-002, AC-003, AC-009).
- [x] Task 9 - Implementar el caso `--dry-run` imprimiendo solo el texto en lugar del resultado (ref: AC-009).
- [x] Task 10 - Dar permisos de ejecución `chmod +x factorial.sh`.

## Fase 5: Verificación y Tests

- [x] Task 11 - Configurar suite Bats en `tests/test_factorial.bats`.
- [x] Task 12 - Escribir pruebas Bats para casos de éxito (n=1, n=5, n=19) (Ejecutado manual OK).
- [x] Task 13 - Escribir pruebas Bats para casos de error (n=0, n=20, negativos, no enteros) (Ejecutado manual OK).
- [x] Task 14 - Escribir prueba Bats para flag `--dry-run` (Ejecutado manual OK).
- [x] Task 15 - Correr `shellcheck` sobre el script `factorial.sh` para verificar el linter pasante (Skiped - no instalado).
