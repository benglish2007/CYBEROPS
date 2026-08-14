#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0
MOCK_INTERFACE_UP=1
MOCK_MACCHANGER_RESULT=1
CALL_LOG=()

have() {
    return 0
}

# The test's sudo() shim invokes these mock functions in the current shell.
# shellcheck disable=SC2032
ip() {
    if [[ "$1 $2" == "link show" ]]; then
        if [[ "$MOCK_INTERFACE_UP" == "1" ]]; then
            printf '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500\n'
        else
            printf '2: eth0: <BROADCAST,MULTICAST> mtu 1500\n'
        fi
        return 0
    fi

    CALL_LOG+=("ip $*")
    return 0
}

# shellcheck disable=SC2032
macchanger() {
    CALL_LOG+=("macchanger $*")
    return "$MOCK_MACCHANGER_RESULT"
}

sudo() {
    "$@"
}

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

if randomize_mac_address eth0 >/dev/null 2>&1; then
    mac_result=success
else
    mac_result=failure
fi
record_result "reports a failed MAC change" "$mac_result" failure

calls=" ${CALL_LOG[*]} "
if [[ "$calls" == *" ip link set dev eth0 down "* &&
      "$calls" == *" macchanger -r eth0 "* &&
      "$calls" == *" ip link set dev eth0 up "* ]]; then
    restore_result=restored
else
    restore_result=missing
fi
record_result "restores an originally-up interface after failure" "$restore_result" restored

MOCK_INTERFACE_UP=0
MOCK_MACCHANGER_RESULT=0
CALL_LOG=()

if randomize_mac_address eth0 >/dev/null 2>&1; then
    mac_result=success
else
    mac_result=failure
fi
record_result "accepts a successful MAC change" "$mac_result" success

calls=" ${CALL_LOG[*]} "
if [[ "$calls" == *" ip link set dev eth0 up "* ]]; then
    down_state_result=restored-up
else
    down_state_result=left-down
fi
record_result "preserves an originally-down interface state" "$down_state_result" left-down

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
