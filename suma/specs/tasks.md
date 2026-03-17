# Tareas — suma.sh

## Fase 4: Implementación

- [ ] Task 1 - Crear/directorios `scripts/` y `tests/` y copiar la plantilla `template_script.sh` a `scripts/suma.sh` con ajustes de header y `PROJECT_ROOT`.
- [ ] Task 2 - Ajustar las variables de ejecución (`DEBUG`, `ASSUME_YES`, etc.) y registrar los valores recibidos en STDERR siguiendo el estilo de logs.
- [ ] Task 3 - Implementar el parseo de argumentos mixto incluyendo `-d`, `-h` y opciones aceptadas (sin `--dry-run`).
- [ ] Task 4 - Añadir funciones `usage()`, `validate_input()` y `convert_to_cents()` para comprobar formato y convertir valores con hasta dos decimales.
- [ ] Task 5 - Construir la lógica principal que suma centésimos y formatea el resultado con dos decimales sin perder precisión (ref: AC-001, AC-005, AC-006).
- [ ] Task 6 - Manejar errores: argumentos inválidos, cantidad incorrecta o precisión excedida (ref: AC-002, AC-003, AC-004). Escenarios deben registrar `[ERROR]`.
- [ ] Task 7 - Invocar `cleanup`, aplicar permisos `chmod +x scripts/suma.sh` y asegurar que `main` se ejecute con `main "$@"`.

## Fase 5: Verificación y Tests

- [ ] Task 8 - Crear `tests/test_suma.bats` y añadir pruebas que cubran casos válidos (`3.45 1.55`, `-3.5 2`) y errores (`uno`, `1.234`, 3 args, ninguno).
- [ ] Task 9 - Correr `shellcheck scripts/suma.sh` y documentar cualquier advertencia, asegurando que el linter no reporta errores bloqueantes.
