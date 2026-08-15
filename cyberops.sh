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
#   - System Setup
#
# Designed primarily for Ubuntu/Debian systems.
# ==============================================================================

set -o pipefail

CYBEROPS_SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CYBEROPS_LIB_DIR="${CYBEROPS_LIB_DIR:-$CYBEROPS_SOURCE_DIR/lib}"
CYBEROPS_REQUIRED_MODULES=(
    runtime core ui docker admin info vpn security quickhacks usb setup menu
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if ! validate_configuration; then
        exit 2
    fi
    install_signal_handlers
    main_menu
fi
