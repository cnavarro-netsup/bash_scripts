bash scripts generales para @Infra
Se emplea Google Antigravity para la creación de los scripts, siguiendo el workflow Spec-First definido en `.agents/workflows/new_script.md`.
Todos los desarrollos arrancan desde `template/template_script.sh` y deben cumplir las reglas descritas en `.agents/rules/estilo-seguridad.md`.

## Scripts disponibles
- `factorial/scripts/factorial.sh`: calcula factoriales iterativamente dentro del rango validado `[1, 19]`, ofrece `--dry-run` y `-d`, y registra sus pasos con la librería `lib/logger.sh`.
- `suma/scripts/suma.sh`: suma exactamente dos números reales con hasta dos decimales (solo punto decimal), convierte internamente a centésimos para evitar pérdida de precisión y documenta el flujo en `suma/Readme.md`.

## Librerías compartidas
Las utilidades comunes (`lib/logger.sh`, `lib/ssh_utils.sh` y `lib/sqlite_utils.sh`) se importan según el alcance del proyecto para mantener consistencia en logging, acceso remoto o persistencia cuando corresponda.
