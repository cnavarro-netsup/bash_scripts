# Proyecto: auth_watch

## Descripcion General

`auth_watch.sh` controla la cantidad diaria de autenticaciones Exim realizadas por
cada cuenta de correo y dispara una alerta cuando una cuenta alcanza o supera un
umbral configurable.

El objetivo es detectar comportamientos anormales compatibles con cuentas de mail
comprometidas. El script fue pensado para ejecutarse desde cron en un servidor
Linux CentOS 7 con Exim.

## Uso

```bash
./scripts/auth_watch.sh [-l patron_log] [-t limite] [-r destinatario] [-d] [-y]
```

## Opciones

- `-l <patron_log>`: Patron simple de logs dentro de `EXIM_LOG_DIR`. Default:
  `main.log`.
- `-t <limite>`: Umbral diario de autenticaciones por cuenta. Default: `100`.
- `-r <destinatario>`: Lista de destinatarios separada por coma. Default:
  `infraestructura@gigot.com.ar,cnavarro@gigot.com.ar,sagrelo@gigot.com.ar,mloubet@gigot.com.ar`.
- `-d`: Activa modo debug (`set -x`).
- `-y`: Modo batch/cron. Omite confirmacion interactiva y no imprime variables de ejecucion.
- `-h`: Muestra ayuda.

## Variables de Entorno

- `EXIM_LOG_DIR`: Directorio donde se buscan los logs de Exim. Default:
  `/var/log/exim`.
- `MAIL_RECIPIENT`: Lista default de destinatarios separada por coma si no se informa `-r`.
- `DEBUG`: Permite activar debug por entorno con `TRUE` o `FALSE`.
- `ASSUME_YES`: Permite forzar modo batch con `TRUE` o `FALSE`.

## Comportamiento

- Solo cuenta autenticaciones del dia actual del servidor.
- Detecta autenticaciones mediante el token `A=login:<cuenta>`.
- Agrupa por `fecha + cuenta`.
- Envia un mail por cada cuenta que alcance o supere el umbral en la corrida.
- Si la misma cuenta sigue excedida en una corrida posterior del cron, se vuelve
  a enviar la alerta.
- Si no hay cuentas excedidas, finaliza sin enviar mails.

## Backends de Mail

El script busca primero `sendmail` y usa `mailx` como fallback. Si no encuentra
ninguno de los dos, finaliza con error operativo.

## Formato del Aviso

Cada mail incluye como minimo:

- asunto con prefijo `⚠️ Alerta auth_watch`
- cuenta de mail
- fecha analizada
- cantidad de autenticaciones detectadas
- limite configurado

## Ejemplos

Ejecucion tipica desde cron o pruebas manuales:

```bash
./scripts/auth_watch.sh -y
```

Analizar logs rotados del dia y bajar el umbral para una validacion puntual:

```bash
./scripts/auth_watch.sh -y -l 'main.log*' -t 20
```

Enviar alertas a otra casilla durante una prueba:

```bash
./scripts/auth_watch.sh -y -r admin@gigot.com.ar -t 50
```

## Ejemplo de Cron

```cron
0 6,14,22 * * * /ruta/auth_watch/scripts/auth_watch.sh -y >> /var/log/auth_watch.log 2>&1
```

## Validacion Local

```bash
shellcheck auth_watch/scripts/auth_watch.sh
bats auth_watch/tests
./ci/run_checks.sh -p auth_watch
```
