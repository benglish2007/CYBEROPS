#!/usr/bin/env bash

# CYBEROPS_THEME is intentionally changed to exercise sourced UI helpers.
# shellcheck disable=SC2034

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

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

strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

successful_command() {
    printf 'command output\n'
    return 0
}

failing_command() {
    return 37
}

show_arguments() {
    printf '%s|%s|%s\n' "$1" "$2" "$3"
}

set +e
success_output="$(run_checked "Successful action" "No recovery needed." successful_command 2>&1)"
success_status=$?
set -e
record_result "checked success preserves status 0" "$success_status" 0
record_result "checked success preserves command output" "$success_output" "command output"

set +e
failure_output="$(run_checked "Test action" "Apply the test recovery." failing_command 2>&1)"
failure_status=$?
set -e
record_result "checked failure preserves the command exit status" "$failure_status" 37
failure_output="$(printf '%s\n' "$failure_output" | strip_ansi)"

if [[ "$failure_output" == *"Test action failed (exit status 37)."* ]]; then
    action_result=reported
else
    action_result=missing
fi
record_result "checked failure identifies the action and exit status" "$action_result" reported

if [[ "$failure_output" == *"RECOVERY:: Apply the test recovery."* ]]; then
    recovery_result=reported
else
    recovery_result=missing
fi
record_result "checked failure provides a recovery step" "$recovery_result" reported

# shellcheck disable=SC2016
literal_argument='$(not executed)'
argument_output="$(run_checked "Argument test" "" show_arguments "one two" "$literal_argument" three)"
record_result "checked command forwards arguments without evaluation" \
    "$argument_output" "one two|${literal_argument}|three"

success_message="$(report_success "Operation complete" | strip_ansi)"
if [[ "$success_message" == *"[ ACK ] Operation complete"* ]]; then
    format_result=standard
else
    format_result=unexpected
fi
record_result "success reports use the standard marker" "$format_result" standard

warning_message="$(report_warning "Review required" | strip_ansi)"
error_message="$(report_error "Operation failed" "Retry safely" | strip_ansi)"
preview_message="$(preview_command "Inspect mutation" printf payload | strip_ansi)"
if [[ "$warning_message" == *"[ CAUTION ] Review required"* &&
    "$error_message" == *"[ FAULT ] Operation failed"* &&
    "$error_message" == *"RECOVERY:: Retry safely"* &&
    "$preview_message" == *"[ SIMULATION ] Inspect mutation"* &&
    "$preview_message" == *"PAYLOAD:: printf payload"* ]]; then
    overdrive_signals=consistent
else
    overdrive_signals=mixed
fi
record_result "overdrive feedback uses a consistent signal vocabulary" \
    "$overdrive_signals" consistent

CYBEROPS_THEME=classic
classic_success="$(report_success "Operation complete" | strip_ansi)"
record_result "classic feedback marker remains available" \
    "$classic_success" "[OK] Operation complete"
CYBEROPS_THEME=neon-overdrive

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
