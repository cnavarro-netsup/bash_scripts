# Diseño — clean_sent_to_todos.sh

## 1. Arquitectura del Script

El script sigue el template estándar del repositorio con las siguientes secciones:

1. **Shebang + strict mode** (`set -euo pipefail`)
2. **Header estándar** con metadatos (nombre, versión, autor, modelo, fecha, descripción, uso, estado)
3. **Modo debug** (`set -x` si `DEBUG=TRUE`)
4. **Variables de color** (`R`, `G`, `Y`, `B`, `C`, `N`)
5. **Variables globales con defaults** (flags de ejecución, constantes de paths)
6. **Funciones base obligatorias**: `usage`, `confirm_or_exit`, `cleanup` (con `trap`)
7. **Funciones de validación**: `validate_args`, `validate_year`, `validate_dest_dir`, `validate_maildir`
8. **Función de procesamiento**: `process_maildir`
9. **Función principal**: `main` (parseo con `getopts` + orquestación)
10. **Invocación**: `main "$@"`

No se cargan librerías externas (`logger.sh`, `ssh_utils.sh`, `sqlite_utils.sh`) ya que el script
opera de forma autónoma sobre el sistema de archivos local. Los logs se emiten directamente
con `echo` hacia stdout/stderr usando las variables de color.

---

## 2. Variables Globales

```
# Flags de ejecución (seteados por getopts)
DEST_DIR=""          # -d: directorio destino (obligatorio)
FROM_USER=""         # -f: remitente (obligatorio)
YEAR=""              # -Y: año a analizar (obligatorio)
SINGLE_USER=""       # -u: usuario puntual (opcional)
DRY_RUN=FALSE         # -r: modo dry-run
ASSUME_YES=FALSE     # -y: asumir confirmación / modo silencioso

# Constantes
MAIL_BASE="/srv/mail"
MAILDIR_SUFFIX="Maildir"
ENVELOPE_TO="grp_todos@gigot.com.ar"

# Contadores
FILES_MATCHED=0
FILES_MOVED=0
FILES_FAILED=0
```

---

## 3. Funciones Propuestas

### 3.1 `usage()`

**Firma:** `usage()`
**Responsabilidad:** Imprime el bloque de ayuda en stdout y termina con exit 0 cuando se llama desde `-h`.
Muestra flags obligatorios, opcionales, ejemplos de uso y variables de entorno relevantes.

---

### 3.2 `confirm_or_exit()`

**Firma:** `confirm_or_exit()`
**Responsabilidad:** Muestra el prompt `¿Continuar? (s/N):` y lee la respuesta del operador.
Acepta `s`, `S`, `si`, `SI`, `Si`. Cualquier otra respuesta (incluyendo Enter vacío) imprime
mensaje de cancelación en rojo y termina con exit 1. Si `ASSUME_YES=TRUE`, retorna 0 sin preguntar.

---

### 3.3 `cleanup()`

**Firma:** `cleanup()`
**Responsabilidad:** Función de limpieza enlazada con `trap cleanup EXIT ERR INT TERM`.
En este script no hay archivos temporales, por lo que su rol principal es emitir un mensaje
de resumen final (archivos procesados, movidos, fallidos) si la ejecución fue interrumpida.

---

### 3.4 `validate_args()`

**Firma:** `validate_args()`
**Responsabilidad:** Verifica que los tres flags obligatorios (`DEST_DIR`, `FROM_USER`, `YEAR`)
estén presentes y no vacíos. Si falta alguno, imprime el flag faltante en stderr, llama a
`usage` y termina con exit 1.

---

### 3.5 `validate_year()`

**Firma:** `validate_year()`
**Responsabilidad:** Verifica que `YEAR` sea un entero de exactamente 4 dígitos en el rango
1970–2099. Usa una regex `^[0-9]{4}$` y luego compara el valor numérico. Si no es válido,
imprime error en stderr y termina con exit 1.

Pseudocódigo:
```
if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]]; then error; fi
if (( YEAR < 1970 || YEAR > 2099 )); then error; fi
```

---

### 3.6 `validate_dest_dir()`

**Firma:** `validate_dest_dir()`
**Responsabilidad:** Verifica que `DEST_DIR` exista como directorio (`-d`). Si no existe,
imprime error en stderr y termina con exit 1. No crea el directorio.

---

### 3.7 `validate_maildir()`

**Firma:** `validate_maildir(base_path)`
**Responsabilidad:** Recibe el path base del Maildir a analizar y verifica que exista como
directorio. Se usa cuando `-u` está presente para validar `/srv/mail/{usuario}/Maildir`.
Si no existe, imprime error en stderr y termina con exit 1.

---

### 3.8 `print_error_red()`

**Firma:** `print_error_red(message)`
**Responsabilidad:** Imprime en stderr una línea de error en color rojo para
que el motivo de rechazo resalte visualmente antes del bloque `usage`.

---

### 3.9 `print_match_info()`

**Firma:** `print_match_info(mail_file, date_value)`
**Responsabilidad:** Emite en stdout la ruta del archivo coincidente y el valor
del header `Date:` en una sola línea.

---

### 3.10 `process_maildir()`

**Firma:** `process_maildir(search_path)`
**Responsabilidad:** Función central. Recibe el path de búsqueda (glob o path específico),
ejecuta `find` con el filtro de año, itera sobre los resultados y para cada archivo:
 verifica headers, decide si mover o listar, emite la fecha del mail y actualiza contadores.
Retorna 1 si no se encontró ningún archivo coincidente (para que `main` pueda hacer exit 1).

---

## 4. Algoritmo Principal

### 4.1 Flujo de `main()`

```
1. Parsear argumentos con getopts (-d, -f, -Y, -u, -r, -y, -h)
2. Activar set -x si DEBUG=TRUE
3. Llamar validate_args()
4. Llamar validate_year()
5. Llamar validate_dest_dir()
6. Construir SEARCH_PATH:
   - Si SINGLE_USER está definido:
       SEARCH_PATH="/srv/mail/${SINGLE_USER}/Maildir"
       Llamar validate_maildir("$SEARCH_PATH")
   - Si no:
       SEARCH_PATH="/srv/mail"   # find recorrerá */Maildir recursivamente
7. Mostrar Variables de Ejecución (si ASSUME_YES != TRUE)
8. Llamar confirm_or_exit()
9. Llamar process_maildir("$SEARCH_PATH")
10. Si FILES_MATCHED == 0: error en stderr, exit 1
11. Imprimir resumen: archivos movidos / fallidos
12. exit 0
```

### 4.2 Flujo de `process_maildir(search_path)`

```
1. Construir el comando find:
   find "$search_path" \
       -type f \
       -newermt "${YEAR}-01-01" \
       -not -newermt "$((YEAR + 1))-01-01"

   Nota: cuando SINGLE_USER está vacío, search_path es /srv/mail y find
   recorre todos los subdirectorios. El filtro de Maildir se aplica
   implícitamente porque solo los paths bajo */Maildir contienen archivos
   de mail; sin embargo, para mayor precisión se puede usar el patrón
   -path "*/Maildir/*" en el find.

2. Leer la salida de find línea a línea (while IFS= read -r mail_file):

   a. Leer header From:
       from_header=$(grep -m 1 "^From:" "$mail_file" 2>/dev/null || true)
       Extraer el valor completo de From sin parseo RFC complejo.

   b. Leer header Return-path:
        return_path_header=$(grep -m 1 "^Return-path:" "$mail_file" 2>/dev/null || true)
        Extraer el valor completo para comparar contra `<${expected_from}>`.

   c. Leer header Envelope-to:
        env_header=$(grep -m 1 "^Envelope-to:" "$mail_file" 2>/dev/null || true)
        Extraer la dirección: env_addr=${env_header#Envelope-to: }

   d. Leer header Date:
        date_header=$(grep -m 1 "^Date:" "$mail_file" 2>/dev/null || true)
        date_value=${date_header#Date: }
        Si está ausente, usar `Date header ausente`.

   e. Si falta `Envelope-to:` o faltan a la vez `From:` y `Return-path:`:
        → Emitir advertencia en stderr: "[WARN] Headers ausentes: $mail_file"
        → continue (no abortar)

   f. Verificar coincidencia:
        expected_from="${FROM_USER}@gigot.com.ar"
        aceptar `From: ${expected_from}`
        aceptar `From: Nombre Visible <${expected_from}>`
        aceptar `Return-path: <${expected_from}>` como fallback
        cualquier otra forma → continue
        if [[ "$env_addr"  != "$ENVELOPE_TO"   ]]; then continue; fi

   g. Incrementar FILES_MATCHED

   h. Si DRY_RUN == TRUE:
       → print_match_info "$mail_file" "$date_value"  (stdout)
       → continue

   i. Modo real: ejecutar mv
       if mv "$mail_file" "$DEST_DIR/" 2>/dev/null; then
           print_match_info "$mail_file" "$date_value"   (stdout)
           (( FILES_MOVED++ ))
      else
          echo "[ERROR] No se pudo mover: $mail_file" >&2
          (( FILES_FAILED++ ))
          # continuar con el siguiente archivo
      fi

3. Retornar FILES_MATCHED para que main evalúe si hubo resultados
```

### 4.3 Construcción del `find` con filtro de año

El filtro de año usa exclusivamente `mtime` del archivo:

```bash
find "$search_path" \
    -path "*/Maildir/*" \
    ! -path "*/Maildir/.Sent/*" \
    ! -path "*/Maildir/.Template/*" \
    -type f \
    ! -name 'dovecot*' \
    -newermt "${YEAR}-01-01" \
    -not -newermt "$((YEAR + 1))-01-01"
```

**Decisión de diseño**: usar `-path "*/Maildir/*"` para restringir la búsqueda
a archivos dentro de subdirectorios Maildir, evitando procesar archivos de
configuración u otros archivos bajo `/srv/mail` que no sean mensajes de correo.
Además se excluyen `.Sent`, `.Template` y archivos `dovecot*` para reducir
ruido operativo y evitar falsos positivos.

**Nota sobre zona horaria**: `-newermt` interpreta la fecha en la zona horaria
local del servidor. Un archivo con `mtime` en el límite exacto de año puede
quedar incluido o excluido dependiendo del offset UTC del servidor. Este
comportamiento debe documentarse en el Readme.

---

## 5. Validaciones

| Validación | Función | Condición de error | Acción |
|---|---|---|---|
| Flag `-d` presente | `validate_args` | `DEST_DIR` vacío | stderr en rojo + usage + exit 1 |
| Flag `-f` presente | `validate_args` | `FROM_USER` vacío | stderr en rojo + usage + exit 1 |
| Flag `-Y` presente | `validate_args` | `YEAR` vacío | stderr en rojo + usage + exit 1 |
| Año 4 dígitos, 1970–2099 | `validate_year` | No cumple regex o rango | stderr + exit 1 |
| Directorio destino existe | `validate_dest_dir` | `! -d "$DEST_DIR"` | stderr + exit 1 |
| Maildir de usuario existe | `validate_maildir` | `! -d "$SEARCH_PATH"` (solo con `-u`) | stderr + exit 1 |
| Flag desconocido | `getopts \?)` | Opción no reconocida | stderr en rojo + usage + exit 1 |
| Argumento posicional extra | `main` post-getopts | `$# -gt 0` tras shift | stderr en rojo + usage + exit 1 |
| Sin archivos coincidentes | `main` | `FILES_MATCHED == 0` | stderr + exit 1 |

---

## 6. Manejo de Errores

### 6.1 Colisión de nombres en destino

Cuando `mv` falla porque ya existe un archivo con el mismo nombre en `DEST_DIR`,
el error se captura por el `else` del bloque `mv ... 2>/dev/null`. Se emite
`[ERROR] No se pudo mover: $mail_file` en stderr, se incrementa `FILES_FAILED`
y la ejecución continúa con el siguiente archivo. El script **no aborta**.

Al finalizar, si `FILES_FAILED > 0`, el resumen lo indica y el exit code es 0
(se procesaron archivos exitosamente). Si `FILES_MOVED == 0` y `FILES_FAILED > 0`,
el exit code es 1.

### 6.2 Headers ausentes o malformados

Si `grep` no encuentra `Envelope-to:` o no encuentra ni `From:` ni `Return-path:`,
el archivo se omite con una advertencia en stderr. La ejecución continúa.
Esto cubre archivos corruptos, archivos que no son mensajes de correo, o
mensajes con headers no estándar.

La ausencia del header `Date:` no excluye el archivo. En ese caso, la salida
usa el texto `Date header ausente`.

Si `From:` no coincide o no está presente, pero `Return-path:` coincide con
`<${expected_from}>`, el archivo se considera válido.

### 6.3 Estructura vacía / sin coincidencias

Si `find` no retorna ningún archivo (Maildir vacío, sin archivos en el año
indicado, o ningún archivo pasa el filtro de headers), `FILES_MATCHED` queda
en 0. `main` detecta esta condición, emite error en stderr y termina con exit 1.

### 6.4 Interrupción por señal

`trap cleanup EXIT ERR INT TERM` garantiza que si el script es interrumpido
(Ctrl+C, SIGTERM, error inesperado), se ejecuta `cleanup` que emite el estado
parcial de la ejecución (archivos procesados hasta ese momento).

### 6.5 Directorio destino igual al origen

No se implementa detección activa de este caso. Si `-d` apunta a un directorio
que ya contiene alguno de los archivos a mover, `mv` fallará con "mismo archivo"
y el error se manejará como colisión (6.1). Se documenta como comportamiento
no soportado en el Readme.

### 6.6 Caracteres especiales en `-f` o `-u`

Los valores de `FROM_USER` y `SINGLE_USER` se usan como literales en
comparaciones de strings (`[[ "$from_addr" == "$expected_from" ]]`) y en
construcción de paths. Se tratan como literales, no como expresiones regulares.
El `grep` usa `-F` (fixed string) si se necesita buscar el valor en el archivo,
o se compara la salida de `grep` con el valor esperado post-extracción.

---

## 7. Propiedades de Corrección

*Una propiedad es una característica o comportamiento que debe ser verdadero en todas las
ejecuciones válidas del sistema — esencialmente, un enunciado formal sobre lo que el sistema
debe hacer. Las propiedades sirven como puente entre especificaciones legibles por humanos
y garantías de corrección verificables automáticamente.*

### Propiedad 1: Modo real mueve exactamente los archivos coincidentes

*Para cualquier* conjunto de archivos de mail bajo un Maildir sintético, donde un subconjunto
cumple los criterios (mtime en el año indicado, `From:` igual a `{usuario}@gigot.com.ar` o
`Nombre Visible <{usuario}@gigot.com.ar>`, o `Return-path:` igual a `<{usuario}@gigot.com.ar>`,
`Envelope-to:` igual a `grp_todos@gigot.com.ar`), ejecutar el script en modo real debe
 resultar en que exactamente ese subconjunto fue movido al directorio destino y cada ruta
 apareció en stdout junto con la fecha del mail.

**Valida: AC-001**

---

### Propiedad 2: Dry-run no modifica el sistema de archivos

*Para cualquier* conjunto de archivos de mail coincidentes, ejecutar el script con `-r`
(dry-run) debe resultar en que ningún archivo fue movido de su ubicación original, y que
cada ruta del subconjunto coincidente apareció en stdout junto con la fecha del mail.

**Valida: AC-002**

---

### Propiedad 3: Flag `-u` restringe el procesamiento al usuario indicado

*Para cualquier* conjunto de Maildirs de múltiples usuarios donde solo algunos archivos
pertenecen al usuario indicado con `-u`, el script debe procesar únicamente los archivos
bajo `/srv/mail/{usuario}/Maildir` y no tocar los archivos de otros usuarios.

**Valida: AC-003**

---

### Propiedad 4: Flags obligatorios ausentes producen exit 1

*Para cualquier* invocación del script donde al menos uno de los flags `-d`, `-f`, `-Y`
esté ausente, el script debe terminar con exit 1 y emitir un mensaje de error en stderr.

**Valida: AC-004**

---

### Propiedad 5: Flags desconocidos producen exit 1

*Para cualquier* flag que no esté en el conjunto `{-d, -f, -Y, -u, -r, -y, -h}`, el script
debe terminar con exit 1 y emitir un mensaje de error en stderr.

**Valida: AC-006**

---

### Propiedad 6: Sin archivos coincidentes produce exit 1

*Para cualquier* invocación válida donde ningún archivo bajo el Maildir cumpla los tres
criterios (mtime en el año, From correcto, Envelope-to correcto), incluyendo el caso de
Maildir vacío, el script debe terminar con exit 1 y emitir un mensaje de error en stderr.

**Valida: AC-007, AC-009 (edge case)**

---

### Propiedad 7: Filtro de año por mtime es preciso

*Para cualquier* archivo de mail con `mtime` controlado en el año Y, ese archivo debe ser
incluido en el procesamiento con `-Y Y` e ignorado con `-Y (Y-1)` o `-Y (Y+1)`.

**Valida: AC-008**

---

### Propiedad 8: Validación de paths de precondición

*Para cualquier* path de directorio destino (`-d`) o Maildir de usuario (`-u`) que no exista
en el sistema de archivos en el momento de la ejecución, el script debe terminar con exit 1
y emitir un mensaje de error en stderr sin ejecutar ningún `mv`.

**Valida: AC-010, AC-011**

---

### Propiedad 9: Respuesta negativa a confirmación cancela sin mv

*Para cualquier* respuesta al prompt de confirmación que no sea `s`, `S`, `si`, `SI` o `Si`
(incluyendo Enter vacío, `N`, `n`, cualquier otro string), el script debe terminar con exit 1
sin haber ejecutado ningún `mv`.

**Valida: AC-012**

---

### Propiedad 10: Año inválido produce exit 1

*Para cualquier* valor de `-Y` que no sea un entero de exactamente 4 dígitos en el rango
1970–2099 (incluyendo strings no numéricos, años fuera de rango, strings vacíos), el script
debe terminar con exit 1 y emitir un mensaje de error en stderr.

**Valida: AC-013**

---

## 8. Manejo de Errores — Resumen de Códigos de Salida

| Condición | Exit code |
|---|---|
| Ejecución exitosa (al menos un archivo movido) | 0 |
| Dry-run exitoso (al menos un archivo listado) | 0 |
| Flag obligatorio ausente | 1 |
| Año inválido | 1 |
| Directorio destino inexistente | 1 |
| Maildir de usuario inexistente (con `-u`) | 1 |
| Flag desconocido o argumento posicional extra | 1 |
| Sin archivos coincidentes | 1 |
| Cancelación por el operador | 1 |
| Flag `-h` (help) | 0 |

---

## 9. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|---|---|
| Filtro de año incorrecto por zona horaria | Documentar que `-newermt` usa la TZ local del servidor. El operador debe conocer el offset UTC del sistema. |
| Colisión de nombres en destino | `mv` falla por archivo; el script continúa y reporta el fallo en stderr. No se aborta la ejecución completa. |
| Archivos sin headers válidos procesados incorrectamente | `grep -m 1` con `\|\| true` evita que el script aborte por `set -e`. La comparación posterior descarta el archivo. |
| Inyección de comandos vía `-f` o `-u` | Los valores se usan como literales en comparaciones de strings y construcción de paths entre comillas dobles. No se pasan a `eval` ni a expansiones sin comillas. |
| `find` con glob `*/Maildir/*` en sistema con muchos usuarios | El rendimiento es lineal en el número de archivos. No hay mitigación especial; el operador puede usar `-u` para restringir el alcance. |
| `mv` mueve a destino que es el mismo directorio origen | `mv` falla con "mismo archivo"; se trata como colisión (ver arriba). Documentado como no soportado. |
| Interrupción durante `mv` (Ctrl+C entre archivos) | `trap cleanup EXIT ERR INT TERM` emite el estado parcial. Los archivos ya movidos no se revierten (no hay rollback). |
| Archivos con nombres que contienen espacios o caracteres especiales | `find` con `-print0` y `while IFS= read -r -d ''` garantiza el manejo correcto de nombres arbitrarios. |

---

## 10. Compatibilidad

| Componente | Versión / Restricción |
|---|---|
| Bash | 4.2.46 (CentOS 7). Se usan solo construcciones compatibles: `[[ ]]`, `(( ))`, arrays simples, `getopts`. No se usa `mapfile`/`readarray` con `-d` (requiere Bash 4.4+). |
| `find` | GNU find (CentOS 7). `-newermt` es una extensión GNU, disponible en findutils ≥ 4.3. CentOS 7 incluye findutils 4.5.11. |
| `grep` | GNU grep. Se usa `-m 1` (primera coincidencia) para leer `From:`, `Return-path:`, `Envelope-to:` y `Date:`. |
| `mv` | GNU coreutils. Comportamiento estándar POSIX. |
| `set -euo pipefail` | Compatible con Bash 4.2.46. |
| Zona horaria | El script opera en la TZ del sistema. No modifica `TZ`. |

---

## 11. Estrategia de Testing

### 11.1 Enfoque dual

Se implementan dos tipos de tests complementarios:

- **Tests de ejemplo (BATS)**: verifican comportamientos concretos, casos de error
  y condiciones de borde con fixtures controlados.
- **Tests de propiedad (BATS + generación aleatoria)**: verifican que las propiedades
  de corrección se mantienen para un amplio rango de inputs generados.

### 11.2 Tests de ejemplo (BATS)

Archivo: `tests/test_clean_sent_to_todos.bats`

Casos a cubrir:
- AC-005: `-h` imprime help y sale con exit 0
- AC-004: cada combinación de flag obligatorio ausente produce exit 1
- AC-010: directorio destino inexistente produce exit 1
- AC-011: Maildir de usuario inexistente produce exit 1
- AC-013: valores de año inválidos específicos (`abc`, `1800`, `2100`, `99`, ``)
- AC-014: `-y` omite confirmación interactiva y el bloque de variables
- AC-015: `.Sent`, `.Template` y `dovecot*` quedan fuera del análisis
- AC-016: `Return-path:` permite validar el remitente cuando `From:` no sirve
- Colisión de nombres: un archivo ya existe en destino → error en stderr, continúa
- Headers ausentes: archivo sin `Envelope-to:` o sin `From:` y `Return-path:` → ignorado, ejecución continúa

### 11.3 Tests de propiedad (BATS)

Cada propiedad del diseño se implementa como un test BATS que genera fixtures
aleatorios y verifica la propiedad. Mínimo 100 iteraciones por propiedad.

Cada test debe incluir un comentario de trazabilidad:
```
# Feature: clean-sent-to-todos, Propiedad N: <texto de la propiedad>
```

| Propiedad | Estrategia de generación |
|---|---|
| P1: Modo real mueve coincidentes | Generar N archivos con mtime controlado, M con headers correctos; verificar que exactamente M fueron movidos y que la salida incluye `Date:` |
| P2: Dry-run no modifica FS | Igual que P1 pero con `-r`; verificar que ningún archivo fue movido |
| P3: `-u` restringe al usuario | Generar Maildirs para K usuarios; verificar que solo se procesó el indicado |
| P6: Sin coincidentes → exit 1 | Generar archivos que no cumplan algún criterio; verificar exit 1 |
| P7: Filtro de año por mtime | Crear archivo con `touch -t`; verificar inclusión/exclusión según `-Y` |
| P11: `-y` asume confirmación | Ejecutar modo real y dry-run con `-y`; verificar ausencia de prompt y del bloque de variables |
| P8: Paths inexistentes → exit 1 | Generar paths aleatorios inexistentes; verificar exit 1 |
| P9: Respuesta negativa cancela | Simular respuesta con `echo "N" \| script`; verificar exit 1 y sin mv |
| P10: Año inválido → exit 1 | Generar strings aleatorios no numéricos y números fuera de rango; verificar exit 1 |

### 11.4 Fixtures de test

Los tests crean un Maildir sintético bajo `$BATS_TMPDIR` con la estructura:
```
$BATS_TMPDIR/
  srv/mail/
    usuario1/Maildir/cur/
    usuario1/Maildir/new/
    usuario2/Maildir/cur/
  destino/
```

Los archivos de mail sintéticos tienen el formato mínimo:
```
From: remitente@gigot.com.ar
Return-path: <remitente@gigot.com.ar>
Envelope-to: grp_todos@gigot.com.ar
Date: Tue, 11 Jun 2024 12:00:00 -0300
Subject: Test

Cuerpo del mensaje.
```

El `mtime` se controla con `touch -t YYYYMMDDHHSS archivo`.
