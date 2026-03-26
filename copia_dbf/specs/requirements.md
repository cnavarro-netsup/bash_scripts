# Requerimientos - copia_dbf.sh

## 1. Descripcion del Problema

- Crear un script Bash que copie archivos `*.DBF` desde un Windows Server hacia un server Linux publico usando un jump host Linux.
- El flujo se ejecuta en dos etapas consecutivas: primero desde `txs02` al jump host y luego desde el jump host al server publico `planif.gigot.com.ar`.
- El script no debe borrar, mover ni modificar archivos existentes; solo debe copiar y registrar lo sucedido en un archivo de log.

## 2. Alcance

- Aceptar solo los flags `-h` y `-d`.
- Ejecutar exactamente estos pasos operativos:
  1. `rsync -avz Administrador@txs02:/cygdrive/d/Aplicaciones/FoxApp/Planif/*.DBF /tmp`
  2. `rsync -avz --chmod=F600,D700 -e 'ssh -i /root/.ssh/copia_dbf -o BatchMode=yes -o StrictHostKeyChecking=yes' /tmp/*.DBF admingc@planif.gigot.com.ar:/tmp`
- Considerar unicamente archivos con extension `*.DBF` en mayusculas.
- Registrar en `/var/log/copia_dbf.log` los eventos principales y cada archivo `*.DBF` transferido en cada etapa.
- Mantener la consola silenciosa en ejecucion normal; solo la ayuda y los errores de uso pueden mostrar texto.

## 3. Supuestos

- El script se ejecuta en Ubuntu 24.01.1 con GNU Bash 5.2.21.
- La ejecucion como `root` es responsabilidad del operador; el script no valida ese requisito.
- La conectividad SSH desde el jump host hacia `txs02` y `planif.gigot.com.ar` ya esta resuelta.
- La clave privada `/root/.ssh/copia_dbf` existe y es valida para el segundo salto.
- El shell remoto del origen permite evaluar el patron `*.DBF` mediante `ssh`.

## 4. Restricciones

| # | Restriccion |
|---|-------------|
| R-01 | No se aceptan argumentos posicionales ni flags distintos de `-h` y `-d`. |
| R-02 | La combinacion `-d -h` o `-h -d` es invalida y debe finalizar con exit 1. |
| R-03 | No se implementan `--dry-run`, `-y`, `--yes` ni variables de entorno publicas de configuracion. |
| R-04 | El script solo considera archivos `*.DBF` en mayusculas; archivos `*.dbf` o variantes mixtas no cuentan como validos. |
| R-05 | No se ejecutan acciones destructivas sobre archivos locales o remotos. |
| R-06 | Los comandos operativos permitidos son `rsync`, `ssh` y `lib/logger.sh`. |
| R-07 | El log persistente debe escribirse en `/var/log/copia_dbf.log`. |

## 5. Criterios de Aceptacion

| ID | Descripcion | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Invocar `./scripts/copia_dbf.sh -h` | Muestra ayuda y finaliza con exit 0. |
| AC-002 | Invocar `./scripts/copia_dbf.sh -d` con ambas etapas exitosas | Ejecuta las dos copias con debug activo, registra los archivos transferidos y finaliza con exit 0. |
| AC-003 | Invocar `./scripts/copia_dbf.sh` sin archivos `*.DBF` en el origen Windows | Registra el error y finaliza con exit 1. |
| AC-004 | Invocar `./scripts/copia_dbf.sh` cuando la segunda etapa no tiene archivos nuevos para transferir | Registra `No new DBF files transferred to remote host.` y finaliza con exit 0. |
| AC-005 | Invocar con un flag no permitido, un argumento posicional o la combinacion `-d -h` | Informa error de uso y finaliza con exit 1. |
| AC-006 | Existen archivos `*.dbf` pero no `*.DBF` en el origen | Se consideran inexistentes los archivos validos, se registra error y finaliza con exit 1. |

## 6. Edge Cases identificados

- El origen remoto puede devolver coincidencia vacia para `*.DBF`; eso debe tratarse como error funcional y no como exito vacio.
- La primera etapa puede copiar archivos al `/tmp` local y la segunda etapa puede no transferir nada nuevo; eso es un exito valido.
- Los nombres de archivo pueden contener espacios y deben registrarse completos en el log.
- El log nunca debe incluir secretos, solo nombres de archivos y estados del flujo.
