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
    if have expressvpn; then
        ((clients_found == 0)) || printf '\n'
        clients_found=1
        printf '%s\n' '[EXPRESSVPN]'
        run_checked \
            "ExpressVPN status query" \
            "Verify the ExpressVPN daemon is running." \
            expressvpn status || ((failures += 1))
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
        menu_item 2 "Tailscale up" "TAILNET // CONNECT"
        menu_item 3 "Tailscale down" "TAILNET // DISCONNECT"
        menu_item 4 "ExpressVPN status" "VPN // STATUS"
        menu_item 5 "ExpressVPN connect" "VPN // CONNECT"
        menu_item 6 "ExpressVPN disconnect" "VPN // DISCONNECT"
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
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
