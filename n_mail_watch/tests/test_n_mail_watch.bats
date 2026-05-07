#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/n_mail_watch/scripts/n_mail_watch.sh"
    TEST_TMPDIR="$(mktemp -d)"
    MOCK_BIN="${TEST_TMPDIR}/bin"
    MAIL_CAPTURE_DIR="${TEST_TMPDIR}/mail_capture"
    CURRENT_DATE="$(date +%F)"
    OLD_DATE="2026-01-01"
    DEFAULT_RECIPIENTS="infraestructura@gigot.com.ar,cnavarro@gigot.com.ar"

    mkdir -p "${MOCK_BIN}" "${MAIL_CAPTURE_DIR}"

    cat <<'EOF' > "${MOCK_BIN}/sendmail"
#!/usr/bin/env bash
set -euo pipefail
output_file="$(mktemp "${SENDMAIL_CAPTURE_DIR}/mail.XXXXXX")"
cat > "${output_file}"
EOF
    chmod +x "${MOCK_BIN}/sendmail"

    cat <<EOF > "${TEST_TMPDIR}/main.log"
${CURRENT_DATE} 10:00:00 1abc <= ana@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=1
${CURRENT_DATE} 10:05:00 1abd <= ana@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=2
${CURRENT_DATE} 11:00:00 1abe <= beto@gigot.com.ar H=(host2) [10.0.0.2] P=esmtp S=100 id=3
${CURRENT_DATE} 11:05:00 1abx <= externo@example.com H=(host3) [10.0.0.3] P=esmtp S=100 id=4
${OLD_DATE} 09:00:00 1abf <= historico@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=5
EOF

    cat <<EOF > "${TEST_TMPDIR}/main.log-rotated"
${CURRENT_DATE} 12:00:00 1abg <= ana@gigot.com.ar H=(host1) [10.0.0.1] P=esmtp S=100 id=6
${CURRENT_DATE} 12:05:00 1abh <= cora@gigot.com.ar H=(host2) [10.0.0.2] P=esmtp S=100 id=7
${CURRENT_DATE} 12:10:00 1abi <= cora@gigot.com.ar H=(host2) [10.0.0.2] P=esmtp S=100 id=8
${OLD_DATE} 12:15:00 1abj <= historico@gigot.com.ar H=(host2) [10.0.0.2] P=esmtp S=100 id=9
EOF
}

teardown()
{
    rm -rf "${TEST_TMPDIR}"
}

count_captured_mails()
{
    find "${MAIL_CAPTURE_DIR}" -type f | wc -l | tr -d ' '
}

@test "Usa defaults y no envia mails si nadie supera el umbral" {
    run env PATH="${MOCK_BIN}:${PATH}" SENDMAIL_CAPTURE_DIR="${MAIL_CAPTURE_DIR}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        bash "${SCRIPT}" -y

    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Variables de Ejecución"* ]]
    [[ "${output}" != *"LOG_PATTERN      : main.log"* ]]
    [[ "${output}" == *"No se detectaron cuentas con mails enviados por encima del límite"* ]]
    [ "$(count_captured_mails)" -eq 0 ]
}

@test "Muestra variables de ejecucion cuando no se usa -y" {
    run bash -c 'printf "s\n" | PATH="$1:$PATH" SENDMAIL_CAPTURE_DIR="$2" EXIM_LOG_DIR="$3" "$4"' \
        bash "${MOCK_BIN}" "${MAIL_CAPTURE_DIR}" "${TEST_TMPDIR}" "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Variables de Ejecución"* ]]
    [[ "${output}" == *"LOG_PATTERN      : main.log"* ]]
    [[ "${output}" == *"THRESHOLD        : 100"* ]]
    [[ "${output}" == *"RECIPIENT        : ${DEFAULT_RECIPIENTS}"* ]]
}

@test "Cuenta solo mails enviados del dia actual y envia un mail al superar el umbral" {
    run env PATH="${MOCK_BIN}:${PATH}" SENDMAIL_CAPTURE_DIR="${MAIL_CAPTURE_DIR}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        bash "${SCRIPT}" -y -l 'main.log*' -t 3

    [ "${status}" -eq 0 ]
    [ "$(count_captured_mails)" -eq 1 ]

    captured_mail="$(find "${MAIL_CAPTURE_DIR}" -type f | head -n 1)"
    [ -f "${captured_mail}" ]
    mail_content="$(<"${captured_mail}")"

    [[ "${mail_content}" == *"From: mail_watch@gigot.com.ar"* ]]
    [[ "${mail_content}" == *"To: ${DEFAULT_RECIPIENTS}"* ]]
    [[ "${mail_content}" == *"Subject: Alerta n_mail_watch: mails enviados excedidos para ana@gigot.com.ar"* ]]
    [[ "${mail_content}" == *"Cuenta de mail: ana@gigot.com.ar"* ]]
    [[ "${mail_content}" == *"Fecha: ${CURRENT_DATE}"* ]]
    [[ "${mail_content}" == *"Mails enviados: 3"* ]]
    [[ "${mail_content}" != *"historico@gigot.com.ar"* ]]
    [[ "${mail_content}" != *"externo@example.com"* ]]
}

@test "Envia un mail por cada cuenta excedida" {
    run env PATH="${MOCK_BIN}:${PATH}" SENDMAIL_CAPTURE_DIR="${MAIL_CAPTURE_DIR}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        bash "${SCRIPT}" -y -l 'main.log*' -t 2

    [ "${status}" -eq 0 ]
    [ "$(count_captured_mails)" -eq 2 ]

    all_mail_content="$(find "${MAIL_CAPTURE_DIR}" -type f -print0 | xargs -0 cat)"
    [[ "${all_mail_content}" == *"From: mail_watch@gigot.com.ar"* ]]
    [[ "${all_mail_content}" == *"Subject: Alerta n_mail_watch: mails enviados excedidos para ana@gigot.com.ar"* ]]
    [[ "${all_mail_content}" == *"Subject: Alerta n_mail_watch: mails enviados excedidos para cora@gigot.com.ar"* ]]
    [[ "${all_mail_content}" == *"Cuenta de mail: ana@gigot.com.ar"* ]]
    [[ "${all_mail_content}" == *"Mails enviados: 3"* ]]
    [[ "${all_mail_content}" == *"Cuenta de mail: cora@gigot.com.ar"* ]]
    [[ "${all_mail_content}" == *"Mails enviados: 2"* ]]
}

@test "Reenvia alertas en corridas sucesivas si la cuenta sigue excedida" {
    run env PATH="${MOCK_BIN}:${PATH}" SENDMAIL_CAPTURE_DIR="${MAIL_CAPTURE_DIR}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        bash "${SCRIPT}" -y -l 'main.log*' -t 3

    [ "${status}" -eq 0 ]
    [ "$(count_captured_mails)" -eq 1 ]

    run env PATH="${MOCK_BIN}:${PATH}" SENDMAIL_CAPTURE_DIR="${MAIL_CAPTURE_DIR}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        bash "${SCRIPT}" -y -l 'main.log*' -t 3

    [ "${status}" -eq 0 ]
    [ "$(count_captured_mails)" -eq 2 ]
}

@test "Falla si el patron incluye rutas" {
    run env PATH="${MOCK_BIN}:${PATH}" SENDMAIL_CAPTURE_DIR="${MAIL_CAPTURE_DIR}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        bash "${SCRIPT}" -y -l ../main.log

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"sin rutas"* ]]
}

@test "Falla si no hay backend de correo disponible" {
    NO_MAIL_BIN="${TEST_TMPDIR}/no_mail_bin"
    mkdir -p "${NO_MAIL_BIN}"
    ln -s /usr/bin/awk "${NO_MAIL_BIN}/awk"
    ln -s /usr/bin/sort "${NO_MAIL_BIN}/sort"
    ln -s /usr/bin/date "${NO_MAIL_BIN}/date"
    ln -s /usr/bin/realpath "${NO_MAIL_BIN}/realpath"
    ln -s /usr/bin/dirname "${NO_MAIL_BIN}/dirname"

    run env PATH="${NO_MAIL_BIN}" EXIM_LOG_DIR="${TEST_TMPDIR}" \
        /bin/bash "${SCRIPT}" -y

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"backend de correo disponible"* ]]
}
