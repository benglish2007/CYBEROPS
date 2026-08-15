#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329 # Mocks are invoked indirectly by sourced menu code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
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

run_menu_sequence() {
    local -a choices=(0 1 2 3 4 5 6 7 8)
    local choice_index=0

    banner() { :; }
    ui_section() { :; }
    menu_item() { :; }
    prompt_choice() {
        local -n destination="$1"
        destination="${choices[choice_index]}"
        ((choice_index += 1))
    }
    system_setup() { printf 'system_setup\n'; }
    admin_menu() { printf 'admin_menu\n'; }
    info_menu() { printf 'info_menu\n'; }
    vpn_menu() { printf 'vpn_menu\n'; }
    cyber_defense_menu() { printf 'cyber_defense_menu\n'; }
    quickhacks_menu() { printf 'quickhacks_menu\n'; }
    docker_menu() { printf 'docker_menu\n'; }
    usb_menu() { printf 'usb_menu\n'; }
    typewrite() { printf '%s\n' "$1"; }

    main_menu
}

set +e
dispatch_output="$(run_menu_sequence 2>&1)"
dispatch_status=$?
set -e
record_result "main menu exits successfully after dispatch sequence" "$dispatch_status" 0

expected_dispatches=(
    system_setup
    admin_menu
    info_menu
    vpn_menu
    cyber_defense_menu
    quickhacks_menu
    docker_menu
    usb_menu
)
for expected_dispatch in "${expected_dispatches[@]}"; do
    if [[ "$dispatch_output" == *"$expected_dispatch"* ]]; then
        dispatch_result=called
    else
        dispatch_result=missing
    fi
    record_result "dispatches $expected_dispatch" "$dispatch_result" called
done

if [[ "$dispatch_output" == *"LINK TERMINATED"* ]]; then
    exit_result=shown
else
    exit_result=missing
fi
record_result "shows the disconnect message" "$exit_result" shown

run_invalid_selection() {
    local -a choices=(invalid 8)
    local choice_index=0

    banner() { :; }
    ui_section() { :; }
    menu_item() { :; }
    prompt_choice() {
        local -n destination="$1"
        destination="${choices[choice_index]}"
        ((choice_index += 1))
    }
    invalid_selection() { printf 'invalid_selection\n'; }
    typewrite() { :; }

    main_menu
}

set +e
invalid_output="$(run_invalid_selection 2>&1)"
invalid_status=$?
set -e
record_result "invalid selection path still permits a clean exit" "$invalid_status" 0
record_result "dispatches invalid selections to the UI helper" "$invalid_output" invalid_selection

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
