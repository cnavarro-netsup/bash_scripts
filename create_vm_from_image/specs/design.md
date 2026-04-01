# Proyecto: create_vm_from_image

## 1. Objetivo tecnico

Crear una VM temporal en `nas03` a partir de una imagen de disco local y un XML de libvirt ya respaldados, aislando su conectividad sobre la network `dumb` y dejando al operador el comando manual para abrir la consola desde otra maquina.

## 2. Arquitectura del script

El script sera monolitico y vivira en `create_vm_from_image/scripts/create_vm_from_image.sh`.

Componentes principales:

- Parseo de argumentos con `getopts`.
- Validacion de dependencias locales (`virsh`, `xmlstarlet`, `virt-xml-validate`, `realpath`).
- Resolucion segura de rutas de imagen y XML.
- Extraccion del nombre del dominio desde el XML.
- Extraccion de vCPU y RAM desde el XML original para informar los valores recibidos.
- Deduccion del nombre esperado de la VM desde el nombre de la imagen.
- Verificacion de colision de nombre y existencia de la network `dumb`.
- Reescritura controlada de un XML temporal usando `xmlstarlet`.
- Validacion del XML temporal con `virt-xml-validate`.
- Definicion y arranque del dominio con `virsh`.
- Impresion del comando final para `virt-viewer` con host fijo `nas03`.

## 3. Algoritmo principal

1. Parsear `-i`, `-c`, `-d`, `-y`, `-D`, `-h`.
2. Validar que `-i` y `-c` esten presentes.
3. Verificar binarios requeridos.
4. Verificar que imagen y XML existan y resolverlos con `realpath`.
5. Extraer `<vm>` desde `/domain/name` usando `xmlstarlet`.
6. Leer `/domain/vcpu` y `/domain/memory` del XML original e informar esos valores al operador.
7. Derivar `<vm>` desde el basename de la imagen con el patron `lv_<vm>_os(-fecha|_snap-fecha)`.
8. Comparar ambos nombres y abortar si no coinciden.
9. Comprobar con `virsh dominfo <vm>` que el dominio no exista.
10. Comprobar con `virsh net-info dumb` que la network aislada exista.
11. Copiar el XML original a un temporal.
12. Reescribir el XML temporal:
    - primer `disk[@device='disk']`: `@type=file` y `source file=<imagen>`
    - primera `interface`: `@type=network` y `source network=dumb`
    - `vcpu=3`
    - `memory=2097152 KiB`
    - `currentMemory=2097152 KiB` si existe
    - eliminar `/domain/cpu/topology` si existe
13. Validar el XML temporal con `virt-xml-validate <xml> domain`.
14. Mostrar variables de ejecucion y pedir confirmacion, salvo `-y`.
15. Si `-D` esta activo, mostrar el plan y finalizar con exito sin invocar `virsh define` ni `virsh start`.
16. Ejecutar `virsh define <xml_temporal>`.
17. Ejecutar `virsh start <vm>`.
18. Imprimir el comando final `virt-viewer -c qemu+ssh://{usuario}@nas03/system <vm>`.

## 4. Validaciones relevantes

- Imagen local existente y archivo regular.
- XML local existente y archivo regular.
- Nombre de VM presente en XML.
- `/domain/vcpu` presente y numerico.
- `/domain/memory` presente y numerico.
- Nombre de VM deducible desde la imagen.
- Al menos un disco de datos principal y una interfaz de red en el XML.
- Network `dumb` disponible en libvirt local.
- Dominio inexistente antes de definirlo.

## 5. Riesgos y mitigaciones

- Riesgo: XML con estructura distinta a la esperada.
  Mitigacion: contar explicitamente discos e interfaces y abortar si faltan nodos criticos.

- Riesgo: XML incompatible con el stack local.
  Mitigacion: validar el XML temporal con `virt-xml-validate` antes de intentar `virsh define`.

- Riesgo: el XML original pida una topologia CPU incompatible con el valor fijo de vCPU.
  Mitigacion: eliminar `/domain/cpu/topology` del XML temporal antes de validarlo.

- Riesgo: `virsh start` falla luego de definir.
  Mitigacion: informar el error sin eliminar el dominio, ya que el usuario quiere conservarlo para revision.

## 6. Compatibilidad

- Bash 4.x o superior.
- Libvirt/KVM local operativo en `nas03`.
- Dependencia explicita de `xmlstarlet` para edicion XML no destructiva.
- Dependencia explicita de `virt-xml-validate` para validacion estructural del dominio.

## 7. Decisions

- No se modifica UUID ni MAC porque la VM quedara aislada en la network `dumb`.
- No se modifica el XML original respaldado; solo se trabaja sobre un XML temporal derivado.
- El comando de consola no se ejecuta automaticamente porque `nas03` no tiene sesion grafica.
- El usuario SSH se deja como placeholder literal `{usuario}` en la salida final.
