# Diseno - copia_dbf.sh

## 1. Arquitectura del Script

- El script vive en `copia_dbf/scripts/copia_dbf.sh` y usa `set -euo pipefail`.
- Se basa en `template/template_script.sh`, ajustando `PROJECT_ROOT` a dos niveles (`../..`).
- Importa solamente `lib/logger.sh`.
- Configura `LOG_STDOUT=FALSE`, `LOG_TO_STDERR=FALSE` y `LOG_FILE=/var/log/copia_dbf.log` para dejar toda la bitacora en archivo y mantener la consola silenciosa.

## 2. Flujo Principal

1. Parsear `-h` y `-d` con `getopts`.
2. Rechazar cualquier argumento posicional o la combinacion simultanea de `-h` y `-d`.
3. Preparar el archivo de log y registrar el inicio de la ejecucion.
4. Verificar por `ssh` que existan archivos `*.DBF` en `txs02:/cygdrive/d/Aplicaciones/FoxApp/Planif/`.
5. Ejecutar la primera copia con `rsync` hacia `/tmp`.
6. Registrar cada archivo `*.DBF` reportado por la salida de `rsync` de la primera etapa.
7. Verificar que en `/tmp` existan archivos `*.DBF` locales.
8. Ejecutar la segunda copia con `rsync` hacia `admingc@planif.gigot.com.ar:/tmp` usando la clave `/root/.ssh/copia_dbf`.
9. Registrar cada archivo `*.DBF` informado por `rsync` en la segunda etapa; si no hubo archivos nuevos, registrar `No new DBF files transferred to remote host.`.
10. Registrar el fin exitoso y devolver exit 0.

## 3. Validaciones

- `-h` solo es valido si es el unico flag.
- `-d` puede aparecer solo o combinado con ausencia de otros flags.
- Cualquier flag invalido, argumento faltante o argumento posicional produce exit 1.
- La ausencia de archivos `*.DBF` en el origen remoto produce exit 1.
- La ausencia de archivos `*.DBF` locales luego de la primera etapa produce exit 1.
- Cualquier fallo de `ssh` o `rsync` produce exit 1.

## 4. Logging

- `usage()` escribe a stdout cuando se invoca con `-h`.
- Los errores de uso se escriben a stderr.
- La operacion normal no imprime nada en consola.
- `lib/logger.sh` escribe toda la bitacora en `/var/log/copia_dbf.log`.
- Cada archivo `*.DBF` detectado en la salida de `rsync` se registra como evento individual.

## 5. Riesgos y Mitigaciones

| Riesgo | Mitigacion |
|--------|------------|
| Coincidencia vacia del patron remoto `*.DBF` | Verificacion previa con `ssh` antes de lanzar el primer `rsync`. |
| Salida no deseada a consola durante una ejecucion normal | Desactivar salida por consola en `logger.sh` y capturar la salida de `rsync` en variables. |
| Archivos con extension minuscula o mixta | Restringir todos los patrones a `*.DBF` y documentarlo explicitamente. |
| Dificultad para distinguir error real de “sin novedades” en la segunda etapa | Analizar la salida de `rsync`; si no reporta archivos `*.DBF` pero retorna 0, registrar el mensaje de no novedades. |
