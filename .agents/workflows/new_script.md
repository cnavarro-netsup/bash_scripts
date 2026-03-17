---
description: Crear un nuevo proyecto Bash utilizando el enfoque estricto Spec-First, estructura de directorios estándar y pruebas unitarias.
---

# Flujo de Trabajo (Workflow) para crear nuevos proyectos Bash

Este flujo garantiza que cada nuevo proyecto de Bash siga la metodología **Spec-First** exigida en las normativas del repositorio, incluyendo el diseño documental, las pruebas unitarias y el uso de la plantilla base.

## FASE 1: Requerimientos (Requirements Phase)
1. El agente debe crear el directorio del nuevo proyecto bajo `~/workspace/_proyectos_/bash_scripts/<nombre_proyecto>/`.
2. Crear la carpeta `specs/` dentro del proyecto.
3. El agente DEBE generar el archivo `specs/requirements.md` basado en las indicaciones del usuario.
   - Contenido obligatorio: Descripción del problema, Alcance, Supuestos, Restricciones y Criterios de Aceptación (AC-001, AC-002, etc.).
   - El agente debe identificar ambigüedades y proponer edge cases. Pedir confirmación antes de continuar.

## FASE 2: Diseño (Design Phase)
1. Una vez aprobados los requerimientos, el agente creará `specs/design.md`.
2. Contenido esperado: Arquitectura del script, algoritmo principal, validaciones, riesgos, mitigaciones y compatibilidad.
3. No se escribirá código en esta fase.

## FASE 3: Tareas (Tasks Phase)
1. El agente creará `specs/tasks.md` dividiendo el trabajo en pasos pequeños y ejecutables.
2. Formato:
   - [ ] Task 1 - descripción (hace referencia a AC-001)
   - [ ] Task 2 - descripción (hace referencia a AC-002)

## FASE 4: Implementación (Implementation Phase)
1. Solo comenzar cuando `requirements.md`, `design.md` y `tasks.md` existan y estén validados.
2. Crear los directorios `scripts/` y `tests/` en el proyecto.
3. **Copiar la Plantilla Base:**
   - Crear el nuevo script en `scripts/<nombre_script>.sh` copiando exactamente el contenido de `/home/carlos/workspace/_proyectos_/bash_scripts/template/template_script.sh`.
   - **IMPORTANTE (Ruteo Dinámico):** Modificar la variable `PROJECT_ROOT` del nuevo script para que suba DOS niveles en lugar de uno, ya que ahora el script vive en `scripts/`:
     `PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"`
   - Modificar la cabecera (HEADER) para actualizar `NOMBRE:`, `FECHA:` (hoy) y `DESCRIPCION:`.
4. **Integrar Librerías Obligatorias:**
   - El script DEBE importar siempre `logger.sh`.
   - Según el `design.md`, evaluar si se debe conservar la importación de `ssh_utils.sh` o `sqlite_utils.sh`.
4. **Desarrollar Lógica y Parseo:**
   - Implementar las opciones acordadas en la sección 4.1 del script (parseo de argumentos).
   - Actualizar `usage()`.
   - Insertar la lógica en la sección 4.6. Si el proyecto realiza **operaciones destructivas** (modificación/eliminación de datos o archivos), implementar y respetar el flag `--dry-run`. De lo contrario, omitirlo.
6. Otorgar permisos de ejecución: `chmod +x scripts/<nombre_script>.sh`.

## FASE 5: Verificación y Tests (Verification Phase)
1. Crear el archivo de pruebas unitarias en `tests/test_<nombre_script>.bats`.
2. Escribir pruebas unitarias (Bats) comprobando los Criterios de Aceptación (AC).
3. Asegurarse de ejecutar `shellcheck scripts/*.sh` comprobando que no haya errores de sintaxis (linting).

## FASE 6: Documentación (Documentation Phase)
1. El agente DEBE generar un archivo `Readme.md` en la raíz del proyecto `<nombre_proyecto>/`.
2. El documento contrendrá: Descripción detallada del objetivo del script, modo de uso, explicación de cada bandera/argumento, límites definidos y ejemplos claros de ejecución.
3. El flujo global también requiere una anota en el `Readme.md` principal del repositorio indicando que se añadió el nuevo script, con su breve descripción y dónde encontrarlo.

## Reglas de Seguridad (Safety Rules)
- Implementar flag `--dry-run` **solo si el script incluye operaciones destructivas** (ej. modificaciones o eliminaciones del entorno).
- Validar todos los paths con `realpath`.
- No usar `rm` sin guardrails (rutas estrictas).
- Requerir confirmación formal para operaciones destructivas.
- El agente mostrará el `diff` antes de aplicar cambios complejos y pedirá aprobación.
