# Diseno - mail_size_analyzer.sh

## 1. Arquitectura del Script

- El proyecto tendra un unico script principal en `scripts/mail_size_analyzer.sh` y una suite Bats en `tests/`.
- El script seguira la estructura general del repositorio: `set -euo pipefail`, header estandar, bloque de configuracion, funciones y `main()`.
- No se importara `logger.sh` porque la especificacion funcional del proyecto lo prohibe explicitamente.
- No se usaran `ssh_utils.sh` ni `sqlite_utils.sh` porque no hay acceso remoto ni persistencia.
- La salida funcional ira por `stdout` y los errores por `stderr`.

## 2. Flujo Principal

1. Inicializar Bash estricto y constantes de clasificacion.
2. Parsear `-h`, `-c` y `-u` con `getopts`.
3. Validar `-u` si fue provisto, y rechazar argumentos posicionales o flags no soportados.
4. Resolver el directorio base de mail y descubrir `Maildir` bajo `/srv/mail/*/Maildir`, o un unico `Maildir` si se usa `-u`.
5. En modo no compacto, imprimir el nombre del usuario activo antes de recorrer su `Maildir`.
6. Recorrer cada `Maildir` con `find`, obteniendo el tamano de cada archivo regular en bytes.
7. Convertir cada tamano a MB enteros truncados con `bytes / 1048576`.
8. Clasificar el valor en uno de los 11 nichos.
9. Incrementar el contador del nicho y el total global.
10. Si no hubo archivos regulares, fallar como estructura vacia.
11. Si hubo error de lectura o recorrido, fallar como estructura corrupta.
12. Imprimir el resultado en formato normal o compacto.

## 3. Descubrimiento de Maildir

- El script usara `find` sobre el directorio base `/srv/mail` para localizar directorios con patron `*/Maildir` a profundidad fija.
- Si se recibe `-u <usuario>`, se omitira el descubrimiento global y se usara solo `/srv/mail/<usuario>/Maildir`.
- La implementacion verificara primero que el directorio base exista.
- El descubrimiento se hara sin depender de rutas arbitrarias provistas por el usuario.
- Para facilitar pruebas automatizadas, el codigo permitira un override interno del directorio base mediante `MAIL_ROOT_DIR`, pero no se documentara como interfaz de uso normal.
- El nombre visible del usuario se derivara del path del `Maildir` con expansion de parametros de Bash, sin comandos externos adicionales.

## 4. Clasificacion de Tamanos

- Cada tamano se recibe en bytes desde GNU `find -printf '%s'`.
- La conversion sera: `mail_size_mb = mail_size_bytes / 1048576`.
- La clasificacion sera:
  - `0<=x<10` -> nicho 1
  - `10<=x<20` -> nicho 2
  - ...
  - `90<=x<=100` -> nicho 10
  - `x>100` -> nicho 11
- Implementacion sugerida:
  - si `mail_size_mb > 100`, usar nicho 11
  - si `mail_size_mb == 100`, usar nicho 10
  - en los demas casos, usar `mail_size_mb / 10`

## 5. Formatos de Salida

- Modo normal:
  - `<usuario1>`
  - `<usuario2>`
  - ...
  - `0-10 -> N1`
  - `10-20 -> N2`
  - ...
  - `90-100 -> N10`
  - `+100 -> N11`
  - `TOTAL -> Nt`
- Modo compacto (`-c`): una sola linea con `N1 N2 ... N11 Nt`.
- Con `-u <usuario>` y sin `-c`, el bloque inicial de usuarios contiene solo ese usuario.
- `stdout` queda reservado para el resultado funcional.
- Los errores operativos se imprimen por `stderr` con mensajes breves en ingles.

## 6. Validaciones

- `-h` muestra ayuda y sale con `0`.
- `-c` habilita salida compacta.
- `-u` requiere un nombre de usuario simple (`[A-Za-z0-9._-]+`).
- Cualquier otro flag es invalido.
- Cualquier argumento posicional es invalido.
- El directorio base debe existir y ser accesible.
- Debe existir al menos un `Maildir` y al menos un archivo regular analizable.
- Si se usa `-u`, el `Maildir` objetivo debe existir y ser accesible.
- Si `find` falla durante el descubrimiento o el recorrido de archivos, la ejecucion se considera corrupta.

## 7. Riesgos y Mitigaciones

| Riesgo | Mitigacion |
|--------|------------|
| Ambiguedad en los limites de 10/20/100 MB | Fijar clasificacion sobre MB truncados con intervalos semiabiertos ya documentados. |
| Directorios vacios o sin archivos regulares | Tratarlo explicitamente como error de estructura vacia. |
| Fallo de lectura dentro de un Maildir | Detectar estado no exitoso de `find` y abortar con error claro. |
| Ruido que rompa automatizacion | Reservar `stdout` solo para el resultado y enviar errores a `stderr`. |
| Dependencias excesivas | Limitar el script productivo a Bash builtin mas GNU `find`. |

## 8. Compatibilidad

- Bash 4.2.46 o superior compatible.
- CentOS 7 con GNU `find`.
- Ejecucion local con permisos suficientes para leer `/srv/mail`.
