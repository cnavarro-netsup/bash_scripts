#!/usr/bin/env bats

setup() {
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/vm_test.sh"
    export MOCK_DIR="$(mktemp -d)"
    
    # Mocking external commands to prevent actual execution requiring root
    export PATH="${MOCK_DIR}:$PATH"

    cat << 'EOF' > "${MOCK_DIR}/kpartx"
#!/usr/bin/env bash
if [[ "$*" == *"fail.raw"* ]]; then exit 1; fi
exit 0
EOF
    chmod +x "${MOCK_DIR}/kpartx"

    cat << 'EOF' > "${MOCK_DIR}/vgchange"
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${MOCK_DIR}/vgchange"

    cat << 'EOF' > "${MOCK_DIR}/fsck"
#!/usr/bin/env bash
if [ "${EXPECT_FSCK_FAIL:-0}" = "1" ]; then exit 1; fi
exit 0
EOF
    chmod +x "${MOCK_DIR}/fsck"

    cat << 'EOF' > "${MOCK_DIR}/mount"
#!/usr/bin/env bash
mnt_dir="${@: -1}"
# Touch a flag to simulate mount success
touch "${MOCK_DIR}/mock_mounted"
# Mock the etc/hostname content
mkdir -p "$mnt_dir/etc"
echo "test-vm-host" > "$mnt_dir/etc/hostname"
exit 0
EOF
    chmod +x "${MOCK_DIR}/mount"

    cat << 'EOF' > "${MOCK_DIR}/umount"
#!/usr/bin/env bash
rm -f "${MOCK_DIR}/mock_mounted"
exit 0
EOF
    chmod +x "${MOCK_DIR}/umount"

    # Create dummy images
    touch "${MOCK_DIR}/valid.raw"
    touch "${MOCK_DIR}/fail_fsck.raw"
}

teardown() {
    rm -rf "${MOCK_DIR}"
}

@test "AC-001: Fails when no arguments provided" {
    run bash "$SCRIPT_PATH"
    [ "$status" -eq 1 ]
}

@test "AC-001: Fails when file does not exist" {
    run bash "$SCRIPT_PATH" "nonexistent.raw"
    [ "$status" -eq 1 ]
}

@test "AC-004: Prints hostname and exits 0 on valid image" {
    run bash "$SCRIPT_PATH" "${MOCK_DIR}/valid.raw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-vm-host"* ]]
}

@test "AC-003: Cleans up and exits 1 if fsck fails" {
    export EXPECT_FSCK_FAIL=1
    run bash "$SCRIPT_PATH" "${MOCK_DIR}/fail_fsck.raw"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR al ejecutar fsck"* ]]
    [[ "$output" != *"test-vm-host"* ]]
    # Ensure umount was simulated/not left hooked
    [ ! -f "${MOCK_DIR}/mock_mounted" ]
}

@test "Help option outputs usage" {
    run bash "$SCRIPT_PATH" "-h"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
