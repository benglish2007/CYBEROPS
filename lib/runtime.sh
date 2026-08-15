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

VERSION="2.10.1"

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
            STACK_ROOT | RETRY_DELAY | HEALTH_TIMEOUT | HEALTH_INTERVAL | FAILURE_LOG_LINES | DRY_RUN | CYBEROPS_NO_COLOR | CYBEROPS_LOGGING)
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
    DIM=""
    RESET=""
    CYBEROPS_NO_COLOR=1
}

CYBEROPS_NO_COLOR="${CYBEROPS_NO_COLOR:-0}"
CYBEROPS_LOGGING="${CYBEROPS_LOGGING:-1}"
CYBEROPS_LOG_ACTIVE=0
CYBEROPS_STATE_DIR="${CYBEROPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cyberops}"
CYBEROPS_LOG_FILE="${CYBEROPS_LOG_FILE:-$CYBEROPS_STATE_DIR/operations.log}"
if [[ -v NO_COLOR ]] || [[ "$CYBEROPS_NO_COLOR" == "1" ]]; then
    disable_color
else
    CYAN='\033[1;96m'
    MAGENTA='\033[1;95m'
    YELLOW='\033[1;93m'
    RED='\033[1;91m'
    GREEN='\033[1;92m'
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
DOCKER_REPORT_FILE=""
