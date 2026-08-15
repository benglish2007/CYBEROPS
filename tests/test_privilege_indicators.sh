#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced menu code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
current_menu=""
privileged_rows=()

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
menu_privileged_item() {
    privileged_rows+=("$current_menu:$1:$2")
}
prompt_choice() {
    local -n destination="$1"
    destination=0
}

current_menu="admin"
admin_menu >/dev/null
current_menu="vpn"
vpn_menu >/dev/null
current_menu="security"
cyber_defense_menu >/dev/null
current_menu="quickhacks"
quickhacks_menu >/dev/null
current_menu="mac"
mac_address_menu >/dev/null
current_menu="docker"
docker_menu >/dev/null
current_menu="usb"
usb_menu >/dev/null
current_menu="info"
info_menu >/dev/null

expected_rows=(
    "admin:1:Update package lists"
    "admin:2:Upgrade installed packages"
    "admin:7:Reboot system"
    "vpn:2:Tailscale up"
    "vpn:3:Tailscale down"
    "security:1:UFW status"
    "security:2:Enable UFW"
    "security:3:Disable UFW"
    "security:5:rkhunter check"
    "security:6:Recent failed SSH logins"
    "quickhacks:3:Wi-Fi analyzer"
    "quickhacks:5:Flush DNS cache"
    "quickhacks:7:MAC address controls"
    "mac:2:Randomize MAC for this session"
    "mac:3:Enable automatic MAC randomization"
    "mac:4:Disable automatic MAC randomization"
    "mac:5:Restore permanent MAC now"
    "usb:1:Create bootable USB from ISO"
    "usb:2:Quick reset USB signatures"
    "usb:3:Wipe / zero-fill USB drive"
)

record_result "marks every audited sudo-backed menu operation" \
    "${privileged_rows[*]}" "${expected_rows[*]}"

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
