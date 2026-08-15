#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Cross-module state and indirect mocks.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
CYBEROPS_SYS_CLASS_NET="$TEST_ROOT/sys/class/net"
CURL_LOG="$TEST_ROOT/curl.log"
tests_run=0
tests_failed=0
TAILSCALE_STATE=Running

cleanup() {
    if [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/* && -d "$TEST_ROOT" ]]; then
        rm -rf -- "$TEST_ROOT"
    fi
}
trap cleanup EXIT

# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

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

strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

mkdir -p -- "$CYBEROPS_SYS_CLASS_NET/eth0"
printf '%s\n' '02:42:ac:11:00:02' >"$CYBEROPS_SYS_CLASS_NET/eth0/address"
printf '%s\n' 'up' >"$CYBEROPS_SYS_CLASS_NET/eth0/operstate"
: >"$CURL_LOG"

have() {
    case "$1" in
        ip | curl | ethtool | tailscale | timeout) return 0 ;;
        *) return 1 ;;
    esac
}

ip() {
    case "$*" in
        '-o route show default') printf '%s\n' 'default via 192.0.2.1 dev eth0 proto dhcp' ;;
        '-o -4 address show dev eth0 scope global')
            printf '%s\n' '2: eth0    inet 192.0.2.25/24 brd 192.0.2.255 scope global eth0'
            ;;
        '-o -4 address show dev tailscale0 scope global')
            printf '%s\n' '7: tailscale0    inet 100.64.0.25/32 scope global tailscale0'
            ;;
        '-o -6 address show dev eth0 scope global') return 0 ;;
        '-o link show up')
            printf '%s\n' '2: eth0: <UP> mtu 1500' '7: tailscale0: <UP> mtu 1280'
            ;;
        '-o -d link show dev eth0') printf '%s\n' '2: eth0: <UP> mtu 1500' ;;
        *) return 1 ;;
    esac
}

ethtool() {
    [[ "$*" == '-P eth0' ]] || return 1
    printf '%s\n' 'Permanent address: 02:42:ac:11:00:02'
}

timeout() {
    shift
    "$@"
}

tailscale() {
    [[ "$*" == 'status --json' ]] || return 1
    printf '{"BackendState":"%s"}\n' "$TAILSCALE_STATE"
}

date() {
    case "$1" in
        +%s) printf '%s\n' 2000000000 ;;
        *) printf '%s\n' '2033-05-18 03:33:20 UTC' ;;
    esac
}

curl() {
    printf x >>"$CURL_LOG"
    printf '%s' '198.51.100.8'
}

CYBEROPS_HEADER_TELEMETRY=1
CYBEROPS_HEADER_PUBLIC_IP=0
collect_header_telemetry
record_result "discovers the primary routed interface" "$HEADER_IFACE" eth0
record_result "shows the primary local address without its prefix" "$HEADER_ADDRESS" 192.0.2.25
record_result "shows the current interface MAC address" "$HEADER_MAC" 02:42:ac:11:00:02
record_result "identifies a current permanent MAC address" "$HEADER_MAC_STATE" PERMANENT
record_result "reports local route availability without an external probe" "$HEADER_ROUTE_STATE" ROUTED
record_result "detects the running Tailscale backend" "$HEADER_VPN" tailscale0
record_result "shows the VPN interface local address" "$HEADER_VPN_ADDRESS" 100.64.0.25
TAILSCALE_STATE=Stopped
collect_header_telemetry
record_result "ignores a stale Tailscale interface after tailscale down" "$HEADER_VPN" NONE
record_result "clears the VPN address when disconnected" "$HEADER_VPN_ADDRESS" UNAVAILABLE
TAILSCALE_STATE=Running
record_result "keeps public-IP lookup disabled by default" "$(wc -c <"$CURL_LOG")" 0

CYBEROPS_HEADER_PUBLIC_IP=1
collect_header_telemetry
record_result "shows an explicitly enabled public IP" "$HEADER_PUBLIC_IP" 198.51.100.8
collect_header_telemetry
record_result "caches public-IP lookup between header redraws" "$(wc -c <"$CURL_LOG")" 1

CYBEROPS_PUBLIC_IP_CACHE=""
CYBEROPS_PUBLIC_IP_CACHE_TIME=0
: >"$CURL_LOG"
curl() {
    printf x >>"$CURL_LOG"
    return 28
}
collect_header_telemetry
failed_public_ip="$HEADER_PUBLIC_IP"
collect_header_telemetry
record_result "public-IP timeout leaves the header responsive" "$failed_public_ip" ""
record_result "caches public-IP failures between redraws" "$(wc -c <"$CURL_LOG")" 1

printf '%s\n' '02:42:ac:11:00:99' >"$CYBEROPS_SYS_CLASS_NET/eth0/address"
CYBEROPS_HEADER_PUBLIC_IP=0
collect_header_telemetry
record_result "identifies a MAC address differing from hardware" "$HEADER_MAC_STATE" MODIFIED
printf '%s\n' '02:42:ac:11:00:02' >"$CYBEROPS_SYS_CLASS_NET/eth0/address"

ip() {
    case "$*" in
        '-o route show default' | '-o link show up') return 0 ;;
        *) return 1 ;;
    esac
}
CYBEROPS_HEADER_PUBLIC_IP=0
TAILSCALE_STATE=Stopped
collect_header_telemetry
record_result "offline collection uses an unavailable interface marker" "$HEADER_IFACE" UNAVAILABLE
record_result "offline collection reports no local route" "$HEADER_ROUTE_STATE" OFFLINE
record_result "offline collection reports no detected VPN" "$HEADER_VPN" NONE

HEADER_TIME='2033-05-18 03:33:20 UTC'
HEADER_ROUTE_STATE=ROUTED
HEADER_VPN=tailscale0
HEADER_VPN_ADDRESS=100.64.0.25
HEADER_IFACE=eth0
HEADER_ADDRESS=192.0.2.25
HEADER_MAC=02:42:ac:11:00:02
HEADER_MAC_STATE=PERMANENT
HEADER_PUBLIC_IP=''
COLUMNS=50
narrow_output="$(render_header_telemetry | strip_ansi)"
if [[ "$narrow_output" == *'TIME // 2033-05-18'* &&
    "$narrow_output" == *'IP   // 192.0.2.25'* &&
    "$narrow_output" == *'VPN-IP // 100.64.0.25'* &&
    "$narrow_output" == *'CURRENT MAC'* &&
    "$narrow_output" == *'[PERMANENT // 02:42:ac:11:00:02]'* ]]; then
    narrow_result=readable
else
    narrow_result=broken
fi
record_result "narrow terminals receive split telemetry rows" "$narrow_result" readable

COLUMNS=80
vpn_row_output="$(render_header_telemetry | strip_ansi)"
local_row="$(printf '%s\n' "$vpn_row_output" | awk '/^LOCAL / { print; exit }')"
if [[ "$vpn_row_output" == *'VPN   // STATUS [ON // tailscale0] // LOCAL IP 100.64.0.25'* &&
    "$local_row" != *'VPN'* ]]; then
    vpn_row_result=dedicated
else
    vpn_row_result=embedded
fi
record_result "VPN status and local address use a dedicated row" "$vpn_row_result" dedicated
COLUMNS=50

saved_red="$RED"
saved_green="$GREEN"
saved_reset="$RESET"
RED='<RED>'
GREEN='<GREEN>'
RESET='<RESET>'
HEADER_VPN=NONE
vpn_off_output="$(render_vpn_badge)"
record_result "VPN off uses a bracketed red badge" "$vpn_off_output" '<RED>[OFF]<RESET>'
HEADER_VPN=tailscale0
vpn_on_output="$(render_vpn_badge)"
record_result "VPN on names the interface in a bracketed green badge" \
    "$vpn_on_output" '<GREEN>[ON // tailscale0]<RESET>'
HEADER_MAC_STATE=PERMANENT
permanent_badge_output="$(render_mac_badge)"
record_result "permanent MAC uses a bracketed red badge" \
    "$permanent_badge_output" '<RED>[PERMANENT // 02:42:ac:11:00:02]<RESET>'
HEADER_MAC_STATE=MODIFIED
modified_badge_output="$(render_mac_badge)"
record_result "modified MAC uses a bracketed green badge" \
    "$modified_badge_output" '<GREEN>[MODIFIED // 02:42:ac:11:00:02]<RESET>'
RED="$saved_red"
GREEN="$saved_green"
RESET="$saved_reset"
HEADER_MAC_STATE=PERMANENT

CYBEROPS_HEADER_MAC=0
mac_hidden_output="$(render_header_telemetry)"
if [[ "$mac_hidden_output" != *'CURRENT MAC'* ]]; then
    mac_toggle_result=hidden
else
    mac_toggle_result=visible
fi
record_result "individual header fields can be disabled" "$mac_toggle_result" hidden
CYBEROPS_HEADER_MAC=1

disable_color
no_color_output="$(render_header_telemetry)"
if [[ "$no_color_output" == *'CURRENT MAC [PERMANENT // 02:42:ac:11:00:02]'* &&
    "$no_color_output" != *$'\033['* ]]; then
    no_color_result=readable
else
    no_color_result=broken
fi
record_result "header remains readable without color" "$no_color_result" readable

CYBEROPS_HEADER_TELEMETRY=0
disabled_output="$(render_header_telemetry)"
record_result "header telemetry can be disabled completely" "$disabled_output" ""

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
