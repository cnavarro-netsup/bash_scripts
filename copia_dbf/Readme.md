# Proyecto: copia_dbf

## Descripcion General

`copia_dbf.sh` es una utilidad CLI en Bash que corre en un jump host Linux y copia archivos `*.DBF` desde `txs02` hacia un server Linux publico en dos etapas consecutivas con `rsync`.

La primera etapa descarga los archivos desde el Windows Server al directorio local `/tmp`. La segunda etapa reenvia los mismos archivos desde el jump host hacia `admingc@planif.gigot.com.ar:/tmp` usando la clave `/root/.ssh/copia_dbf`.

## Uso

```bash
./scripts/copia_dbf.sh [-d]
./scripts/copia_dbf.sh -h
```

## Opciones

- `-d`: activa modo debug (`set -x`).
- `-h`: muestra la ayuda y finaliza.

## Restricciones funcionales

- Solo se consideran archivos con extension `*.DBF` en mayusculas.
- Archivos `*.dbf` o con capitalizacion mixta no se procesan.
- El script no implementa `--dry-run`, `-y` ni argumentos posicionales.
- El flujo normal no imprime salida en consola.

## Logging

- Archivo de log: `/var/log/copia_dbf.log`.
- Los mensajes se registran en ingles.
- Se deja constancia de cada archivo `*.DBF` copiado en la etapa 1 y de cada archivo transferido en la etapa 2.
- Si la segunda etapa no envia archivos nuevos, se registra `No new DBF files transferred to remote host.`.

## Comandos ejecutados

```bash
rsync -avz Administrador@txs02:/cygdrive/d/Aplicaciones/FoxApp/Planif/*.DBF /tmp
rsync -avz --chmod=F600,D700 -e 'ssh -i /root/.ssh/copia_dbf -o BatchMode=yes -o StrictHostKeyChecking=yes' /tmp/*.DBF admingc@planif.gigot.com.ar:/tmp
```

## Codigos de salida

- `0`: ejecucion correcta, incluso si la segunda etapa no encontro archivos nuevos para transferir.
- `1`: error de uso, fallo de conectividad/copia o ausencia de archivos `*.DBF` validos en el origen.

## Ejemplos

```bash
./scripts/copia_dbf.sh
./scripts/copia_dbf.sh -d
./scripts/copia_dbf.sh -h
```
