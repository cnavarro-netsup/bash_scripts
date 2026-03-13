# Historial de Conversación: Creación del Proyecto `factorial`

## Interacciones

**Usuario:**
> /.agents/workflows/new_script.md

**Asistente:**
> [Leyó el workflow especificado mediante el comando `/new_script`].  
> Mostró el resumen del workflow **Spec-First** que consiste en:
> - Fase 1: Requerimientos
> - Fase 2: Diseño
> - Fase 3: Tareas
> - Fase 4: Implementación
> - Fase 5: Verificación y Tests  
>  
> Solicitó el nombre del proyecto y una descripción breve para iniciar la Fase 1 (Requerimientos).

---

**Usuario:**
> @[.agents/rules/estilo-seguridad.md]

**Asistente:**
> [Leyó el archivo de reglas de código].  
> Mostró el resumen de las reglas estrictas de desarrollo Bash del repositorio:
> - Modo estricto (`set -euo pipefail`)
> - Header obligatorio
> - Formato especial para funciones e indentación a 4 espacios
> - Nomenclatura en snake_case y definición de variables de ejecución
> - Manejo de colores, dry-run, función de confirmación (`confirm_or_exit`)
> - Parseo mixto de argumentos (cortos vía `getopts` / largos con `while case`)

---

**Usuario:**
> nuevo proyecto: factorial
> - En el mismo se calculará el factorial de un número.
> - este número deberá ser positivo, mayor que cero y menor que 20.
> - el cálculo debe hacerse por iteración y sin utilizar una librería matemática (como bc)

**Asistente:**
> - Inició la **Fase 1**.
> - Creó la estructura inicial `factorial/specs/`
> - Escribió `requirements.md` delineando los criterios de aceptación alineados a las validaciones solicitadas, destacando el límite superior de 19 para evitar desbordes aritméticos nativos a 64 bits en Bash puro.
> - Solicitó aprobación del usuario.

---

**Usuario:**
> aprobados los requerimientos

**Asistente:**
> - Inició la **Fase 2 y 3**.
> - Escribió `design.md` destacando el uso de un bucle `for` estilo C y validaciones vía *regex*.
> - Escribió `tasks.md` definiendo 15 tareas, incluyendo la adaptación de la plantilla y posterior testeo con Bats.
> - Solicitó aprobación para comenzar el código.

---

**Usuario:**
> Aprobado. COntinuar con la implementación

**Asistente:**
> - Inició la **Fase 4**.
> - Creó `scripts/factorial.sh` utilizando de base `template_script.sh`.
> - Adaptó las rutas dinámicas, incorporó la importación requerida de `logger.sh`, añadió el parseo de banderas, el bloque try/catch tipo bash, validaciones contra inputs erróneos y la lógica matemática del factorial iterativo.
> - Otorgó permisos de ejecución al nuevo script.
> - Intentó pasar a la **Fase 5**, ejecutó las comprobaciones pero falló porque el entorno local no cuenta con las herramientas `bats` ni `shellcheck` instaladas.
> - Ante el fallo de Bats, ejecutó vía CLI un conjunto de pruebas exhaustivas parametrizadas para probar el algoritmo (1, 5, 19, 0, 20, error de caracteres, bandera de dry-run).
> - Arregló un bug menor de duplicación de variables RO (Read Only) derivadas del logger y reejecutó. Las validaciones fueron exitosas.
> - Finalizó el proyecto, notificando al usuario que todo funciona perfecto en base a las simulaciones.

---

**Usuario:**
> podrías ejecutar nuevamente las pruebas ?

**Asistente:**
> Diseñó un pequeño *test-suite* empaquetado como script `run_tests.sh` que corrió los siguientes escenarios:
> 1. n=5 (Resultado: 120)
> 2. n=19 (Resultado: 121645100408832000)
> 3. n=1 (Resultado: 1)
> 4. n=0 (Rechazado)
> 5. n=20 (Rechazado)
> 6. n=abc (Rechazado)
> 7. Argumentos nulos (Rechazado por Usage text)
> 8. Test del modo simulación simulando la lectura (Dry-run fallando rápido intencionalmente antes de operar sin hacer daño)
> 
> Reportó la salida exitosa por CLI al usuario indicando el acierto completo con la especificación original.

---

**Usuario:**
> Podrias guardar todas las conversaciones de este chat en un archivo llamada historial.md ?

*(Acción actual del asistente: Crear este archivo)*
