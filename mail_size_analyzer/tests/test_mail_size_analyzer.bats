#!/usr/bin/env bats

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    ORIGINAL_SCRIPT="${PROJECT_ROOT}/mail_size_analyzer/scripts/mail_size_analyzer.sh"
    TEST_TMPDIR="$(mktemp -d)"
    TEST_SCRIPT="${TEST_TMPDIR}/mail_size_analyzer.sh"
    TEST_MAIL_ROOT="${TEST_TMPDIR}/srv_mail"

    mkdir -p "${TEST_MAIL_ROOT}"
    while IFS= read -r line; do
        if [ "${line}" = ': "${MAIL_ROOT_DIR:=${DEFAULT_MAIL_ROOT_DIR}}"' ]; then
            printf ': "${MAIL_ROOT_DIR:=%s}"\n' "${TEST_MAIL_ROOT}"
            continue
        fi

        printf '%s\n' "${line}"
    done < "${ORIGINAL_SCRIPT}" > "${TEST_SCRIPT}"
    chmod +x "${TEST_SCRIPT}"
}

teardown()
{
    chmod -R u+rwx "${TEST_TMPDIR}" 2>/dev/null || true
    rm -rf "${TEST_TMPDIR}"
}

create_maildir_user()
{
    local user_name="$1"
    local maildir_path="${TEST_MAIL_ROOT}/${user_name}/Maildir"

    mkdir -p "${maildir_path}/cur" "${maildir_path}/new" "${maildir_path}/tmp"
    printf '%s\n' "${maildir_path}"
}

create_mail_file()
{
    local file_path="$1"
    local size_mb="$2"

    if [ "${size_mb}" -eq 0 ]; then
        : > "${file_path}"
        return 0
    fi

    truncate -s "${size_mb}M" "${file_path}"
}

@test "Shows help with -h" {
    run bash "${TEST_SCRIPT}" -h

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"-c  Print the 11 bucket counters and total in one line."* ]]
    [[ "${output}" == *"-u  Analyze only the specified user."* ]]
}

@test "Prints users, multiline distribution and total" {
    user_one_maildir="$(create_maildir_user ana)"
    user_two_maildir="$(create_maildir_user beto)"

    create_mail_file "${user_one_maildir}/cur/mail_zero" 0
    create_mail_file "${user_one_maildir}/cur/mail_nine" 9
    create_mail_file "${user_one_maildir}/new/mail_ten" 10
    create_mail_file "${user_two_maildir}/cur/mail_fifty_five" 55
    create_mail_file "${user_two_maildir}/new/mail_hundred" 100
    create_mail_file "${user_two_maildir}/tmp/mail_hundred_one" 101

    run bash "${TEST_SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *$'ana\n'* ]]
    [[ "${output}" == *$'beto\n'* ]]
    [[ "${output}" == *"0-10 -> 2"* ]]
    [[ "${output}" == *"10-20 -> 1"* ]]
    [[ "${output}" == *"50-60 -> 1"* ]]
    [[ "${output}" == *"90-100 -> 1"* ]]
    [[ "${output}" == *"+100 -> 1"* ]]
    [[ "${output}" == *"TOTAL -> 6"* ]]
}

@test "Prints compact output with -c" {
    user_one_maildir="$(create_maildir_user compact_user)"

    create_mail_file "${user_one_maildir}/cur/mail_zero" 0
    create_mail_file "${user_one_maildir}/cur/mail_nine" 9
    create_mail_file "${user_one_maildir}/new/mail_ten" 10
    create_mail_file "${user_one_maildir}/new/mail_hundred_one" 101

    run bash "${TEST_SCRIPT}" -c

    [ "${status}" -eq 0 ]
    [ "${output}" = "2 1 0 0 0 0 0 0 0 0 1 4" ]
}

@test "Analyzes only the requested user with -u" {
    target_maildir="$(create_maildir_user cnavarro)"
    other_maildir="$(create_maildir_user otheruser)"

    create_mail_file "${target_maildir}/cur/mail_zero" 0
    create_mail_file "${target_maildir}/new/mail_ten" 10
    create_mail_file "${other_maildir}/cur/mail_hundred_one" 101

    run bash "${TEST_SCRIPT}" -u cnavarro

    [ "${status}" -eq 0 ]
    [[ "${output}" == *$'cnavarro\n'* ]]
    [[ "${output}" != *$'otheruser\n'* ]]
    [[ "${output}" == *"0-10 -> 1"* ]]
    [[ "${output}" == *"10-20 -> 1"* ]]
    [[ "${output}" == *"+100 -> 0"* ]]
    [[ "${output}" == *"TOTAL -> 2"* ]]
}

@test "Analyzes only the requested user in compact mode" {
    target_maildir="$(create_maildir_user cnavarro)"
    other_maildir="$(create_maildir_user otheruser)"

    create_mail_file "${target_maildir}/cur/mail_zero" 0
    create_mail_file "${target_maildir}/new/mail_hundred_one" 101
    create_mail_file "${other_maildir}/cur/mail_ten" 10

    run bash "${TEST_SCRIPT}" -u cnavarro -c

    [ "${status}" -eq 0 ]
    [ "${output}" = "1 0 0 0 0 0 0 0 0 0 1 2" ]
}

@test "Rejects invalid flags" {
    run bash "${TEST_SCRIPT}" -x

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid option: -x."* ]]
}

@test "Rejects positional arguments" {
    run bash "${TEST_SCRIPT}" unexpected

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Positional arguments are not supported."* ]]
}

@test "Rejects invalid user names" {
    run bash "${TEST_SCRIPT}" -u ../bad

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"User names must not contain '/'"* ]]
}

@test "Fails when the requested user does not exist" {
    run bash "${TEST_SCRIPT}" -u missing_user

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Maildir directory not found for user: missing_user."* ]]
}

@test "Fails when the structure has no regular files" {
    create_maildir_user empty_user >/dev/null

    run bash "${TEST_SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Empty mail structure: no regular files found"* ]]
}

@test "Fails when the structure is corrupt" {
    corrupt_maildir="$(create_maildir_user corrupt_user)"
    mkdir -p "${corrupt_maildir}/blocked"
    chmod 000 "${corrupt_maildir}/blocked"

    run bash "${TEST_SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Corrupt mail structure: failed to read"* ]]
}
