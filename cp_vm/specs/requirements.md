# Proyecto: cp_vm

## 1. Descripcion del Problema

Se necesita un script Bash ejecutado desde un NAS Linux para copiar la imagen de almacenamiento de una VM alojada en un hypervisor remoto. El almacenamiento de origen vive en volumentes logicos LVM y el destino debe ser un archivo local persistido en el NAS.

El flujo debe soportar dos modos: copia directa desde el LV nativo de la VM o copia desde un snapshot LVM creado y removido por el mismo script. Ademas, debe copiar el archivo de configuracion libvirt de la VM ubicado en el hypervisor remoto bajo `/etc/libvirt/qemu/<vm>.xml`. La transferencia remota debe realizarse por SSH usando `dd`, con `pv` para mostrar estadisticas en tiempo real.

---

## 2. Alcance

- Ejecutar el script en Ubuntu 24.04 o superior usando Bash.
- Resolver el hypervisor remoto a partir de `/etc/vm_hypervisor.map` o un archivo alternativo indicado por parametro.
- Construir el LV remoto con el patron `/dev/<vg>/lv_<vm>_os`.
- Soportar backup tipo `snap` y `lv` mediante la opcion `-t`.
- Crear snapshots remotos con `lvcreate -L 1G -s -n snap` cuando el tipo sea `snap`.
- Remover snapshots remotos al finalizar o ante error si el tipo sea `snap`.
- Consultar el tamano del LV remoto para alimentar `pv --size`.
- Validar que el espacio libre del filesystem destino supere al tamano de la copia en al menos 5%.
- Persistir la copia como archivo local en `/srv/bk-vm` o un directorio alternativo indicado por parametro.
- Persistir tambien el archivo XML remoto de la VM con el nombre `<vm>-ddmmYYYY.xml` en el mismo directorio de backup.
- Fallar si el archivo destino ya existe.
- Continuar con el backup del disco aunque falle la copia del XML, dejando constancia con un warning.
- Mostrar las variables de ejecucion y requerir confirmacion explicita antes de comenzar.
- Soportar `-D` para simulacion sin cambios destructivos ni copia real.

---

## 3. Supuestos

- El acceso SSH con llave publica desde el NAS hacia los hypervisores ya esta implementado.
- El nombre del LV remoto siempre sigue el formato `lv_<vm>_os`.
- El volume group remoto por defecto es `vg_vm`.
- El snapshot remoto por defecto se llama `snap` y un tamano fijo de `1G` es suficiente durante la copia.
- El archivo de mapeo usa exactamente el formato `<vm> <hypervisor>` por linea.
- El usuario remoto dispone de permisos para `lvs`, `lvcreate`, `lvremove` y lectura del device LVM.

---

## 4. Restricciones

| # | Restriccion |
|---|-------------|
| R-01 | El script debe ser monolitico y vivir en `cp_vm/scripts/cp_vm.sh`. |
| R-02 | El parseo de opciones debe hacerse con `getopts` y opciones cortas. |
| R-03 | La transferencia debe usar `ssh`, `pv` y `dd` en ambos extremos. |
| R-04 | El `dd` local debe usar `conv=fsync status=none`. |
| R-05 | El `dd` remoto debe usar `status=none`. |
| R-06 | El nombre del archivo destino debe ser `lv_<vm>_os-ddmmYYYY` para `lv` y `lv_<vm>_os_snap-ddmmYYYY` para `snap`. |
| R-07 | Si el archivo destino del disco o del XML existe, el script debe fallar sin sobrescribirlo. |
| R-08 | Si el espacio libre es menor al 105% del tamano origen, el script debe abortar con un error claro. |
| R-09 | El XML remoto debe copiarse antes que el disco remoto. |
| R-10 | Si la copia del XML falla, el script debe emitir warning y continuar con el backup del disco. |

---

## 5. Criterios de Aceptacion (AC)

| ID | Descripcion | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | `-h` | Muestra ayuda y finaliza con codigo 0. |
| AC-002 | Ejecucion sin `-v` | Falla con mensaje de uso y codigo distinto de 0. |
| AC-003 | `-t` invalido | Falla indicando que el tipo debe ser `snap` o `lv`. |
| AC-004 | VM presente en el mapa | Resuelve correctamente el hypervisor remoto asociado. |
| AC-005 | VM ausente en el mapa | Falla indicando que no existe mapeo para la VM. |
| AC-006 | Tipo `snap` | Crea snapshot remoto, copia desde `/dev/<vg>/<snap>` y remueve el snapshot al finalizar. |
| AC-007 | Tipo `lv` | Copia directamente desde `/dev/<vg>/lv_<vm>_os` sin crear snapshot. |
| AC-008 | `-D` | Muestra el plan de ejecucion sin crear snapshot ni copiar datos reales. |
| AC-009 | Espacio insuficiente | Falla informando tamano origen, espacio requerido y espacio disponible. |
| AC-010 | Destino existente | Falla informando que el archivo ya existe. |
| AC-011 | XML remoto disponible | Copia `/etc/libvirt/qemu/<vm>.xml` como `<vm>-ddmmYYYY.xml` antes del backup del disco. |
| AC-012 | XML remoto ausente o fallido | Emite warning y continua con el backup del disco si este puede completarse. |

---

## 6. Edge Cases identificados

- El archivo de mapeo existe pero contiene una linea mal formada para la VM buscada.
- El archivo de mapeo contiene entradas duplicadas para la misma VM.
- El directorio de backups no existe o no puede resolverse con `realpath`.
- `lvs` remoto devuelve un tamano vacio o no numerico.
- El snapshot se crea pero la copia falla: el `cleanup` debe intentar removerlo igualmente.
- El XML remoto no existe o no puede leerse: debe emitirse warning y no dejar archivos parciales locales.
