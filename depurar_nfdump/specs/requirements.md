# Requerimientos - depurar_nfdump.sh

## 1. Descripcion del Problema

- Crear un script Bash que elimine los archivos generados por `nfcapd` ubicados directamente en `/var/cache/nfdump`.
- El script debe limitarse a esa operacion y no debe ejecutar acciones recursivas ni tocar otros directorios.

## 2. Alcance

- Aceptar solo los flags `-y`, `--yes`, `--dry-run`, `-h` y `--help`.
- Mostrar el contexto de ejecucion antes de continuar.
- Solicitar confirmacion interactiva por defecto.
- Omitir confirmacion con `-y` o `--yes`.
- Simular la eliminacion con `--dry-run` sin borrar archivos.
- Eliminar solo archivos regulares ubicados directamente en `/var/cache/nfdump`.
- Imprimir todos los mensajes operativos y de error por `stderr`.
- Registrar eventos mediante `lib/logger.sh` y syslog usando `logger`.

## 3. Supuestos

- El sistema operativo objetivo es Ubuntu 24.01.1 con Bash 5.2.21.
- La ejecucion como root es responsabilidad del operador o de `cron`.
- La ejecucion interactiva se usa en pruebas y `-y` se usara en produccion.
- No se usan variables de entorno publicas; `NFDUMP_TARGET_DIR` solo existe para pruebas automatizadas.

## 4. Restricciones

| # | Restriccion |
|---|-------------|
| R-01 | No se aceptan argumentos posicionales ni flags distintos de `-y`, `--yes`, `--dry-run`, `-h`, `--help`. |
| R-02 | La eliminacion real debe ejecutarse exclusivamente con `rm -f`. |
| R-03 | El script solo puede operar sobre el directorio base `/var/cache/nfdump` y sin recursion. |
| R-04 | Si existe cualquier entrada no regular dentro del directorio objetivo, debe considerarse estructura corrupta y fallar. |
| R-05 | `stdout` debe permanecer vacio en todos los flujos. |
| R-06 | Los logs deben enviarse a `stderr` y a syslog mediante `logger` usando `lib/logger.sh`. |

## 5. Criterios de Aceptacion

| ID | Descripcion | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Invocar `./scripts/depurar_nfdump.sh -h` | Muestra ayuda por `stderr` y finaliza con exit 0. |
| AC-002 | Invocar con un flag invalido o argumento posicional | Informa error por `stderr` y finaliza con exit 1. |
| AC-003 | Invocar con `--dry-run` y archivos presentes | No elimina archivos, informa cuantos se borrarian y finaliza con exit 0. |
| AC-004 | Invocar sin `-y/--yes` y rechazar la confirmacion | No elimina archivos y finaliza con exit 1. |
| AC-005 | Invocar con `-y` o `--yes` y archivos validos | Elimina todos los archivos regulares directos, informa el total borrado y finaliza con exit 0. |
| AC-006 | Directorio inexistente | Informa error por `stderr` y finaliza con exit 1. |
| AC-007 | Directorio vacio | Informa error por `stderr` y finaliza con exit 1. |
| AC-008 | Directorio con subdirectorios o entradas no regulares | Informa estructura corrupta por `stderr` y finaliza con exit 1. |

## 6. Edge Cases identificados

- Archivos con espacios en el nombre deben eliminarse correctamente.
- Un fallo en `logger` con `LOG_TO_SYSLOG=TRUE` debe abortar la ejecucion antes del borrado.
- `--dry-run` debe respetar la misma validacion de estructura que la ejecucion real.
