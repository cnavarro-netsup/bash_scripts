bash scripts generales para @Infra
Se emplea Google Antigravity para la creación de los scripts, siguiendo el workflow Spec-First definido en `.agents/workflows/new_script.md`.
Todos los desarrollos arrancan desde `template/template_script.sh`, usan `template/template_spec.md` como guía de especificaciones y deben cumplir las reglas descritas en `.agents/rules/estilo-seguridad.md`.

## Scripts disponibles
- `vm_test/scripts/vm_test.sh`: verifica la integridad de una imagen cruda de VM, mapea las particiones (LVM/kpartx) pasivamente (`fsck -n`) y extrae silenciosamente su hostname.
- `factorial/scripts/factorial.sh`: calcula factoriales iterativamente dentro del rango validado `[1, 19]`, ofrece `--dry-run` y `-d`, y registra sus pasos con la librería `lib/logger.sh`.
- `suma/scripts/suma.sh`: suma exactamente dos números reales con hasta dos decimales (solo punto decimal), convierte internamente a centésimos para evitar pérdida de precisión y documenta el flujo en `suma/Readme.md`.
- `copia_dbf/scripts/copia_dbf.sh`: copia archivos `*.DBF` en mayúsculas desde `txs02` al jump host y luego a `planif.gigot.com.ar`, registrando cada transferencia en `/var/log/copia_dbf.log` sin emitir salida operativa en consola.
- `cp_vm/scripts/cp_vm.sh`: copia el almacenamiento remoto de una VM hacia `/srv/bk-vm` desde un snapshot LVM o desde el LV nativo, intenta respaldar tambien su XML de libvirt, valida espacio libre local, resuelve el hypervisor desde `/etc/vm_hypervisor.map` y transfiere con `ssh`, `pv` y `dd`.
- `create_vm_from_image/scripts/create_vm_from_image.sh`: crea una VM temporal local en `nas03` desde una imagen de backup y su XML de libvirt, fuerza la primera NIC a la network `dumb`, arranca el dominio y muestra el comando manual de `virt-viewer` para validar la consola desde otra maquina.
- `cantidad_autenticaciones/scripts/cantidad_autenticaciones.sh`: cuenta autenticaciones Exim por `A=login:<usuario>`, acumula multiples logs resueltos por patron y presenta el ranking en una tabla ASCII alineada.
- `auth_watch/scripts/auth_watch.sh`: controla autenticaciones Exim del dia actual por cuenta, compara cada total contra un umbral diario y envia una alerta por mail por cada cuenta que lo alcance o supere.
- `n_mail_watch/scripts/n_mail_watch.sh`: controla mails enviados por cuenta durante el dia actual, reutiliza la deteccion de `cantidad_mail_enviados` y envia una alerta por mail por cada cuenta que alcance o supere el umbral diario.
- `mail_size_analyzer/scripts/mail_size_analyzer.sh`: recorre `/srv/mail/*/Maildir` o un usuario puntual con `-u`, convierte el tamano de cada mail a MB enteros truncados y muestra la distribucion en 11 nichos mas el total analizado.

## Librerías compartidas
Las utilidades comunes (`lib/logger.sh`, `lib/ssh_utils.sh` y `lib/sqlite_utils.sh`) se importan según el alcance del proyecto para mantener consistencia en logging, acceso remoto o persistencia cuando corresponda.

## Guías del agente
- `.agents/rules/estilo-seguridad.md`: reglas always-on para estilo y seguridad base en scripts de infraestructura.
- `.agents/workflows/new_script.md`: workflow Spec-First para nuevos proyectos Bash.
- `.agents/skills/infra_bash_secure.md`: skill especializado en scripting Bash seguro para infraestructura, con foco en guardrails operativos, validación estricta y manejo seguro de secretos.

## Validación común
- `make checks`: ejecuta `shellcheck` y `bats` sobre todos los proyectos detectados (`*/scripts` y `*/tests`).
- `make checks-factorial` y `make checks-suma`: permiten validar un proyecto puntual.
- La ejecución central usa `ci/run_checks.sh` y guarda una bitácora en `tmp/checks/checks_YYYYMMDD_HHMMSS.log`, además de actualizar `tmp/checks/latest.log`.
- Convención sugerida: después de cada cambio funcional, correr `make checks` y usar `tmp/checks/latest.log` como referencia rápida del último resultado local.

## Despliegue remoto
- `ansible/` contiene una base de despliegue para promover scripts aprobados a servidores remotos con releases versionadas y symlink `current`.
- El playbook principal es `ansible/playbooks/deploy_scripts.yml` y los inventarios base están en `ansible/inventories/dev/` y `ansible/inventories/prod/`.
- La guía de uso, variables y estructura remota está en `ansible/Readme.md`.
