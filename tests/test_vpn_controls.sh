#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced menu code.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CYBEROPS_BUILTIN_PLUGIN_DIR="$REPO_DIR/plugins-available"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
commands=()
menu_rows=()
choice_index=0
choices=(1 1 0 0)

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
menu_item() { menu_rows+=("item:$1:$2:$3"); }
menu_privileged_item() { menu_rows+=("sudo:$1:$2:$3"); }
menu_navigation_item() { menu_rows+=("nav:$1:$2:$3"); }
pause() { :; }
prompt_choice() {
    local -n destination="$1"
    destination="${choices[$choice_index]}"
    ((choice_index += 1))
}
have() { [[ "$1" == "expressvpnctl" || "$1" == "tailscale" || "$1" == "sudo" ]]; }
require_commands() { have "$1"; }
run_checked() {
    shift 2
    commands+=("$*")
}
run_mutating_checked() {
    shift 2
    commands+=("$*")
}

vpn_menu >/dev/null
case "${menu_rows[*]}" in
    *"item:1:ExpressVPN:VPN // ExpressVPN"*"item:2:Mullvad VPN:VPN // Mullvad VPN"*"item:3:NordVPN:VPN // NordVPN"*"item:4:Proton VPN:VPN // Proton VPN"*"item:5:Tailscale:VPN // Tailscale"*) provider_menu=dynamic ;;
    *) provider_menu=static ;;
esac
record_result "VPN menu lists discovered provider plugins" "$provider_menu" dynamic
case "${menu_rows[*]}" in
    *"item:6:Install VPN plugins:VPN // PLUGIN CATALOG"*"item:7:Uninstall VPN plugins:VPN // USER PLUGINS"*) plugin_menus=separate ;;
    *) plugin_menus=missing ;;
esac
record_result "VPN menu separates plugin installation and removal" "$plugin_menus" separate
case "${menu_rows[*]}" in
    *"item:1:Status:VPN // STATUS"*"item:2:Connect:VPN // CONNECT"*"item:3:Disconnect:VPN // DISCONNECT"*"item:4:Background mode on:VPN // HEADLESS ENABLE"*"item:5:Background mode off:VPN // HEADLESS DISABLE"*) action_menu=plugin ;;
    *) action_menu=missing ;;
esac
record_result "VPN provider menu lists plugin-supported actions" "$action_menu" plugin
record_result "VPN provider menu keeps sudo markers action-specific" \
    "${commands[*]}" "expressvpnctl status"

commands=()
EXPRESSVPN_CLI=""
have() { [[ "$1" == "expressvpn" ]]; }
run_vpn_plugin_action expressvpn status >/dev/null
record_result "ExpressVPN selection retains the legacy v2 client fallback" \
    "${commands[*]}" "expressvpn status"

EXPRESSVPN_CLI="stale"
have() { return 1; }
set +e
missing_output="$(run_vpn_plugin_action expressvpn status 2>&1)"
missing_status=$?
set -e
record_result "ExpressVPN selection fails when neither CLI is installed" \
    "$missing_status" 1
if [[ "$missing_output" == *"expressvpnctl"* ]]; then
    missing_guidance=clear
else
    missing_guidance=unclear
fi
record_result "missing ExpressVPN guidance names the current CLI" \
    "$missing_guidance" clear

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
