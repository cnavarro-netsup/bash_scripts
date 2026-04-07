# Requirements - cantidad_autenticaciones

## Descripcion del problema

Se requiere un script Bash que lea uno o mas logs de Exim y cuente autenticaciones
por usuario usando el patron `A=login:<cuenta_de_usuario>`. El resultado debe
agruparse por fecha y cuenta de usuario, ordenarse por conteo descendente y
mostrarse en una tabla ASCII alineada.

## Alcance

- Resolver uno o varios archivos de log dentro de `/var/log/exim` mediante `-l`.
- Contar autenticaciones detectadas con el patron `A=login:<cuenta_de_usuario>`.
- Acumular resultados entre todos los logs encontrados.
- Mostrar variables de ejecucion antes de procesar.
- Requerir confirmacion interactiva `s/N` antes de ejecutar.
- Mostrar el ranking en tabla ASCII con columnas fijas.

## Supuestos

- La fecha del evento se toma del primer campo de cada linea del log.
- La cuenta autenticada se encuentra en un token independiente con formato
  `A=login:<usuario>`.
- Los logs a procesar existen dentro de `/var/log/exim` o en el path inyectado
  por `EXIM_LOG_DIR` durante tests.

## Restricciones

- No se aceptan rutas arbitrarias en `-l`; solo nombres o patrones simples.
- La confirmacion debe aceptar solo `s`; cualquier otra respuesta aborta.
- El default de log es `main.log`.
- El default de cantidad de resultados es `10`.
- La salida debe ser una tabla ASCII con columnas, no texto libre.

## Edge Cases

- El patron no encuentra archivos.
- Un match no es archivo regular o no es legible.
- `-n` no es entero positivo.
- El usuario cancela con Enter o cualquier valor distinto de `s`.
- Los logs resueltos no contienen autenticaciones; en ese caso se muestra solo
  el encabezado de tabla.

## Criterios de Aceptacion

- AC-001: Si no se informa `-l`, el script usa `main.log`.
- AC-002: El script acepta `-l main.log`, `-l 'main.log*'` y
  `-l main.log-20260412`.
- AC-003: Si `-l` resuelve multiples archivos, el conteo se acumula entre todos.
- AC-004: El script detecta autenticaciones a partir de `A=login:<usuario>`.
- AC-005: El resultado se agrupa por `fecha + cuenta_de_usuario`.
- AC-006: El resultado se ordena por conteo descendente, fecha ascendente y
  cuenta ascendente.
- AC-007: El script muestra las variables de ejecucion antes de procesar.
- AC-008: El script solicita confirmacion `s/N` y aborta salvo respuesta `s`.
- AC-009: El script acepta `-n <cantidad>` y limita la salida al top indicado.
- AC-010: La salida final se imprime como tabla ASCII con columnas `conteo`,
  `fecha` y `cuenta de usuario`.
- AC-011: Si el patron de log es invalido o no encuentra archivos, el script
  falla con mensaje claro y codigo distinto de cero.
- AC-012: El proyecto incluye tests Bats y pasa `shellcheck`.
