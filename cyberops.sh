#!/usr/bin/env bash

# ==============================================================================
# CYBEROPS TERMINAL
# Unified Linux Operations Console
#
# Includes:
#   - Admin Ops
#   - Info Scan
#   - VPN Control
#   - Cyber Defense
#   - Quickhacks
#   - Docker Maintenance
#   - USB Operations
#
# Designed primarily for Ubuntu/Debian systems.
# ==============================================================================

set -o pipefail

CYBEROPS_SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CYBEROPS_LIB_DIR="${CYBEROPS_LIB_DIR:-$CYBEROPS_SOURCE_DIR/lib}"
CYBEROPS_REQUIRED_MODULES=(
    runtime core telemetry ui diagnostics docker admin info vpn security mac quickhacks usb menu
)

load_cyberops_module() {
    local module_name="$1"
    local module_path="$CYBEROPS_LIB_DIR/$module_name.sh"

    if [[ ! -r "$module_path" ]]; then
        printf 'CYBEROPS could not load required module: %s\n' "$module_path" >&2
        return 1
    fi

    # The required module list above constrains every dynamic source target.
    # shellcheck disable=SC1090
    if ! source "$module_path"; then
        printf 'CYBEROPS required module failed during load: %s\n' "$module_path" >&2
        return 1
    fi
}

for cyberops_module in "${CYBEROPS_REQUIRED_MODULES[@]}"; do
    if ! load_cyberops_module "$cyberops_module"; then
        if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
            exit 1
        else
            return 1
        fi
    fi
done
unset cyberops_module

cyberops_usage() {
    cat <<EOF
CYBEROPS Terminal v$VERSION
Unified Linux Operations Console

Usage:
  cyberops [OPTIONS]
  cyberops [OPTIONS] info
  cyberops [OPTIONS] system <disk|memory|services|failures>
  cyberops [OPTIONS] storage devices
  cyberops [OPTIONS] network <interfaces|routes|sockets>
  cyberops [OPTIONS] vpn status
  cyberops [OPTIONS] docker status
  cyberops [OPTIONS] config <path|show|check>
  cyberops [OPTIONS] logs <path|tail>
  cyberops [OPTIONS] diagnostics <preview|export> [OUTPUT]

Options:
  -h, --help       Show this help and exit.
  -V, --version    Show the CYBEROPS version and exit.
      --no-color   Disable ANSI color output for this invocation.

Commands:
  info             Print a read-only host summary.
  system disk      Print local filesystem usage without probing remote mounts.
  system memory    Print memory and swap usage.
  system services  Print active systemd services.
  system failures  Print failed systemd units.
  storage devices  Print block-device telemetry.
  network interfaces
                   Print local network-interface addresses and state.
  network routes   Print the local routing table.
  network sockets  Print listening sockets.
  vpn status       Print status for installed supported VPN clients.
  docker status    Print container status and Docker disk usage.
  config path      Print the active configuration-file path.
  config show      Print the effective non-secret configuration.
  config check     Validate the effective configuration.
  logs path        Print the private operation-log path.
  logs tail        Print the latest structured operation events.
  diagnostics preview
                   Show exactly what a diagnostics bundle includes and excludes.
  diagnostics export [OUTPUT]
                   Create a privacy-filtered diagnostics archive.

Run without options in an interactive terminal to open the control deck.
EOF
}

cyberops_main() {
    local argument
    local action=menu
    local -a command_arguments=()

    CYBEROPS_LOG_ACTIVE=0

    while (($# > 0)); do
        argument="$1"
        case "$argument" in
            -h | --help) action=help ;;
            -V | --version) action=version ;;
            --no-color) disable_color ;;
            --)
                shift
                break
                ;;
            -*)
                printf 'CYBEROPS: unknown option: %s\n' "$argument" >&2
                printf "Try 'cyberops --help' for usage.\n" >&2
                return 2
                ;;
            *)
                command_arguments+=("$argument")
                ;;
        esac
        shift
    done

    if (($# > 0)); then
        command_arguments+=("$@")
    fi

    case "$action" in
        help)
            cyberops_usage
            return 0
            ;;
        version)
            printf 'CYBEROPS Terminal %s\n' "$VERSION"
            return 0
            ;;
    esac

    # Consumed by write_operation_log after modules are sourced dynamically.
    # shellcheck disable=SC2034
    CYBEROPS_LOG_ACTIVE=1

    if ((${#command_arguments[@]} > 0)); then
        if [[ "${command_arguments[0]}" == "diagnostics" &&
            "${command_arguments[1]:-}" == "export" ]]; then
            if ((${#command_arguments[@]} > 3)); then
                printf 'CYBEROPS: diagnostics export accepts at most one output path.\n' >&2
                return 2
            fi
            export_diagnostics_bundle "${command_arguments[2]:-}"
            return
        fi
        case "${command_arguments[*]}" in
            info)
                show_system_summary
                return
                ;;
            "system disk")
                show_local_disk_usage
                return
                ;;
            "system memory")
                show_memory_usage
                return
                ;;
            "system services")
                show_running_services
                return
                ;;
            "system failures")
                show_failed_services
                return
                ;;
            "storage devices")
                show_storage_devices
                return
                ;;
            "network interfaces")
                show_network_interfaces
                return
                ;;
            "network routes")
                show_routing_table
                return
                ;;
            "network sockets")
                show_listening_sockets
                return
                ;;
            "vpn status")
                show_vpn_status
                return
                ;;
            "docker status")
                show_docker_status
                return
                ;;
            "config path")
                printf '%s\n' "$CYBEROPS_CONFIG_FILE"
                return 0
                ;;
            "config show")
                show_configuration
                return
                ;;
            "config check")
                if validate_configuration; then
                    report_success "CYBEROPS configuration is valid."
                    return 0
                fi
                return 2
                ;;
            "logs path")
                printf '%s\n' "$CYBEROPS_LOG_FILE"
                return 0
                ;;
            "logs tail")
                show_operation_log_tail
                return
                ;;
            "diagnostics preview")
                diagnostics_preview
                return
                ;;
            *)
                printf 'CYBEROPS: unknown command: %s\n' "${command_arguments[*]}" >&2
                printf "Try 'cyberops --help' for usage.\n" >&2
                return 2
                ;;
        esac
    fi

    if [[ ! -t 0 || ! -t 1 ]]; then
        printf 'CYBEROPS: the control deck requires an interactive terminal.\n' >&2
        printf "Use 'cyberops --help' to view non-interactive options.\n" >&2
        return 2
    fi

    if ! validate_configuration; then
        return 2
    fi
    install_signal_handlers
    main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    cyberops_main "$@"
fi
