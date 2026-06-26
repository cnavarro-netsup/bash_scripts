#!/usr/bin/env bats

# Tests for backup_users_txs03.sh
# Strategy: stub all external commands (sshfs, rsync, rdiff-backup, mail,
# fusermount, mountpoint) so the suite runs without real infrastructure.

setup()
{
    PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCRIPT="${PROJECT_ROOT}/backup_users_txs03/scripts/backup_users_txs03.sh"

    # Temporary directory acting as a fake filesystem root for this test
    TEST_TMPDIR="$(mktemp -d)"

    # Fake mount point and staging/dest dirs
    FAKE_MOUNT="${TEST_TMPDIR}/mnt/txs03"
    FAKE_STAGING="${TEST_TMPDIR}/srv/tmp/txs03-user-staging"
    FAKE_DEST="${TEST_TMPDIR}/srv/bk-daily/txs03-users"
    mkdir -p "${FAKE_MOUNT}" "${FAKE_STAGING}" "${FAKE_DEST}"

    # Stub bin directory (prepended to PATH so stubs take precedence)
    STUB_BIN="${TEST_TMPDIR}/bin"
    mkdir -p "${STUB_BIN}"

    # --- stub: mountpoint ---
    # Returns 1 (not mounted) by default so the script will attempt to mount
    cat > "${STUB_BIN}/mountpoint" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

    # --- stub: sshfs (always succeeds) ---
    cat > "${STUB_BIN}/sshfs" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    # --- stub: rsync (always succeeds) ---
    cat > "${STUB_BIN}/rsync" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    # --- stub: rdiff-backup (always succeeds) ---
    cat > "${STUB_BIN}/rdiff-backup" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    # --- stub: mail (always succeeds) ---
    cat > "${STUB_BIN}/mail" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
exit 0
EOF

    # --- stub: fusermount (always succeeds) ---
    cat > "${STUB_BIN}/fusermount" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    chmod +x "${STUB_BIN}"/*

    # Create two fake user profiles with all three subdirs
    mkdir -p "${FAKE_MOUNT}/alice/Desktop"
    mkdir -p "${FAKE_MOUNT}/alice/Documents"
    mkdir -p "${FAKE_MOUNT}/alice/Downloads"
    mkdir -p "${FAKE_MOUNT}/bob/Desktop"
    mkdir -p "${FAKE_MOUNT}/bob/Documents"
    mkdir -p "${FAKE_MOUNT}/bob/Downloads"
}

teardown()
{
    rm -rf "${TEST_TMPDIR}"
}

# Helper: run the script with stubs injected via PATH and overridden variables
run_script()
{
    run env PATH="${STUB_BIN}:${PATH}" \
        MOUNT_POINT="${FAKE_MOUNT}" \
        STAGING_DIR="${FAKE_STAGING}" \
        DEST_DIR="${FAKE_DEST}" \
        MAIL_TO="infraestructura@gigot.com.ar" \
        "$@" \
        bash "${SCRIPT}"
}

# ---------------------------------------------------------------------------
# AC-010: script passes shellcheck (basic syntax validation via bash -n)
# ---------------------------------------------------------------------------
@test "Script passes bash syntax check" {
    run bash -n "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC-001: mounts sshfs when mount point is not yet mounted
# ---------------------------------------------------------------------------
@test "Mounts sshfs when not already mounted" {
    # mountpoint stub exits 1 (not mounted) — sshfs stub must be called
    local sshfs_called="${TEST_TMPDIR}/sshfs_called"

    cat > "${STUB_BIN}/sshfs" <<EOF
#!/usr/bin/env bash
touch "${sshfs_called}"
exit 0
EOF
    chmod +x "${STUB_BIN}/sshfs"

    run_script
    [ -f "${sshfs_called}" ]
}

# ---------------------------------------------------------------------------
# AC-001: always unmounts via fusermount in cleanup
# ---------------------------------------------------------------------------
@test "Always unmounts via fusermount in cleanup" {
    # Make mountpoint return 0 (already mounted) after mount step
    local fusermount_called="${TEST_TMPDIR}/fusermount_called"

    # mountpoint: return 0 so cleanup sees it as mounted
    cat > "${STUB_BIN}/mountpoint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    cat > "${STUB_BIN}/fusermount" <<EOF
#!/usr/bin/env bash
touch "${fusermount_called}"
exit 0
EOF
    chmod +x "${STUB_BIN}/mountpoint" "${STUB_BIN}/fusermount"

    run_script
    [ -f "${fusermount_called}" ]
}

# ---------------------------------------------------------------------------
# AC-001: skips mounting when already mounted
# ---------------------------------------------------------------------------
@test "Skips sshfs mount when already mounted" {
    local sshfs_called="${TEST_TMPDIR}/sshfs_called"

    # mountpoint returns 0 → already mounted
    cat > "${STUB_BIN}/mountpoint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    cat > "${STUB_BIN}/sshfs" <<EOF
#!/usr/bin/env bash
touch "${sshfs_called}"
exit 0
EOF
    chmod +x "${STUB_BIN}/mountpoint" "${STUB_BIN}/sshfs"

    run_script
    [ ! -f "${sshfs_called}" ]
}

# ---------------------------------------------------------------------------
# AC-002 / AC-003: rsync is called for each subdir of each profile
# ---------------------------------------------------------------------------
@test "rsync called for Desktop, Documents and Downloads of each profile" {
    local rsync_log="${TEST_TMPDIR}/rsync_calls.log"

    cat > "${STUB_BIN}/rsync" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${rsync_log}"
exit 0
EOF
    chmod +x "${STUB_BIN}/rsync"

    run_script
    [ "${status}" -eq 0 ]

    # Six calls expected: 2 profiles × 3 subdirs
    local call_count
    call_count="$(wc -l < "${rsync_log}")"
    [ "${call_count}" -eq 6 ]
}

# ---------------------------------------------------------------------------
# AC-002: missing subdir is skipped without aborting (WARN only)
# ---------------------------------------------------------------------------
@test "Missing subdir in a profile is skipped without fatal error" {
    # Remove Downloads from alice
    rm -rf "${FAKE_MOUNT}/alice/Downloads"

    run_script
    # Script should still exit 0 (missing dir is a WARN, not an ERROR)
    [ "${status}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC-003: rsync uses staging directory as destination
# ---------------------------------------------------------------------------
@test "rsync destination is inside staging directory" {
    local rsync_log="${TEST_TMPDIR}/rsync_calls.log"

    cat > "${STUB_BIN}/rsync" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${rsync_log}"
exit 0
EOF
    chmod +x "${STUB_BIN}/rsync"

    run_script
    # Every rsync call destination should contain FAKE_STAGING
    while IFS= read -r line; do
        [[ "${line}" == *"${FAKE_STAGING}"* ]]
    done < "${rsync_log}"
}

# ---------------------------------------------------------------------------
# AC-004 / AC-005: rdiff-backup backup and remove increments are called
# ---------------------------------------------------------------------------
@test "rdiff-backup backup and remove increments are both called" {
    local rdiff_log="${TEST_TMPDIR}/rdiff_calls.log"

    cat > "${STUB_BIN}/rdiff-backup" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${rdiff_log}"
exit 0
EOF
    chmod +x "${STUB_BIN}/rdiff-backup"

    run_script
    [ "${status}" -eq 0 ]

    grep -q "^backup" "${rdiff_log}"
    grep -q "^remove increments" "${rdiff_log}"
}

# ---------------------------------------------------------------------------
# AC-005: rdiff-backup remove increments uses --older-than with 10B
# ---------------------------------------------------------------------------
@test "rdiff-backup remove uses --older-than 10B" {
    local rdiff_log="${TEST_TMPDIR}/rdiff_calls.log"

    cat > "${STUB_BIN}/rdiff-backup" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${rdiff_log}"
exit 0
EOF
    chmod +x "${STUB_BIN}/rdiff-backup"

    run_script
    grep -q "\-\-older-than 10B" "${rdiff_log}"
}

# ---------------------------------------------------------------------------
# AC-006: mail is called at the end of execution
# ---------------------------------------------------------------------------
@test "mail is called to send the log on success" {
    local mail_called="${TEST_TMPDIR}/mail_called"

    cat > "${STUB_BIN}/mail" <<EOF
#!/usr/bin/env bash
touch "${mail_called}"
cat > /dev/null
exit 0
EOF
    chmod +x "${STUB_BIN}/mail"

    run_script
    [ -f "${mail_called}" ]
}

# ---------------------------------------------------------------------------
# AC-006: mail subject contains OK on success
# ---------------------------------------------------------------------------
@test "mail subject contains OK on successful run" {
    local mail_subject="${TEST_TMPDIR}/mail_subject"

    cat > "${STUB_BIN}/mail" <<EOF
#!/usr/bin/env bash
echo "\$@" > "${mail_subject}"
cat > /dev/null
exit 0
EOF
    chmod +x "${STUB_BIN}/mail"

    run_script
    grep -q "OK" "${mail_subject}"
}

# ---------------------------------------------------------------------------
# AC-007: script exits 0 on clean run
# ---------------------------------------------------------------------------
@test "Exits with code 0 on clean run" {
    run_script
    [ "${status}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC-007: script exits 1 when rdiff-backup fails
# ---------------------------------------------------------------------------
@test "Exits with code 1 when rdiff-backup backup fails" {
    cat > "${STUB_BIN}/rdiff-backup" <<'EOF'
#!/usr/bin/env bash
if [ "${1}" = "backup" ]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${STUB_BIN}/rdiff-backup"

    run_script
    [ "${status}" -eq 1 ]
}

# ---------------------------------------------------------------------------
# AC-007: script exits 1 when sshfs mount fails
# ---------------------------------------------------------------------------
@test "Exits with code 1 when sshfs mount fails" {
    # mountpoint says not mounted, sshfs fails
    cat > "${STUB_BIN}/mountpoint" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    cat > "${STUB_BIN}/sshfs" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "${STUB_BIN}/mountpoint" "${STUB_BIN}/sshfs"

    run_script
    [ "${status}" -eq 1 ]
}

# ---------------------------------------------------------------------------
# AC-008: no writes to the sshfs mount point
# ---------------------------------------------------------------------------
@test "No writes are performed on the sshfs mount point" {
    # Record any write attempt to FAKE_MOUNT using inotifywait — but since
    # that is not always available, we verify via rsync args instead:
    # rsync source must always point INTO FAKE_MOUNT, never as destination.
    local rsync_log="${TEST_TMPDIR}/rsync_calls.log"

    cat > "${STUB_BIN}/rsync" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${rsync_log}"
exit 0
EOF
    chmod +x "${STUB_BIN}/rsync"

    run_script

    # The last argument to rsync (destination) must never start with FAKE_MOUNT
    while IFS= read -r line; do
        local dest
        dest="$(echo "${line}" | awk '{print $NF}')"
        [[ "${dest}" != "${FAKE_MOUNT}"* ]]
    done < "${rsync_log}"
}

# ---------------------------------------------------------------------------
# AC-009: rsync error on one profile increments error counter but continues
# ---------------------------------------------------------------------------
@test "rsync failure on one profile does not abort remaining profiles" {
    local rsync_log="${TEST_TMPDIR}/rsync_calls.log"

    # Fail only when syncing alice's Desktop
    cat > "${STUB_BIN}/rsync" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${rsync_log}"
if [[ "\$*" == *"alice/Desktop"* ]]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${STUB_BIN}/rsync"

    run_script
    # Must still attempt bob's directories despite alice/Desktop failure
    grep -q "bob" "${rsync_log}"
}

# ---------------------------------------------------------------------------
# AC-010: script exits 1 when no profiles found in mount point
# ---------------------------------------------------------------------------
@test "Exits with code 1 when mount point has no user profiles" {
    # Remove all profiles from fake mount
    rm -rf "${FAKE_MOUNT:?}"/*

    run_script
    [ "${status}" -eq 1 ]
}
