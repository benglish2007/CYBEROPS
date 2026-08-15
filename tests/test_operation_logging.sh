#!/usr/bin/env bash
# shellcheck disable=SC2034 # Runtime globals are consumed by dynamically loaded helpers.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

TEST_ROOT="$(mktemp -d)"
CYBEROPS_STATE_DIR="$TEST_ROOT/state"
CYBEROPS_LOG_FILE="$CYBEROPS_STATE_DIR/operations.log"
CYBEROPS_LOGGING=1
CYBEROPS_LOG_ACTIVE=1
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

run_checked "Read-only probe" "none" true
set +e
run_checked "Expected failure" "none" false >/dev/null 2>&1
set -e

if [[ -f "$CYBEROPS_LOG_FILE" ]] &&
    grep -Fq $'level=info\tstatus=0\taction=Read-only probe' "$CYBEROPS_LOG_FILE" &&
    grep -Fq $'level=error\tstatus=1\taction=Expected failure' "$CYBEROPS_LOG_FILE"; then
    event_result=recorded
else
    event_result=missing
fi
record_result "structured log records success and failure outcomes" "$event_result" recorded

record_result "state directory uses private permissions" \
    "$(stat -c '%a' "$CYBEROPS_STATE_DIR")" 700
record_result "operation log uses private permissions" \
    "$(stat -c '%a' "$CYBEROPS_LOG_FILE")" 600

run_checked "Secret-free action" "none" true super-secret-argument
if grep -Fq 'super-secret-argument' "$CYBEROPS_LOG_FILE"; then
    privacy_result=leaked
else
    privacy_result=protected
fi
record_result "structured log excludes raw command arguments" "$privacy_result" protected

tail_output="$(show_operation_log_tail)"
if [[ "$tail_output" == *"Secret-free action"* ]]; then
    tail_result=shown
else
    tail_result=missing
fi
record_result "log tail command exposes recorded events" "$tail_result" shown

CYBEROPS_LOGGING=0
line_count_before="$(wc -l <"$CYBEROPS_LOG_FILE")"
write_operation_log info "Disabled event" 0
line_count_after="$(wc -l <"$CYBEROPS_LOG_FILE")"
record_result "logging can be disabled through configuration" "$line_count_after" "$line_count_before"

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
