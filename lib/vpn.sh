#!/usr/bin/env bash

# VPN operations contract
# -----------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Tailscale and ExpressVPN status and control results.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   May connect or disconnect VPN clients through dry-run-aware helpers.
#   Loading this module itself produces no output and performs no mutation.

# ------------------------------------------------------------------------------
# VPN Control
# ------------------------------------------------------------------------------

EXPRESSVPN_CLI=""

select_expressvpn_cli() {
    EXPRESSVPN_CLI=""
    if have expressvpnctl; then
        EXPRESSVPN_CLI="expressvpnctl"
    elif have expressvpn; then
        EXPRESSVPN_CLI="expressvpn"
    else
        report_error \
            "ExpressVPN command-line controls are unavailable." \
            "Install the current ExpressVPN client with expressvpnctl, then retry."
        return 1
    fi
}

show_vpn_status() {
    local clients_found=0
    local failures=0

    if have tailscale; then
        clients_found=1
        printf '%s\n' '[TAILSCALE]'
        run_checked \
            "Tailscale status query" \
            "Verify the Tailscale daemon is running." \
            tailscale status || ((failures += 1))
    fi
    if have expressvpnctl || have expressvpn; then
        ((clients_found == 0)) || printf '\n'
        clients_found=1
        printf '%s\n' '[EXPRESSVPN]'
        select_expressvpn_cli || return 1
        run_checked \
            "ExpressVPN status query" \
            "Open the ExpressVPN GUI or enable background mode, then verify the daemon is running." \
            "$EXPRESSVPN_CLI" status || ((failures += 1))
    fi
    if ((clients_found == 0)); then
        report_error \
            "No supported VPN client is installed." \
            "Install Tailscale or ExpressVPN, then retry."
        return 1
    fi
    ((failures == 0))
}

vpn_menu() {
    local choice=""

    while true; do
        banner
        ui_section "VPN CONTROL" "ENCRYPTED LINKS // TUNNEL CONTROL"
        menu_item 1 "Tailscale status" "TAILNET // STATUS"
        menu_privileged_item 2 "Tailscale up" "TAILNET // CONNECT"
        menu_privileged_item 3 "Tailscale down" "TAILNET // DISCONNECT"
        menu_item 4 "ExpressVPN status" "VPN // STATUS"
        menu_item 5 "ExpressVPN connect" "VPN // SELECTED REGION"
        menu_item 6 "ExpressVPN disconnect" "VPN // DISCONNECT"
        menu_item 7 "ExpressVPN background mode on" "VPN // HEADLESS ENABLE"
        menu_item 8 "ExpressVPN background mode off" "VPN // HEADLESS DISABLE"
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

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
                if select_expressvpn_cli; then
                    run_checked "ExpressVPN status query" \
                        "Open the ExpressVPN GUI or enable background mode, then verify the daemon is running." \
                        "$EXPRESSVPN_CLI" status
                fi
                pause
                ;;
            5)
                if select_expressvpn_cli; then
                    run_mutating_checked \
                        "ExpressVPN connection" \
                        "Open the ExpressVPN GUI or enable background mode, then verify login and daemon status." \
                        "$EXPRESSVPN_CLI" connect
                fi
                pause
                ;;
            6)
                if select_expressvpn_cli; then
                    run_mutating_checked "ExpressVPN disconnection" \
                        "Verify the ExpressVPN daemon is running." \
                        "$EXPRESSVPN_CLI" disconnect
                fi
                pause
                ;;
            7)
                if require_commands expressvpnctl; then
                    run_mutating_checked \
                        "ExpressVPN background-mode enablement" \
                        "Verify the current ExpressVPN GUI client is installed and logged in." \
                        expressvpnctl background enable
                fi
                pause
                ;;
            8)
                if require_commands expressvpnctl; then
                    run_mutating_checked \
                        "ExpressVPN background-mode disablement" \
                        "Open the ExpressVPN GUI before reconnecting; disabling background mode may disconnect the VPN." \
                        expressvpnctl background disable
                fi
                pause
                ;;
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
