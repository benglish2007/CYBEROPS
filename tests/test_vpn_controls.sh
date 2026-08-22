#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced menu code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
choice_index=0
choices=(4 5 6 7 8 0)
commands=()

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

banner() { :; }
ui_section() { :; }
menu_item() { :; }
menu_navigation_item() { :; }
pause() { :; }
prompt_choice() {
    local -n destination="$1"
    destination="${choices[$choice_index]}"
    ((choice_index += 1))
}
have() { [[ "$1" == "expressvpnctl" ]]; }
require_commands() {
    [[ "$1" == "expressvpnctl" ]]
}
run_checked() {
    shift 2
    commands+=("$*")
}
run_mutating_checked() {
    shift 2
    commands+=("$*")
}

vpn_menu >/dev/null
record_result "ExpressVPN menu uses the current expressvpnctl command set" \
    "${commands[*]}" \
    "expressvpnctl status expressvpnctl connect expressvpnctl disconnect expressvpnctl background enable expressvpnctl background disable"

EXPRESSVPN_CLI=""
have() { [[ "$1" == "expressvpn" ]]; }
select_expressvpn_cli >/dev/null
record_result "ExpressVPN selection retains the legacy v2 client fallback" \
    "$EXPRESSVPN_CLI" expressvpn

EXPRESSVPN_CLI="stale"
have() { return 1; }
set +e
select_expressvpn_cli >/dev/null 2>&1
missing_status=$?
set -e
record_result "ExpressVPN selection fails when neither CLI is installed" \
    "$missing_status" 1
missing_output="$(select_expressvpn_cli 2>&1 || true)"
if [[ "$missing_output" == *"expressvpnctl"* && -z "$EXPRESSVPN_CLI" ]]; then
    missing_guidance=clear
else
    missing_guidance=unclear
fi
record_result "missing ExpressVPN guidance names the current CLI" \
    "$missing_guidance" clear

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
