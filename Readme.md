bash scripts generales para @Infra
Se emplea Google Antigravity para la creación de los scripts, siguiendo el workflow Spec-First definido en `.agents/workflows/new_script.md`.
Todos los desarrollos arrancan desde `template/template_script.sh`, usan `template/template_spec.md` como guía de especificaciones y deben cumplir las reglas descritas en `.agents/rules/estilo-seguridad.md`.

## Scripts disponibles
- `vm_test/scripts/vm_test.sh`: verifica la integridad de una imagen cruda de VM, mapea las particiones (LVM/kpartx) pasivamente (`fsck -n`) y extrae silenciosamente su hostname.
- `factorial/scripts/factorial.sh`: calcula factoriales iterativamente dentro del rango validado `[1, 19]`, ofrece `--dry-run` y `-d`, y registra sus pasos con la librería `lib/logger.sh`.
- `suma/scripts/suma.sh`: suma exactamente dos números reales con hasta dos decimales (solo punto decimal), convierte internamente a centésimos para evitar pérdida de precisión y documenta el flujo en `suma/Readme.md`.

## Librerías compartidas
Las utilidades comunes (`lib/logger.sh`, `lib/ssh_utils.sh` y `lib/sqlite_utils.sh`) se importan según el alcance del proyecto para mantener consistencia en logging, acceso remoto o persistencia cuando corresponda.

## Validación común
- `make checks`: ejecuta `shellcheck` y `bats` sobre todos los proyectos detectados (`*/scripts` y `*/tests`).
- `make checks-factorial` y `make checks-suma`: permiten validar un proyecto puntual.
- La ejecución central usa `ci/run_checks.sh` y guarda una bitácora en `tmp/checks/checks_YYYYMMDD_HHMMSS.log`, además de actualizar `tmp/checks/latest.log`.
- Convención sugerida: después de cada cambio funcional, correr `make checks` y usar `tmp/checks/latest.log` como referencia rápida del último resultado local.

## Despliegue remoto
- `ansible/` contiene una base de despliegue para promover scripts aprobados a servidores remotos con releases versionadas y symlink `current`.
- El playbook principal es `ansible/playbooks/deploy_scripts.yml` y los inventarios base están en `ansible/inventories/dev/` y `ansible/inventories/prod/`.
- La guía de uso, variables y estructura remota está en `ansible/Readme.md`.
