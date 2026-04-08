# Requerimientos — n_mail_watch.sh

## 1. Descripción del Problema

Se requiere un script Bash que lea logs de Exim en un servidor Linux y detecte
cuántos correos envió cada cuenta durante el día actual. El objetivo es contar
envíos diarios por usuario y emitir una alerta por mail cuando una cuenta iguale
o supere un umbral configurable en la corrida.

El nuevo proyecto debe seguir la estructura y el comportamiento general de
`auth_watch`, pero reemplazando la detección de autenticaciones por la lógica de
detección de mails enviados utilizada en `cantidad_mail_enviados`.

Cuando una cuenta iguale o supere el umbral configurado durante el día actual,
el script debe enviar un aviso por correo electrónico a
`infraestructura@gigot.com.ar`, `cnavarro@gigot.com.ar`,
`sagrelo@gigot.com.ar` y `mloubet@gigot.com.ar`.

---

## 2. Alcance

- Leer uno o más logs de Exim desde `EXIM_LOG_DIR` mediante un patrón simple.
- Detectar correos enviados usando el mismo criterio de `cantidad_mail_enviados`.
- Considerar únicamente eventos correspondientes al día actual del servidor.
- Agrupar el conteo por `fecha + cuenta`.
- Comparar cada cuenta contra un umbral configurable.
- Enviar un mail por cada cuenta que alcance o supere el umbral en la corrida.
- Permitir ejecución no interactiva desde cron con `-y`.
- Registrar variables de ejecución y resultados operativos de forma clara.

---

## 3. Supuestos

- El servidor dispone de Bash 4.x o superior.
- Exim registra la fecha en el primer campo de cada línea con formato
  `YYYY-MM-DD`.
- La detección de correo enviado debe seguir el patrón usado en
  `cantidad_mail_enviados`: líneas que contengan `<=` y una cuenta emisora con
  formato `usuario@gigot.com.ar`.
- El host dispone de `sendmail` y opcionalmente de `mailx` como fallback.
- El cron puede ejecutar el script varias veces por día y la alerta puede
  repetirse en cada corrida si la cuenta sigue excedida.

---

## 4. Restricciones

| # | Restricción |
|---|-------------|
| R-01 | El script solo debe contar mails enviados del día actual. |
| R-02 | El patrón de log no puede aceptar rutas arbitrarias ni caracteres inseguros. |
| R-03 | El umbral default debe ser `100`. |
| R-04 | Los destinatarios default son `infraestructura@gigot.com.ar`, `cnavarro@gigot.com.ar`, `sagrelo@gigot.com.ar` y `mloubet@gigot.com.ar`. |
| R-05 | El script debe repetir el aviso en cada corrida donde la cuenta siga excedida. |
| R-06 | Debe enviar un mail por cuenta excedida, no un resumen consolidado. |
| R-07 | Debe reutilizar la estructura de proyecto y estilo de `auth_watch`. |
| R-08 | Debe respetar el estilo definido en `.agents/rules/estilo-seguridad.md`. |

---

## 5. Criterios de Aceptación

| ID | Descripción | Resultado esperado |
|----|-------------|-------------------|
| AC-001 | Ejecución sin `-l` | Usa `main.log` como patrón por default |
| AC-002 | Ejecución sin `-t` | Usa `100` como umbral por default |
| AC-003 | Ejecución sin `-r` | Usa la lista default de destinatarios configurada |
| AC-004 | Procesamiento de logs con fechas múltiples | Solo cuenta líneas de la fecha actual del sistema |
| AC-005 | Detección de mails enviados | Cuenta solo líneas que sigan la misma regla de `cantidad_mail_enviados` |
| AC-006 | Cuenta bajo el umbral | No envía ningún mail y finaliza con código 0 |
| AC-007 | Cuenta igual o superior al umbral | Envía un mail por cada cuenta excedida |
| AC-008 | Múltiples cuentas excedidas | Envía múltiples mails, uno por cuenta |
| AC-009 | Corridas sucesivas con la misma cuenta excedida | Reenvía el aviso en cada corrida |
| AC-010 | Contenido del mail | Incluye cantidad de mails enviados, fecha y cuenta de mail |
| AC-011 | Patrón inválido o sin coincidencias | Falla con mensaje claro y código distinto de cero |
| AC-012 | Backend de correo no disponible | Falla con mensaje claro y código distinto de cero |
| AC-013 | Ejecución en cron con `-y` | No solicita confirmación interactiva |
| AC-014 | El proyecto incluye tests Bats y pasa `shellcheck` |

---

## 6. Ambigüedades y Edge Cases

- Se asume que “seguir la misma acción que `cantidad_mail_enviados`” implica
  contar únicamente líneas con `<=` y remitentes `@gigot.com.ar`, no cualquier
  remitente externo.
- Los logs resueltos pueden contener eventos históricos y actuales mezclados.
- El patrón puede expandir varios archivos rotados del mismo día y días
  anteriores.
- Existen líneas de entrega `=>` u otros eventos de Exim que deben ignorarse.
- El directorio de logs puede no existir, no ser legible o resolver matches que
  no sean archivos regulares.
- El umbral recibido puede no ser entero positivo.
- El host puede no tener `sendmail` ni `mailx` instalados.
- La lista de destinatarios puede contener valores vacíos o mails inválidos.
