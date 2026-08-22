#!/usr/bin/env bash

# Core and validation contract
# ----------------------------
# Inputs:
#   Runtime configuration and shared state from lib/runtime.sh.
# Outputs:
#   Standardized command results, validation errors, previews, timestamps, and
#   interruption guidance.
# Return statuses:
#   Validators and checked-command helpers preserve meaningful nonzero status;
#   signal handlers exit with conventional 128+signal statuses.
# Side effects:
#   May register process cleanup state and install traps only when explicitly
#   requested by the launcher. Loading this module changes no traps or options.

have() {
    command -v "$1" >/dev/null 2>&1
}

require_commands() {
    local command_name
    local -a missing=()

    for command_name in "$@"; do
        have "$command_name" || missing+=("$command_name")
    done

    if ((${#missing[@]} > 0)); then
        report_error \
            "Missing required command(s): ${missing[*]}" \
            "Install the missing tools with your system package manager; 'sudo make install-deps' covers the optional CYBEROPS baseline."
        return 1
    fi

    return 0
}

report_success() {
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b[ ACK ]%b %s\n' "$GREEN" "$RESET" "$1"
    else
        printf '%b[OK] %s%b\n' "$GREEN" "$1" "$RESET"
    fi
}

report_warning() {
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b[ CAUTION ]%b %s\n' "$YELLOW" "$RESET" "$1"
    else
        printf '%b[!] %s%b\n' "$YELLOW" "$1" "$RESET"
    fi
}

report_error() {
    local message="$1"
    local recovery="${2:-}"

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b[ FAULT ]%b %s\n' "$RED" "$RESET" "$message"
    else
        printf '%b[!] %s%b\n' "$RED" "$message" "$RESET"
    fi
    if [[ -n "$recovery" ]]; then
        if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
            printf '%bRECOVERY::%b %s\n' "$ORANGE" "$RESET" "$recovery"
        else
            echo "Next step: $recovery"
        fi
    fi
}

write_operation_log() {
    local level="$1"
    local action="$2"
    local status="$3"
    local timestamp_value

    [[ "$CYBEROPS_LOGGING" == "1" && "$CYBEROPS_LOG_ACTIVE" == "1" ]] || return 0
    action="${action//$'\t'/ }"
    action="${action//$'\n'/ }"
    timestamp_value="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" || return 0

    if ! mkdir -p -- "$CYBEROPS_STATE_DIR" 2>/dev/null; then
        return 0
    fi
    chmod 700 -- "$CYBEROPS_STATE_DIR" 2>/dev/null || true
    if ! touch -- "$CYBEROPS_LOG_FILE" 2>/dev/null; then
        return 0
    fi
    chmod 600 -- "$CYBEROPS_LOG_FILE" 2>/dev/null || true
    printf '%s\tpid=%s\tlevel=%s\tstatus=%s\taction=%s\n' \
        "$timestamp_value" "$$" "$level" "$status" "$action" >>"$CYBEROPS_LOG_FILE" 2>/dev/null || true
}

run_checked() {
    local action="$1"
    local recovery="$2"
    local status

    shift 2
    "$@"
    status=$?

    if ((status != 0)); then
        write_operation_log error "$action" "$status"
        report_error "$action failed (exit status $status)." "$recovery"
        return "$status"
    fi

    write_operation_log info "$action" 0

    return 0
}

is_dry_run() {
    [[ "$DRY_RUN" == "1" ]]
}

preview_command() {
    local action="$1"

    shift
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b[ SIMULATION ]%b %s\n' "$PURPLE" "$RESET" "$action"
        printf '%bPAYLOAD::%b' "$MUTED" "$RESET"
    else
        printf '%b[DRY-RUN] %s%b\n' "$CYAN" "$action" "$RESET"
        printf 'Command:'
    fi
    printf ' %q' "$@"
    printf '\n'
    write_operation_log preview "$action" 0
}

run_mutating_checked() {
    local action="$1"
    local recovery="$2"

    shift 2
    if is_dry_run; then
        preview_command "$action" "$@"
        return 0
    fi

    run_checked "$action" "$recovery" "$@"
}

integer_in_range() {
    local value="$1"
    local minimum="$2"
    local maximum="$3"
    local numeric_value

    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    ((${#value} <= 10)) || return 1
    numeric_value=$((10#$value))
    ((numeric_value >= minimum && numeric_value <= maximum))
}

validate_configuration() {
    local errors=0
    local config_error
    local header_toggle

    for config_error in "${CYBEROPS_CONFIG_ERRORS[@]}"; do
        report_error "$config_error"
        ((errors += 1))
    done

    if [[ "$STACK_ROOT" != /* || -z "${STACK_ROOT//\//}" ||
        "$STACK_ROOT" =~ (^|/)\.\.?(/|$) ]]; then
        report_error "STACK_ROOT must be a safe absolute path other than /."
        ((errors += 1))
    fi

    if ! integer_in_range "$RETRY_DELAY" 0 3600; then
        report_error "RETRY_DELAY must be an integer from 0 to 3600 seconds."
        ((errors += 1))
    fi

    if ! integer_in_range "$HEALTH_TIMEOUT" 1 86400; then
        report_error "HEALTH_TIMEOUT must be an integer from 1 to 86400 seconds."
        ((errors += 1))
    fi

    if ! integer_in_range "$HEALTH_INTERVAL" 1 3600; then
        report_error "HEALTH_INTERVAL must be an integer from 1 to 3600 seconds."
        ((errors += 1))
    fi

    if ! integer_in_range "$FAILURE_LOG_LINES" 1 10000; then
        report_error "FAILURE_LOG_LINES must be an integer from 1 to 10000."
        ((errors += 1))
    fi

    if [[ "$DRY_RUN" != "0" && "$DRY_RUN" != "1" ]]; then
        report_error "DRY_RUN must be either 0 or 1."
        ((errors += 1))
    fi

    if [[ "$CYBEROPS_THEME" != "classic" && "$CYBEROPS_THEME" != "neon-overdrive" ]]; then
        report_error "CYBEROPS_THEME must be classic or neon-overdrive."
        ((errors += 1))
    fi

    if [[ "$CYBEROPS_NO_COLOR" != "0" && "$CYBEROPS_NO_COLOR" != "1" ]]; then
        report_error "CYBEROPS_NO_COLOR must be either 0 or 1."
        ((errors += 1))
    fi

    if [[ "$CYBEROPS_LOGGING" != "0" && "$CYBEROPS_LOGGING" != "1" ]]; then
        report_error "CYBEROPS_LOGGING must be either 0 or 1."
        ((errors += 1))
    fi

    for header_toggle in \
        CYBEROPS_HEADER_TELEMETRY CYBEROPS_HEADER_TIME CYBEROPS_HEADER_LINK \
        CYBEROPS_HEADER_VPN CYBEROPS_HEADER_IFACE CYBEROPS_HEADER_LOCAL_IP \
        CYBEROPS_HEADER_MAC CYBEROPS_HEADER_PUBLIC_IP; do
        if [[ "${!header_toggle}" != "0" && "${!header_toggle}" != "1" ]]; then
            report_error "$header_toggle must be either 0 or 1."
            ((errors += 1))
        fi
    done

    if ! integer_in_range "$CYBEROPS_HEADER_TIMEOUT" 1 10; then
        report_error "CYBEROPS_HEADER_TIMEOUT must be an integer from 1 to 10 seconds."
        ((errors += 1))
    fi

    if ! integer_in_range "$CYBEROPS_PUBLIC_IP_CACHE_TTL" 30 86400; then
        report_error "CYBEROPS_PUBLIC_IP_CACHE_TTL must be an integer from 30 to 86400 seconds."
        ((errors += 1))
    fi

    if integer_in_range "$HEALTH_TIMEOUT" 1 86400 &&
        integer_in_range "$HEALTH_INTERVAL" 1 3600 &&
        ((10#$HEALTH_INTERVAL > 10#$HEALTH_TIMEOUT)); then
        report_error "HEALTH_INTERVAL cannot exceed HEALTH_TIMEOUT."
        ((errors += 1))
    fi

    if ((errors > 0)); then
        report_error "CYBEROPS configuration is invalid. Correct the settings above and retry."
        return 1
    fi

    return 0
}

show_configuration() {
    printf 'Configuration file: %s\n' "$CYBEROPS_CONFIG_FILE"
    if ((CYBEROPS_CONFIG_LOADED == 1)); then
        printf 'Configuration state: loaded\n'
    else
        printf 'Configuration state: defaults/environment only\n'
    fi
    printf 'STACK_ROOT=%s\n' "$STACK_ROOT"
    printf 'RETRY_DELAY=%s\n' "$RETRY_DELAY"
    printf 'HEALTH_TIMEOUT=%s\n' "$HEALTH_TIMEOUT"
    printf 'HEALTH_INTERVAL=%s\n' "$HEALTH_INTERVAL"
    printf 'FAILURE_LOG_LINES=%s\n' "$FAILURE_LOG_LINES"
    printf 'DRY_RUN=%s\n' "$DRY_RUN"
    printf 'CYBEROPS_THEME=%s\n' "$CYBEROPS_THEME"
    printf 'CYBEROPS_NO_COLOR=%s\n' "$CYBEROPS_NO_COLOR"
    printf 'CYBEROPS_LOGGING=%s\n' "$CYBEROPS_LOGGING"
    printf 'CYBEROPS_HEADER_TELEMETRY=%s\n' "$CYBEROPS_HEADER_TELEMETRY"
    printf 'CYBEROPS_HEADER_TIME=%s\n' "$CYBEROPS_HEADER_TIME"
    printf 'CYBEROPS_HEADER_LINK=%s\n' "$CYBEROPS_HEADER_LINK"
    printf 'CYBEROPS_HEADER_VPN=%s\n' "$CYBEROPS_HEADER_VPN"
    printf 'CYBEROPS_HEADER_IFACE=%s\n' "$CYBEROPS_HEADER_IFACE"
    printf 'CYBEROPS_HEADER_LOCAL_IP=%s\n' "$CYBEROPS_HEADER_LOCAL_IP"
    printf 'CYBEROPS_HEADER_MAC=%s\n' "$CYBEROPS_HEADER_MAC"
    printf 'CYBEROPS_HEADER_PUBLIC_IP=%s\n' "$CYBEROPS_HEADER_PUBLIC_IP"
    printf 'CYBEROPS_HEADER_TIMEOUT=%s\n' "$CYBEROPS_HEADER_TIMEOUT"
    printf 'CYBEROPS_PUBLIC_IP_CACHE_TTL=%s\n' "$CYBEROPS_PUBLIC_IP_CACHE_TTL"
    printf 'CYBEROPS_STATE_DIR=%s\n' "$CYBEROPS_STATE_DIR"
    printf 'CYBEROPS_LOG_FILE=%s\n' "$CYBEROPS_LOG_FILE"
}

show_operation_log_tail() {
    if [[ ! -f "$CYBEROPS_LOG_FILE" ]]; then
        report_warning "No CYBEROPS operation log exists yet."
        return 0
    fi
    tail -n 50 -- "$CYBEROPS_LOG_FILE"
}

begin_operation() {
    ACTIVE_OPERATION="$1"
    INTERRUPT_WARNING="${2:-}"
}

end_operation() {
    ACTIVE_OPERATION=""
    INTERRUPT_WARNING=""
}

register_network_restore() {
    local iface="$1"
    local was_up="$2"

    NETWORK_RESTORE_INTERFACE=""
    if [[ "$was_up" == "1" ]]; then
        NETWORK_RESTORE_INTERFACE="$iface"
    fi
}

register_connection_restore() {
    NETWORK_CONNECTION_RESTORE_UUID="$1"
    NETWORK_CONNECTION_RESTORE_PROPERTY="$2"
    NETWORK_CONNECTION_RESTORE_POLICY="$3"
    NETWORK_CONNECTION_REACTIVATE=0
}

mark_connection_for_reactivation() {
    NETWORK_CONNECTION_REACTIVATE=1
}

clear_connection_restore() {
    NETWORK_CONNECTION_RESTORE_UUID=""
    NETWORK_CONNECTION_RESTORE_PROPERTY=""
    NETWORK_CONNECTION_RESTORE_POLICY=""
    NETWORK_CONNECTION_REACTIVATE=0
}

perform_connection_cleanup() {
    local connection_uuid="$NETWORK_CONNECTION_RESTORE_UUID"
    local property="$NETWORK_CONNECTION_RESTORE_PROPERTY"
    local policy="$NETWORK_CONNECTION_RESTORE_POLICY"
    local reactivate="$NETWORK_CONNECTION_REACTIVATE"
    local result=0

    clear_connection_restore
    [[ -n "$connection_uuid" ]] || return 0

    printf '%bRestoring NetworkManager profile %s to its previous MAC policy...%b\n' \
        "$YELLOW" "$connection_uuid" "$RESET"
    if ! sudo nmcli connection modify "$connection_uuid" "$property" "$policy"; then
        report_error \
            "Automatic MAC policy rollback failed for $connection_uuid." \
            "Inspect it manually with: nmcli connection show $connection_uuid"
        result=1
    fi

    if ((reactivate == 1)); then
        printf '%bReactivating NetworkManager profile %s...%b\n' \
            "$YELLOW" "$connection_uuid" "$RESET"
        if ! sudo nmcli connection up "$connection_uuid"; then
            report_error \
                "Automatic connection recovery failed for $connection_uuid." \
                "Run manually: sudo nmcli connection up $connection_uuid"
            result=1
        fi
    fi

    return "$result"
}

perform_registered_cleanup() {
    local iface="$NETWORK_RESTORE_INTERFACE"
    local result=0

    # Clear registration before cleanup so a failed command is never retried
    # recursively by the EXIT trap.
    NETWORK_RESTORE_INTERFACE=""
    if [[ -n "$iface" ]]; then
        printf '%bRestoring network interface %s to its original up state...%b\n' \
            "$YELLOW" "$iface" "$RESET"
        if ! sudo ip link set dev "$iface" up; then
            report_error \
                "Automatic restoration failed for $iface." \
                "Run manually: sudo ip link set dev $iface up"
            result=1
        fi
    fi

    perform_connection_cleanup || result=1
    return "$result"
}

cleanup_on_exit() {
    local status=$?

    trap - EXIT
    perform_registered_cleanup || true
    exit "$status"
}

handle_signal() {
    local signal_name="$1"
    local exit_status=1

    trap - INT TERM
    case "$signal_name" in
        INT) exit_status=130 ;;
        TERM) exit_status=143 ;;
    esac

    echo
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b[ LINK SEVERED ]%b Received %s; stopping CYBEROPS.\n' \
            "$YELLOW" "$RESET" "$signal_name"
    else
        printf '%b[!] Received %s; stopping CYBEROPS.%b\n' \
            "$YELLOW" "$signal_name" "$RESET"
    fi
    if [[ -n "$ACTIVE_OPERATION" ]]; then
        echo "Interrupted operation: $ACTIVE_OPERATION"
    fi
    if [[ -n "$INTERRUPT_WARNING" ]]; then
        printf '%b%s%b\n' "$RED" "$INTERRUPT_WARNING" "$RESET"
    fi

    exit "$exit_status"
}

install_signal_handlers() {
    trap 'handle_signal INT' INT
    trap 'handle_signal TERM' TERM
    trap cleanup_on_exit EXIT
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}
