# Requirements - backup_users_txs03

## Descripción del problema

Se requiere un script Bash que copie los directorios de perfil de usuario
(`Desktop`, `Documents`, `Downloads`) desde un servidor Windows 2016 (txs03)
hacia un NAS Linux, de forma incremental y versionada.

El servidor Windows se monta como sistema de archivos de solo lectura mediante
`sshfs`. La copia se realiza en dos etapas para sortear las limitaciones de
`rdiff-backup` con rutas largas y formatos de archivo propios de Windows:

1. Copia de staging con `rsync` al directorio temporal `/srv/tmp/txs03-user-staging`.
2. Copia definitiva con `rdiff-backup` desde staging hacia `/srv/bk-daily/txs03-users`,
   conservando 10 incrementos.

El script está diseñado para ejecución automatizada vía cron (no interactivo).
Al finalizar, envía por mail el log completo de la ejecución a
`infraestructura@gigot.com.ar` desde el usuario `root`.

## Alcance

- Montar `/mnt/txs03` como read-only vía `sshfs` si no está montado.
- Iterar sobre todos los perfiles de usuario en `/mnt/txs03/*`.
- Copiar únicamente `Desktop`, `Documents` y `Downloads` de cada perfil.
- Copiar al staging `/srv/tmp/txs03-user-staging` con `rsync`.
- Ejecutar `rdiff-backup` desde staging hacia `/srv/bk-daily/txs03-users`.
- Mantener exactamente 10 incrementos en `rdiff-backup`.
- Enviar mail con el log de ejecución a `infraestructura@gigot.com.ar`.
- No realizar ninguna modificación sobre el recurso Windows montado.
- Ejecutarse como root (el script no verifica esto; es responsabilidad del ejecutor).

## Supuestos

- El directorio `/mnt/txs03` existe y es el punto de montaje del recurso Windows.
- El recurso `Administrador@txs03:..` ya tiene la clave SSH configurada y disponible
  para el usuario root (autenticación por clave, sin password interactivo).
- Los perfiles de usuario se encuentran en `/mnt/txs03/*` (cada subdirectorio
  es un perfil).
- Dentro de cada perfil pueden o no existir los directorios `Desktop`, `Documents`
  y `Downloads`; el script debe manejar la ausencia de cualquiera de ellos.
- `/srv/tmp` existe y tiene espacio suficiente para el staging.
- `/srv/bk-daily/txs03-users` existe o puede ser creado por root.
- `rdiff-backup`, `rsync`, `sshfs`, `mail` (o `sendmail`) están instalados.
- La ejecución en cron implica que no hay terminal interactiva.
- El locale del sistema puede producir paths con caracteres no-ASCII; el script
  debe manejarlos de forma robusta.

## Restricciones

- No usar comandos que modifiquen, eliminen o escriban en el recurso montado.
- No hardcodear credenciales ni passwords en el script.
- El script no recibe argumentos; toda la configuración es interna mediante
  variables con defaults.
- No usar `logger.sh` (no aplica para este script según requerimiento).
- Los mensajes deben estar en inglés.
- Solo se copian los tres directorios explicitamente definidos (`Desktop`,
  `Documents`, `Downloads`).

## Edge Cases

- `/mnt/txs03` no está montado y el montaje falla.
- Un perfil de usuario no contiene ninguno de los tres directorios objetivo.
- Un archivo en el recurso Windows tiene un path demasiado largo o caracteres
  especiales que `rsync` no puede manejar.
- El directorio de staging no existe o no tiene permisos de escritura.
- `rdiff-backup` falla por inconsistencia en el repositorio destino.
- El comando `mail` no está disponible o falla al enviar el log.
- El recurso sshfs ya estaba montado de una ejecución previa interrumpida.
- Falta de espacio en disco en staging o en destino final.

## Criterios de Aceptación

- AC-001: El script monta `/mnt/txs03` en modo read-only si no está ya montado,
  y siempre lo desmonta al finalizar (tanto en éxito como en error).
- AC-002: El script copia únicamente los subdirectorios `Desktop`, `Documents`
  y `Downloads` de cada perfil encontrado en `/mnt/txs03/*`.
- AC-003: La copia de staging se realiza con `rsync` hacia
  `/srv/tmp/txs03-user-staging`, replicando la estructura de perfiles.
- AC-004: La copia definitiva se realiza con `rdiff-backup` desde staging hacia
  `/srv/bk-daily/txs03-users`.
- AC-005: `rdiff-backup` mantiene exactamente 10 incrementos, eliminando los
  más antiguos al superar ese límite.
- AC-006: Al finalizar (con éxito o error), se envía un mail a
  `infraestructura@gigot.com.ar` con el log completo de la ejecución.
- AC-007: El script termina con código de salida 0 si completó sin errores,
  y con código 1 ante cualquier fallo.
- AC-008: El script no realiza ninguna escritura ni modificación sobre el
  recurso montado en `/mnt/txs03`.
- AC-009: El script captura errores de `rsync` o `rdiff-backup` por perfil
  (advertencia en log) sin abortar la copia del resto de los perfiles.
- AC-010: El proyecto incluye tests Bats y el script pasa `shellcheck`.
