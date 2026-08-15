#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0
MOCK_SUDO_RESULT=0
SUDO_CALLS=()

sudo() {
    SUDO_CALLS+=("$*")
    return "$MOCK_SUDO_RESULT"
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

begin_operation "Test operation" "Test warning"
record_result "records active operation context" "$ACTIVE_OPERATION" "Test operation"
record_result "records interruption guidance" "$INTERRUPT_WARNING" "Test warning"
end_operation
record_result "clears completed operation context" \
    "$ACTIVE_OPERATION|$INTERRUPT_WARNING" "|"

register_network_restore eth0 1
if perform_registered_cleanup >/dev/null 2>&1; then
    cleanup_result=success
else
    cleanup_result=failure
fi
record_result "restores a registered interface" "$cleanup_result" success
record_result "uses the expected interface restoration command" \
    "${SUDO_CALLS[*]}" "ip link set dev eth0 up"
record_result "clears restoration state before running cleanup" \
    "$NETWORK_RESTORE_INTERFACE" ""

SUDO_CALLS=()
register_network_restore eth0 0
perform_registered_cleanup >/dev/null 2>&1
record_result "does not raise an interface that was originally down" \
    "${SUDO_CALLS[*]}" ""

set +e
signal_output="$(
    ACTIVE_OPERATION="USB test write"
    INTERRUPT_WARNING="USB test warning"
    handle_signal INT 2>&1
)"
signal_status=$?
set -e
record_result "SIGINT exits with status 130" "$signal_status" 130
if [[ "$signal_output" == *"USB test write"* &&
    "$signal_output" == *"USB test warning"* ]]; then
    signal_context=reported
else
    signal_context=missing
fi
record_result "SIGINT reports operation context and recovery warning" \
    "$signal_context" reported

set +e
(
    handle_signal TERM
) >/dev/null 2>&1
signal_status=$?
set -e
record_result "SIGTERM exits with status 143" "$signal_status" 143

set +e
cleanup_output="$(
    NETWORK_RESTORE_INTERFACE=eth9
    install_signal_handlers
    handle_signal INT 2>&1
)"
signal_status=$?
set -e
record_result "installed EXIT cleanup preserves signal status" "$signal_status" 130
if [[ "$cleanup_output" == *"Restoring network interface eth9"* ]]; then
    exit_cleanup=ran
else
    exit_cleanup=missing
fi
record_result "signal exit invokes registered cleanup" "$exit_cleanup" ran

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
