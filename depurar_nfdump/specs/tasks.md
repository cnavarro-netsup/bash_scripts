# Tareas - depurar_nfdump.sh

## Fase 1: Definicion y especificacion  [completada]

- [x] Crear la estructura del proyecto (`scripts/`, `specs/`, `tests/`).
- [x] Completar `specs/requirements.md` (objetivo, alcance, restricciones, criterios de aceptacion).
- [x] Completar `specs/design.md` (arquitectura, flujo, validaciones, riesgos).

## Fase 2: Implementacion  [completada]

- [x] Implementar el parseo de argumentos (`-y`, `--yes`, `--dry-run`, `-h`, `--help`).
- [x] Cargar `lib/logger.sh` y validar el backend de syslog.
- [x] Recolectar los archivos objetivo excluyendo `nfcapd.current.*`, sin recursion.
- [x] Implementar el borrado con `rm -f`, el modo `--dry-run` y la confirmacion interactiva.
- [x] Manejar errores y codigos de salida (0/1), incluido el caso `Total deleted files: 0` con exit 0.

## Fase 3: Verificacion  [completada]

- [x] Escribir las pruebas Bats del comportamiento actual (incluye current preservado y solo-current -> exit 0).
- [x] Ejecutar `./ci/run_checks.sh -p depurar_nfdump` (shellcheck + bats en verde).

## Fase 4: Documentacion  [completada]

- [x] Documentar el comportamiento real y ejemplos de uso en `Readme.md`.
- [x] Documentar la automatizacion en produccion (systemd timers) y la alternativa cron.

## Pendientes / higiene

- [ ] (Opcional) Silenciar los warnings `SC2034` de shellcheck sobre las variables `LOG_*`
      (consumidas por `lib/logger.sh` tras el `source`), p. ej. con `# shellcheck disable=SC2034`.
      Hoy el gate del repo los tolera y los checks pasan en verde.
