# backup_users_txs03

Copia de seguridad incremental y versionada de los perfiles de usuario de un servidor
Windows 2016 (txs03) hacia un NAS Linux.

## Descripción

El script monta el recurso compartido de Windows via `sshfs` en modo read-only,
copia los directorios `Desktop`, `Documents` y `Downloads` de cada perfil de usuario
hacia un directorio de staging con `rsync`, y luego ejecuta `rdiff-backup` para
producir la copia definitiva versionada. Al finalizar desmonta el recurso y envía
un mail con el log completo de la ejecución.

### Flujo de ejecución

```
sshfs (ro) → /mnt/txs03/*  →  rsync staging  →  rdiff-backup  →  /srv/bk-daily/txs03-users
                                /srv/tmp/txs03-user-staging
```

## Requisitos

- Ubuntu 24.04, Bash 5.2+
- Herramientas: `sshfs`, `rsync`, `rdiff-backup` (2.0.5+), `mail`, `fusermount`
- Autenticación SSH por clave ya desplegada para `root@localhost → Administrador@txs03`
- Ejecutar como `root`

## Configuración interna

| Variable         | Default                            | Descripción                          |
|------------------|------------------------------------|--------------------------------------|
| `SSHFS_SRC`      | `Administrador@txs03:..`           | Recurso remoto Windows               |
| `MOUNT_POINT`    | `/mnt/txs03`                       | Punto de montaje local               |
| `STAGING_DIR`    | `/srv/tmp/txs03-user-staging`      | Directorio de staging para rsync     |
| `DEST_DIR`       | `/srv/bk-daily/txs03-users`        | Destino final de rdiff-backup        |
| `MAX_INCREMENTS` | `10`                               | Incrementos a conservar              |
| `MAIL_TO`        | `infraestructura@gigot.com.ar`     | Destinatario del log por mail        |
| `SUBDIRS`        | `Desktop Documents Downloads`      | Directorios a copiar por perfil      |

## Uso

El script no recibe argumentos. Está diseñado para ejecución automática via cron:

```bash
# /etc/cron.d/backup_users_txs03
0 2 * * * root /opt/scripts/backup_users_txs03/scripts/backup_users_txs03.sh
```

Modo debug (imprime trazas de ejecución):

```bash
DEBUG=TRUE /opt/scripts/backup_users_txs03/scripts/backup_users_txs03.sh
```

## Salida

- Stdout: ninguna (diseñado para cron).
- Stderr: errores fatales si los hay.
- Mail: log completo enviado a `infraestructura@gigot.com.ar` con asunto
  `backup_users_txs03: OK` o `backup_users_txs03: FAILED`.

## Códigos de salida

| Código | Significado                                      |
|--------|--------------------------------------------------|
| `0`    | Ejecución completada sin errores                 |
| `1`    | Error fatal o al menos un perfil falló al copiarse |

## Prerequisitos para prueba en QA

Antes de ejecutar en el ambiente de QA verificar:

```bash
# 1. Dependencias instaladas
command -v sshfs rdiff-backup rsync mail fusermount mountpoint

# 2. Punto de montaje existe
ls -ld /mnt/txs03

# 3. Staging y destino existen (o crearlos)
mkdir -p /srv/tmp/txs03-user-staging
mkdir -p /srv/bk-daily/txs03-users

# 4. Conectividad SSH sin password hacia txs03 (como root)
ssh -o BatchMode=yes Administrador@txs03 exit

# 5. Permisos de ejecución
chmod +x scripts/backup_users_txs03.sh
```

## Especificaciones

- `specs/requirements.md`: criterios de aceptación y restricciones.
- `specs/design.md`: arquitectura, flujo y decisiones de diseño.
- `specs/tasks.md`: plan de implementación.
