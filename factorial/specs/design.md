# Diseño — factorial.sh

## 1. Arquitectura del Script

El script estará estructurado siguiendo el template estándar del repositorio,
compuesto por:
1. **Header estándar** con metadatos.
2. **Setup estricto** (`set -euo pipefail`).
3. **Importaciones**: carga de `logger.sh` (obligatorio). No se usarán utilidades extras de BDD u opciones de red.
4. **Configuración y variables globales**.
5. **Parseo de argumentos** adaptado a `--dry-run` y `-d`.
6. **Lógica Principal** (main).

## 2. Algoritmo Principal

El core del cálculo será una función iterativa `calculate_factorial`:
```bash
calculate_factorial()
{
    local n="$1"
    local iter
    local result=1

    for (( iter=1; iter<=n; iter++ )); do
        result=$(( result * iter ))
    done

    echo "$result"
}
```

## 3. Validaciones

Antes de calcular, el script validará el argumento recibido (`$NUMBER`):
1. **Presencia**: Se debe proveer exactamente un argumento `-n <valor>`.
2. **Formato**: Se verificará usando una regex para enteros positivos: `^[0-9]+$`.
3. **Rango Inferior**: Si el valor es `0`, arrojará error (requerimiento: mayor a 0).
4. **Rango Superior**: Si el valor es `>= 20`, arrojará error (límite de 64 bits en Bash).

## 4. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Desbordamiento entero aritmético de Bash | Limitar `n <= 19`. El valor `20!` (2.432.902.008.176.640.000) entra en conflicto con enteros de 64 bits signados. `19!` es seguro. |
| Inyección de comandos en el input | Uso estricto de regex `^[0-9]+$` para el input antes de procesarlo en expresiones `$(( ))`. |
| Falta de entorno base | Source seguro de `logger.sh` utilizando rutas relativas resolviendo `PROJECT_ROOT`. |

## 5. Compatibilidad

El script se diseñará para ser 100% nativo Bash (POSIX standard fallback where possible, though C-style for loop is Bash extension), sin dependencias como `bc` o `python`.
Requiere `bash >= 4.0` (por estándar del SO).
