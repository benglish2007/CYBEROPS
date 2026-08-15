#!/usr/bin/env bash

# Header state is written here and consumed by the separately loaded UI module.
# shellcheck disable=SC2034

# Header telemetry contract
# -------------------------
# Inputs:
#   Header configuration and cache state from lib/runtime.sh.
# Outputs:
#   Fast, read-only local status values for the interactive banner.
# Side effects:
#   Optional public-IP discovery contacts api.ipify.org only when explicitly
#   enabled and caches the result in memory for the configured interval.

telemetry_primary_interface() {
    have ip || return 1
    ip -o route show default 2>/dev/null |
        awk '{ for (field = 1; field <= NF; field++) if ($field == "dev") { print $(field + 1); exit } }'
}

telemetry_interface_address() {
    local iface="$1"
    local address

    [[ "$iface" =~ ^[[:alnum:]_.:-]+$ ]] || return 1
    address="$(ip -o -4 address show dev "$iface" scope global 2>/dev/null |
        awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }')"
    if [[ -z "$address" ]]; then
        address="$(ip -o -6 address show dev "$iface" scope global 2>/dev/null |
            awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }')"
    fi
    [[ -n "$address" ]] || return 1
    printf '%s' "$address"
}

telemetry_current_mac() {
    local iface="$1"
    local mac_file
    local mac

    [[ "$iface" =~ ^[[:alnum:]_.:-]+$ ]] || return 1
    mac_file="${CYBEROPS_SYS_CLASS_NET:-/sys/class/net}/$iface/address"
    [[ -r "$mac_file" ]] || return 1
    IFS= read -r mac <"$mac_file" || return 1
    [[ "$mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || return 1
    printf '%s' "${mac,,}"
}

telemetry_permanent_mac() {
    local iface="$1"
    local permanent_file
    local permanent_mac=""

    [[ "$iface" =~ ^[[:alnum:]_.:-]+$ ]] || return 1
    permanent_file="${CYBEROPS_SYS_CLASS_NET:-/sys/class/net}/$iface/perm_address"
    if [[ -r "$permanent_file" ]]; then
        IFS= read -r permanent_mac <"$permanent_file" || permanent_mac=""
    fi
    if [[ ! "$permanent_mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ||
        "$permanent_mac" == "00:00:00:00:00:00" ]]; then
        permanent_mac="$(ip -o -d link show dev "$iface" 2>/dev/null |
            awk '{ for (field = 1; field <= NF; field++) if ($field == "permaddr") { print $(field + 1); exit } }')"
    fi
    if [[ ! "$permanent_mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ||
        "$permanent_mac" == "00:00:00:00:00:00" ]]; then
        if have ethtool; then
            permanent_mac="$(ethtool -P "$iface" 2>/dev/null |
                awk '/Permanent address:/ { print $3; exit }')"
        fi
    fi
    [[ "$permanent_mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ &&
        "$permanent_mac" != "00:00:00:00:00:00" ]] || return 1
    printf '%s' "${permanent_mac,,}"
}

telemetry_route_state() {
    local iface="$1"
    local state_file
    local state

    [[ "$iface" =~ ^[[:alnum:]_.:-]+$ ]] || {
        printf 'OFFLINE'
        return 0
    }
    state_file="${CYBEROPS_SYS_CLASS_NET:-/sys/class/net}/$iface/operstate"
    if [[ -r "$state_file" ]]; then
        IFS= read -r state <"$state_file" || state=""
        if [[ "$state" != "up" && "$state" != "unknown" ]]; then
            printf 'LINK DOWN'
            return 0
        fi
    fi
    printf 'ROUTED'
}

telemetry_vpn_interface() {
    local iface
    local tailscale_status

    have ip || return 1
    if have tailscale && have timeout; then
        tailscale_status="$(timeout "${CYBEROPS_HEADER_TIMEOUT}s" \
            tailscale status --json 2>/dev/null || true)"
        if grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"' \
            <<<"$tailscale_status"; then
            printf 'tailscale0'
            return 0
        fi
    fi
    while IFS= read -r iface; do
        iface="${iface%%@*}"
        case "$iface" in
            tailscale*) continue ;;
            tun[0-9]* | tap[0-9]* | wg[0-9]* | wg-* | proton* | nordlynx)
                printf '%s' "$iface"
                return 0
                ;;
        esac
    done < <(ip -o link show up 2>/dev/null | awk -F': ' '{ print $2 }')
    return 1
}

telemetry_public_ip() {
    local now
    local public_ip

    TELEMETRY_PUBLIC_IP_RESULT=""
    [[ "$CYBEROPS_HEADER_PUBLIC_IP" == "1" ]] || return 1
    have curl || return 1
    now="$(date +%s 2>/dev/null)" || return 1
    if ((CYBEROPS_PUBLIC_IP_CACHE_TIME > 0)) &&
        ((now - CYBEROPS_PUBLIC_IP_CACHE_TIME < CYBEROPS_PUBLIC_IP_CACHE_TTL)); then
        if [[ -n "$CYBEROPS_PUBLIC_IP_CACHE" ]]; then
            TELEMETRY_PUBLIC_IP_RESULT="$CYBEROPS_PUBLIC_IP_CACHE"
            return 0
        fi
        return 1
    fi

    public_ip="$(curl --silent --show-error --fail \
        --max-time "$CYBEROPS_HEADER_TIMEOUT" https://api.ipify.org 2>/dev/null)" || {
        CYBEROPS_PUBLIC_IP_CACHE=""
        CYBEROPS_PUBLIC_IP_CACHE_TIME="$now"
        return 1
    }
    [[ ${#public_ip} -le 64 && "$public_ip" != *[[:space:]]* &&
        "$public_ip" =~ ^[0-9A-Fa-f:.]+$ ]] || {
        CYBEROPS_PUBLIC_IP_CACHE=""
        CYBEROPS_PUBLIC_IP_CACHE_TIME="$now"
        return 1
    }
    CYBEROPS_PUBLIC_IP_CACHE="$public_ip"
    CYBEROPS_PUBLIC_IP_CACHE_TIME="$now"
    TELEMETRY_PUBLIC_IP_RESULT="$public_ip"
}

collect_header_telemetry() {
    local detected_iface=""
    local permanent_mac=""

    HEADER_TIME=""
    HEADER_ROUTE_STATE=""
    HEADER_VPN=""
    HEADER_IFACE=""
    HEADER_ADDRESS=""
    HEADER_MAC=""
    HEADER_MAC_STATE="UNKNOWN"
    HEADER_PUBLIC_IP=""
    [[ "$CYBEROPS_HEADER_TELEMETRY" == "1" ]] || return 0

    if [[ "$CYBEROPS_HEADER_TIME" == "1" ]]; then
        HEADER_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf 'UNAVAILABLE')"
    fi
    detected_iface="$(telemetry_primary_interface 2>/dev/null || true)"
    if [[ -n "$detected_iface" ]]; then
        HEADER_IFACE="$detected_iface"
        HEADER_ADDRESS="$(telemetry_interface_address "$detected_iface" 2>/dev/null || printf 'UNAVAILABLE')"
        HEADER_MAC="$(telemetry_current_mac "$detected_iface" 2>/dev/null || printf 'UNAVAILABLE')"
        if [[ "$HEADER_MAC" != "UNAVAILABLE" ]]; then
            permanent_mac="$(telemetry_permanent_mac "$detected_iface" 2>/dev/null || true)"
            if [[ -n "$permanent_mac" && "$HEADER_MAC" == "$permanent_mac" ]]; then
                HEADER_MAC_STATE="PERMANENT"
            elif [[ -n "$permanent_mac" ]]; then
                HEADER_MAC_STATE="MODIFIED"
            fi
        fi
    else
        HEADER_IFACE="UNAVAILABLE"
        HEADER_ADDRESS="UNAVAILABLE"
        HEADER_MAC="UNAVAILABLE"
        HEADER_MAC_STATE="UNKNOWN"
    fi
    HEADER_ROUTE_STATE="$(telemetry_route_state "$detected_iface")"
    if [[ "$CYBEROPS_HEADER_VPN" == "1" ]]; then
        HEADER_VPN="$(telemetry_vpn_interface 2>/dev/null || printf 'NONE')"
    fi
    if telemetry_public_ip 2>/dev/null; then
        HEADER_PUBLIC_IP="$TELEMETRY_PUBLIC_IP_RESULT"
    fi
}
