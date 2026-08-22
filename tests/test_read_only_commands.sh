#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced feature helpers.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
checked_command=""

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

require_commands() { return 0; }
run_checked() {
    shift 2
    checked_command="$*"
}

show_memory_usage
record_result "memory telemetry uses free" "$checked_command" "free -h"
show_running_services
record_result "service telemetry uses a bounded no-pager query" "$checked_command" \
    "systemctl --type=service --state=running --no-pager"
show_failed_services
record_result "failure telemetry uses systemd's failed-unit query" "$checked_command" \
    "systemctl --failed --no-pager"
show_storage_devices
record_result "storage telemetry exposes the documented block fields" "$checked_command" \
    "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,TRAN"
show_network_interfaces
record_result "interface telemetry uses concise local addresses" "$checked_command" \
    "ip -brief address"
show_routing_table
record_result "route telemetry uses the local route table" "$checked_command" "ip route"
show_listening_sockets
record_result "socket telemetry limits output to listening sockets" "$checked_command" "ss -tulpn"

vpn_commands=()
have() { [[ "$1" == "tailscale" || "$1" == "expressvpnctl" || "$1" == "expressvpn" ]]; }
run_checked() {
    shift 2
    vpn_commands+=("$*")
}
show_vpn_status >/dev/null
record_result "combined VPN status queries each installed supported client" \
    "${vpn_commands[*]}" "tailscale status expressvpnctl status"

vpn_commands=()
have() { [[ "$1" == "expressvpn" ]]; }
show_vpn_status >/dev/null
record_result "combined VPN status retains legacy ExpressVPN CLI fallback" \
    "${vpn_commands[*]}" "expressvpn status"

have() { return 1; }
set +e
vpn_missing_output="$(show_vpn_status 2>&1)"
vpn_missing_status=$?
set -e
record_result "VPN status fails when no supported client exists" "$vpn_missing_status" 1
if [[ "$vpn_missing_output" == *"No supported VPN client is installed"* ]]; then
    vpn_guidance=clear
else
    vpn_guidance=missing
fi
record_result "VPN status explains the missing-client condition" "$vpn_guidance" clear

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
