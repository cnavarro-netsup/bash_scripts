# Requerimientos - mail_size_analyzer.sh

## 1. Descripcion del Problema

- Se requiere un script Bash que analice los mails almacenados en un sistema de correo local con Exim y calcule su distribucion por tamano.
- El script debe recorrer los `Maildir` ubicados bajo `/srv/mail/*/Maildir`, medir cada mail en bytes, convertir ese tamano a MB enteros mediante division truncada y clasificar cada resultado en uno de 11 nichos.
- Al finalizar debe informar los 11 contadores de nicho y la cantidad total de mails analizados.

## 2. Alcance

- Aceptar solo los flags `-h`, `-c` y `-u`.
- Rechazar cualquier otro flag o cualquier argumento posicional.
- Descubrir los `Maildir` de usuarios bajo `/srv/mail/*/Maildir`.
- Permitir analizar un unico usuario cuando se use `-u <usuario>`.
- Recorrer archivos regulares dentro de cada `Maildir`.
- Obtener el tamano de cada archivo en bytes.
- Convertir cada tamano a MB enteros con division truncada (`bytes / 1048576`).
- Clasificar cada mail en los intervalos semiabiertos `0<=x<10`, `10<=x<20`, ..., `90<=x<=100`, `x>100`.
- Mostrar los 11 nichos y el total al final de la ejecucion.
- Mostrar cada usuario analizado, uno por linea, durante la ejecucion cuando no se use `-c`.
- Mostrar la salida compacta en una sola linea cuando se use `-c`.
- Imprimir los errores por `stderr` y finalizar con `1` ante fallas.

## 3. Supuestos

- El sistema objetivo es CentOS 7 con Bash 4.2.46.
- El script se ejecuta localmente y con privilegios suficientes para leer `/srv/mail`.
- La implementacion debe seguir Bash compatible cuando sea posible, sin recurrir a Python u otros lenguajes.
- El script productivo solo puede depender de `find` y `ls` como comandos externos de lectura del sistema de archivos.
- GNU `find` esta disponible y soporta `-printf`, como es habitual en CentOS 7.
- No se usara `logger.sh` en este proyecto por requerimiento explicito de la especificacion.

## 4. Restricciones

| # | Restriccion |
|---|-------------|
| R-01 | El script acepta solo `-h`, `-c` y `-u <usuario>`. |
| R-02 | No se aceptan argumentos posicionales. |
| R-03 | `-u` debe recibir un nombre de usuario simple y sin `/`. |
| R-04 | La clasificacion debe usar bytes convertidos a MB enteros con division truncada. |
| R-05 | Los nichos son exactamente 11: `0-10`, `10-20`, ..., `90-100`, `+100`. |
| R-06 | Los intervalos de clasificacion son `0<=x<10`, `10<=x<20`, ..., `90<=x<=100`, `x>100`. |
| R-07 | La salida normal debe mostrar primero los usuarios analizados, uno por linea, y luego terminar con `TOTAL -> Nt`. |
| R-08 | La salida con `-c` debe devolver solo numeros en una sola linea: `N1 N2 ... N11 Nt`. |
| R-09 | Con `-c` no se deben mostrar usuarios durante la ejecucion. |
| R-10 | El script no debe usar variables de entorno como interfaz operativa documentada. |
| R-11 | El script no debe usar `logger.sh`, ni `ssh`, ni APIs, ni persistencia en archivos o DB. |
| R-12 | El script no realiza operaciones destructivas; por lo tanto no debe implementar `--dry-run` ni confirmacion interactiva. |
| R-13 | Los errores deben imprimirse por `stderr` en ingles y finalizar con exit `1`. |

## 5. Criterios de Aceptacion

| ID | Descripcion | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Invocar `./scripts/mail_size_analyzer.sh -h` | Muestra la ayuda y finaliza con exit `0`. |
| AC-002 | Invocar `./scripts/mail_size_analyzer.sh` con multiples usuarios | Imprime cada usuario analizado en una linea, luego 11 lineas de nichos mas `TOTAL -> Nt`, y finaliza con exit `0`. |
| AC-003 | Invocar `./scripts/mail_size_analyzer.sh -c` | Imprime una sola linea con `N1 N2 ... N11 Nt` y finaliza con exit `0`, sin mostrar usuarios. |
| AC-004 | Invocar `./scripts/mail_size_analyzer.sh -u cnavarro` | Analiza solo `/srv/mail/cnavarro/Maildir`, imprime `cnavarro` en una linea, luego el resumen y finaliza con exit `0`. |
| AC-005 | Invocar `./scripts/mail_size_analyzer.sh -u cnavarro -c` | Analiza solo `cnavarro`, imprime una sola linea compacta y no muestra usuarios. |
| AC-006 | Clasificacion con valores en limites | Ubica cada mail segun `0<=x<10`, `10<=x<20`, ..., `90<=x<=100`, `x>100`. |
| AC-007 | Estructura sin archivos regulares analizables | Informa error por `stderr` y finaliza con exit `1`. |
| AC-008 | Estructura con fallo de lectura o analisis | Informa error por `stderr` y finaliza con exit `1`. |
| AC-009 | Flag invalido, argumento posicional o `-u` invalido | Informa error por `stderr` y finaliza con exit `1`. |
| AC-010 | Usuario indicado inexistente | Informa error por `stderr` y finaliza con exit `1`. |
| AC-011 | El proyecto incluye pruebas Bats y pasa `shellcheck` | La validacion comun del repositorio finaliza sin errores. |

## 6. Edge Cases identificados

- Maildirs presentes pero vacios.
- Archivos de tamano `0` bytes, que deben caer en el nicho `0-10`.
- Archivos exactamente en los limites de 10, 20, ..., 100 MB luego de la division truncada.
- Archivos mayores a 100 MB que deben acumularse solo en `+100`.
- Multiples usuarios con uno o varios `Maildir` validos bajo `/srv/mail`.
- Uso de `-u` con un usuario valido que no tenga `Maildir`.
- Uso de `-u` con caracteres inseguros o rutas.
- Entradas no legibles o errores de `find` durante el recorrido.
- Nombres de archivo con espacios, que no deben romper el analisis.
