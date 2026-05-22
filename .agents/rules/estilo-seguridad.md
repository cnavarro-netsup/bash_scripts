---
trigger: always_on
---

# Coding Rules for Infrastructure Scripts

Estas reglas definen el estilo y comportamiento que el agente debe seguir
al generar o modificar código en este repositorio.

El agente debe cumplir estas reglas en todas las implementaciones.

---

# Language

El lenguaje principal del repositorio es:

Bash (POSIX compatible cuando sea posible)

---

# Bash Coding Style

## Strict Mode

Todos los scripts deben comenzar con:

set -euo pipefail

---

## Header

Todos los scripts deben tener el siguiente header (luego de set -euo pipefail)


#------+---------+---------+---------+---------+---------+---------+---------+
# NOMBRE: <nombre del script>
# VERSION: x.x.x
# AUTOR: CPN
# MODELO: <Nombre del Modelo AI>
# FECHA: <fecha>
# DESCRIPCION: <breve descripción del propósito>
# ...
#
# REQUERIMIENTOS: <los permisos necesarios en la estructura de ejecución>
# USO: <descripción del uso>
# ESTADO: <desarrollo | producción>
#------+---------+---------+---------+---------+---------+---------+---------+

---

## Function Style

Las funciones deben declararse exactamente con este formato:

function_name()
{
    comandos
}

Ejemplo correcto:

check_directory()
{
    local dir="$1"

    if [ ! -d "$dir" ]; then
        echo "Directory not found"
        return 1
    fi
}

Formato incorrecto (NO usar):

check_directory {
    ...
}

o

function check_directory() {
    ...
}

La llave de apertura debe estar en línea separada.

Las funciones deben estar separadas por:
#--------------------------------------

Cada función debe incluir una breve descripción inmediatamente encima.
La descripción debe resumir su responsabilidad en una sola línea clara,
sin repetir literalmente el nombre de la función ni agregar comentarios obvios.

---

## Indentation

- 4 espacios
- No usar tabs

---

## Variables

Las variables deben ser:

snake_case

Ejemplo:

backup_directory
log_file
target_date

---

# Safety Rules (Infrastructure)

Para scripts que interactúan con el sistema:

1. Validar todos los paths antes de usarlos
2. Usar realpath cuando sea posible
3. Evitar eliminar archivos fuera de directorios permitidos

---

# Destructive Operations

Para operaciones destructivas:

- Siempre implementar flag `--dry-run`
- Requerir confirmación explícita
- Mostrar los archivos afectados antes de ejecutar

Ejemplo:

--dry-run
--yes

---

# Logging

Los scripts deben producir logs claros.

Formato recomendado:

[INFO]
[WARN]
[ERROR]

---

# Script Structure

Un script típico debe tener:

1. Header
2. Configuración
3. Funciones
4. Main

Ejemplo:

#!/usr/bin/env bash

set -euo pipefail

# configuration

# functions

main()
{
    ...
}

main "$@"

---

DEBE EXISTIR UNA OPCIÓN DE EJECUCIÓN EN MODE DEBUG:
if [ "${DEBUG:-FALSE}" = "TRUE" ]; then
    set -x
else
    set +x
fi

---

SE DEBEN DEFINIR VARIABLES LOCALES PARA COLORES:
R="\033[0;31m"  # Color rojo
G="\033[0;32m"  # Color verde
Y="\033[0;33m"  # Color amarillo
B="\033[0;34m"  # Color azul
C="\033[0;36m"  # Color cian
N="\033[0m"     # Color normal (sin color)

---

SI HAY VARIABLES DE ENTORNO DEFINIDAS, LOS DEFAULT
DEBEN ESPECIFICARSE DE LA SIGUIENTE MANERA:
: ${DEBUG:=FALSE}
: ${DB="/var/log/mail_uso.db"}
: ${MODE="column"}
: ${LIMIT=30}
: ${ORDER="DESC"}
: ${MAX=30}

---

SE DEBEN MOSTRAR LAS VARIABLES DE EJECUCIÓN SOLO CUANDO `ASSUME_YES` NO ESTÁ EN `TRUE`.
SI EL SCRIPT SE EJECUTA CON `-y` / `ASSUME_YES=TRUE`, DEBE OPERAR EN MODO SILENCIOSO
Y NO IMPRIMIR EL BLOQUE "Variables de Ejecución".

(DONDE $G SETEA EL COLOR VERDE Y $N LO RESETEA)
if [ "${ASSUME_YES:-FALSE}" != "TRUE" ]; then
    echo -e "$G Variables de Ejecución $N"
    echo "DB        : $DB"
    echo "MODE      : $MODE"
    echo "LIMIT     : $LIMIT"
    echo "ORDER     : $ORDER"
    echo "MAX       : $MAX"
fi

A CONTINUACIÓN SE DEBE USAR LA FUNCIÓN confirm_or_exit PARA CONFIRMAR O ABORTAR LA EJECUCIÓN:
($R SETEA COLOR ROJO)
confirm_or_exit()
{
    # Si está activado asume-yes, saltamos la confirmación
    if [ "${ASSUME_YES:-FALSE}" = "TRUE" ]; then
        return 0
    fi

    local confirm
    read -r -p "¿Continuar? (s/N): " confirm
    case "${confirm:-}" in
        s|S|si|SI|Si) return 0 ;;
        *) echo -e "$R ✖ Cancelado por el usuario. $N"; exit 1 ;;
    esac
}
 ---

SI ES NECESARIO DEBE HABER UNA FUNCIÓN DE CLEAN-UP.
Se aconseja enlazarla usando `trap` para que se ejecute siempre que el script finalice:
trap cleanup EXIT ERR INT TERM

---

DEBE HABER UNA FUNCIÓN HELP, SIMILAR A ESTE EJEMPLO:
usage()
{
    cat <<EOF
Uso:
  cp_vm.sh -v nombre_vm [-t SNAP|LV] [opciones]

Obligatorios:
  -v  Nombre de la VM

Opciones:
  -t  Tipo de backup: SNAP o LV (default: $TIPO_DEFAULT)
  -m  Archivo de mapeo VM->Hypervisor (default: $MAP_FILE_DEFAULT)
  -b  Directorio de backups (default: $BK_DIR_DEFAULT)
  -g  Nombre del VG (default: $VG_NAME_DEFAULT)
  -s  Nombre del snapshot LVM (default: $SNAP_NAME_DEFAULT)
  -d  Debug (activa trazas de log extra)
  -y, --yes      Asumir "sí" a las interacciones y ejecutar en modo silencioso (batch/cron)
  -D, --dry-run  Mostrar lo que se ejecutaría sin hacer cambios destructivos
  -h, --help     Mostrar esta ayuda

Ejemplos:
  ./cp_vm.sh -v webserver01
  ./cp_vm.sh -v webserver01 -t LV -b /mnt/backups --dry-run
EOF
}

---

EL PARSEO DE ARGUMENTOS DEBE SER REALIZADO CON EL COMANDO getopts COMO INDICA ESTE EJEMPLO:
    while getopts ":df:l:n:i:yh" opt
    do
        case "$opt" in
            d) DEBUG=TRUE ;;
            f) FILTER="$OPTARG" ;;
            l) LIMIT="$OPTARG" ;;
            n) NUMBER="$OPTARG" ;;
            i) IP="$OPTARG" ;;
            y) ASSUME_YES=TRUE ;;
            h) usage; exit 0 ;;
            :)
                echo "Error: -$OPTARG requiere un argumento." >&2
                usage
                exit 2
                ;;
            \?)
                echo "Error: opción inválida -$OPTARG" >&2
                usage
                exit 2
                ;;
        esac
    done
    shift $((OPTIND - 1))

NOTA SOBRE OPCIONES LARGAS:
El comando interno \`getopts\` de Bash **solo soporta opciones cortas**.
Las banderas en formato largo (como \`--dry-run\` o \`--yes\`) sugeridas en secciones anteriores NO podrán ser analizadas con este método. Para utilizarlas, se deberá optar por un `while [[ "\$#" -gt 0 ]]` con un `case` propio en lugar de \`getopts\`.

---

# Agent Behavior

El agente debe:

- respetar este estilo en todo el código generado incluso la documentación de los bloques: CONFIGURACION, FUNCIONES, MAIN
- refactorizar código existente para cumplir estas reglas
- no introducir estilos alternativos
