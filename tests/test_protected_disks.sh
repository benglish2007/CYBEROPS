#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

findmnt() {
    case "${*: -1}" in
        /) printf '/dev/mapper/vg-root\n' ;;
        /boot) printf '/dev/nvme0n1p2\n' ;;
        /boot/efi) printf '/dev/nvme1n1p1\n' ;;
        *) return 1 ;;
    esac
}

lsblk() {
    case "${*: -1}" in
        /dev/mapper/vg-root)
            printf '/dev/mapper/vg-root lvm\n'
            printf '/dev/nvme0n1p3 part\n'
            printf '/dev/nvme0n1 disk\n'
            ;;
        /dev/nvme0n1p2)
            printf '/dev/nvme0n1p2 part\n'
            printf '/dev/nvme0n1 disk\n'
            ;;
        /dev/nvme1n1p1)
            printf '/dev/nvme1n1p1 part\n'
            printf '/dev/nvme1n1 disk\n'
            ;;
        *) return 1 ;;
    esac
}

actual="$(protected_system_disks)"
expected=$'/dev/nvme0n1\n/dev/nvme1n1'

if [[ "$actual" == "$expected" ]]; then
    printf 'ok 1 - resolves protected disks through partitions and device mapper parents\n'
    printf '1..1\n'
else
    printf 'not ok 1 - protected disks mismatch\n'
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual"
    printf '1..1\n'
    exit 1
fi
