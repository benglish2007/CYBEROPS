#!/usr/bin/env bash

set -uo pipefail

tests_run=0
tests_failed=0

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

if ((BASH_VERSINFO[0] >= 5)); then
    version_result=supported
else
    version_result=unsupported
fi
record_result "uses Bash 5 or newer" "$version_result" supported

mapfile -d '' -t mapfile_values < <(printf 'alpha\0beta\0')
record_result "supports null-delimited mapfile input" \
    "${#mapfile_values[@]}:${mapfile_values[0]}:${mapfile_values[1]}" \
    "2:alpha:beta"

VERSION_CASE_TEST=MiXeD
lowercase_value="${VERSION_CASE_TEST,,}"
record_result "supports Bash lowercase expansion" "$lowercase_value" "mixed"

if lsblk -dn -o MOUNTPOINTS >/dev/null 2>&1; then
    lsblk_result=supported
else
    lsblk_result=missing
fi
record_result "lsblk exposes the MOUNTPOINTS column" "$lsblk_result" supported

if dd if=/dev/zero of=/dev/null bs=16M count=1B 2>/dev/null ||
    dd if=/dev/zero of=/dev/null bs=16M count=1 iflag=count_bytes 2>/dev/null; then
    dd_result=supported
else
    dd_result=missing
fi
record_result "dd supports an exact byte-count mode" "$dd_result" supported

sorted_values="$(printf 'beta\0alpha\0' | sort -z | tr '\0' '\n')"
record_result "GNU sort supports null-delimited ordering" \
    "$sorted_values" $'alpha\nbeta'

if find . -maxdepth 0 -print0 | tr '\0' '\n' | grep -qx '\.'; then
    find_result=supported
else
    find_result=missing
fi
record_result "GNU find supports null-delimited output" "$find_result" supported

if [[ "$(readlink -f /)" == "/" ]]; then
    readlink_result=supported
else
    readlink_result=missing
fi
record_result "readlink supports canonical path resolution" "$readlink_result" supported

if printf '<BROADCAST,UP,LOWER_UP>\n' | grep -qE '<[^>]*\bUP\b[^>]*>'; then
    grep_result=supported
else
    grep_result=missing
fi
record_result "grep supports the interface-state expression" "$grep_result" supported

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
