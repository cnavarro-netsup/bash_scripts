# Diseño — suma.sh

## 1. Arquitectura del Script

- El script adopta el template oficial con header, `set -euo pipefail`, `main()` separado y funciones auxiliares bien delimitadas.
- Se cargará `logger.sh` desde `${PROJECT_ROOT}/lib/` y se harán logs con `[INFO]`/`[ERROR]` hacia STDERR.
- El flujo principal sigue el patrón: configuración → parseo → validación → cálculo → salida.
- No se incluyen librerías adicionales (ni `ssh_utils.sh` ni `sqlite_utils.sh`).

## 2. Algoritmo Principal

1. Determinar los argumentos posicionales esperados (exactamente dos) y activar debug si `-d`.
2. Validar cada argumento con una regex que acepte opcionalmente un signo `-`, dígitos enteros y hasta dos decimales separados por un punto.
3. Convertir cada número a centésimos: extraer parte entera y fraccionaria, garantizar hasta dos decimales, normalizar a entero mediante multiplicación por 100 y conservar el signo.
4. Sumar los centésimos usando aritmética entera de Bash (`$(( ))`).
5. Formatear el resultado con dos decimales (ej. usando `printf %.2f` aplicando división de centésimos) y escribirlo en STDOUT.
6. Registrar en STDERR el inicio, los valores recibidos y el resultado final, incluso para errores.

## 3. Validaciones

- Conteo de argumentos: exactamente dos; si no, mostrar uso y salir con código 1.
- Formato de número: regex `^-?[0-9]+(\.[0-9]{1,2})?$` (punto como separador y máximo dos decimales).
- Precisión: negar más de dos dígitos fraccionales y rechazar valores que incluyan coma decimal.
- Conversión segura a enteros: verificar que cada fracción tiene hasta dos dígitos y rellenar con ceros a la derecha si hace falta.
- Registro de errores en STDERR y uso de `usage()` para explicar la sintaxis.

## 4. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Pérdida de precisión al usar aritmética de punto flotante nativa de Bash | Escalar los valores a centésimos (`*100`) y sumar enteros en `$(( ))` para evitar redondeos. |
| Argumentos mal formateados (coma decimal, más decimal) | Validar con regex estricta y rechazar cualquier entrada que no cumpla, detallando el error en STDERR. |
| Falta de trazabilidad | Registrar `[INFO]` al inicio y al final, así como `[ERROR]` cuando algo falla. |

## 5. Compatibilidad

- El script es 100% Bash POSIX-compatible dentro de las limitaciones (se usa `(( ))` y expansion para manipular strings). Requiere Bash ≥ 4.0 para manejar arrays simples si se opta por esa ruta.
- No depende de herramientas externas como `bc`, `awk` ni intérpretes adicionales de scripting.
