#!/usr/bin/env bash

# These declarations are consumed by the launcher and feature modules after
# this file is sourced; independent-file analysis cannot observe those reads.
# shellcheck disable=SC2034

# Runtime contract
# ----------------
# Inputs:
#   Optional environment overrides documented in README.md.
# Outputs:
#   No standard output or standard error during a successful load.
# Side effects:
#   Initializes mutable process-wide CYBEROPS configuration and operation state.
# Callers:
#   This file must be sourced by cyberops.sh; it is not a standalone command.

VERSION="2.14"

CYBEROPS_CONFIG_FILE="${CYBEROPS_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/cyberops/config}"
CYBEROPS_CONFIG_LOADED=0
CYBEROPS_CONFIG_ERRORS=()

trim_configuration_value() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

load_configuration_file() {
    local line
    local key
    local value
    local line_number=0

    [[ -e "$CYBEROPS_CONFIG_FILE" ]] || return 0
    if [[ ! -f "$CYBEROPS_CONFIG_FILE" || ! -r "$CYBEROPS_CONFIG_FILE" ]]; then
        CYBEROPS_CONFIG_ERRORS+=("Configuration path is not a readable regular file: $CYBEROPS_CONFIG_FILE")
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number += 1))
        line="$(trim_configuration_value "$line")"
        [[ -n "$line" ]] || continue
        [[ "$line" == \#* ]] && continue

        if [[ "$line" != *=* ]]; then
            CYBEROPS_CONFIG_ERRORS+=("Line $line_number must use KEY=VALUE syntax.")
            continue
        fi

        key="$(trim_configuration_value "${line%%=*}")"
        value="$(trim_configuration_value "${line#*=}")"
        case "$key" in
            STACK_ROOT | RETRY_DELAY | HEALTH_TIMEOUT | HEALTH_INTERVAL | FAILURE_LOG_LINES | DRY_RUN | CYBEROPS_THEME | CYBEROPS_NO_COLOR | CYBEROPS_LOGGING | CYBEROPS_HEADER_TELEMETRY | CYBEROPS_HEADER_TIME | CYBEROPS_HEADER_LINK | CYBEROPS_HEADER_VPN | CYBEROPS_HEADER_IFACE | CYBEROPS_HEADER_LOCAL_IP | CYBEROPS_HEADER_MAC | CYBEROPS_HEADER_PUBLIC_IP | CYBEROPS_HEADER_TIMEOUT | CYBEROPS_PUBLIC_IP_CACHE_TTL)
                if ! [[ -v $key ]]; then
                    printf -v "$key" '%s' "$value"
                fi
                ;;
            *) CYBEROPS_CONFIG_ERRORS+=("Line $line_number uses unknown setting: $key") ;;
        esac
    done <"$CYBEROPS_CONFIG_FILE"

    CYBEROPS_CONFIG_LOADED=1
    ((${#CYBEROPS_CONFIG_ERRORS[@]} == 0))
}

load_configuration_file || true

disable_color() {
    CYAN=""
    MAGENTA=""
    YELLOW=""
    RED=""
    GREEN=""
    PURPLE=""
    BLUE=""
    ORANGE=""
    WHITE=""
    MUTED=""
    DIM=""
    RESET=""
    CYBEROPS_NO_COLOR=1
}

CYBEROPS_THEME="${CYBEROPS_THEME:-neon-overdrive}"
CYBEROPS_NO_COLOR="${CYBEROPS_NO_COLOR:-0}"
CYBEROPS_LOGGING="${CYBEROPS_LOGGING:-1}"
CYBEROPS_HEADER_TELEMETRY="${CYBEROPS_HEADER_TELEMETRY:-1}"
CYBEROPS_HEADER_TIME="${CYBEROPS_HEADER_TIME:-1}"
CYBEROPS_HEADER_LINK="${CYBEROPS_HEADER_LINK:-1}"
CYBEROPS_HEADER_VPN="${CYBEROPS_HEADER_VPN:-1}"
CYBEROPS_HEADER_IFACE="${CYBEROPS_HEADER_IFACE:-1}"
CYBEROPS_HEADER_LOCAL_IP="${CYBEROPS_HEADER_LOCAL_IP:-1}"
CYBEROPS_HEADER_MAC="${CYBEROPS_HEADER_MAC:-1}"
CYBEROPS_HEADER_PUBLIC_IP="${CYBEROPS_HEADER_PUBLIC_IP:-0}"
CYBEROPS_HEADER_TIMEOUT="${CYBEROPS_HEADER_TIMEOUT:-2}"
CYBEROPS_PUBLIC_IP_CACHE_TTL="${CYBEROPS_PUBLIC_IP_CACHE_TTL:-300}"
CYBEROPS_PUBLIC_IP_CACHE=""
CYBEROPS_PUBLIC_IP_CACHE_TIME=0
TELEMETRY_PUBLIC_IP_RESULT=""
HEADER_TIME=""
HEADER_ROUTE_STATE=""
HEADER_VPN=""
HEADER_VPN_ADDRESS=""
HEADER_IFACE=""
HEADER_ADDRESS=""
HEADER_MAC=""
HEADER_MAC_STATE=""
HEADER_PUBLIC_IP=""
CYBEROPS_LOG_ACTIVE=0
CYBEROPS_STATE_DIR="${CYBEROPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cyberops}"
CYBEROPS_LOG_FILE="${CYBEROPS_LOG_FILE:-$CYBEROPS_STATE_DIR/operations.log}"
if [[ -v NO_COLOR ]] || [[ "$CYBEROPS_NO_COLOR" == "1" ]]; then
    disable_color
else
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        CYAN='\033[1;38;2;0;245;255m'
        MAGENTA='\033[1;38;2;255;45;149m'
        YELLOW='\033[1;38;2;255;230;0m'
        RED='\033[1;38;2;255;49;71m'
        GREEN='\033[1;38;2;57;255;20m'
        PURPLE='\033[1;38;2;179;0;255m'
        BLUE='\033[1;38;2;35;120;255m'
        ORANGE='\033[1;38;2;255;126;0m'
        WHITE='\033[1;97m'
        MUTED='\033[38;2;116;132;156m'
    else
        CYAN='\033[1;96m'
        MAGENTA='\033[1;95m'
        YELLOW='\033[1;93m'
        RED='\033[1;91m'
        GREEN='\033[1;92m'
        PURPLE="$MAGENTA"
        BLUE="$CYAN"
        ORANGE="$YELLOW"
        WHITE='\033[1;97m'
        MUTED='\033[2m'
    fi
    DIM='\033[2m'
    RESET='\033[0m'
fi

# Docker updater defaults
STACK_ROOT="${STACK_ROOT:-/srv/stacks}"
RETRY_DELAY="${RETRY_DELAY:-5}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"
FAILURE_LOG_LINES="${FAILURE_LOG_LINES:-80}"
DRY_RUN="${DRY_RUN:-0}"

# Shared operation state. Modules communicate selected targets and registered
# cleanup work through these variables; functions that mutate them must state
# that side effect in their contract.
SELECTED_USB_DEVICE=""
SELECTED_USB_IDENTITY=""
ACTIVE_OPERATION=""
INTERRUPT_WARNING=""
NETWORK_RESTORE_INTERFACE=""
NETWORK_CONNECTION_RESTORE_UUID=""
NETWORK_CONNECTION_RESTORE_PROPERTY=""
NETWORK_CONNECTION_RESTORE_POLICY=""
NETWORK_CONNECTION_REACTIVATE=0
DOCKER_REPORT_FILE=""
