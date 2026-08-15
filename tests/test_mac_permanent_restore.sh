#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced module code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
DRY_RUN=0
FAIL_ACTION=""
CURRENT_MAC="02:42:ac:11:00:02"
PERMANENT_MAC="00:11:22:33:44:55"
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
telemetry_current_mac() { printf '%s' "$CURRENT_MAC"; }
telemetry_permanent_mac() { printf '%s' "$PERMANENT_MAC"; }

ip() {
    CALL_LOG+=("ip $*")
    [[ "$FAIL_ACTION" != "link-down" ]]
}

nmcli() {
    case "$*" in
        '-g connection.id connection show ethernet-uuid') printf 'Wired Grid\n' ;;
        '-g connection.type connection show ethernet-uuid') printf '802-3-ethernet\n' ;;
        '-g GENERAL.DEVICES connection show ethernet-uuid') printf 'enp7s0\n' ;;
        '-g 802-3-ethernet.cloned-mac-address connection show ethernet-uuid') printf 'random\n' ;;
        'connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address permanent')
            CALL_LOG+=("nmcli $*")
            [[ "$FAIL_ACTION" != "modify" ]]
            ;;
        'connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address random')
            CALL_LOG+=("nmcli $*")
            return 0
            ;;
        'connection down ethernet-uuid')
            CALL_LOG+=("nmcli $*")
            [[ "$FAIL_ACTION" != "down" ]]
            ;;
        'connection up ethernet-uuid')
            CALL_LOG+=("nmcli $*")
            if [[ "$FAIL_ACTION" == "up" ]]; then
                FAIL_ACTION=""
                return 1
            fi
            CURRENT_MAC="$PERMANENT_MAC"
            ;;
        *) return 1 ;;
    esac
}

macchanger() {
    CALL_LOG+=("macchanger $*")
    [[ "$FAIL_ACTION" != "macchanger" ]]
}

restore_permanent_mac_now ethernet-uuid >/dev/null
expected_success="nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address permanent nmcli connection down ethernet-uuid ip link set dev enp7s0 down macchanger -p enp7s0 nmcli connection up ethernet-uuid"
record_result "restores the selected active profile immediately" \
    "${CALL_LOG[*]}" "$expected_success"
record_result "clears connection recovery state after success" \
    "$NETWORK_CONNECTION_RESTORE_UUID|$NETWORK_CONNECTION_REACTIVATE" "|0"

CALL_LOG=()
CURRENT_MAC="02:42:ac:11:00:02"
FAIL_ACTION=macchanger
set +e
restore_permanent_mac_now ethernet-uuid >/dev/null 2>&1
restore_status=$?
set -e
record_result "reports a hardware restoration failure" "$restore_status" 1
expected_rollback="nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address permanent nmcli connection down ethernet-uuid ip link set dev enp7s0 down macchanger -p enp7s0 nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address random nmcli connection up ethernet-uuid"
record_result "rolls back policy and reconnects after restoration failure" \
    "${CALL_LOG[*]}" "$expected_rollback"

CALL_LOG=()
CURRENT_MAC="02:42:ac:11:00:02"
FAIL_ACTION=up
set +e
restore_permanent_mac_now ethernet-uuid >/dev/null 2>&1
restore_status=$?
set -e
record_result "reports an initial reactivation failure" "$restore_status" 1
expected_recovery="nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address permanent nmcli connection down ethernet-uuid ip link set dev enp7s0 down macchanger -p enp7s0 nmcli connection up ethernet-uuid nmcli connection modify ethernet-uuid 802-3-ethernet.cloned-mac-address random nmcli connection up ethernet-uuid"
record_result "restores the prior policy and retries activation" \
    "${CALL_LOG[*]}" "$expected_recovery"

CALL_LOG=()
CURRENT_MAC="02:42:ac:11:00:02"
FAIL_ACTION=""
DRY_RUN=1
dry_output="$(restore_permanent_mac_now ethernet-uuid)"
if [[ "$dry_output" == *"Set permanent MAC policy"* &&
    "$dry_output" == *"Deactivate Wired Grid"* &&
    "$dry_output" == *"ip link set dev enp7s0 down"* &&
    "$dry_output" == *"macchanger -p enp7s0"* &&
    "$dry_output" == *"Reactivate Wired Grid"* ]]; then
    dry_result=complete
else
    dry_result=incomplete
fi
record_result "dry-run previews the complete restoration sequence" "$dry_result" complete
record_result "dry-run performs no restoration mutation" "${#CALL_LOG[@]}" 0

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
