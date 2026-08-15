#!/usr/bin/env bash

# Host information operations contract
# ------------------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Read-only host, hardware, network, disk, and socket telemetry.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   Runs read-only system inspection commands.
#   Loading this module itself produces no output and performs no mutation.

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
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

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
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
