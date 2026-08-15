#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
PREFIX=/usr/local
VERSION="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$REPO_DIR/lib/runtime.sh")"
tests_run=0
tests_failed=0

cleanup() {
    if [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/* && -d "$TEST_ROOT" ]]; then
        rm -rf -- "$TEST_ROOT"
    fi
}
trap cleanup EXIT

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

make -s -C "$REPO_DIR" install DESTDIR="$TEST_ROOT" PREFIX="$PREFIX"

managed_root="$TEST_ROOT$PREFIX/lib/cyberops"
legacy_module="$managed_root/lib/setup.sh"
legacy_icon="$TEST_ROOT$PREFIX/share/icons/hicolor/1024x1024/apps/cyberops.png"
user_config="$TEST_ROOT/home/operator/.config/cyberops/config"
user_log="$TEST_ROOT/home/operator/.local/state/cyberops/operations.log"

mkdir -p -- "$(dirname -- "$legacy_icon")" "$(dirname -- "$user_config")" \
    "$(dirname -- "$user_log")"
printf 'legacy\n' >"$legacy_module"
printf 'legacy\n' >"$legacy_icon"
printf 'CYBEROPS_THEME=classic\n' >"$user_config"
printf 'private-history\n' >"$user_log"

make -s -C "$REPO_DIR" install DESTDIR="$TEST_ROOT" PREFIX="$PREFIX"

if [[ ! -e "$legacy_module" && ! -e "$legacy_icon" ]]; then
    legacy_result=removed
else
    legacy_result=remaining
fi
record_result "in-place source upgrades remove obsolete managed files" \
    "$legacy_result" removed

installed_version="$(bash "$managed_root/cyberops.sh" --version)"
record_result "upgraded launcher reports the current source version" \
    "$installed_version" "CYBEROPS Terminal $VERSION"

if [[ "$(<"$user_config")" == "CYBEROPS_THEME=classic" &&
    "$(<"$user_log")" == "private-history" ]]; then
    user_data_result=preserved
else
    user_data_result=changed
fi
record_result "in-place upgrades preserve user configuration and state" \
    "$user_data_result" preserved

make -s -C "$REPO_DIR" uninstall DESTDIR="$TEST_ROOT" PREFIX="$PREFIX"

if [[ -f "$user_config" && -f "$user_log" ]]; then
    removal_boundary_result=preserved
else
    removal_boundary_result=removed
fi
record_result "source uninstall preserves user-owned configuration and state" \
    "$removal_boundary_result" preserved

if [[ ! -e "$TEST_ROOT$PREFIX/bin/cyberops" && ! -e "$managed_root" &&
    ! -e "$TEST_ROOT$PREFIX/share/applications/cyberops.desktop" ]]; then
    managed_removal_result=removed
else
    managed_removal_result=remaining
fi
record_result "source uninstall removes upgraded managed files" \
    "$managed_removal_result" removed

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
