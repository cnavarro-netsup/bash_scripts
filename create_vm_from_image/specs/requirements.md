# Proyecto: create_vm_from_image

## 1. Descripcion del Problema

Se necesita un script Bash ejecutado localmente en `nas03`, donde existen copias de seguridad de discos de VMs y tambien un stack KVM/libvirt operativo. El objetivo es tomar una imagen de disco ya copiada junto con su archivo XML de libvirt, crear una VM temporal basada en ambos artefactos, arrancarla y dejar al operador el comando necesario para abrir manualmente la consola grafica desde otra maquina.

El flujo debe modificar el XML recibido solo en lo imprescindible para que la VM temporal use la imagen copiada y quede conectada a una red aislada llamada `dumb`, evitando conflictos con la VM productiva original. Ademas, debe validar la compatibilidad basica del XML ajustado con el entorno libvirt/KVM disponible en el NAS antes de intentar definir la nueva VM.

---

## 2. Alcance

- Ejecutar el script localmente en `nas03` usando Bash.
- Recibir la ruta de la imagen con `-i` y la ruta del XML con `-c`.
- Validar existencia y resolver ambas rutas con `realpath`.
- Extraer el nombre de la VM desde el XML recibido.
- Validar que el nombre deducido desde la imagen coincida con el nombre definido en el XML.
- Informar siempre cuantas vCPU y cuanta RAM declara el XML original.
- Fallar si ya existe una VM con ese nombre en el libvirt local.
- Crear un XML temporal ajustando el primer disco principal para apuntar a la imagen local recibida.
- Reconfigurar la primera interfaz de red del XML para que use la network libvirt `dumb`.
- Forzar en el XML temporal el valor de `/domain/vcpu` a `3`.
- Forzar en el XML temporal el valor de `/domain/memory` a `2097152 KiB`.
- Forzar `currentMemory` a `2097152 KiB` si el nodo existe en el XML original.
- Eliminar `cpu/topology` del XML temporal si existe para evitar inconsistencias con las vCPU forzadas.
- Mantener sin cambios el UUID y la MAC presentes en el XML recibido.
- Validar el XML ajustado con herramientas locales de libvirt antes de definir la VM.
- Definir y arrancar la VM temporal con `virsh` local.
- Imprimir el comando manual para abrir la consola desde otra maquina usando `virt-viewer -c qemu+ssh://{usuario}@nas03/system <vm>`.
- Soportar `-D` para simulacion sin crear ni arrancar la VM.

---

## 3. Supuestos

- `nas03` dispone de acceso funcional a libvirt/KVM local y permisos suficientes para ejecutar `virsh define` y `virsh start`.
- La imagen recibida es un archivo regular local y sigue el patron `lv_<vm>_os-ddmmYYYY` o `lv_<vm>_os_snap-ddmmYYYY`.
- El XML recibido corresponde a una definicion de dominio libvirt valida y contiene al menos un disco `device='disk'` y una interfaz de red.
- La network libvirt `dumb` ya existe y esta disponible en el NAS.
- Las utilidades `virsh`, `xmlstarlet`, `virt-xml-validate` y `realpath` estan instaladas en el host.

---

## 4. Restricciones

| # | Restriccion |
|---|-------------|
| R-01 | El script debe vivir en `create_vm_from_image/scripts/create_vm_from_image.sh`. |
| R-02 | El parseo de opciones debe hacerse con `getopts` y opciones cortas. |
| R-03 | Los argumentos funcionales obligatorios deben ser `-i` para la imagen y `-c` para el XML. |
| R-04 | El host mostrado en el comando final de `virt-viewer` debe ser siempre `nas03`. |
| R-05 | El comando final debe mostrar el placeholder literal `{usuario}` y no un usuario explicito. |
| R-06 | Si la VM ya existe en libvirt local, el script debe abortar sin modificarla. |
| R-07 | El script no debe eliminar la VM creada ni el dominio definido al finalizar. |
| R-08 | La unica adaptacion obligatoria del XML es cambiar el disco principal y la primera interfaz de red. |
| R-09 | No se deben regenerar ni modificar UUID ni direcciones MAC. |
| R-10 | El XML original recibido por copia no debe ser modificado. |
| R-11 | La VM temporal debe definirse siempre con `3` vCPU y `2097152 KiB` de RAM. |
| R-12 | El script debe informar siempre las vCPU y la RAM detectadas en el XML original. |

---

## 5. Criterios de Aceptacion (AC)

| ID | Descripcion | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | `-h` | Muestra ayuda y finaliza con codigo 0. |
| AC-002 | Ejecucion sin `-i` | Falla indicando que falta la imagen. |
| AC-003 | Ejecucion sin `-c` | Falla indicando que falta el XML. |
| AC-004 | Imagen o XML inexistentes | Falla con mensaje claro sin invocar `virsh define`. |
| AC-005 | Nombre de VM distinto entre imagen y XML | Falla informando incompatibilidad entre ambos artefactos. |
| AC-006 | XML original con recursos altos | El script informa los valores originales y continua. |
| AC-007 | Reescritura de recursos | El XML temporal queda con `3` vCPU y `2097152 KiB` de RAM. |
| AC-008 | La VM ya existe en libvirt local | Falla sin redefinir ni arrancar el dominio existente. |
| AC-009 | La network `dumb` no existe | Falla antes de definir la VM. |
| AC-010 | El XML ajustado no valida | Falla antes de definir la VM. |
| AC-011 | `virsh define` falla | El script informa error y finaliza con codigo distinto de 0. |
| AC-012 | `virsh start` falla | El script informa error y finaliza con codigo distinto de 0. |
| AC-013 | Caso exitoso | Define y arranca la VM localmente. |
| AC-014 | Caso exitoso | Imprime `virt-viewer -c qemu+ssh://{usuario}@nas03/system <vm>`. |
| AC-015 | `-D` | Muestra el plan y el comando de consola esperado sin definir ni arrancar la VM. |

---

## 6. Edge Cases identificados

- El XML no contiene `/domain/name` o contiene un nombre vacio.
- El XML no contiene `/domain/vcpu` o contiene un valor no numerico.
- El XML no contiene `/domain/memory` o contiene un valor no numerico.
- El XML incluye `currentMemory` y debe mantenerse consistente con la RAM forzada del XML temporal.
- El XML no contiene ningun disco `device='disk'`.
- El XML no contiene ninguna interfaz de red reutilizable.
- El nombre de la VM incluye guiones bajos y la deduccion desde la imagen debe preservarlos.
- La edicion del XML falla a mitad del proceso: se debe abortar y limpiar solo temporales.
- `virsh define` crea el dominio pero `virsh start` falla: el dominio queda definido para analisis posterior.
