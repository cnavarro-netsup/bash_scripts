# Diseno - depurar_nfdump.sh

## 1. Arquitectura del Script

- El script vive en `scripts/depurar_nfdump.sh` y usa `set -euo pipefail`.
- La configuracion de logging es opt-in por script sobre `lib/logger.sh`.
- Se define `LOG_STDOUT=FALSE`, `LOG_TO_STDERR=TRUE` y `LOG_TO_SYSLOG=TRUE` para cumplir el UX.
- El directorio de trabajo real es `/var/cache/nfdump`; `NFDUMP_TARGET_DIR` solo se admite para pruebas Bats.

## 2. Flujo Principal

1. Cargar `logger.sh` y validar que el backend syslog este disponible.
2. Parsear solo `-y`, `--yes`, `--dry-run`, `-h`, `--help`.
3. Mostrar el contexto de ejecucion por `stderr`.
4. Validar que el directorio objetivo exista.
5. Recolectar las entradas directas del directorio usando glob no recursivo.
6. Fallar si el directorio esta vacio o si encuentra una entrada que no sea archivo regular.
7. Solicitar confirmacion salvo que se haya indicado `-y` o `--yes`.
8. Si `--dry-run` esta activo, informar cuantos archivos se borrarian y terminar sin cambios.
9. Si no hay simulacion, eliminar cada archivo con `rm -f -- <archivo>`.
10. Informar el total de archivos borrados por `stderr` y syslog.

## 3. Validaciones

- Cualquier flag no permitido produce exit 1.
- Cualquier argumento posicional produce exit 1.
- Directorio inexistente produce exit 1.
- Directorio vacio produce exit 1.
- Cualquier entrada no regular dentro del directorio se interpreta como estructura corrupta y produce exit 1.
- Si `rm -f` falla en un archivo, la ejecucion se aborta con exit 1.

## 4. Logging

- `stdout` no se utiliza.
- Los mensajes operativos y de error se escriben por `stderr`.
- `lib/logger.sh` replica los eventos a syslog con el tag `depurar_nfdump`.
- El backend de syslog usa el comando `logger` y prioridad `user.info`, `user.warning` o `user.err` segun el nivel.

## 5. Riesgos y Mitigaciones

| Riesgo | Mitigacion |
|--------|------------|
| Eliminacion fuera del directorio objetivo | Directorio fijo y glob no recursivo sobre un unico nivel. |
| Salida inesperada por stdout | Configurar `LOG_STDOUT=FALSE` y usar solo `stderr`. |
| Estructura mezclada con subdirectorios | Tratar cualquier entrada no regular como error y abortar. |
| Tests peligrosos sobre `/var/cache/nfdump` real | Usar `NFDUMP_TARGET_DIR` exclusivamente en pruebas automatizadas. |
