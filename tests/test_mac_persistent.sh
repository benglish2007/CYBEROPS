#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced module code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$(mktemp -d)"
OUTPUT_FILE="$TEST_DIR/output"
trap 'rm -f -- "$OUTPUT_FILE"; rmdir -- "$TEST_DIR"' EXIT
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
NMCLI_MODE=normal
DRY_RUN=0
CALL_LOG=()

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
sudo() { "$@"; }

nmcli() {
    case "$*" in
        '-g UUID connection show')
            if [[ "$NMCLI_MODE" == "unsupported-only" ]]; then
                printf 'vpn-uuid\n'
            else
                printf '%s\n' ethernet-uuid wifi-uuid vpn-uuid
            fi
            ;;
        '-g connection.id connection show ethernet-uuid') printf 'Wired Grid\n' ;;
        '-g connection.type connection show ethernet-uuid') printf '802-3-ethernet\n' ;;
        '-g GENERAL.DEVICES connection show ethernet-uuid') printf 'enp7s0\n' ;;
        '-g 802-3-ethernet.cloned-mac-address connection show ethernet-uuid') printf 'default\n' ;;
        '-g connection.id connection show wifi-uuid') printf 'Neon WiFi\n' ;;
        '-g connection.type connection show wifi-uuid') printf '802-11-wireless\n' ;;
        '-g GENERAL.DEVICES connection show wifi-uuid') printf '%s\n' -- ;;
        '-g 802-11-wireless.cloned-mac-address connection show wifi-uuid') printf 'stable\n' ;;
        '-g connection.id connection show vpn-uuid') printf 'Tailscale\n' ;;
        '-g connection.type connection show vpn-uuid') printf 'tun\n' ;;
        '-g GENERAL.DEVICES connection show vpn-uuid') printf 'tailscale0\n' ;;
        'connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address random' | 'connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address permanent')
            CALL_LOG+=("nmcli $*")
            ;;
        *) return 1 ;;
    esac
}

select_mac_connection >"$OUTPUT_FILE" <<<'1'
record_result "selects a supported profile by stable UUID" \
    "$SELECTED_MAC_CONNECTION_UUID" ethernet-uuid
selection_output="$(<"$OUTPUT_FILE")"
if [[ "$selection_output" == *"Wired Grid"* &&
    "$selection_output" == *"Neon WiFi"* &&
    "$selection_output" != *"Tailscale"* ]]; then
    profile_filter=safe
else
    profile_filter=unsafe
fi
record_result "offers only supported wired and wireless profiles" "$profile_filter" safe
record_result "labels inactive supported profiles" \
    "${selection_output//*device=inactive*/inactive}" inactive

select_mac_connection 1 >"$OUTPUT_FILE" <<<'1'
active_selection_output="$(<"$OUTPUT_FILE")"
if [[ "$active_selection_output" == *"Wired Grid"* &&
    "$active_selection_output" != *"Neon WiFi"* ]]; then
    active_filter=safe
else
    active_filter=unsafe
fi
record_result "immediate operations offer only active supported profiles" \
    "$active_filter" safe

randomize_mac_address() {
    SELECTED_RANDOMIZE_DEVICE="$1"
}
SELECTED_RANDOMIZE_DEVICE=""
randomize_selected_mac_for_session >"$OUTPUT_FILE" <<<'1'
record_result "temporary randomization resolves the selected active device" \
    "$SELECTED_RANDOMIZE_DEVICE" enp7s0

CALL_LOG=()
set_mac_connection_policy ethernet-uuid random >/dev/null
record_result "enables randomization only on the selected UUID" \
    "${CALL_LOG[*]}" \
    "nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address random"

CALL_LOG=()
set_mac_connection_policy ethernet-uuid permanent >/dev/null
record_result "disables randomization with the permanent-address policy" \
    "${CALL_LOG[*]}" \
    "nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address permanent"

CALL_LOG=()
set +e
set_mac_connection_policy vpn-uuid random >/dev/null 2>&1
unsupported_status=$?
set -e
record_result "rejects persistent changes for unsupported profile types" \
    "$unsupported_status" 1
record_result "unsupported profile rejection performs no mutation" "${#CALL_LOG[@]}" 0

NMCLI_MODE=unsupported-only
set +e
select_mac_connection >/dev/null <<<'1'
unsupported_selection_status=$?
set -e
record_result "fails closed when no supported profiles exist" \
    "$unsupported_selection_status" 1
NMCLI_MODE=normal

CALL_LOG=()
DRY_RUN=1
dry_run_output="$(set_mac_connection_policy ethernet-uuid random)"
if [[ "$dry_run_output" == *"[ SIMULATION ]"* &&
    "$dry_run_output" == *"connection modify ethernet-uuid"* ]]; then
    dry_run_result=previewed
else
    dry_run_result=missing
fi
record_result "dry-run previews the persistent policy mutation" \
    "$dry_run_result" previewed
record_result "dry-run performs no NetworkManager mutation" "${#CALL_LOG[@]}" 0

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
