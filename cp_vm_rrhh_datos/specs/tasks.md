# Tareas de `cp_vm_rrhh_datos`

- [x] 1. Crear `scripts/cp_vm_rrhh_datos.sh` como script Bash monolítico basado en la plantilla del repositorio, importar `logger.sh`, activar `set -euo pipefail` y definir las constantes y opciones `-y`, `-D`, `-d` y `-h` aprobadas; apuntar a 200-250 líneas y no superar nunca 300.
- [x] 2. Implementar ayuda, parseo de argumentos, trazas de depuración, plan de ejecución y confirmación, omitiendo variables y pregunta con `-y` y finalizando sin cambios con `-D`.
- [x] 3. Implementar las precondiciones de `design.md`: dependencias locales y remotas, SSH estricto, LV existentes, directorio de backup y ausencia del snapshot, destinos y temporales previstos.
- [x] 4. Implementar el procesamiento secuencial de `lv_rrhh_data1` y `lv_rrhh_data2`: crear `snap` de `1G`, copiar mediante el pipeline `ssh`/`dd`/`pv` al temporal, retirar el snapshot y publicar con `mv`.
- [x] 5. Implementar traps y cleanup para descartar únicamente el temporal activo e intentar retirar solo el snapshot marcado como creado por la ejecución actual cuando ocurra un fallo.
- [x] 6. Crear `tests/test_cp_vm_rrhh_datos.bats` con mocks pequeños y aislados para evitar operaciones reales de SSH, LVM, `dd` y `pv`.
- [x] 7. Añadir pruebas Bats mínimas para ayuda, argumentos, dry-run y flujo exitoso simulado en el orden aprobado.
- [x] 8. Añadir pruebas Bats mínimas para snapshot o destino preexistente y para cleanup ante un fallo simulado.
- [x] 9. Ejecutar ShellCheck sobre el script y corregir únicamente los hallazgos necesarios para que pase sin errores.
- [x] 10. Ejecutar el runner común del repositorio para `cp_vm_rrhh_datos` y comprobar que ShellCheck y Bats finalizan correctamente.
