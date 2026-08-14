#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0
MOCK_LAYOUT=whole-disk
SUDO_CALLS=()

lsblk() {
    if [[ "$*" == *"-bdn -o SIZE"* ]]; then
        printf '31994150912\n'
        return 0
    fi

    case "$MOCK_LAYOUT" in
        whole-disk)
            printf '/dev/sdb disk\n'
            ;;
        disk-and-partition)
            printf '/dev/sdb disk\n'
            printf '/dev/sdb1 part\n'
            ;;
    esac
}

device_mountpoints() {
    case "$1" in
        /dev/sdb) printf '/run/media/test/WHOLE DISK\n' ;;
        /dev/sdb1) printf '/run/media/test/PARTITION\n' ;;
    esac
}

sudo() {
    SUDO_CALLS+=("$*")
    return 0
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

if unmount_device_filesystems /dev/sdb >/dev/null 2>&1; then
    unmount_result=success
else
    unmount_result=failure
fi
record_result "unmounts a filesystem attached directly to the disk" \
    "${SUDO_CALLS[*]}" "umount -- /dev/sdb"
record_result "reports whole-disk unmount success" "$unmount_result" success

MOCK_LAYOUT=disk-and-partition
SUDO_CALLS=()
unmount_device_filesystems /dev/sdb >/dev/null 2>&1
record_result "unmounts child partitions before the parent disk" \
    "${SUDO_CALLS[*]}" "umount -- /dev/sdb1 umount -- /dev/sdb"

SUDO_CALLS=()
dd_byte_count_mode() {
    printf 'suffix\n'
}

if zero_fill_device /dev/sdb >/dev/null 2>&1; then
    fill_result=success
else
    fill_result=failure
fi
record_result "reports an exact-capacity zero-fill as success" "$fill_result" success
record_result "limits dd to the exact device byte capacity" \
    "${SUDO_CALLS[*]}" \
    "dd if=/dev/zero of=/dev/sdb bs=16M count=31994150912B status=progress conv=fsync"

SUDO_CALLS=()
dd_byte_count_mode() {
    printf 'count_bytes\n'
}
zero_fill_device /dev/sdb >/dev/null 2>&1
record_result "falls back to iflag=count_bytes when required" \
    "${SUDO_CALLS[*]}" \
    "dd if=/dev/zero of=/dev/sdb bs=16M count=31994150912 iflag=count_bytes status=progress conv=fsync"

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
