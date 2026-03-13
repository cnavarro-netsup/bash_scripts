# Requerimientos — factorial.sh

## 1. Descripción del Problema

Calcular el factorial de un número entero positivo dado como argumento al script.  
El cálculo se realiza mediante **iteración pura en Bash**, sin recurrir a herramientas
externas de aritmética como `bc`, `awk` o `python`.

---

## 2. Alcance

- El script recibe un único número entero como argumento (`-n`).
- Valida que el número sea entero positivo y esté en el rango `[1, 19]`.
- Calcula el factorial mediante un bucle iterativo interno.
- Muestra el resultado en stdout con formato claro.
- Admite modo `--dry-run`: muestra la operación que se realizaría sin ejecutarla.
- Admite modo debug (`-d`) para trazas detalladas.

---

## 3. Supuestos

- Bash >= 4.x disponible en el sistema.
- No se requiere ninguna librería matemática externa.
- El resultado de `19!` (= 121.645.100.408.832.000) cabe dentro de un entero de 64 bits
  de Bash (límite: ~9.2 × 10¹⁸). El valor `20!` supera ese límite, por lo que el
  máximo permitido es **19**.
- El usuario puede ejecutar el script directamente (no requiere root).

---

## 4. Restricciones

| # | Restricción |
|---|-------------|
| R-01 | El número debe ser entero positivo (sin decimales, sin signo negativo). |
| R-02 | El rango válido es `1 ≤ n ≤ 19`. |
| R-03 | No se permite usar `bc`, `awk`, `python` ni ningún intérprete matemático externo. |
| R-04 | El cálculo debe realizarse mediante iteración (no recursión). |
| R-05 | El script debe respetar el estilo definido en `estilo-seguridad.md`. |

---

## 5. Criterios de Aceptación

| ID | Descripción | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Ejecución con `-n 5` | Muestra `5! = 120` |
| AC-002 | Ejecución con `-n 1` | Muestra `1! = 1` (caso límite inferior) |
| AC-003 | Ejecución con `-n 19` | Muestra `19! = 121645100408832000` (caso límite superior) |
| AC-004 | Ejecución con `-n 0` | Error: "El número debe ser mayor que cero." y exit 1 |
| AC-005 | Ejecución con `-n 20` | Error: "El número debe ser menor que 20." y exit 1 |
| AC-006 | Ejecución con `-n -3` | Error: "El número debe ser positivo." y exit 1 |
| AC-007 | Ejecución con `-n abc` | Error: "El argumento debe ser un número entero." y exit 1 |
| AC-008 | Ejecución sin argumentos | Muestra usage y exit 1 |
| AC-009 | Ejecución con `--dry-run` y `-n 7` | Muestra "Se calcularía: 7!" sin ejecutar el cálculo |
| AC-010 | Ejecución con `-d` (debug) | Activa `set -x` y muestra trazas de ejecución |

---

## 6. Edge Cases identificados

- `n = 0`: matemáticamente `0! = 1`, pero el enunciado pide **mayor que cero**, se rechaza.
- `n = 1`: resultado trivial, debe manejarse correctamente en el bucle (sin iterar).
- `n = 19`: verificar que el resultado no desborde el entero de Bash.
- Valores con espacios o caracteres especiales en el argumento (ej: `-n " 5"`).
- Argumento flotante (ej: `-n 3.5`): debe rechazarse.
