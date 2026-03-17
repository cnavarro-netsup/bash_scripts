# Requerimientos — suma.sh

## 1. Descripción del Problema

- Crear un script Bash que reciba exactamente **dos números reales** como argumentos posicionales y muestre su suma en stdout.
- El script debe usar únicamente capacidades nativas de Bash y cumplir con las reglas de estilo e infraestructura del repositorio.
- Cada ejecución debe registrar el contexto y los pasos principales en STDERR usando el esquema de logs vigente.

## 2. Alcance

- Aceptar exactamente dos argumentos posicionales sin banderas adicionales.
- Validar que cada argumento sea una representación decimal con **máximo dos dígitos fraccionales** y que utilice el punto (`.`) como separador decimal.
- Permitir valores positivos y negativos, con o sin parte decimal (ej. `12`, `-35.3`, `3.45`).
- Calcular la suma con precisión de punto flotante limitada a dos decimales (p.ej. `printf` o `awk` interno con `bc` deshabilitado) y mostrar el resultado en stdout en formato legible.
- Registrar la solicitud y el resultado en STDERR siempre (incluso en modo de error).
- No se implementa modo `--dry-run` ni `--yes` porque no hay operaciones destructivas ni confirmaciones requeridas.

## 3. Supuestos

- Bash >= 4.x está disponible y soporta aritmética con operadores `awk` o `printf` para manejar decimales.
- Los argumentos se proveen directamente (no interactivo ni stdin).
- El usuario espera que las salidas informativas se escriban en STDERR y el resultado en STDOUT tal como el enunciado.
- Solo se acepta como separador decimal el punto (`.`); los valores con coma serán considerados inválidos, como respondimos en la aclaración del workflow.

## 4. Restricciones

| # | Restricción |
|---|-------------|
| R-01 | Deben recibirse exactamente 2 argumentos posicionales; cualquier otra cantidad genera error y salida con código 1. |
| R-02 | Cada número debe tener a lo sumo 2 dígitos decimales (si los tiene); más precisión se rechaza. |
| R-03 | No se puede utilizar `bc`, `python`, `awk` externo ni intérpretes adicionales (solo herramientas estándar de Bash). |
| R-04 | Las operaciones financieras se limitan a sumar los dos valores sin modificar archivos ni conexiones de red. |
| R-05 | Todos los mensajes informativos o de error deben ir a STDERR, salvo el resultado final que se imprime en STDOUT. |

## 5. Criterios de Aceptación

| ID | Descripción | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Invocar `./suma.sh 3.45 1.55` | STDOUT muestra `Resultado: 5.00` y STDERR contiene el log informativo; exit 0. |
| AC-002 | Invocar sin argumentos o con 1/3+ argumentos | STDOUT vacío, STDERR muestra mensaje de uso y error; exit 1. |
| AC-003 | Invocar con valor no numérico (`abc`) | STDERR informa `Argumento inválido`; exit 1. |
| AC-004 | Invocar con valores con más de 2 decimales (`1.234`) | STDERR indica exceso de precisión; exit 1. |
| AC-005 | Invocar con valores negativos (`-3.5 2.25`) | Suma correcta (`-1.25`) en STDOUT y logs en STDERR; exit 0. |
| AC-006 | Invocar con uno o ambos números sin parte decimal (`5 2`) | Resultado `7.00` en STDOUT y logs en STDERR. |

## 6. Ambigüedades y Edge Cases identificados

- **Separador decimal:** El ejemplo `0,2` sugiere coma como separador. Se decidió aceptar únicamente el punto decimal para evitar interpretar múltiples locales; los valores con coma se tratarán como inválidos.
- **Signos y espacios:** Debemos especificar si los argumentos pueden incluir espacios o signos adheridos (`+5`). Se asumirá que el signo `-` es válido en el inicio y que el argumento no llega con espacios internos.
- **Ceros a la izquierda y formato:** Casos como `003.50` o `-0.5` deben aceptarse siempre que respeten la regla de dos decimales.
- **Precisión máxima:** Al sumar números con dos decimales, el resultado se redondea (o se formatea) a dos decimales exactos.
