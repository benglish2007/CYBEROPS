#!/usr/bin/env bash

# Main control deck contract
# --------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Top-level module selection and session-disconnect output.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   Dispatches feature menus and exits only when the user selects disconnect.
#   Loading this module itself produces no output and performs no mutation.

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
