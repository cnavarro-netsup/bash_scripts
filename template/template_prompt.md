# Template de prompt para nuevo script Bash

Utiliza esta guía para describir un nuevo script antes de iniciar la fase Spec-First del repositorio.

## 1. Objetivo
- Nombre del script:
- Qué problema resuelve:
- Qué debe hacer exactamente:
- Qué NO debe hacer:

## 2. Entorno
- Sistema operativo objetivo: (ej. Ubuntu 24.04)
- Versión de Bash requerida: (salida de `bash --version`)
- ¿Debe ser Bash puro o POSIX-compatible?
- ¿Requiere root/sudo?
- ¿Depende de terminal interactiva?:

## 3. Entradas
- ¿Recibe argumentos?:
- Cantidad de argumentos:
- ¿Son posicionales o con flags?:
- Flags requeridos:
- Formato de flags: cortos, largos o mixtos:
- Tipos de dato aceptados:
- Reglas de validación:
- Valores inválidos que deben rechazarse:

## 4. Variables de entorno
- ¿Usa variables de entorno?:
- Defaults requeridos:
- ¿Deben mostrarse antes de ejecutar?:

## 5. Comportamiento
- Flujo principal del script:
- ¿Tiene operaciones destructivas?:
- ¿Requiere `--dry-run`?:
- ¿Requiere `-y` o `--yes`?:
- ¿Debe pedir confirmación interactiva?:

## 6. Salidas y logs
- ¿Qué se imprime en stdout?:
- ¿Qué se imprime en stderr?:
- ¿Debe usar `logger.sh`?:
- ¿Los logs van a consola, archivo o syslog?:
- Idioma de mensajes:

## 7. Integraciones y dependencias
- ¿Usa archivos locales?:
- ¿Usa red, SSH, API o SQLite?:
- Comandos externos permitidos:
- Comandos externos prohibidos:

## 8. Manejo de errores
- Casos de error esperados:
- Mensajes esperados:
- Códigos de salida esperados:

## 9. Criterios de aceptación
- AC-001:
- AC-002:
- AC-003:

## 10. Ejemplos
- Ejemplo válido 1:
- Ejemplo válido 2:
- Ejemplo inválido 1:
- Ejemplo inválido 2:

## Recomendaciones
- Si el script usa librerías compartidas, indicarlo explícitamente (`lib/logger.sh`, `lib/ssh_utils.sh`, `lib/sqlite_utils.sh`).
- Si hay ambigüedades de locale (fechas, separador decimal, timezone, encoding), definirlas antes de escribir `requirements.md`.
- Siempre que sea posible, incluir ejemplos reales de invocación y salida esperada.
