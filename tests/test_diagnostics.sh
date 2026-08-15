#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -f -- "$TEST_DIR/bundle.tar.gz" "$TEST_DIR/report.txt"; rmdir -- "$TEST_DIR"' EXIT

export CYBEROPS_CONFIG_FILE="$TEST_DIR/private-user-marker-config"
export CYBEROPS_STATE_DIR="$TEST_DIR/private-state-marker"
export STACK_ROOT="/srv/private-stack-marker"
export CYBEROPS_LOGGING=0
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

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

preview_output="$(diagnostics_preview)"
[[ "$preview_output" == *"Included:"* && "$preview_output" == *"Excluded:"* ]]
record_result "previews included and excluded data" "$?" 0

export_output="$(cyberops_main --no-color diagnostics export "$TEST_DIR/bundle.tar.gz")"
record_result "exports a diagnostics archive" "$?" 0
[[ "$export_output" == *"Diagnostics bundle created:"* ]]
record_result "reports the archive location" "$?" 0
record_result "sets private archive permissions" \
    "$(stat -c '%a' "$TEST_DIR/bundle.tar.gz")" 600

tar -xOf "$TEST_DIR/bundle.tar.gz" report.txt >"$TEST_DIR/report.txt"
report_contents="$(<"$TEST_DIR/report.txt")"
[[ "$report_contents" == *"CYBEROPS diagnostics"* &&
    "$report_contents" == *"[anonymous_block_devices]"* ]]
record_result "contains the documented anonymous report" "$?" 0

if [[ "$report_contents" == *"private-user-marker"* ||
    "$report_contents" == *"private-state-marker"* ||
    "$report_contents" == *"private-stack-marker"* ]]; then
    privacy_result=leaked
else
    privacy_result=filtered
fi
record_result "filters configured private paths" "$privacy_result" filtered

set +e
overwrite_output="$(cyberops_main --no-color diagnostics export "$TEST_DIR/bundle.tar.gz" 2>&1)"
overwrite_status=$?
set -e
record_result "refuses to overwrite an archive" "$overwrite_status" 1
[[ "$overwrite_output" == *"already exists"* ]]
record_result "explains overwrite refusal" "$?" 0

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
