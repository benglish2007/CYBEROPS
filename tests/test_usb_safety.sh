#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0

MOCK_BLOCK=1
MOCK_REMOVABLE=1
MOCK_PROTECTED=0
MOCK_PROTECTION_READY=1
MOCK_IDENTITY="/dev/sdz|disk|usb|1|16G|Test USB|SERIAL-1|WWN-1"
MOCK_MOUNTS=""

resolve_device_path() {
    [[ "$1" == "/dev/sdz" ]] || return 1
    printf '/dev/sdz\n'
}

is_block_device() {
    [[ "$MOCK_BLOCK" == "1" && "$1" == "/dev/sdz" ]]
}

is_removable_usb_disk() {
    [[ "$MOCK_REMOVABLE" == "1" ]]
}

is_protected_system_disk() {
    [[ "$MOCK_PROTECTED" == "1" ]]
}

system_disk_protection_ready() {
    [[ "$MOCK_PROTECTION_READY" == "1" ]]
}

usb_device_identity() {
    printf '%s\n' "$MOCK_IDENTITY"
}

device_mountpoints() {
    printf '%s' "$MOCK_MOUNTS"
}

list_usb_candidates() {
    printf '/dev/sdz\n'
}

block_property() {
    case "$2" in
        SIZE) printf '16G\n' ;;
        MODEL) printf 'Test USB\n' ;;
        TRAN) printf 'usb\n' ;;
        *) return 1 ;;
    esac
}

record_result() {
    local name="$1"
    local actual="$2"
    local expected="$3"

    ((tests_run += 1))
    if [[ "$actual" == "$expected" ]]; then
        printf 'ok %d - %s\n' "$tests_run" "$name"
    else
        printf 'not ok %d - %s (expected %s, got %s)\n' \
            "$tests_run" "$name" "$expected" "$actual"
        ((tests_failed += 1))
    fi
}

expect_success() {
    local name="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        record_result "$name" success success
    else
        record_result "$name" failure success
    fi
}

expect_failure() {
    local name="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        record_result "$name" success failure
    else
        record_result "$name" failure failure
    fi
}

expected_identity="$MOCK_IDENTITY"

expect_success "accepts an unchanged removable USB disk" \
    validate_usb_target /dev/sdz "$expected_identity"

MOCK_IDENTITY="/dev/sdz|disk|usb|1|32G|Replacement USB|SERIAL-2|WWN-2"
expect_failure "rejects a device whose identity changed" \
    validate_usb_target /dev/sdz "$expected_identity"
MOCK_IDENTITY="$expected_identity"

MOCK_PROTECTED=1
expect_failure "rejects a disk backing a protected mount" \
    validate_usb_target /dev/sdz "$expected_identity"
MOCK_PROTECTED=0

MOCK_REMOVABLE=0
expect_failure "rejects a non-removable non-USB target" \
    validate_usb_target /dev/sdz "$expected_identity"
MOCK_REMOVABLE=1

MOCK_PROTECTION_READY=0
expect_failure "fails closed when system disks cannot be resolved" \
    validate_usb_target /dev/sdz "$expected_identity"
MOCK_PROTECTION_READY=1

MOCK_BLOCK=0
expect_failure "rejects a path that is not a block device" \
    validate_usb_target /dev/sdz "$expected_identity"
MOCK_BLOCK=1

MOCK_MOUNTS="/media/test"
expect_failure "rejects mounted filesystems before writing" \
    validate_usb_target /dev/sdz "$expected_identity" 1
MOCK_MOUNTS=""

if select_usb_device <<< "1" >/dev/null 2>&1; then
    record_result "selector returns only the chosen device through state" \
        "$SELECTED_USB_DEVICE" /dev/sdz
else
    record_result "selector returns only the chosen device through state" failure /dev/sdz
fi

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
