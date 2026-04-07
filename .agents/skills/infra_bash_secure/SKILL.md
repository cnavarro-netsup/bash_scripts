---
name: infra_bash_secure
description: Skill para desarrollo y revisión de scripts Bash de infraestructura con foco en seguridad, validación estricta, operación segura y protección de secretos.
---

# Skill: infra_bash_secure

## Propósito

Usa este skill cuando la tarea involucre scripts Bash que:
- operan sobre sistemas, archivos, servicios, storage o red
- usan `ssh`, `scp`, `rsync`, `dd`, `virsh`, `mount`, `umount`, `lvm`, `rm`, `cp`, `mv`
- tocan backups, restauraciones, validaciones, despliegues o automatización operativa
- puedan causar impacto operativo si fallan o si se ejecutan con parámetros incorrectos

Este skill prioriza:
- minimizar riesgo
- validar temprano
- operar sobre temporales cuando sea posible
- hacer visible el plan antes de ejecutar
- dejar evidencia verificable con tests y lint
- proteger secretos de manera estricta

## Principios

1. Fallar temprano y con mensaje claro.
2. Nunca asumir contexto operativo implícito.
3. Validar todos los inputs antes de actuar.
4. Trabajar sobre copias o temporales si el original debe preservarse.
5. Toda operación potencialmente destructiva debe tener guardrails.
6. El script debe ser legible, verificable y predecible.
7. La seguridad de secretos no es negociable.

## Checklist obligatoria

### Estructura base
- Empezar con `set -euo pipefail`
- Incluir header estándar del repositorio
- Definir `SCRIPT_DIR` y `PROJECT_ROOT`
- Cargar `logger.sh`
- Tener `usage()`
- Tener `main()`
- Tener `cleanup()` si hay temporales, mounts, snapshots, loops o recursos remotos
- Registrar `trap cleanup EXIT ERR INT TERM` cuando aplique

### Validación de argumentos
- Validar presencia de obligatorios
- Validar formato y rango de valores
- Rechazar valores vacíos o ambiguos
- Rechazar combinaciones inválidas
- Mostrar ayuda clara ante error de parseo

### Validación de entorno
- Verificar dependencias con `command -v`
- Verificar permisos si hacen falta privilegios
- Validar existencia de archivos/directorios
- Resolver paths con `realpath` cuando corresponda
- Distinguir archivo regular, directorio, symlink o device antes de operar

### Seguridad de paths
- Citar siempre variables de path
- No operar sobre paths no resueltos si la ruta es crítica
- Validar que el destino pertenezca a una ubicación esperada antes de borrar, mover o sobrescribir
- No usar rutas derivadas sin chequear que no quedaron vacías

### Operaciones destructivas
Si el script crea, borra, redefine, desmonta, remueve o sobrescribe:
- exigir `--dry-run` o `-D`
- mostrar plan de ejecución
- requerir confirmación interactiva o `-y`
- no ejecutar cambios reales sin pasar por ese punto de control
- nunca usar `rm -rf` sin validación fuerte del path

### Operaciones remotas
Si usa `ssh` o `scp`:
- usar modo batch
- usar timeouts
- manejar errores remotos explícitamente
- no ocultar errores relevantes
- si hay cleanup remoto, que sea idempotente
- no asumir conectividad ni permisos
- no incrustar autenticación insegura

### Recursos temporales
- usar `mktemp`
- registrar temporales en variables claras
- limpiar siempre en `cleanup`
- no reutilizar nombres temporales fijos

### Salida y logging
- Logs claros y accionables
- Mensajes de error concretos
- No mezclar salida funcional con ruido si el script debe devolver un dato útil
- Mostrar “Variables de Ejecución” antes de actuar cuando el flujo lo requiera, excepto en modo batch con `-y` / `ASSUME_YES=TRUE`
- No exponer datos sensibles en logs

### Verificación
- Ejecutar `shellcheck`
- Agregar tests Bats mínimos ligados a criterios de aceptación
- Correr checks del repo antes de cerrar

## Gestión de secretos

Estas reglas son no negociables.

- Nunca hardcodear contraseñas, claves, llaves privadas, tokens, passphrases ni secretos de ningún tipo.
- Nunca almacenar secretos en el código fuente, tests, documentación, ejemplos, mocks o archivos temporales.
- Nunca incrustar credenciales en comandos `ssh`, `scp`, `curl`, URLs, variables persistentes o archivos auxiliares.
- Nunca pasar secretos en texto plano por parámetros si pueden quedar expuestos en historial, logs o procesos visibles con `ps`.
- Preferir autenticación mediante `ssh-agent`, claves ya desplegadas, variables de entorno seguras inyectadas externamente, vaults o gestores de secretos.
- Si una tarea requiere autenticación y no existe un mecanismo seguro ya establecido, el script debe abortar con un mensaje claro en lugar de implementar una solución insegura.
- Los logs no deben imprimir secretos, ni completos ni parcialmente si no es imprescindible.
- Nunca versionar archivos que probablemente contengan secretos.

## Anti-patrones prohibidos

- `rm -rf "${algo}"` sin validar que `${algo}` no esté vacío y pertenezca a una ruta permitida
- parseo manual frágil cuando `getopts` alcanza
- paths sin comillas
- `|| true` para ocultar errores no justificados
- modificar archivos originales si un temporal resuelve el problema
- usar `ssh` sin timeout ni batch mode
- asumir que una dependencia está instalada sin verificarla
- usar nombres ambiguos para recursos temporales
- mezclar datos funcionales con logs si eso rompe la automatización
- sobrescribir archivos existentes sin regla explícita
- hardcodear contraseñas, tokens, claves o llaves privadas
- usar `sshpass` o mecanismos equivalentes sin justificación explícita y aprobación
- guardar secretos en texto plano en `/tmp`, logs o archivos intermedios
- dejar credenciales expuestas en ejemplos o documentación operativa

## Reglas de implementación

### Parseo
- Preferir `getopts` con opciones cortas si el repo sigue esa convención
- Mensajes claros para opción inválida o faltante de argumento
- `-h` debe salir con código 0

### Funciones
- Mantener funciones pequeñas
- Separar:
  - validación de entorno
  - validación de argumentos
  - resolución de paths
  - lógica principal
  - cleanup

### Confirmación
Para flujos con impacto:
- imprimir resumen de ejecución
- pedir confirmación
- permitir `-y` para modo no interactivo
- si `-y` está activo, omitir confirmación y no imprimir el bloque de variables de ejecución
- permitir `-D` para simulación si corresponde

### XML / config sensible
Si el flujo manipula XML o configuraciones:
- preservar original
- trabajar sobre una copia temporal
- tocar solo nodos estrictamente necesarios
- validar el resultado antes de aplicarlo

### LVM / mounts / loops / libvirt
Si el script usa estos recursos:
- preparar cleanup desde el inicio
- asumir que el script puede abortar en cualquier punto
- diseñar el cleanup para ser seguro si el recurso no llegó a crearse
- si una operación posterior falla, no dejar recursos huérfanos si es evitable

### Acceso remoto y autenticación
- Preferir autenticación con llaves ya distribuidas y `ssh-agent`
- No pedir al script que gestione passwords en claro
- No escribir helpers que exporten o interpolen secretos en comandos
- Si el flujo depende de credenciales externas, documentar el prerequisito sin exponerlas

## Revisión de seguridad

Cuando revises un script con este skill, busca primero:

1. Riesgo de destrucción accidental
- paths mal validados
- borrados inseguros
- sobrescrituras silenciosas

2. Riesgo de inconsistencia
- falta de cleanup
- recursos temporales que quedan vivos
- errores parciales no controlados

3. Riesgo de operación remota insegura
- ssh sin timeout
- falta de control de errores
- supuestos no validados

4. Riesgo de exposición de secretos
- credenciales embebidas
- secretos en tests o fixtures
- URLs con usuario/password
- uso inseguro de `sshpass`
- logs que imprimen variables sensibles
- archivos temporales o ejemplos con material sensible

5. Riesgo de regresión funcional
- cambios sobre stdout esperado
- códigos de salida inconsistentes
- falta de tests para criterios críticos

## Plantilla mental de trabajo

Antes de escribir código, responder:
1. ¿Qué inputs recibe?
2. ¿Qué puede romper?
3. ¿Qué recursos temporales crea?
4. ¿Qué pasa si falla en mitad del flujo?
5. ¿Cómo se valida que actuará sobre el objetivo correcto?
6. ¿Qué dependencias externas necesita?
7. ¿Dónde podría exponerse un secreto por accidente?
8. ¿Qué debe quedar registrado para operar con confianza?

## Criterio de finalización

No considerar terminada una tarea hasta que:
- los argumentos y paths estén validados
- las operaciones riesgosas tengan guardrails
- el cleanup esté contemplado si aplica
- no existan secretos hardcodeados ni exposición accidental de credenciales
- el script pase `shellcheck`
- existan tests para el camino feliz y errores críticos
- la documentación o ayuda refleje el comportamiento real
