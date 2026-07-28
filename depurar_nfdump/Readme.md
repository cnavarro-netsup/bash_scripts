# depurar_nfdump

## Proposito

`depurar_nfdump.sh` es un script de **borrado selectivo** sobre `/var/cache/nfdump`, el
directorio donde `nfcapd` deja los archivos de captura de flujos (traffic flow) recibidos
del router. Elimina los archivos de captura rotados y **preserva siempre** el archivo de
captura activo (`nfcapd.current.*`).

## Comportamiento

- Opera unicamente sobre `/var/cache/nfdump` (redefinible con `NFDUMP_TARGET_DIR` solo para pruebas).
- Elimina **solo archivos regulares directos** de ese directorio; **no** hace recursion.
- **Preserva siempre** los archivos cuyo nombre empieza con `nfcapd.current.` (captura en curso).
- Si tras excluir los `nfcapd.current.*` no queda nada por borrar, informa `Total deleted files: 0` y termina con `exit 0`.
- Falla con `exit 1` si el directorio no existe, esta vacio o contiene entradas no regulares no permitidas (estructura corrupta).
- No escribe en `stdout`; los mensajes operativos y de error salen por `stderr`.
- Registra los eventos con `lib/logger.sh` y syslog (tag `depurar_nfdump`).
- Borra con `rm -f`; pide confirmacion interactiva salvo en modo `-y`/`--yes`.

## Estructura

- `scripts/depurar_nfdump.sh`: script de borrado selectivo (punto de entrada).
- `specs/requirements.md`: requerimientos funcionales y no funcionales.
- `specs/design.md`: decisiones de diseno y flujo.
- `specs/tasks.md`: checklist de estado del proyecto.
- `tests/test_depurar_nfdump.bats`: pruebas Bats del comportamiento actual.
- `systemd_timers/`: unidades `.service` y `.timer` para la ejecucion periodica en produccion.

## Uso

```bash
# Ayuda
./scripts/depurar_nfdump.sh -h

# Ejecucion interactiva (pide confirmacion antes de borrar)
./scripts/depurar_nfdump.sh

# Simulacro con confirmacion interactiva: informa cuantos archivos se borrarian, sin tocar nada
./scripts/depurar_nfdump.sh --dry-run

# Simulacro no interactivo: informa cuantos archivos se borrarian, sin pedir confirmacion
./scripts/depurar_nfdump.sh -y --dry-run

# Ejecucion no interactiva (produccion / batch), sin confirmacion
./scripts/depurar_nfdump.sh -y
```

## Automatizacion (systemd timers)

En el servidor de produccion la ejecucion periodica se realiza con **systemd timers**
(en lugar de cron). El proyecto incluye las unidades:

- `systemd_timers/depurar_nfdump.service`: ejecuta el script como `root` en modo silencioso (`-y`), `Type=oneshot`.
- `systemd_timers/depurar_nfdump.timer`: agenda una ejecucion cada 3 horas (`OnCalendar=*-*-* 00/3:00:00`, dispara a las 00, 03, 06, 09, 12, 15, 18 y 21 h). `Persistent=true` recupera una corrida perdida si el equipo estuvo apagado.

La unidad `service` invoca `/opt/script/local/exec/traffic_flow/depurar_nfdump.sh -y`. Ajustar el `ExecStart`
a la ruta real del script desplegado si difiere.

### Instalacion de las unidades

```bash
sudo cp depurar_nfdump/systemd_timers/depurar_nfdump.service /etc/systemd/system/
sudo cp depurar_nfdump/systemd_timers/depurar_nfdump.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now depurar_nfdump.timer
```

### Verificacion operativa

```bash
sudo systemctl status depurar_nfdump.timer
sudo systemctl list-timers --all | grep depurar_nfdump
sudo systemctl start depurar_nfdump.service   # ejecucion manual puntual
sudo journalctl -u depurar_nfdump.service      # salida capturada por el journal
sudo journalctl -t depurar_nfdump              # eventos enviados a syslog por el script
```

## Automatizacion (CRON)

Alternativa a systemd si el servidor destino usara cron. El script corre como root, en modo
silencioso (`-y`) y cada 3 horas. Como los eventos se registran en syslog (tag `depurar_nfdump`),
la salida se descarta para no generar correo de cron en cada corrida.

Linea para el crontab de root (`sudo crontab -e`):

```cron
0 */3 * * * /opt/script/local/exec/traffic_flow/depurar_nfdump.sh -y >/dev/null 2>&1
```

Alternativa en `/etc/cron.d/depurar_nfdump` (incluye el campo de usuario):

```cron
0 */3 * * * root /opt/script/local/exec/traffic_flow/depurar_nfdump.sh -y >/dev/null 2>&1
```

Notas:
- `0 */3 * * *` dispara a las 00, 03, 06, 09, 12, 15, 18 y 21 h.
- Ajustar la ruta segun el despliegue real. Si se apunta al repo en vez de la release desplegada:
  `/home/carlos/workspace/_proyectos_/bash_scripts/depurar_nfdump/scripts/depurar_nfdump.sh`.
- Para auditar la actividad: `journalctl -t depurar_nfdump`.
- Si el cron tuviera un PATH recortado, agregar al inicio del crontab:
  `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`.
