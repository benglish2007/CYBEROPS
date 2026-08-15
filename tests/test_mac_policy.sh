#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2329 # Mocks are invoked by sourced module code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
NMCLI_MODE=active

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

have() { return 0; }

strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

nmcli() {
    case "$*" in
        '-g UUID connection show --active')
            case "$NMCLI_MODE" in
                active) printf '%s\n' wifi-uuid ethernet-uuid vpn-uuid ;;
                empty) return 0 ;;
                failure) return 10 ;;
            esac
            ;;
        '-g connection.id connection show wifi-uuid') printf 'Neon WiFi\n' ;;
        '-g connection.type connection show wifi-uuid') printf '802-11-wireless\n' ;;
        '-g GENERAL.DEVICES connection show wifi-uuid') printf 'wlan0\n' ;;
        '-g 802-11-wireless.cloned-mac-address connection show wifi-uuid') printf 'random\n' ;;
        '-g connection.id connection show ethernet-uuid') printf 'Wired Grid\n' ;;
        '-g connection.type connection show ethernet-uuid') printf '802-3-ethernet\n' ;;
        '-g GENERAL.DEVICES connection show ethernet-uuid') printf 'eth0\n' ;;
        '-g 802-3-ethernet.cloned-mac-address connection show ethernet-uuid') return 0 ;;
        '-g connection.id connection show vpn-uuid') printf 'Tailscale\n' ;;
        '-g connection.type connection show vpn-uuid') printf 'tun\n' ;;
        '-g GENERAL.DEVICES connection show vpn-uuid') printf 'tailscale0\n' ;;
        *) return 1 ;;
    esac
}

record_result "maps Wi-Fi profiles to the wireless cloned-MAC property" \
    "$(mac_policy_property_for_type 802-11-wireless)" \
    "802-11-wireless.cloned-mac-address"
record_result "maps Ethernet profiles to the wired cloned-MAC property" \
    "$(mac_policy_property_for_type 802-3-ethernet)" \
    "802-3-ethernet.cloned-mac-address"

set +e
mac_policy_property_for_type tun >/dev/null 2>&1
unsupported_status=$?
set -e
record_result "rejects unsupported connection types" "$unsupported_status" 1

policy_output="$(show_mac_address_policies)"
if [[ "$policy_output" == *"Neon WiFi"* &&
    "$policy_output" == *"wlan0"* &&
    "$policy_output" == *"random"* ]]; then
    wifi_result=shown
else
    wifi_result=missing
fi
record_result "shows the active Wi-Fi MAC policy" "$wifi_result" shown

if [[ "$policy_output" == *"Wired Grid"* &&
    "$policy_output" == *"eth0"* &&
    "$policy_output" == *"default"* ]]; then
    ethernet_result=shown
else
    ethernet_result=missing
fi
record_result "labels an unset Ethernet policy as default" "$ethernet_result" shown

if [[ "$policy_output" == *"Tailscale"* &&
    "$policy_output" == *"not applicable"* ]]; then
    unsupported_result=shown
else
    unsupported_result=missing
fi
record_result "labels unsupported active profile types without mutation" \
    "$unsupported_result" shown

NMCLI_MODE=empty
empty_output="$(show_mac_address_policies | strip_ansi)"
record_result "reports when NetworkManager has no active profiles" \
    "$empty_output" "[!] No active NetworkManager connections were found."

NMCLI_MODE=failure
set +e
failure_output="$(show_mac_address_policies 2>&1)"
failure_status=$?
set -e
record_result "preserves NetworkManager query failures" "$failure_status" 1
if [[ "$failure_output" == *"Unable to query active NetworkManager connections."* &&
    "$failure_output" == *"nmcli connection show --active"* ]]; then
    failure_message=actionable
else
    failure_message=unclear
fi
record_result "provides recovery guidance for policy-query failures" \
    "$failure_message" actionable

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
