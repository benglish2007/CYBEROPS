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
    runtime core ui docker admin info vpn security quickhacks usb menu
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
  cyberops [OPTIONS] docker status

Options:
  -h, --help       Show this help and exit.
  -V, --version    Show the CYBEROPS version and exit.
      --no-color   Disable ANSI color output for this invocation.

Commands:
  info             Print a read-only host summary.
  docker status    Print container status and Docker disk usage.

Run without options in an interactive terminal to open the control deck.
EOF
}

cyberops_main() {
    local argument
    local action=menu
    local -a command_arguments=()

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

    if ((${#command_arguments[@]} > 0)); then
        case "${command_arguments[*]}" in
            info)
                show_system_summary
                return
                ;;
            "docker status")
                show_docker_status
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
