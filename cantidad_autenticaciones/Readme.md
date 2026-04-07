# cantidad_autenticaciones

Script Bash para contar autenticaciones en logs de Exim usando el patron
`A=login:<cuenta_de_usuario>`.

## Objetivo

Agrupar autenticaciones por fecha y cuenta de usuario, acumulando todos los
logs que coincidan con un patron dado y mostrando el resultado en una tabla
ASCII alineada.

## Uso

```bash
./scripts/cantidad_autenticaciones.sh [-l patron_log] [-n cantidad] [-d]
```

## Opciones

- `-l patron_log`: patron de archivo dentro de `/var/log/exim`. Default:
  `main.log`.
- `-n cantidad`: cantidad maxima de filas a mostrar. Default: `10`.
- `-d`: activa trazas Bash con `set -x`.
- `-h`: muestra ayuda.

## Comportamiento

- Muestra las variables de ejecucion antes de procesar.
- Requiere confirmacion `s/N`.
- Acumula resultados si el patron resuelve multiples logs.
- Ordena por conteo descendente, fecha ascendente y cuenta ascendente.

## Ejemplos

```bash
./scripts/cantidad_autenticaciones.sh
./scripts/cantidad_autenticaciones.sh -l 'main.log*'
./scripts/cantidad_autenticaciones.sh -l main.log-20260412 -n 20
```

## Salida

```text
Tabla: cantidad de autenticaciones por fecha y cuenta

conteo   fecha        cuenta de usuario
------   ----------   ----------------------------------------
20177    2026-04-04   info
16788    2026-04-03   admin
```
