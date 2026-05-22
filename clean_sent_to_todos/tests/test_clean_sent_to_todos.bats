#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    ORIGINAL_SCRIPT="${PROJECT_ROOT}/clean_sent_to_todos/scripts/clean_sent_to_todos.sh"

    TEST_ROOT="$(mktemp -d)"
    TEST_MAIL_BASE="${TEST_ROOT}/srv/mail"
    TEST_DEST_DIR="${TEST_ROOT}/dest"
    TEST_SCRIPT="${TEST_ROOT}/clean_sent_to_todos.sh"

    mkdir -p "${TEST_MAIL_BASE}" "${TEST_DEST_DIR}"

    while IFS= read -r line; do
        if [ "${line}" = 'readonly MAIL_BASE="/srv/mail"' ]; then
            printf 'readonly MAIL_BASE="%s"\n' "${TEST_MAIL_BASE}"
            continue
        fi

        printf '%s\n' "${line}"
    done < "${ORIGINAL_SCRIPT}" > "${TEST_SCRIPT}"

    chmod +x "${TEST_SCRIPT}"
}

teardown()
{
    chmod -R u+rwx "${TEST_ROOT}" 2>/dev/null || true
    rm -rf "${TEST_ROOT}"
}

create_mail_file()
{
    local user_name="$1"
    local subdir_name="$2"
    local file_name="$3"
    local from_addr="$4"
    local envelope_to="$5"
    local touch_timestamp="$6"
    local date_header_value="${7:-Tue, 11 Jun 2024 12:00:00 -0300}"
    local target_dir="${TEST_MAIL_BASE}/${user_name}/Maildir/${subdir_name}"
    local mail_path="${target_dir}/${file_name}"

    mkdir -p "${target_dir}"

    cat > "${mail_path}" <<EOF
From: ${from_addr}
Envelope-to: ${envelope_to}
Date: ${date_header_value}
Subject: Test

Cuerpo del mensaje.
EOF

    touch -t "${touch_timestamp}" "${mail_path}"
    printf '%s\n' "${mail_path}"
}

create_mail_without_headers()
{
    local user_name="$1"
    local subdir_name="$2"
    local file_name="$3"
    local touch_timestamp="$4"
    local target_dir="${TEST_MAIL_BASE}/${user_name}/Maildir/${subdir_name}"
    local mail_path="${target_dir}/${file_name}"

    mkdir -p "${target_dir}"
    printf 'Subject: Sin headers requeridos\n\nBody\n' > "${mail_path}"
    touch -t "${touch_timestamp}" "${mail_path}"
    printf '%s\n' "${mail_path}"
}

create_mail_with_return_path_only()
{
    local user_name="$1"
    local subdir_name="$2"
    local file_name="$3"
    local return_path_addr="$4"
    local envelope_to="$5"
    local touch_timestamp="$6"
    local date_header_value="${7:-Tue, 11 Jun 2024 12:00:00 -0300}"
    local target_dir="${TEST_MAIL_BASE}/${user_name}/Maildir/${subdir_name}"
    local mail_path="${target_dir}/${file_name}"

    mkdir -p "${target_dir}"

    cat > "${mail_path}" <<EOF
Return-path: <${return_path_addr}>
Envelope-to: ${envelope_to}
Date: ${date_header_value}
Subject: Test

Cuerpo del mensaje.
EOF

    touch -t "${touch_timestamp}" "${mail_path}"
    printf '%s\n' "${mail_path}"
}

run_with_yes_confirmation()
{
    run bash -c 'printf "s\n" | "$0" "$@"' "${TEST_SCRIPT}" "$@"
}

run_with_no_confirmation()
{
    run bash -c 'printf "N\n" | "$0" "$@"' "${TEST_SCRIPT}" "$@"
}

@test "Task 16 / AC-005: -h imprime help y sale con exit 0" {
    run bash "${TEST_SCRIPT}" -h

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Uso:"* ]]
    [[ "${output}" == *"-Y <anio>"* ]]
    [[ "${output}" == *"-y            Asume confirmacion"* ]]
}

@test "Task 17 / AC-004: falta -d produce exit 1" {
    run bash "${TEST_SCRIPT}" -f remitente -Y 2024

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"falta el flag obligatorio -d"* ]]
}

@test "Task 17 / AC-004: falta -f produce exit 1" {
    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -Y 2024

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"falta el flag obligatorio -f"* ]]
}

@test "Task 17 / AC-004: falta -Y produce exit 1" {
    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"falta el flag obligatorio -Y"* ]]
}

@test "Task 18 / AC-006: flag desconocido produce exit 1" {
    run bash "${TEST_SCRIPT}" -z

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"opcion desconocida -z"* ]]
}

@test "Task 18 / AC-006: argumento posicional extra produce exit 1" {
    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y 2024 extra

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"no se admiten argumentos posicionales extra"* ]]
}

@test "Task 19 / AC-013: valores invalidos para -Y producen exit 1" {
    local invalid_year=""

    for invalid_year in abc 1800 2100 99; do
        run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y "${invalid_year}"

        [ "${status}" -eq 1 ]
        [[ "${output}" == *"anio"* ]]
    done
}

@test "Task 20 / AC-010: directorio destino inexistente produce exit 1" {
    run bash "${TEST_SCRIPT}" -d "${TEST_ROOT}/missing_dest" -f remitente -Y 2024

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"directorio destino no existe"* ]]
}

@test "Task 21 / AC-011: Maildir inexistente con -u produce exit 1" {
    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -u inexistente

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Maildir del usuario no existe"* ]]
}

@test "Task 22 / AC-001: ejecucion real mueve coincidencias y las lista" {
    local matching_path
    local other_path
    local matching_date="Tue, 11 Jun 2024 15:45:00 -0300"

    matching_path="$(create_mail_file "user1" "cur" "match.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406011200.00 "${matching_date}")"
    other_path="$(create_mail_file "user2" "cur" "other.eml" "otro@gigot.com.ar" "grp_todos@gigot.com.ar" 202406011300.00)"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f remitente -Y 2024

    [ "${status}" -eq 0 ]
    [ ! -f "${matching_path}" ]
    [ -f "${TEST_DEST_DIR}/match.eml" ]
    [ -f "${other_path}" ]
    [[ "${output}" == *"${matching_path}"* ]]
    [[ "${output}" == *"Date: ${matching_date}"* ]]
}

@test "Acepta From con nombre visible y direccion entre angulos" {
    local matching_path

    matching_path="$(create_mail_file "user1" "cur" "display-name.eml" "Conectados <conectados@gigot.com.ar>" "grp_todos@gigot.com.ar" 202406011500.00)"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f conectados -Y 2024

    [ "${status}" -eq 0 ]
    [ ! -f "${matching_path}" ]
    [ -f "${TEST_DEST_DIR}/display-name.eml" ]
    [[ "${output}" == *"${matching_path}"* ]]
}

@test "Acepta From historico de Conectados Gigot Cosméticos" {
    local matching_path

    matching_path="$(create_mail_file "user1" "cur" "historic-display-name.eml" "Conectados Gigot Cosméticos <conectados@gigot.com.ar>" "grp_todos@gigot.com.ar" 202506011500.00)"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f conectados -Y 2025

    [ "${status}" -eq 0 ]
    [ ! -f "${matching_path}" ]
    [ -f "${TEST_DEST_DIR}/historic-display-name.eml" ]
    [[ "${output}" == *"${matching_path}"* ]]
}

@test "Acepta Return-path cuando From no esta presente" {
    local matching_path

    matching_path="$(create_mail_with_return_path_only "user1" "cur" "return-path-only.eml" "conectados@gigot.com.ar" "grp_todos@gigot.com.ar" 202506021500.00)"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f conectados -Y 2025

    [ "${status}" -eq 0 ]
    [ ! -f "${matching_path}" ]
    [ -f "${TEST_DEST_DIR}/return-path-only.eml" ]
    [[ "${output}" == *"${matching_path}"* ]]
}

@test "Task 23 / AC-002: dry-run lista archivos sin moverlos" {
    local matching_path
    local matching_date="Wed, 12 Jun 2024 08:10:00 -0300"

    matching_path="$(create_mail_file "user1" "new" "dry-run.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406021200.00 "${matching_date}")"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -r

    [ "${status}" -eq 0 ]
    [ -f "${matching_path}" ]
    [ ! -f "${TEST_DEST_DIR}/dry-run.eml" ]
    [[ "${output}" == *"${matching_path}"* ]]
    [[ "${output}" == *"Date: ${matching_date}"* ]]
}

@test "Task 24 / AC-003: -u restringe el analisis al usuario indicado" {
    local target_path
    local other_path

    target_path="$(create_mail_file "target_user" "cur" "target.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406031200.00)"
    other_path="$(create_mail_file "other_user" "cur" "other.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406031300.00)"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -u target_user

    [ "${status}" -eq 0 ]
    [ ! -f "${target_path}" ]
    [ -f "${TEST_DEST_DIR}/target.eml" ]
    [ -f "${other_path}" ]
    [[ "${output}" == *"${target_path}"* ]]
    [[ "${output}" != *"${other_path}"* ]]
}

@test "Task 25 / AC-007: sin coincidencias emite error y sale con exit 1" {
    create_mail_file "user1" "cur" "wrong-from.eml" "otro@gigot.com.ar" "grp_todos@gigot.com.ar" 202406041200.00 >/dev/null
    create_mail_without_headers "user1" "new" "missing-headers.eml" 202406041300.00 >/dev/null

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f remitente -Y 2024

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Headers ausentes"* ]]
    [[ "${output}" == *"no se encontraron archivos que coincidan"* ]]
}

@test "Task 26 / AC-008: filtro por mtime incluye solo el anio correcto" {
    local included_path
    local excluded_path

    included_path="$(create_mail_file "user1" "cur" "include-2024.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406051200.00)"
    excluded_path="$(create_mail_file "user1" "cur" "exclude-2023.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202306051200.00)"

    run_with_yes_confirmation -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -r

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${included_path}"* ]]
    [[ "${output}" != *"${excluded_path}"* ]]
}

@test "Task 27 / AC-012: confirmacion negativa cancela sin mover archivos" {
    local matching_path

    matching_path="$(create_mail_file "user1" "cur" "cancel.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406061200.00)"

    run_with_no_confirmation -d "${TEST_DEST_DIR}" -f remitente -Y 2024

    [ "${status}" -eq 1 ]
    [ -f "${matching_path}" ]
    [ ! -f "${TEST_DEST_DIR}/cancel.eml" ]
    [[ "${output}" == *"Cancelado por el usuario"* ]]
}

@test "Task 27b / AC-014: -y omite confirmacion y bloque de variables" {
    local matching_path

    matching_path="$(create_mail_file "user1" "cur" "assume-yes.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406071200.00)"

    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -r -y

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${matching_path}"* ]]
    [[ "${output}" != *"Variables de Ejecucion"* ]]
    [[ "${output}" != *"¿Continuar?"* ]]
}

@test "Excluye archivos dentro de .Sent del analisis" {
    local sent_path

    sent_path="$(create_mail_file "user1" ".Sent/cur" "sent-copy.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406081200.00)"

    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -r -y

    [ "${status}" -eq 1 ]
    [ -f "${sent_path}" ]
    [[ "${output}" != *"${sent_path}"* ]]
    [[ "${output}" == *"no se encontraron archivos que coincidan"* ]]
}

@test "Excluye archivos dovecot del analisis" {
    local dovecot_path

    dovecot_path="$(create_mail_file "user1" "cur" "dovecot.index.log" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406091200.00)"

    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -r -y

    [ "${status}" -eq 1 ]
    [ -f "${dovecot_path}" ]
    [[ "${output}" != *"${dovecot_path}"* ]]
    [[ "${output}" == *"no se encontraron archivos que coincidan"* ]]
}

@test "Excluye archivos dentro de .Template del analisis" {
    local template_path

    template_path="$(create_mail_file "user1" ".Template/cur" "template-copy.eml" "remitente@gigot.com.ar" "grp_todos@gigot.com.ar" 202406101200.00)"

    run bash "${TEST_SCRIPT}" -d "${TEST_DEST_DIR}" -f remitente -Y 2024 -r -y

    [ "${status}" -eq 1 ]
    [ -f "${template_path}" ]
    [[ "${output}" != *"${template_path}"* ]]
    [[ "${output}" == *"no se encontraron archivos que coincidan"* ]]
}
