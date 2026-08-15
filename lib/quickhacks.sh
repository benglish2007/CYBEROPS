#!/usr/bin/env bash

# Quickhacks operations contract
# ------------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Diagnostic, DNS, process, shred, and MAC-operation results.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   May mutate DNS, processes, files, and interfaces behind existing safety controls.
#   Loading this module itself produces no output and performs no mutation.

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
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

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
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
