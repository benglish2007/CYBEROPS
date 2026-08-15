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
            "Install the missing tools or run 'sudo make install-deps' from the CYBEROPS repository."
        return 1
    fi

    return 0
}

report_success() {
    printf '%b[OK] %s%b\n' "$GREEN" "$1" "$RESET"
}

report_warning() {
    printf '%b[!] %s%b\n' "$YELLOW" "$1" "$RESET"
}

report_error() {
    local message="$1"
    local recovery="${2:-}"

    printf '%b[!] %s%b\n' "$RED" "$message" "$RESET"
    if [[ -n "$recovery" ]]; then
        echo "Next step: $recovery"
    fi
}

run_checked() {
    local action="$1"
    local recovery="$2"
    local status

    shift 2
    "$@"
    status=$?

    if ((status != 0)); then
        report_error "$action failed (exit status $status)." "$recovery"
        return "$status"
    fi

    return 0
}

is_dry_run() {
    [[ "$DRY_RUN" == "1" ]]
}

preview_command() {
    local action="$1"

    shift
    printf '%b[DRY-RUN] %s%b\n' "$CYAN" "$action" "$RESET"
    printf 'Command:'
    printf ' %q' "$@"
    printf '\n'
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

    if [[ "$STACK_ROOT" != /* || -z "${STACK_ROOT//\//}" ||
        "$STACK_ROOT" =~ (^|/)\.\.?(/|$) ]]; then
        printf '%b[!] STACK_ROOT must be a safe absolute path other than /.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if ! integer_in_range "$RETRY_DELAY" 0 3600; then
        printf '%b[!] RETRY_DELAY must be an integer from 0 to 3600 seconds.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if ! integer_in_range "$HEALTH_TIMEOUT" 1 86400; then
        printf '%b[!] HEALTH_TIMEOUT must be an integer from 1 to 86400 seconds.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if ! integer_in_range "$HEALTH_INTERVAL" 1 3600; then
        printf '%b[!] HEALTH_INTERVAL must be an integer from 1 to 3600 seconds.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if ! integer_in_range "$FAILURE_LOG_LINES" 1 10000; then
        printf '%b[!] FAILURE_LOG_LINES must be an integer from 1 to 10000.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if [[ "$DRY_RUN" != "0" && "$DRY_RUN" != "1" ]]; then
        printf '%b[!] DRY_RUN must be either 0 or 1.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if integer_in_range "$HEALTH_TIMEOUT" 1 86400 &&
        integer_in_range "$HEALTH_INTERVAL" 1 3600 &&
        ((10#$HEALTH_INTERVAL > 10#$HEALTH_TIMEOUT)); then
        printf '%b[!] HEALTH_INTERVAL cannot exceed HEALTH_TIMEOUT.%b\n' "$RED" "$RESET"
        ((errors += 1))
    fi

    if ((errors > 0)); then
        printf '%bCYBEROPS configuration is invalid. Correct the settings above and retry.%b\n' "$RED" "$RESET"
        return 1
    fi

    return 0
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

perform_registered_cleanup() {
    local iface="$NETWORK_RESTORE_INTERFACE"

    # Clear registration before cleanup so a failed command is never retried
    # recursively by the EXIT trap.
    NETWORK_RESTORE_INTERFACE=""
    [[ -n "$iface" ]] || return 0

    printf '%bRestoring network interface %s to its original up state...%b\n' \
        "$YELLOW" "$iface" "$RESET"
    if ! sudo ip link set dev "$iface" up; then
        report_error \
            "Automatic restoration failed for $iface." \
            "Run manually: sudo ip link set dev $iface up"
        return 1
    fi

    return 0
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
    printf '%b[!] Received %s; stopping CYBEROPS.%b\n' \
        "$YELLOW" "$signal_name" "$RESET"
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
