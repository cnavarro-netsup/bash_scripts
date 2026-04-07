# Design - cantidad_autenticaciones

## Arquitectura

El proyecto contiene un unico script principal en `scripts/` y una suite Bats
en `tests/`. El script importa `lib/logger.sh`, valida argumentos, resuelve los
logs a procesar y luego cuenta autenticaciones con `awk`.

## Flujo principal

1. Inicializar modo estricto Bash y librerias.
2. Parsear `-l`, `-n`, `-d` y `-h` con `getopts`.
3. Validar el patron de log y la cantidad solicitada.
4. Resolver coincidencias dentro de `EXIM_LOG_DIR` usando `compgen -G`.
5. Mostrar variables de ejecucion y pedir confirmacion `s/N`.
6. Procesar todos los logs en una sola corrida de `awk`.
7. Ordenar resultados con `sort`.
8. Limitar el top con `awk 'NR <= top_n'`.
9. Renderizar la salida final como tabla ASCII alineada.

## Extraccion del patron

La deteccion de autenticaciones se hara token por token dentro de cada linea:

- Si un campo comienza con `A=login:` se extrae el usuario con `substr`.
- La fecha se toma del campo `$1`.
- La agrupacion se hace sobre `count[fecha, usuario]`.

Esto evita depender de posiciones fijas posteriores al patron.

## Validaciones

- `-l` no puede estar vacio.
- `-l` no puede contener `/`.
- `-l` solo acepta `[A-Za-z0-9._*?-]`.
- `-n` debe ser entero positivo mayor a cero.
- Cada archivo resuelto debe existir, ser regular y legible.

## Salida

La salida operativa se divide en dos partes:

1. Variables de ejecucion previas al procesamiento.
2. Tabla final con:
   - `conteo`
   - `fecha`
   - `cuenta de usuario`

## Riesgos y mitigaciones

- Riesgo: patron que expanda fuera del directorio esperado.
  Mitigacion: no aceptar rutas y resolver siempre prefijando `EXIM_LOG_DIR`.
- Riesgo: corte prematuro en pipelines con `pipefail`.
  Mitigacion: limitar el top con `awk` en vez de `head`.
- Riesgo: logs sin matches funcionales.
  Mitigacion: imprimir encabezado de tabla aunque no haya filas.

## Compatibilidad

- Bash 4.x o superior.
- Herramientas requeridas: `awk`, `sort`, `compgen` del shell Bash.
- El script admite override de `EXIM_LOG_DIR` para pruebas automatizadas.
