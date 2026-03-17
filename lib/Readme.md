# Librerías compartidas

Este repositorio expone tres utilidades que se pueden cargar desde cualquier script mediante `source "${PROJECT_ROOT}/lib/<nombre>.sh"`.

## `logger.sh`
- Provee `log_info`, `log_warn`, `log_error` y `die` para estandarizar los logs con colores y marcas temporales.
- Usa las variables `LOG_FILE` (opcional) y `LOG_STDOUT` (TRUE/FALSE) para controlar si además de la consola se escribe un archivo de log.
- Ejemplo de uso:

  ```bash
  source "${PROJECT_ROOT}/lib/logger.sh"
  log_info "Inicio del proceso"
  log_error "Falló la validación" && exit 1
  die "Sucesor crítico" 2
  ```

## `ssh_utils.sh`
- Útil para scripts que necesitan validación de conectividad SSH o ejecución remota.
- Exporta funciones como `test_ssh_connection` y `run_remote_cmd` que reciben nombre/host y comandos.
- Antes de usarla, comprobar que las variables de entorno de autenticación (`SSH_USER`, `SSH_KEY`, etc.) están configuradas.

## `sqlite_utils.sh`
- Facilita inicializar/consultar una base SQLite. Tiene helpers como `db_init` y `db_query`.
- Define la variable `DB_PATH` si quieres apuntar a un archivo específico; por defecto usa la ruta dentro del script.

## Tests sugeridos
- `logger.sh` puede probarse creando un script temporal que reemplace `LOG_STDOUT` y verifique que los mensajes se envían al descriptor correcto.
- Para estas pruebas basta con ejecutar `source lib/logger.sh` y llamar a las funciones dentro de un `bats` o script de shell, redirigiendo stdout/stderr a archivos temporales y validando su contenido.
