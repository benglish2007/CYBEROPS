#!/usr/bin/env bash

# Administrative operations contract
# ----------------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Package, storage, memory, service, and reboot menu output.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   May invoke confirmed APT upgrades and reboot commands.
#   Loading this module itself produces no output and performs no mutation.

# ------------------------------------------------------------------------------
# Admin Ops
# ------------------------------------------------------------------------------

show_local_disk_usage() {
    require_commands df || return 1
    run_checked \
        "Local filesystem usage query" \
        "Verify local mounted filesystems are accessible." \
        df -lhT
}

show_memory_usage() {
    require_commands free || return 1
    run_checked \
        "Memory usage query" \
        "Verify procfs is mounted and readable." \
        free -h
}

show_running_services() {
    require_commands systemctl || return 1
    run_checked \
        "Running-service query" \
        "Verify systemd is the active service manager." \
        systemctl --type=service --state=running --no-pager
}

show_failed_services() {
    require_commands systemctl || return 1
    run_checked \
        "Failed-service query" \
        "Verify systemd is the active service manager." \
        systemctl --failed --no-pager
}

admin_menu() {
    local choice=""

    while true; do
        banner
        ui_section "ADMIN OPS" "SYSTEM CONTROL // PACKAGES + SERVICES"
        menu_privileged_item 1 "Update package lists" "APT // SYNC"
        menu_privileged_item 2 "Upgrade installed packages" "APT // UPGRADE"
        menu_item 3 "Disk usage" "STORAGE // TELEMETRY"
        menu_item 4 "Memory usage" "MEMORY // TELEMETRY"
        menu_item 5 "Active systemd services" "SERVICES // ACTIVE"
        menu_item 6 "Failed systemd services" "SERVICES // FAILED"
        menu_privileged_item 7 "Reboot system" "POWER // RESTART"
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

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
                            sudo apt upgrade -y
                    fi
                fi
                pause
                ;;
            3)
                show_local_disk_usage
                pause
                ;;
            4)
                show_memory_usage
                pause
                ;;
            5)
                show_running_services
                pause
                ;;
            6)
                show_failed_services
                pause
                ;;
            7)
                printf '%bSystem reboot requested.%b\n' "$YELLOW" "$RESET"
                if require_commands sudo reboot && confirm_yes "Type YES to reboot: "; then
                    run_mutating_checked \
                        "System reboot request" \
                        "Check sudo authorization and system policy before retrying." \
                        sudo reboot
                fi
                ;;
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
