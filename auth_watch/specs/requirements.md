# Requerimientos — auth_watch.sh

## 1. Descripción del Problema

Se requiere un script Bash que lea logs de Exim en un servidor Linux CentOS
7.7.1908 y detecte cuentas de correo que hayan alcanzado o superado un límite
diario de autenticaciones SMTP. El objetivo es advertir posibles compromisos de
cuentas existentes cuando una casilla presenta un volumen anormal de logins.

Cuando una cuenta iguale o supere el umbral configurado durante el día actual,
el script debe enviar un aviso por correo electrónico a
`infraestructura@gigot.com.ar`, `cnavarro@gigot.com.ar`,
`sagrelo@gigot.com.ar` y `mloubet@gigot.com.ar`.

---

## 2. Alcance

- Leer uno o más logs de Exim desde `EXIM_LOG_DIR` mediante un patrón simple.
- Contar autenticaciones detectadas con el token `A=login:<cuenta>`.
- Considerar únicamente eventos correspondientes al día actual del servidor.
- Agrupar el conteo por `fecha + cuenta`.
- Comparar cada cuenta contra un umbral configurable.
- Enviar un mail por cada cuenta que alcance o supere el umbral en la corrida.
- Permitir ejecución no interactiva desde cron.
- Registrar variables de ejecución y resultados operativos de forma clara.

---

## 3. Supuestos

- El servidor dispone de Bash 4.x o superior.
- Exim registra la fecha en el primer campo de cada línea con formato
  `YYYY-MM-DD`.
- La autenticación se identifica por un token independiente con formato
  `A=login:<cuenta>`.
- El host dispone de `sendmail` y opcionalmente de `mailx` como fallback.
- El cron ejecutará el script tres veces por día.

---

## 4. Restricciones

| # | Restricción |
|---|-------------|
| R-01 | El script solo debe contar autenticaciones del día actual. |
| R-02 | El patrón de log no puede aceptar rutas arbitrarias ni caracteres inseguros. |
| R-03 | El límite por default es `100`. |
| R-04 | Los destinatarios por default son `infraestructura@gigot.com.ar`, `cnavarro@gigot.com.ar`, `sagrelo@gigot.com.ar` y `mloubet@gigot.com.ar`. |
| R-05 | El script debe repetir el aviso en cada corrida donde la cuenta siga excedida. |
| R-06 | Debe enviar un mail por cuenta excedida, no un resumen consolidado. |
| R-07 | El script debe respetar el estilo definido en `.agents/rules/estilo-seguridad.md`. |

---

## 5. Criterios de Aceptación

| ID | Descripción | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Ejecución sin `-l` | Usa `main.log` como patrón por default |
| AC-002 | Ejecución sin `-t` | Usa `100` como umbral por default |
| AC-003 | Ejecución sin `-r` | Usa la lista default de destinatarios configurada |
| AC-004 | Procesamiento de logs con fechas múltiples | Solo cuenta líneas de la fecha actual del sistema |
| AC-005 | Detección de autenticaciones | Cuenta solo tokens `A=login:<cuenta>` |
| AC-006 | Cuenta bajo el umbral | No envía ningún mail y finaliza con código 0 |
| AC-007 | Cuenta igual o superior al umbral | Envía un mail por cada cuenta excedida |
| AC-008 | Múltiples cuentas excedidas | Envía múltiples mails, uno por cuenta |
| AC-009 | Corridas sucesivas con la misma cuenta excedida | Reenvía el aviso en cada corrida |
| AC-010 | Contenido del mail | Incluye cantidad de autenticaciones, fecha y cuenta de mail |
| AC-011 | Patrón inválido o sin coincidencias | Falla con mensaje claro y código distinto de cero |
| AC-012 | Backend de correo no disponible | Falla con mensaje claro y código distinto de cero |
| AC-013 | Ejecución en cron con `-y` | No solicita confirmación interactiva |
| AC-014 | El proyecto incluye tests Bats y pasa `shellcheck` |

---

## 6. Edge Cases identificados

- Los logs resueltos contienen autenticaciones históricas y actuales mezcladas.
- El patrón expande varios archivos rotados del mismo día y días anteriores.
- Existen líneas sin autenticación o con tokens `P=local` que deben ignorarse.
- La cuenta autenticada contiene caracteres válidos de correo (`.`, `_`, `-`).
- El directorio de logs no existe, no es legible o un match no es archivo regular.
- El umbral recibido no es entero positivo.
- El host no tiene `sendmail` ni `mailx` instalados.
- La lista de destinatarios contiene valores vacíos o mails inválidos.
