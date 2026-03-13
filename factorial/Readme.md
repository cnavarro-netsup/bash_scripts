# Proyecto: Factorial

## Descripción General

`factorial.sh` es una utilidad de línea de comandos (CLI) escrita en **Bash puro** que calcula el factorial de un número entero positivo mediante iteración matemática.

El script fue diseñado siguiendo metodologías estrictas de control de calidad (Spec-First), incorporando validaciones tempranas de formato y rango para evitar desbordamientos aritméticos (`integer overflow`) en entornos de 64 bits.

## Uso

```bash
./scripts/factorial.sh -n <numero> [opciones]
```

## Argumentos

### Obligatorios
- `-n, --number <numero>`: Define el número entero positivo del cual se calculará el factorial. Debe estar en el rango de `1` a `19`.

### Opcionales
- `-d, --debug`: Ejecuta el script en modo de depuración (`set -x`), imprimiendo cada comando evaluado por el intérprete en la salida estándar de errores (útil para análisis de fallos en el algoritmo).
- `-y, --yes`: Modo interactivo desactivado (asume confirmación afirmativa a cualquier prompt).
- `-D, --dry-run`: Modo simulación. Analiza los inputs, evalúa los límites y notifica el cálculo que se va a realizar, pero finaliza la ejecución sin llevar a cabo ningún proceso matemático o destructivo real.
- `-h, --help`: Muestra la pantalla de ayuda interactiva.

## Límites Matemáticos (Edge cases)

- **Cero (0)**: Matemáticamente `0! = 1`, pero los requerimientos de la aplicación limitan la ejecución explícitamente a números mayores que cero. Devuelve `exit code 1`.
- **Veinte (20)**: El límite natural de un entero signado de 64 bits de bash se excede al tratar de calcular `20!` (que es `2.432.902.008.176.640.000`). Para evitar resultados corruptos silenciosos, el rango válido máximo de input se fijó en `19`. Devuelve `exit code 1`.

## Ejemplos de uso

Cálculo normal:
```bash
❯ ./scripts/factorial.sh -y -n 5
 Variables de Ejecución 
NUMBER      : 5
DEBUG       : FALSE
DRY_RUN     : FALSE
2026-03-13 13:37:03 [INFO] Iniciando cálculo para n=5
5! = 120
2026-03-13 13:37:03 [INFO] Ejecución finalizada con éxito.
```

Modo simulación de una operación grande:
```bash
❯ ./scripts/factorial.sh -y -n 19 --dry-run
 Variables de Ejecución 
NUMBER      : 19
DEBUG       : FALSE
DRY_RUN     : TRUE
2026-03-13 13:37:03 [INFO] [DRY-RUN] Se calcularía: 19!
```
