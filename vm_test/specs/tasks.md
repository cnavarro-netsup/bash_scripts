# Tareas: vm_test

- [ ] Task 1 - Crear estructura base del script copiando la plantilla a `scripts/vm_test.sh` y actualizando parámetros y cabecera (`PROJECT_ROOT`, nombre, etc.).
- [ ] Task 2 - Implementar parseo de argumentos único y posicional y validar la existencia del archivo (AC-001).
- [ ] Task 3 - Implementar esqueleto de la función `cleanup` con hooks a señales y errores (`trap` / AC-003).
- [ ] Task 4 - Conectar con `kpartx -av` y `vgchange -ay vg_os` evaluando exit cases (AC-005).
- [ ] Task 5 - Ejecutar `fsck -n /dev/vg_os/root` e invocar a `cleanup` si falla con error estándar (AC-002, AC-003).
- [ ] Task 6 - Montar partición read-only en directorio temporal creado, `cat /etc/hostname`, y salir con éxito. Esto detona `cleanup` que removerá todo de manera segura (AC-004, AC-005).
