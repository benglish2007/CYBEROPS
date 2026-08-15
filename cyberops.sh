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

VERSION="2.3"

CYAN='\033[1;96m'
MAGENTA='\033[1;95m'
YELLOW='\033[1;93m'
RED='\033[1;91m'
GREEN='\033[1;92m'
DIM='\033[2m'
RESET='\033[0m'

# Docker updater defaults
STACK_ROOT="${STACK_ROOT:-/srv/stacks}"
RETRY_DELAY="${RETRY_DELAY:-5}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"
FAILURE_LOG_LINES="${FAILURE_LOG_LINES:-80}"
DRY_RUN="${DRY_RUN:-0}"

SELECTED_USB_DEVICE=""
SELECTED_USB_IDENTITY=""
ACTIVE_OPERATION=""
INTERRUPT_WARNING=""
NETWORK_RESTORE_INTERFACE=""
DOCKER_REPORT_FILE=""

# ------------------------------------------------------------------------------
# Core helpers
# ------------------------------------------------------------------------------

typewrite() {
    local text="$1"
    local delay="${2:-0.008}"
    local i
    for ((i = 0; i < ${#text}; i++)); do
        printf '%s' "${text:i:1}"
        sleep "$delay"
    done
    printf '\n'
}

pause() {
    printf '\n%b[ RETURN ]%b Press Enter to reconnect to the control deck...' \
        "$MAGENTA" "$RESET"
    read -r _
}

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear || printf '\033c'
}

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
            "Install the missing dependencies or use System Setup when supported."
        return 1
    fi

    return 0
}

report_success() {
    echo -e "${GREEN}[OK] $1${RESET}"
}

report_warning() {
    echo -e "${YELLOW}[!] $1${RESET}"
}

report_error() {
    local message="$1"
    local recovery="${2:-}"

    echo -e "${RED}[!] $message${RESET}"
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
    echo -e "${CYAN}[DRY-RUN] $action${RESET}"
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
        echo -e "${RED}[!] STACK_ROOT must be a safe absolute path other than /.${RESET}"
        ((errors += 1))
    fi

    if ! integer_in_range "$RETRY_DELAY" 0 3600; then
        echo -e "${RED}[!] RETRY_DELAY must be an integer from 0 to 3600 seconds.${RESET}"
        ((errors += 1))
    fi

    if ! integer_in_range "$HEALTH_TIMEOUT" 1 86400; then
        echo -e "${RED}[!] HEALTH_TIMEOUT must be an integer from 1 to 86400 seconds.${RESET}"
        ((errors += 1))
    fi

    if ! integer_in_range "$HEALTH_INTERVAL" 1 3600; then
        echo -e "${RED}[!] HEALTH_INTERVAL must be an integer from 1 to 3600 seconds.${RESET}"
        ((errors += 1))
    fi

    if ! integer_in_range "$FAILURE_LOG_LINES" 1 10000; then
        echo -e "${RED}[!] FAILURE_LOG_LINES must be an integer from 1 to 10000.${RESET}"
        ((errors += 1))
    fi

    if [[ "$DRY_RUN" != "0" && "$DRY_RUN" != "1" ]]; then
        echo -e "${RED}[!] DRY_RUN must be either 0 or 1.${RESET}"
        ((errors += 1))
    fi

    if integer_in_range "$HEALTH_TIMEOUT" 1 86400 &&
       integer_in_range "$HEALTH_INTERVAL" 1 3600 &&
       ((10#$HEALTH_INTERVAL > 10#$HEALTH_TIMEOUT)); then
        echo -e "${RED}[!] HEALTH_INTERVAL cannot exceed HEALTH_TIMEOUT.${RESET}"
        ((errors += 1))
    fi

    if ((errors > 0)); then
        echo -e "${RED}CYBEROPS configuration is invalid. Correct the settings above and retry.${RESET}"
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

    echo -e "${YELLOW}Restoring network interface $iface to its original up state...${RESET}"
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
    echo -e "${YELLOW}[!] Received $signal_name; stopping CYBEROPS.${RESET}"
    if [[ -n "$ACTIVE_OPERATION" ]]; then
        echo "Interrupted operation: $ACTIVE_OPERATION"
    fi
    if [[ -n "$INTERRUPT_WARNING" ]]; then
        echo -e "${RED}$INTERRUPT_WARNING${RESET}"
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

separator() {
    printf '%*s\n' 78 '' | tr ' ' '='
}

ui_section() {
    local title="$1"
    local subtitle="${2:-SELECT AN OPERATION}"

    printf '%b╭─[%b %s %b]──────────────────────────────────────────────%b\n' \
        "$MAGENTA" "$CYAN" "$title" "$MAGENTA" "$RESET"
    printf '%b│%b %s%b\n' "$MAGENTA" "$DIM" "$subtitle" "$RESET"
    printf '%b╰──────────────────────────────────────────────────────────%b\n\n' \
        "$MAGENTA" "$RESET"
}

menu_item() {
    local key="$1"
    local label="$2"
    local hint="${3:-}"

    printf '  %b[%02d]%b  %-34s' "$CYAN" "$key" "$RESET" "$label"
    if [[ -n "$hint" ]]; then
        printf ' %b%s%b' "$DIM" "$hint" "$RESET"
    fi
    printf '\n'
}

prompt_choice() {
    local variable_name="$1"
    local channel="${2:-COMMAND}"
    local response

    printf '\n%b%s%b %b>%b ' "$MAGENTA" "$channel" "$RESET" "$CYAN" "$RESET"
    IFS= read -r response
    printf -v "$variable_name" '%s' "$response"
}

prompt_path() {
    local variable_name="$1"
    local label="${2:-FILE PATH}"
    local initial_path="${3:-$HOME/}"
    local first_character
    local last_character
    local response

    printf '%bTAB%b autocomplete  //  %bCTRL-U%b clear path\n' \
        "$CYAN" "$RESET" "$MAGENTA" "$RESET"
    printf '%b%s%b %b>%b ' "$MAGENTA" "$label" "$RESET" "$CYAN" "$RESET"

    if [[ -t 0 ]]; then
        # Readline inserts backslashes when completing paths containing spaces.
        # Omitting -r lets read convert those escapes back to the real path.
        # shellcheck disable=SC2162
        IFS= read -e -i "$initial_path" response
    else
        # Keep noninteractive input consistent with Readline's escaped paths.
        # shellcheck disable=SC2162
        IFS= read response
    fi

    if ((${#response} >= 2)); then
        first_character="${response:0:1}"
        last_character="${response: -1}"
        if [[ "$first_character" == '"' && "$last_character" == '"' ]] ||
           [[ "$first_character" == "'" && "$last_character" == "'" ]]; then
            response="${response:1:${#response}-2}"
        fi
    fi

    case "$response" in
        \~) response="$HOME" ;;
        \~/*) response="$HOME/${response:2}" ;;
    esac

    # Readline appends a separator space after uniquely completing a file.
    # Remove it only when it is not part of a real path.
    if [[ "$response" == *' ' && ! -e "$response" && -e "${response% }" ]]; then
        response="${response% }"
    fi

    printf -v "$variable_name" '%s' "$response"
}

invalid_selection() {
    report_error "Unknown command channel." "Select one of the numbered access nodes."
    sleep 1
}

banner() {
    clear_screen

    printf '%b╔══[%b CYBEROPS // NEON GRID %b]══════════════════[%b NODE ONLINE %b]══╗%b\n' \
        "$MAGENTA" "$CYAN" "$MAGENTA" "$GREEN" "$MAGENTA" "$RESET"

    if have figlet; then
        if have lolcat; then
            figlet -f slant "CYBEROPS" | lolcat
        else
            echo -e "${CYAN}"
            figlet -f slant "CYBEROPS"
            echo -e "${RESET}"
        fi
    else
        echo -e "${CYAN}"
        cat <<'EOF'
   ________  ______  __________  ____  ____  ____  _____
  / ____/\\ \/ / __ )/ ____/ __ \/ __ \/ __ \/ __ \/ ___/
 / /      \  / __  / __/ / /_/ / / / / /_/ / /_/ /\__ \
/ /___    / / /_/ / /___/ _, _/ /_/ / ____/ ____/___/ /
\____/   /_/_____/_____/_/ |_|\____/_/   /_/    /____/
EOF
        echo -e "${RESET}"
    fi

    printf '%b╚══════════════════════════════════════════════════════════════╝%b\n' \
        "$MAGENTA" "$RESET"
    printf '%bBUILD %s%b  //  UNIFIED LINUX OPERATIONS CONSOLE  //  SESSION ACTIVE\n' \
        "$CYAN" "$VERSION" "$RESET"
    if is_dry_run; then
        printf '%b[ PREVIEW PROTOCOL ]%b State-changing commands are simulation-only.\n' \
            "$YELLOW" "$RESET"
    fi
    echo
}

warn_destructive() {
    printf '%b╔═[ DESTRUCTIVE PROTOCOL ]══════════════════════════════════╗%b\n' \
        "$RED" "$RESET"
    printf '%b║ WARNING: THIS OPERATION CAN PERMANENTLY DESTROY DATA.      ║%b\n' \
        "$RED" "$RESET"
    printf '%b╚════════════════════════════════════════════════════════════╝%b\n' \
        "$RED" "$RESET"
}

confirm_yes() {
    local prompt="${1:-Type YES to continue: }"
    local answer
    printf '%bCONFIRM%b // %s' "$RED" "$RESET" "$prompt"
    read -r answer
    [[ "$answer" == "YES" ]]
}

system_disk() {
    local root_source
    local parent

    root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    [[ -n "$root_source" ]] || return 1

    # Resolve mapper/LVM devices to the underlying physical disk when possible.
    parent="$(lsblk -no PKNAME "$root_source" 2>/dev/null | head -n1 || true)"

    if [[ -n "$parent" ]]; then
        # Walk upward until there is no parent.
        while true; do
            local next
            next="$(lsblk -no PKNAME "/dev/$parent" 2>/dev/null | head -n1 || true)"
            [[ -n "$next" ]] || break
            parent="$next"
        done
        printf '/dev/%s\n' "$parent"
        return 0
    fi

    if [[ "$root_source" == /dev/* ]]; then
        printf '%s\n' "$root_source"
        return 0
    fi

    return 1
}

resolve_device_path() {
    readlink -f -- "$1" 2>/dev/null
}

is_block_device() {
    [[ -b "$1" ]]
}

block_property() {
    local device="$1"
    local property="$2"

    lsblk -dn -o "$property" -- "$device" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

block_size_bytes() {
    lsblk -bdn -o SIZE -- "$1" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

device_mountpoints() {
    lsblk -nr -o MOUNTPOINTS -- "$1" 2>/dev/null | sed '/^[[:space:]]*$/d'
}

usb_device_identity() {
    local device
    local type
    local transport
    local removable
    local size
    local model
    local serial
    local wwn

    device="$(resolve_device_path "$1")" || return 1
    [[ "$device" == /dev/* ]] || return 1
    is_block_device "$device" || return 1

    type="$(block_property "$device" TYPE)"
    transport="$(block_property "$device" TRAN)"
    removable="$(block_property "$device" RM)"
    size="$(block_size_bytes "$device")"
    model="$(block_property "$device" MODEL)"
    serial="$(block_property "$device" SERIAL)"
    wwn="$(block_property "$device" WWN)"

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$device" "$type" "$transport" "$removable" "$size" "$model" "$serial" "$wwn"
}

is_removable_usb_disk() {
    local device="$1"
    local type
    local transport
    local removable

    type="$(block_property "$device" TYPE)"
    transport="$(block_property "$device" TRAN)"
    removable="$(block_property "$device" RM)"

    [[ "$type" == "disk" ]] && [[ "$transport" == "usb" || "$removable" == "1" ]]
}

protected_system_disks() {
    local mountpoint
    local source

    for mountpoint in / /boot /boot/efi; do
        source="$(findmnt -n -o SOURCE --target "$mountpoint" 2>/dev/null || true)"
        source="${source%%\[*}"
        [[ "$source" == /dev/* ]] || continue

        lsblk -slnp -o NAME,TYPE -- "$source" 2>/dev/null \
            | awk '$2 == "disk" { print $1 }'
    done | sort -u
}

system_disk_protection_ready() {
    local root_source
    local root_disks

    root_source="$(findmnt -n -o SOURCE --target / 2>/dev/null)" || return 1
    root_source="${root_source%%\[*}"
    [[ "$root_source" == /dev/* ]] || return 1

    root_disks="$(lsblk -slnp -o NAME,TYPE -- "$root_source" 2>/dev/null \
        | awk '$2 == "disk" { print $1 }')"
    [[ -n "$root_disks" ]]
}

is_protected_system_disk() {
    local target="$1"
    local protected

    while read -r protected; do
        [[ -n "$protected" ]] || continue
        protected="$(resolve_device_path "$protected")" || continue
        [[ "$target" == "$protected" ]] && return 0
    done < <(protected_system_disks)

    return 1
}

validate_usb_target() {
    local target="$1"
    local expected_identity="$2"
    local require_unmounted="${3:-0}"
    local resolved
    local current_identity
    local mounts

    resolved="$(resolve_device_path "$target")" || {
        report_error \
            "REFUSING: target device is unavailable." \
            "Reconnect the device and select it again."
        return 1
    }

    if [[ "$resolved" != /dev/* ]] || ! is_block_device "$resolved"; then
        report_error \
            "REFUSING: target is not a block device under /dev." \
            "Select a whole removable disk reported by the USB menu."
        return 1
    fi

    if ! is_removable_usb_disk "$resolved"; then
        report_error \
            "REFUSING: target is not a whole removable/USB disk." \
            "Select a removable disk, not an internal disk or partition."
        return 1
    fi

    if ! system_disk_protection_ready; then
        report_error \
            "REFUSING: unable to resolve the disks backing the running system." \
            "Verify findmnt and lsblk can resolve the root filesystem before retrying."
        return 1
    fi

    if is_protected_system_disk "$resolved"; then
        report_error \
            "REFUSING: target backs /, /boot, or /boot/efi." \
            "Choose a different removable disk."
        return 1
    fi

    current_identity="$(usb_device_identity "$resolved")" || {
        report_error \
            "REFUSING: unable to read the target device identity." \
            "Reconnect the device and select it again."
        return 1
    }

    if [[ "$current_identity" != "$expected_identity" ]]; then
        report_error \
            "REFUSING: target device identity changed after selection." \
            "Return to device selection and verify the intended target."
        return 1
    fi

    if [[ "$require_unmounted" == "1" ]]; then
        mounts="$(device_mountpoints "$resolved")"
        if [[ -n "$mounts" ]]; then
            report_error \
                "REFUSING: target still has mounted filesystems." \
                "Close applications using the paths below, unmount them, and retry."
            printf '%s\n' "$mounts"
            return 1
        fi
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Admin Ops
# ------------------------------------------------------------------------------

admin_menu() {
    local choice=""

    while true; do
        banner
        ui_section "ADMIN OPS" "SYSTEM CONTROL // PACKAGES + SERVICES"
        menu_item 1 "Update package lists" "APT // SYNC"
        menu_item 2 "Upgrade installed packages" "APT // UPGRADE"
        menu_item 3 "Disk usage" "STORAGE // TELEMETRY"
        menu_item 4 "Memory usage" "MEMORY // TELEMETRY"
        menu_item 5 "Active systemd services" "SERVICES // ACTIVE"
        menu_item 6 "Failed systemd services" "SERVICES // FAILED"
        menu_item 7 "Reboot system" "POWER // RESTART"
        menu_item 8 "Return to control deck" "NAV // BACK"

        prompt_choice choice "ADMIN"

        case "$choice" in
            1)
                if require_commands sudo apt; then
                    run_mutating_checked \
                        "Package-list update" \
                        "Check network connectivity and APT repository configuration, then retry." \
                        sudo apt update
                fi
                pause
                ;;
            2)
                if require_commands sudo apt; then
                    if run_mutating_checked \
                        "Package-list update" \
                        "Check network connectivity and APT repository configuration, then retry." \
                        sudo apt update; then
                        run_mutating_checked \
                            "Package upgrade" \
                            "Review the APT error above, resolve held or conflicting packages, then retry." \
                            sudo apt upgrade
                    fi
                fi
                pause
                ;;
            3)
                if require_commands df; then
                    run_checked \
                        "Filesystem usage query" \
                        "Verify mounted filesystems are accessible." \
                        df -hT
                fi
                pause
                ;;
            4)
                if require_commands free; then
                    run_checked \
                        "Memory usage query" \
                        "Verify procfs is mounted and readable." \
                        free -h
                fi
                pause
                ;;
            5)
                if require_commands systemctl; then
                    run_checked \
                        "Running-service query" \
                        "Verify systemd is the active service manager." \
                        systemctl --type=service --state=running --no-pager
                fi
                pause
                ;;
            6)
                if require_commands systemctl; then
                    run_checked \
                        "Failed-service query" \
                        "Verify systemd is the active service manager." \
                        systemctl --failed --no-pager
                fi
                pause
                ;;
            7)
                echo -e "${YELLOW}System reboot requested.${RESET}"
                if require_commands sudo reboot && confirm_yes "Type YES to reboot: "; then
                    run_mutating_checked \
                        "System reboot request" \
                        "Check sudo authorization and system policy before retrying." \
                        sudo reboot
                fi
                ;;
            8) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Info Scan
# ------------------------------------------------------------------------------

show_system_summary() {
    local hostname_value
    local kernel_value
    local uptime_value

    require_commands hostname uname uptime || return 1

    hostname_value="$(hostname)" || {
        report_error "Hostname query failed." "Verify the system hostname configuration."
        return 1
    }
    kernel_value="$(uname -r)" || {
        report_error "Kernel-version query failed." "Verify the running kernel exposes system information."
        return 1
    }
    uptime_value="$(uptime -p 2>/dev/null || uptime)" || {
        report_error "System-uptime query failed." "Verify procfs is mounted and readable."
        return 1
    }

    echo "Hostname: $hostname_value"
    echo "Kernel:   $kernel_value"
    echo "Uptime:   $uptime_value"

    if have hostnamectl; then
        run_checked \
            "Detailed hostname query" \
            "Verify systemd-hostnamed is available." \
            hostnamectl
    fi
}

info_menu() {
    local choice=""

    while true; do
        banner
        ui_section "INFO SCAN" "HOST RECON // READ-ONLY TELEMETRY"
        menu_item 1 "System summary" "HOST // OVERVIEW"
        menu_item 2 "CPU information" "HARDWARE // CPU"
        menu_item 3 "Memory information" "HARDWARE // MEMORY"
        menu_item 4 "Storage devices" "HARDWARE // STORAGE"
        menu_item 5 "Network interfaces" "NETWORK // LINKS"
        menu_item 6 "Routing table" "NETWORK // ROUTES"
        menu_item 7 "Listening sockets" "NETWORK // PORTS"
        menu_item 8 "Public IP address" "NETWORK // EGRESS"
        menu_item 9 "Return to control deck" "NAV // BACK"

        prompt_choice choice "SCAN"

        case "$choice" in
            1)
                show_system_summary
                pause
                ;;
            2)
                if require_commands lscpu; then
                    run_checked "CPU information query" "Verify sysfs and procfs are readable." lscpu
                fi
                pause
                ;;
            3)
                if require_commands free; then
                    run_checked "Memory information query" "Verify procfs is mounted and readable." free -h
                fi
                pause
                ;;
            4)
                if require_commands lsblk; then
                    run_checked \
                        "Storage-device query" \
                        "Verify sysfs is mounted and block devices are accessible." \
                        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,TRAN
                fi
                pause
                ;;
            5)
                if require_commands ip; then
                    run_checked "Network-interface query" "Verify the network namespace is accessible." ip -brief address
                fi
                pause
                ;;
            6)
                if require_commands ip; then
                    run_checked "Routing-table query" "Verify the network namespace is accessible." ip route
                fi
                pause
                ;;
            7)
                if require_commands ss; then
                    run_checked "Listening-socket query" "Retry with sufficient privileges if process details are unavailable." ss -tulpn
                fi
                pause
                ;;
            8)
                if require_commands curl; then
                    if run_checked \
                        "Public-IP lookup" \
                        "Check DNS, internet connectivity, and access to api.ipify.org." \
                        curl -fsS https://api.ipify.org; then
                        echo
                    fi
                fi
                pause
                ;;
            9) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# VPN Control
# ------------------------------------------------------------------------------

vpn_menu() {
    local choice=""

    while true; do
        banner
        ui_section "VPN CONTROL" "ENCRYPTED LINKS // TUNNEL CONTROL"
        menu_item 1 "Tailscale status" "TAILNET // STATUS"
        menu_item 2 "Tailscale up" "TAILNET // CONNECT"
        menu_item 3 "Tailscale down" "TAILNET // DISCONNECT"
        menu_item 4 "ExpressVPN status" "VPN // STATUS"
        menu_item 5 "ExpressVPN connect" "VPN // CONNECT"
        menu_item 6 "ExpressVPN disconnect" "VPN // DISCONNECT"
        menu_item 7 "Return to control deck" "NAV // BACK"

        prompt_choice choice "VPN"

        case "$choice" in
            1)
                if require_commands tailscale; then
                    run_checked "Tailscale status query" "Verify the Tailscale daemon is running." tailscale status
                fi
                pause
                ;;
            2)
                if require_commands sudo tailscale; then
                    run_mutating_checked "Tailscale connection" "Review Tailscale authentication and daemon status." sudo tailscale up
                fi
                pause
                ;;
            3)
                if require_commands sudo tailscale; then
                    run_mutating_checked "Tailscale disconnection" "Verify the Tailscale daemon is running." sudo tailscale down
                fi
                pause
                ;;
            4)
                if require_commands expressvpn; then
                    run_checked "ExpressVPN status query" "Verify the ExpressVPN daemon is running." expressvpn status
                fi
                pause
                ;;
            5)
                if require_commands expressvpn; then
                    run_mutating_checked "ExpressVPN connection" "Review ExpressVPN sign-in and daemon status." expressvpn connect
                fi
                pause
                ;;
            6)
                if require_commands expressvpn; then
                    run_mutating_checked "ExpressVPN disconnection" "Verify the ExpressVPN daemon is running." expressvpn disconnect
                fi
                pause
                ;;
            7) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Cyber Defense
# ------------------------------------------------------------------------------

cyber_defense_menu() {
    local choice=""
    local failed_logins
    local journal_output
    local journal_status
    local scan_status

    while true; do
        banner
        ui_section "CYBER DEFENSE" "DEFENSIVE GRID // FIREWALL + THREAT SCANS"
        menu_item 1 "UFW status" "FIREWALL // STATUS"
        menu_item 2 "Enable UFW" "FIREWALL // ENABLE"
        menu_item 3 "Disable UFW" "FIREWALL // DISABLE"
        menu_item 4 "ClamAV scan home directory" "MALWARE // SCAN"
        menu_item 5 "rkhunter check" "ROOTKIT // SCAN"
        menu_item 6 "Recent failed SSH logins" "AUTH // EVENTS"
        menu_item 7 "Return to control deck" "NAV // BACK"

        prompt_choice choice "DEFENSE"

        case "$choice" in
            1)
                if require_commands sudo ufw; then
                    run_checked "UFW status query" "Verify UFW is installed and sudo access is available." sudo ufw status verbose
                fi
                pause
                ;;
            2)
                if require_commands sudo ufw; then
                    run_mutating_checked "UFW enable" "Review UFW rules and sudo authorization before retrying." sudo ufw enable
                fi
                pause
                ;;
            3)
                report_warning "Disabling the firewall can expose services to the network."
                if require_commands sudo ufw && confirm_yes "Type YES to disable UFW: "; then
                    run_mutating_checked "UFW disable" "Check sudo authorization and UFW service state." sudo ufw disable
                fi
                pause
                ;;
            4)
                if require_commands clamscan; then
                    clamscan -r -i "$HOME"
                    scan_status=$?
                    case "$scan_status" in
                        0) report_success "ClamAV scan completed with no infected files found." ;;
                        1) report_warning "ClamAV found one or more infected files; review the scan output before taking action." ;;
                        *) report_error \
                            "ClamAV scan failed (exit status $scan_status)." \
                            "Update signatures, verify file access, and retry." ;;
                    esac
                fi
                pause
                ;;
            5)
                if require_commands sudo rkhunter; then
                    run_mutating_checked \
                        "rkhunter check" \
                        "Review the rkhunter log and update its data files before retrying." \
                        sudo rkhunter --check
                fi
                pause
                ;;
            6)
                if require_commands sudo journalctl grep tail; then
                    if journal_output="$(sudo journalctl -u ssh -u sshd --since "7 days ago" --no-pager 2>/dev/null)"; then
                        failed_logins="$(
                            printf '%s\n' "$journal_output" \
                                | grep -Ei 'failed password|authentication failure|invalid user' \
                                | tail -n 100 || true
                        )"
                        if [[ -n "$failed_logins" ]]; then
                            printf '%s\n' "$failed_logins"
                        else
                            report_success "No failed SSH authentication entries found in the last 7 days."
                        fi
                    else
                        journal_status=$?
                        report_error \
                            "SSH journal query failed (exit status $journal_status)." \
                            "Verify journal access and the ssh/sshd service names."
                    fi
                fi
                pause
                ;;
            7) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Quickhacks
# ------------------------------------------------------------------------------

randomize_mac_address() {
    local iface="$1"
    local was_up=0
    local result=0

    require_commands sudo ip macchanger grep head || return 1

    if ! ip link show dev "$iface" >/dev/null 2>&1; then
        report_error \
            "Network interface not found: $iface" \
            "List interfaces with 'ip -brief link' and retry with an exact name."
        return 1
    fi

    if ip link show dev "$iface" | head -n 1 | grep -qE '<[^>]*\bUP\b[^>]*>'; then
        was_up=1
    fi

    if is_dry_run; then
        preview_command "Bring $iface down" sudo ip link set dev "$iface" down
        preview_command "Randomize the MAC address for $iface" sudo macchanger -r "$iface"
        if ((was_up == 1)); then
            preview_command "Restore $iface to its original up state" sudo ip link set dev "$iface" up
        fi
        return 0
    fi

    begin_operation \
        "MAC randomization on $iface" \
        "The interface state may need manual verification."
    register_network_restore "$iface" "$was_up"

    if ! sudo ip link set dev "$iface" down; then
        report_error \
            "Unable to bring $iface down." \
            "Check sudo authorization and whether another service manages the interface."
        result=1
    elif ! sudo macchanger -r "$iface"; then
        report_error \
            "MAC randomization failed for $iface." \
            "Verify the driver supports address changes and retry while disconnected."
        result=1
    fi

    if ! perform_registered_cleanup; then
        result=1
    fi

    end_operation
    return "$result"
}

quickhacks_menu() {
    local choice=""
    local target_file=""

    while true; do
        banner
        ui_section "QUICKHACKS" "FIELD TOOLS // DIAGNOSTICS + RAPID ACTIONS"
        menu_item 1 "Temperature monitor" "SENSORS // LIVE"
        menu_item 2 "Ping sweep" "NETWORK // DISCOVERY"
        menu_item 3 "Wi-Fi analyzer" "WIRELESS // SPECTRUM"
        menu_item 4 "Kill process" "PROCESS // TERMINATE"
        menu_item 5 "Flush DNS cache" "DNS // PURGE"
        menu_item 6 "Securely shred a file" "DATA // DESTROY"
        menu_item 7 "Randomize MAC address" "IDENTITY // MASK"
        menu_item 8 "Return to control deck" "NAV // BACK"

        prompt_choice choice "HACKS"

        case "$choice" in
            1)
                if require_commands watch sensors; then
                    run_checked \
                        "Temperature monitor" \
                        "Run sensors-detect and verify hardware-monitoring modules are loaded." \
                        watch -n 2 sensors
                fi
                pause
                ;;
            2)
                if ! require_commands nmap; then
                    pause
                    continue
                fi
                read -r -p "Network/CIDR (example 10.31.1.0/24): " network
                run_checked \
                    "Ping sweep" \
                    "Verify the CIDR value, network connectivity, and scan permissions." \
                    nmap -sn "$network"
                pause
                ;;
            3)
                if require_commands sudo wavemon; then
                    run_checked \
                        "Wi-Fi analyzer" \
                        "Verify a wireless interface is present and sudo access is available." \
                        sudo wavemon
                fi
                pause
                ;;
            4)
                read -r -p "PID to terminate: " pid
                if [[ "$pid" =~ ^[0-9]+$ ]]; then
                    run_mutating_checked \
                        "Process termination for PID $pid" \
                        "Confirm the process still exists and that you own it or have sufficient privileges." \
                        kill "$pid"
                else
                    echo "Invalid PID."
                fi
                pause
                ;;
            5)
                if require_commands sudo resolvectl; then
                    if run_mutating_checked \
                        "DNS cache flush" \
                        "Verify systemd-resolved is running and sudo access is available." \
                        sudo resolvectl flush-caches; then
                        if ! is_dry_run; then
                            report_success "DNS cache flushed."
                        fi
                    fi
                fi
                pause
                ;;
            6)
                if require_commands shred; then
                    prompt_path target_file "SHRED PATH"
                    if [[ -f "$target_file" ]]; then
                        warn_destructive
                        if confirm_yes "Type YES to permanently shred '$target_file': "; then
                            run_mutating_checked \
                                "File shred" \
                                "Check file permissions and filesystem support; the file may remain partially overwritten." \
                                shred -u -v -- "$target_file"
                        fi
                    else
                        echo "File not found."
                    fi
                fi
                pause
                ;;
            7)
                read -r -p "Network interface: " iface
                randomize_mac_address "$iface"
                pause
                ;;
            8) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Docker Maintenance
# ------------------------------------------------------------------------------

compose_for_file() {
    local compose_file="$1"
    docker compose -f "$compose_file" "${@:2}"
}

discover_compose_files() {
    find "$STACK_ROOT" -mindepth 2 -maxdepth 2 -type f \
        \( -name 'compose.yml' -o -name 'compose.yaml' -o -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \) \
        -print0 2>/dev/null | sort -z
}

compose_stack_name() {
    basename "$(dirname "$1")"
}

select_compose_stacks() {
    local available_name="$1"
    local selected_name="$2"
    local -n available_ref="$available_name"
    local -n selected_ref="$selected_name"
    local selection=""
    local token
    local index
    local invalid=0
    local -a tokens=()
    local -A selected_indices=()

    selected_ref=()

    while true; do
        echo "Discovered ${#available_ref[@]} Compose stack(s):"
        for index in "${!available_ref[@]}"; do
            printf '  [%02d] %-24s %s\n' \
                "$((index + 1))" \
                "$(compose_stack_name "${available_ref[$index]}")" \
                "${available_ref[$index]}"
        done

        echo
        echo "Enter stack numbers separated by spaces or commas."
        echo "Type A for every stack or Q to cancel."
        if ! read -r -p "Stack selection: " selection; then
            return 1
        fi

        case "${selection,,}" in
            a|all)
                selected_ref=("${available_ref[@]}")
                return 0
                ;;
            q|quit)
                return 1
                ;;
        esac

        selection="${selection//,/ }"
        read -r -a tokens <<< "$selection"
        selected_ref=()
        selected_indices=()
        invalid=0

        if ((${#tokens[@]} == 0)); then
            invalid=1
        fi

        for token in "${tokens[@]}"; do
            if ! integer_in_range "$token" 1 "${#available_ref[@]}"; then
                invalid=1
                break
            fi

            index=$((10#$token - 1))
            if [[ -z "${selected_indices[$index]+selected}" ]]; then
                selected_ref+=("${available_ref[$index]}")
                selected_indices[$index]=1
            fi
        done

        if ((invalid == 0)) && ((${#selected_ref[@]} > 0)); then
            return 0
        fi

        selected_ref=()
        report_warning "Invalid stack selection; choose listed numbers, A, or Q."
        echo
    done
}

show_docker_update_plan() {
    local selected_name="$1"
    # selected_name is contractually the name of an indexed array.
    # shellcheck disable=SC2178
    local -n selected_ref="$selected_name"
    local compose_file
    local stack_name
    local index=0

    echo
    separator
    echo "DOCKER UPDATE PLAN"
    separator
    echo "Selected Compose projects: ${#selected_ref[@]}"

    for compose_file in "${selected_ref[@]}"; do
        ((index += 1))
        stack_name="$(compose_stack_name "$compose_file")"
        printf '\n  [%02d] PROJECT: %s\n' "$index" "$stack_name"
        printf '       Compose file: %s\n' "$compose_file"
        printf '       Pull:   docker compose -f %q pull\n' "$compose_file"
        printf '       Deploy: docker compose -f %q up -d --remove-orphans\n' "$compose_file"
        printf '       Verify: container state, health status, and docker compose ps\n'
    done

    echo
    echo "Optional post-action: docker image prune -f, offered with a separate confirmation"
    echo "only if every selected stack succeeds."
    echo "Recovery evidence: save before/after container and image state in a private report."
}

offer_image_prune() {
    echo
    report_warning "Image pruning can remove cached images that may be useful for manual recovery."
    if ! confirm_yes "Type YES to prune unused Docker images as a separate action: "; then
        echo "Unused image pruning skipped."
        return 0
    fi

    run_mutating_checked \
        "Prune unused Docker images" \
        "Run 'docker image prune' manually after checking daemon access." \
        docker image prune -f
}

create_docker_state_report() {
    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    local report_dir="$state_home/cyberops/docker"

    DOCKER_REPORT_FILE=""
    if ! mkdir -p -- "$report_dir"; then
        report_error \
            "Could not create the Docker recovery-report directory: $report_dir" \
            "Check directory ownership and available disk space."
        return 1
    fi

    DOCKER_REPORT_FILE="$(mktemp "$report_dir/update-$(date '+%Y%m%d-%H%M%S').XXXXXX.log")" || {
        report_error \
            "Could not create a Docker recovery report under $report_dir." \
            "Check directory ownership and available disk space."
        return 1
    }

    if ! chmod 600 -- "$DOCKER_REPORT_FILE"; then
        report_error \
            "Could not restrict access to Docker recovery report: $DOCKER_REPORT_FILE" \
            "Correct the file permissions before running Docker maintenance."
        DOCKER_REPORT_FILE=""
        return 1
    fi

    {
        printf 'CYBEROPS Docker recovery report\n'
        printf 'Started: %s\n' "$(timestamp)"
        printf 'Stack root: %s\n' "$STACK_ROOT"
        printf 'Note: This report records state for manual recovery; CYBEROPS does not automatically roll back.\n'
    } >> "$DOCKER_REPORT_FILE"
}

capture_stack_state() {
    local phase="$1"
    local compose_file="$2"
    local cid
    local inspect_format
    local -a containers=()

    [[ -n "$DOCKER_REPORT_FILE" ]] || return 1

    {
        printf '\n[%s] %s\n' "$phase" "$(timestamp)"
        printf 'Compose file: %s\n' "$compose_file"
    } >> "$DOCKER_REPORT_FILE" || return 1

    mapfile -t containers < <(
        compose_for_file "$compose_file" ps --all --quiet 2>/dev/null
    )

    if ((${#containers[@]} == 0)); then
        printf 'Containers: none\n' >> "$DOCKER_REPORT_FILE"
        return 0
    fi

    inspect_format='container={{.Name}} service={{index .Config.Labels "com.docker.compose.service"}} image_ref={{.Config.Image}} image_id={{.Image}} state={{.State.Status}} exit={{.State.ExitCode}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'
    for cid in "${containers[@]}"; do
        if ! docker inspect -f "$inspect_format" "$cid" >> "$DOCKER_REPORT_FILE" 2>&1; then
            printf 'container=%s inspection=failed\n' "$cid" >> "$DOCKER_REPORT_FILE"
            return 1
        fi
    done
}

stack_header() {
    local stack_name="$1"
    echo
    separator
    echo "STACK: $stack_name"
    separator
}

show_failure_logs() {
    local compose_file="$1"

    echo
    echo -e "${YELLOW}Recent container logs:${RESET}"
    if ! compose_for_file "$compose_file" logs \
        --tail "$FAILURE_LOG_LINES" \
        --no-color 2>&1; then
        report_warning "Recent logs were unavailable; run docker compose logs manually for $compose_file."
    fi
}

check_stack_health() {
    local compose_file="$1"
    local start_time
    local elapsed
    local cid
    local state
    local exit_code
    local health
    local unhealthy=0
    local pending=0
    local -a containers=()

    start_time="$(date +%s)"

    while true; do
        unhealthy=0
        pending=0
        containers=()

        # Refresh the full project container set on every pass. Compose may
        # replace container IDs while an update is still converging, and
        # successful one-shot services are visible only with --all.
        mapfile -t containers < <(
            compose_for_file "$compose_file" ps --all --quiet 2>/dev/null
        )

        if ((${#containers[@]} == 0)); then
            echo "No Compose containers detected."
            return 1
        fi

        for cid in "${containers[@]}"; do
            state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo unknown)"

            case "$state" in
                running)
                    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo unknown)"
                    case "$health" in
                        healthy|none)
                            ;;
                        starting)
                            pending=1
                            ;;
                        *)
                            echo "Container ${cid:0:12} health: $health"
                            unhealthy=1
                            ;;
                    esac
                    ;;
                exited)
                    exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$cid" 2>/dev/null || echo unknown)"
                    if [[ "$exit_code" == "0" ]]; then
                        echo "Container ${cid:0:12} completed successfully (one-shot exit 0)."
                    else
                        echo "Container ${cid:0:12} exited with status $exit_code."
                        unhealthy=1
                    fi
                    ;;
                created|restarting|removing)
                    echo "Container ${cid:0:12} state: $state"
                    pending=1
                    ;;
                *)
                    echo "Container ${cid:0:12} state: $state"
                    unhealthy=1
                    ;;
            esac
        done

        ((unhealthy == 0 && pending == 0)) && return 0
        ((unhealthy != 0)) && return 1

        elapsed=$(( $(date +%s) - start_time ))
        if ((elapsed >= HEALTH_TIMEOUT)); then
            echo "Health-check timeout after ${HEALTH_TIMEOUT}s."
            return 1
        fi

        sleep "$HEALTH_INTERVAL"
    done
}

update_one_stack() {
    local compose_file="$1"
    local stack_dir
    local stack_name

    stack_dir="$(dirname "$compose_file")"
    stack_name="$(basename "$stack_dir")"

    stack_header "$stack_name"
    echo "Compose file: $compose_file"

    if is_dry_run; then
        preview_command "Pull images for $stack_name" docker compose -f "$compose_file" pull
        preview_command "Start/recreate $stack_name" docker compose -f "$compose_file" up -d --remove-orphans
        echo "Would check container state and Docker health status after recreation."
        return 0
    fi

    if ! capture_stack_state "BEFORE $stack_name" "$compose_file"; then
        report_error \
            "Could not preserve before-state for $stack_name; the stack was not changed." \
            "Check the Docker recovery report and filesystem permissions."
        return 1
    fi

    echo
    echo "[1/4] Pulling images..."
    if ! run_checked \
        "Image pull for $stack_name" \
        "Check registry authentication, image names, and network connectivity." \
        compose_for_file "$compose_file" pull; then
        capture_stack_state "AFTER FAILED PULL $stack_name" "$compose_file" || true
        return 1
    fi

    echo
    echo "[2/4] Starting/recreating stack..."
    if ! run_checked \
        "Initial stack start for $stack_name" \
        "CYBEROPS will retry once after ${RETRY_DELAY}s." \
        compose_for_file "$compose_file" up -d --remove-orphans; then
        report_warning "Initial start failed. Retrying once in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"

        if ! run_checked \
            "Stack start retry for $stack_name" \
            "Review the Compose configuration and recent container logs below." \
            compose_for_file "$compose_file" up -d --remove-orphans; then
            capture_stack_state "AFTER FAILED DEPLOY $stack_name" "$compose_file" || true
            show_failure_logs "$compose_file"
            return 1
        fi
    fi

    echo
    echo "[3/4] Checking container health..."
    if ! run_checked \
        "Health check for $stack_name" \
        "Inspect container state and health-check output before retrying." \
        check_stack_health "$compose_file"; then
        run_checked \
            "Failed-stack status query" \
            "Run docker compose ps manually for $compose_file." \
            compose_for_file "$compose_file" ps || true
        capture_stack_state "AFTER FAILED HEALTH CHECK $stack_name" "$compose_file" || true
        show_failure_logs "$compose_file"
        return 1
    fi

    echo
    echo "[4/4] Stack status:"
    if ! run_checked \
        "Stack status query for $stack_name" \
        "Run docker compose ps manually for $compose_file." \
        compose_for_file "$compose_file" ps; then
        capture_stack_state "AFTER FAILED STATUS QUERY $stack_name" "$compose_file" || true
        return 1
    fi

    if ! capture_stack_state "AFTER SUCCESS $stack_name" "$compose_file"; then
        report_warning "Stack succeeded, but its after-state could not be appended to $DOCKER_REPORT_FILE."
    fi

    report_success "Stack updated successfully: $stack_name"
    return 0
}

docker_update_stacks() {
    local -a compose_files=()
    local -a selected_compose_files=()
    local -a successful_stacks=()
    local -a failed_stacks=()
    local compose_file
    local confirmation_prompt
    local stack_name

    DOCKER_REPORT_FILE=""

    banner
    ui_section "DOCKER MAINTENANCE" "CONTAINER GRID // FULL STACK DEPLOYMENT"
    echo "Started: $(timestamp)"
    echo "Stack root: $STACK_ROOT"
    echo

    if ! require_commands docker find sort date sleep basename dirname tr mkdir mktemp chmod; then
        pause
        return
    fi

    if ! is_dry_run && ! docker info >/dev/null 2>&1; then
        report_error \
            "Docker daemon is unavailable or your user lacks access." \
            "Run 'sudo systemctl status docker' and verify Docker group membership."
        pause
        return
    fi

    if ! docker compose version >/dev/null 2>&1; then
        report_error \
            "Docker Compose v2 plugin is unavailable." \
            "Install the Docker Compose v2 plugin and verify 'docker compose version'."
        pause
        return
    fi

    if [[ ! -d "$STACK_ROOT" ]]; then
        report_error \
            "Stack root does not exist: $STACK_ROOT" \
            "Create the directory or set STACK_ROOT to the correct absolute path."
        pause
        return
    fi

    mapfile -d '' -t compose_files < <(discover_compose_files)

    if ((${#compose_files[@]} == 0)); then
        report_warning "No Compose stacks found under $STACK_ROOT."
        pause
        return
    fi

    if ! select_compose_stacks compose_files selected_compose_files; then
        echo "Docker maintenance cancelled."
        pause
        return
    fi

    show_docker_update_plan selected_compose_files

    echo
    confirmation_prompt="Type YES to update the selected Compose stacks: "
    if is_dry_run; then
        confirmation_prompt="Type YES to preview the selected Compose stack updates: "
    fi
    if ! confirm_yes "$confirmation_prompt"; then
        echo "Docker maintenance cancelled."
        pause
        return
    fi

    if ! is_dry_run; then
        if ! create_docker_state_report; then
            pause
            return
        fi
        echo "Recovery report: $DOCKER_REPORT_FILE"
        begin_operation \
            "Docker Compose stack maintenance" \
            "One or more stacks may be mid-update; inspect Docker status and $DOCKER_REPORT_FILE before retrying."
    fi

    for compose_file in "${selected_compose_files[@]}"; do
        stack_name="$(compose_stack_name "$compose_file")"

        if update_one_stack "$compose_file"; then
            successful_stacks+=("$stack_name")
        else
            failed_stacks+=("$stack_name")
        fi
    done

    if ! is_dry_run; then
        end_operation
    fi

    echo
    separator
    echo "DOCKER MAINTENANCE SUMMARY"
    separator
    echo "Successful stacks: ${#successful_stacks[@]}"
    for stack_name in "${successful_stacks[@]}"; do
        echo "  [OK] $stack_name"
    done

    echo
    echo "Failed stacks: ${#failed_stacks[@]}"
    for stack_name in "${failed_stacks[@]}"; do
        echo "  [FAILED] $stack_name"
    done

    if [[ -n "$DOCKER_REPORT_FILE" ]]; then
        echo
        echo "Recovery report: $DOCKER_REPORT_FILE"
    fi

    if ((${#failed_stacks[@]} == 0)); then
        if is_dry_run; then
            offer_image_prune || true
            echo
            report_success "Docker maintenance preview completed."
        else
            offer_image_prune || true

            echo
            echo "Final Docker status:"
            run_checked \
                "Final Docker status query" \
                "Run 'docker ps' manually and verify daemon access." \
                docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true

            echo
            report_success "Docker maintenance completed successfully."
        fi
        echo "Finished: $(timestamp)"
    else
        echo
        report_error \
            "Docker maintenance completed with errors." \
            "Review each failed stack above before running maintenance again."
        echo "No automatic rollback was attempted."
        if [[ -n "$DOCKER_REPORT_FILE" ]]; then
            echo "Use the before/after image IDs in $DOCKER_REPORT_FILE for manual recovery."
        fi
        echo "Unused image pruning skipped because one or more stacks failed."
        echo "Finished: $(timestamp)"
    fi

    pause
}

docker_status() {
    banner
    ui_section "DOCKER STATUS" "CONTAINER GRID // RUNTIME TELEMETRY"

    if ! require_commands docker; then
        pause
        return
    fi

    if run_checked \
        "Docker container status query" \
        "Verify the Docker daemon is running and your user has access." \
        docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'; then
        echo
        run_checked \
            "Docker disk-usage query" \
            "Verify the Docker daemon is running and your user has access." \
            docker system df
    fi
    pause
}

docker_menu() {
    local choice=""

    while true; do
        banner
        ui_section "DOCKER OPS" "CONTAINER GRID // COMPOSE MAINTENANCE"
        printf '  %bSTACK ROOT%b  %s\n\n' "$MAGENTA" "$RESET" "$STACK_ROOT"
        menu_item 1 "Select/update Compose stacks" "GRID // DEPLOY"
        menu_item 2 "Container/status overview" "GRID // STATUS"
        menu_item 3 "Return to control deck" "NAV // BACK"

        prompt_choice choice "DOCKER"

        case "$choice" in
            1) docker_update_stacks ;;
            2) docker_status ;;
            3) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# USB Operations
# ------------------------------------------------------------------------------

list_usb_candidates() {
    local device
    local type

    while read -r device; do
        [[ -n "$device" ]] || continue
        device="$(resolve_device_path "$device")" || continue
        type="$(block_property "$device" TYPE)"

        [[ "$type" == "disk" ]] || continue
        is_removable_usb_disk "$device" || continue
        is_protected_system_disk "$device" && continue

        printf '%s\n' "$device"
    done < <(lsblk -dn -o PATH 2>/dev/null)
}

select_usb_device() {
    local -a candidates=()
    local dev
    local i
    local size
    local model
    local transport
    local mounts
    local selection

    SELECTED_USB_DEVICE=""
    SELECTED_USB_IDENTITY=""
    mapfile -t candidates < <(list_usb_candidates)

    if ((${#candidates[@]} == 0)); then
        report_error \
            "No removable/USB disks were detected." \
            "Connect the target device and verify it appears in lsblk."
        return 1
    fi

    echo "Detected removable disks:"
    echo

    for i in "${!candidates[@]}"; do
        dev="${candidates[$i]}"
        size="$(block_property "$dev" SIZE)"
        model="$(block_property "$dev" MODEL)"
        transport="$(block_property "$dev" TRAN)"
        mounts="$(device_mountpoints "$dev" | paste -sd ',' -)"
        printf "  %d. %-12s %-8s %-24s transport=%-7s mounts=%s\n" \
            "$((i + 1))" "$dev" "${size:-unknown}" "${model:-Unknown}" \
            "${transport:-unknown}" "${mounts:-not mounted}"
    done

    echo
    read -r -p "Select target disk number: " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] ||
       ((selection < 1 || selection > ${#candidates[@]})); then
        report_error "Invalid disk selection." "Choose one of the displayed disk numbers."
        return 1
    fi

    dev="${candidates[$((selection - 1))]}"
    SELECTED_USB_IDENTITY="$(usb_device_identity "$dev")" || {
        report_error \
            "Unable to record the selected device identity." \
            "Reconnect the device and select it again."
        return 1
    }
    SELECTED_USB_DEVICE="$dev"
}

unmount_device_filesystems() {
    local device="$1"
    local node
    local mounts
    local i
    local -a nodes=()

    mapfile -t nodes < <(
        lsblk -ln -o PATH,TYPE -- "$device" 2>/dev/null \
            | awk '$2 == "disk" || $2 == "part" { print $1 }'
    )

    # Unmount child partitions before the parent disk. Some hybrid images, such
    # as Tails, mount an ISO9660 filesystem directly from the whole disk.
    for ((i = ${#nodes[@]} - 1; i >= 0; i--)); do
        node="${nodes[$i]}"
        mounts="$(device_mountpoints "$node")"
        [[ -n "$mounts" ]] || continue

        echo "Unmounting $node ..."
        printf '%s\n' "$mounts" | sed 's/^/  /'
        sudo umount -- "$node" || return 1
    done
}

preview_device_unmounts() {
    local device="$1"
    local node
    local mounts
    local i
    local found=0
    local -a nodes=()

    mapfile -t nodes < <(
        lsblk -ln -o PATH,TYPE -- "$device" 2>/dev/null \
            | awk '$2 == "disk" || $2 == "part" { print $1 }'
    )

    for ((i = ${#nodes[@]} - 1; i >= 0; i--)); do
        node="${nodes[$i]}"
        mounts="$(device_mountpoints "$node")"
        [[ -n "$mounts" ]] || continue
        preview_command "Unmount filesystems on $node" sudo umount -- "$node"
        found=1
    done

    if ((found == 0)); then
        echo "No mounted target filesystems would need to be unmounted."
    fi
}

dd_byte_count_mode() {
    if dd if=/dev/zero of=/dev/null bs=16M count=1B 2>/dev/null; then
        printf 'suffix\n'
    elif dd if=/dev/zero of=/dev/null bs=16M count=1 \
        iflag=count_bytes 2>/dev/null; then
        printf 'count_bytes\n'
    else
        return 1
    fi
}

zero_fill_device() {
    local target="$1"
    local count_mode
    local target_bytes

    target_bytes="$(block_size_bytes "$target")"
    if ! [[ "$target_bytes" =~ ^[1-9][0-9]*$ ]]; then
        report_error \
            "Unable to determine a valid byte capacity for $target." \
            "Reconnect the device, verify it with lsblk, and select it again."
        return 1
    fi

    count_mode="$(dd_byte_count_mode)" || {
        report_error \
            "Installed dd cannot express an exact byte-count write." \
            "Install a supported GNU Coreutils or uutils dd implementation."
        return 1
    }

    case "$count_mode" in
        suffix)
            sudo dd if=/dev/zero of="$target" bs=16M count="${target_bytes}B" \
                status=progress conv=fsync
            ;;
        count_bytes)
            sudo dd if=/dev/zero of="$target" bs=16M count="$target_bytes" \
                iflag=count_bytes status=progress conv=fsync
            ;;
        *)
            report_error \
                "Unable to select a supported dd byte-count mode." \
                "Verify the installed dd implementation and retry."
            return 1
            ;;
    esac
}

validate_iso() {
    local iso="$1"

    [[ -f "$iso" ]] || {
        report_error \
            "ISO file does not exist: $iso" \
            "Verify the path and file permissions before retrying."
        return 1
    }

    if [[ "$(file -b --mime-type "$iso" 2>/dev/null)" != "application/x-iso9660-image" ]]; then
        report_warning "File does not identify as an ISO9660 image."
        if ! confirm_yes "Type YES to continue anyway: "; then
            return 1
        fi
    fi

    return 0
}

build_bootable_usb() {
    local iso
    local iso_start
    local target
    local target_identity
    local expected_hash
    local actual_hash

    banner
    ui_section "CREATE BOOTABLE USB" "REMOVABLE MEDIA // ISO FLASH PROTOCOL"
    echo "Uses Ubuntu-native tools: lsblk, findmnt, sha256sum, umount, dd, sync."
    echo

    if ! require_commands readlink lsblk findmnt awk sed sort paste file sha256sum sudo umount dd sync; then
        pause
        return
    fi

    iso_start="$HOME/Downloads/"
    [[ -d "$iso_start" ]] || iso_start="$HOME/"
    prompt_path iso "ISO PATH" "$iso_start"

    validate_iso "$iso" || {
        pause
        return
    }

    echo
    read -r -p "Expected SHA-256 (optional; press Enter to skip): " expected_hash

    if [[ -n "$expected_hash" ]]; then
        actual_hash="$(sha256sum "$iso" | awk '{print $1}')"

        echo "Expected: $expected_hash"
        echo "Actual:   $actual_hash"

        if [[ "${actual_hash,,}" != "${expected_hash,,}" ]]; then
            report_error \
                "SHA-256 verification failed; the write was aborted." \
                "Download the ISO again or verify the expected checksum source."
            pause
            return
        fi

        report_success "SHA-256 verification passed."
    fi

    echo
    if ! select_usb_device; then
        pause
        return
    fi

    target="$SELECTED_USB_DEVICE"
    target_identity="$SELECTED_USB_IDENTITY"

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo
    warn_destructive
    echo
    echo "ISO:    $iso"
    echo "TARGET: $target"
    echo
    if ! run_checked \
        "Selected-device detail query" \
        "Reconnect the device and select it again." \
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "$target"; then
        pause
        return
    fi
    echo
    echo "EVERYTHING on $target will be overwritten."

    if is_dry_run; then
        echo
        preview_device_unmounts "$target"
        preview_command \
            "Write the ISO image to $target" \
            sudo dd if="$iso" of="$target" bs=4M status=progress conv=fsync
        preview_command "Flush filesystem buffers" sync
        report_success "Bootable USB preview completed; no device state was changed."
        pause
        return
    fi

    if ! confirm_yes "Type YES to write the ISO to $target: "; then
        echo "Operation cancelled."
        pause
        return
    fi

    echo
    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo "Unmounting target partitions..."
    if ! run_checked \
        "Target filesystem unmount" \
        "Close applications using the device, unmount it, and retry." \
        unmount_device_filesystems "$target"; then
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity" 1; then
        pause
        return
    fi

    echo
    echo "Writing image..."
    echo "Command: sudo dd if=\"$iso\" of=\"$target\" bs=4M status=progress conv=fsync"
    echo

    begin_operation \
        "Bootable USB write to $target" \
        "The target may contain an incomplete image and must be rewritten before use."

    if run_checked \
        "Bootable USB image write" \
        "Inspect the connection and rewrite the target before use; it may contain an incomplete image." \
        sudo dd if="$iso" of="$target" bs=4M status=progress conv=fsync; then
        if run_checked \
            "Filesystem buffer sync" \
            "Keep the USB connected and run 'sync' again before ejecting it." \
            sync; then
            end_operation
            echo
            report_success "Bootable USB creation completed successfully."
            echo "You may now safely eject $target."
        else
            end_operation
        fi
    else
        end_operation
    fi

    pause
}

usb_zero_fill() {
    local count_mode
    local target
    local target_identity
    local target_bytes

    banner
    ui_section "USB WIPE / ZERO-FILL" "REMOVABLE MEDIA // DESTRUCTIVE PROTOCOL"
    warn_destructive
    echo "This function overwrites the selected removable drive with zeroes."
    echo "On flash storage, wear leveling means this is not a guaranteed secure erase."
    echo

    if ! require_commands readlink lsblk findmnt awk sed sort paste sudo umount dd sync; then
        pause
        return
    fi

    if ! select_usb_device; then
        pause
        return
    fi

    target="$SELECTED_USB_DEVICE"
    target_identity="$SELECTED_USB_IDENTITY"

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo
    echo "TARGET: $target"
    if ! run_checked \
        "Selected-device detail query" \
        "Reconnect the device and select it again." \
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "$target"; then
        pause
        return
    fi
    echo
    echo -e "${RED}ALL DATA ON THIS DEVICE WILL BE DESTROYED.${RESET}"

    if is_dry_run; then
        target_bytes="$(block_size_bytes "$target")"
        if ! [[ "$target_bytes" =~ ^[1-9][0-9]*$ ]]; then
            report_error \
                "Unable to determine a valid byte capacity for $target." \
                "Reconnect the device, verify it with lsblk, and select it again."
            pause
            return
        fi

        count_mode="$(dd_byte_count_mode)" || {
            report_error \
                "Installed dd cannot express an exact byte-count write." \
                "Install a supported GNU Coreutils or uutils dd implementation."
            pause
            return
        }

        echo
        preview_device_unmounts "$target"
        if [[ "$count_mode" == "suffix" ]]; then
            preview_command \
                "Zero-fill $target" \
                sudo dd if=/dev/zero of="$target" bs=16M count="${target_bytes}B" \
                    status=progress conv=fsync
        else
            preview_command \
                "Zero-fill $target" \
                sudo dd if=/dev/zero of="$target" bs=16M count="$target_bytes" \
                    iflag=count_bytes status=progress conv=fsync
        fi
        preview_command "Flush filesystem buffers" sync
        report_success "USB zero-fill preview completed; no device state was changed."
        pause
        return
    fi

    if ! confirm_yes "Type YES to continue: "; then
        echo "Operation cancelled."
        pause
        return
    fi

    read -r -p "For final confirmation, type the device path exactly ($target): " final_target

    if [[ "$final_target" != "$target" ]]; then
        echo -e "${YELLOW}Device confirmation did not match. Aborting.${RESET}"
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    if ! run_checked \
        "Target filesystem unmount" \
        "Close applications using the device, unmount it, and retry." \
        unmount_device_filesystems "$target"; then
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity" 1; then
        pause
        return
    fi

    echo
    echo "Zero-filling $target ..."
    begin_operation \
        "USB zero-fill on $target" \
        "The target may be only partially overwritten; verify it before reuse."

    if run_checked \
        "USB zero-fill" \
        "Inspect the connection and repeat the wipe before reuse; the target may be partially overwritten." \
        zero_fill_device "$target"; then
        if run_checked \
            "Filesystem buffer sync" \
            "Keep the USB connected and run 'sync' again before ejecting it." \
            sync; then
            end_operation
            echo
            report_success "USB zero-fill completed."
        else
            end_operation
        fi
    else
        end_operation
    fi

    pause
}

usb_menu() {
    local choice=""

    while true; do
        banner
        ui_section "USB OPERATIONS" "REMOVABLE MEDIA // WRITE + WIPE"
        menu_item 1 "Create bootable USB from ISO" "MEDIA // FLASH"
        menu_item 2 "Wipe / zero-fill USB drive" "MEDIA // DESTROY"
        menu_item 3 "List removable storage" "MEDIA // SCAN"
        menu_item 4 "Return to control deck" "NAV // BACK"

        prompt_choice choice "USB"

        case "$choice" in
            1) build_bootable_usb ;;
            2) usb_zero_fill ;;
            3)
                echo
                if require_commands lsblk; then
                    run_checked \
                        "Removable-storage query" \
                        "Verify sysfs is mounted and storage devices are accessible." \
                        lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,TRAN,RM
                fi
                pause
                ;;
            4) return ;;
            *) invalid_selection ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# System Setup
# ------------------------------------------------------------------------------

system_setup() {
    banner
    ui_section "SYSTEM SETUP" "BOOTSTRAP // OPTIONAL DEPENDENCIES"
    echo "This installs optional CYBEROPS utilities using APT."
    echo "Core commands used by Docker/USB operations are provided by Ubuntu packages."
    echo

    if ! require_commands sudo apt; then
        echo "Automatic setup currently targets Ubuntu/Debian."
        pause
        return
    fi

    if ! confirm_yes "Type YES to install/update CYBEROPS dependencies: "; then
        echo "Setup cancelled."
        pause
        return
    fi

    if ! run_mutating_checked \
        "Dependency package-list update" \
        "Check network connectivity and APT repository configuration, then retry." \
        sudo apt update; then
        pause
        return
    fi

    local -a packages=(
        figlet
        lolcat
        htop
        nmap
        wavemon
        macchanger
        lm-sensors
        clamav
        rkhunter
        curl
    )

    if run_mutating_checked \
        "CYBEROPS dependency installation" \
        "Review unavailable or conflicting packages in the APT output, then retry." \
        sudo apt install -y "${packages[@]}"; then
        if ! is_dry_run; then
            echo
            report_success "CYBEROPS dependency setup complete."
        fi
    fi
    pause
}

# ------------------------------------------------------------------------------
# Main Menu
# ------------------------------------------------------------------------------

main_menu() {
    local choice=""

    while true; do
        banner
        ui_section "CONTROL DECK" "SELECT AN OPERATIONS NODE"
        menu_item 0 "System Setup" "BOOTSTRAP // DEPENDENCIES"
        menu_item 1 "Admin Ops" "SYSTEM // CONTROL"
        menu_item 2 "Info Scan" "HOST // RECON"
        menu_item 3 "VPN Control" "NETWORK // TUNNELS"
        menu_item 4 "Cyber Defense" "SECURITY // DEFENSE"
        menu_item 5 "Quickhacks" "TOOLS // FIELD KIT"
        menu_item 6 "Docker Ops" "CONTAINERS // GRID"
        menu_item 7 "USB Operations" "MEDIA // I/O"
        menu_item 8 "Exit Interface" "SESSION // DISCONNECT"

        prompt_choice choice "CYBEROPS"

        case "$choice" in
            0) system_setup ;;
            1) admin_menu ;;
            2) info_menu ;;
            3) vpn_menu ;;
            4) cyber_defense_menu ;;
            5) quickhacks_menu ;;
            6) docker_menu ;;
            7) usb_menu ;;
            8)
                echo
                typewrite "LINK TERMINATED // Returning control to local shell..." 0.015
                exit 0
                ;;
            *) invalid_selection ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if ! validate_configuration; then
        exit 2
    fi
    install_signal_handlers
    main_menu
fi
