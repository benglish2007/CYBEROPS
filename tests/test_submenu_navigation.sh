#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329 # Mocks are invoked indirectly by sourced menu code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
return_item_seen=0

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
menu_item() {
    if [[ "$1" == "0" && "$2" == "Return to control deck" ]]; then
        return_item_seen=1
    fi
}
prompt_choice() {
    local -n destination="$1"
    destination=0
}

submenu_functions=(
    admin_menu
    info_menu
    vpn_menu
    cyber_defense_menu
    quickhacks_menu
    docker_menu
    usb_menu
)

for submenu_function in "${submenu_functions[@]}"; do
    return_item_seen=0
    if "$submenu_function" >/dev/null 2>&1; then
        submenu_status=returned
    else
        submenu_status=failed
    fi
    record_result "$submenu_function returns on selection zero" "$submenu_status" returned
    record_result "$submenu_function labels zero as control-deck return" \
        "$return_item_seen" 1
done

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
