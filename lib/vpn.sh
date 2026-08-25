#!/usr/bin/env bash

# VPN plugin dispatcher contract
# ------------------------------
# Inputs:
#   VPN plugins discovered by lib/plugins.sh plus shared core/UI helpers.
# Outputs:
#   Provider status, dynamic provider menus, and action results.
# Return statuses:
#   Returns nonzero when no usable provider exists or a selected action fails.
# Side effects:
#   May connect or disconnect VPN clients through dry-run-aware plugin actions.
#   Loading this module itself produces no output and performs no mutation.

vpn_plugin_label() {
    local provider="$1"
    printf '%s' "${provider^^}"
}

run_vpn_plugin_action() {
    local plugin_id="$1"
    local action="$2"
    local plugin_path
    local function_name

    plugin_path="$(plugin_path_for vpn "$plugin_id")" || return 1
    load_plugin vpn "$plugin_path" || return 1
    if ! plugin_action_supported "$action"; then
        report_error "VPN plugin $plugin_id does not support action: $action"
        return 1
    fi
    plugin_dependencies_available || return 1
    function_name="cyberops_plugin_$action"
    "$function_name"
}

show_vpn_status() {
    local descriptor
    local plugin_path
    local clients_found=0
    local failures=0

    while IFS= read -r descriptor; do
        plugin_path="${descriptor#*:*:}"
        load_plugin vpn "$plugin_path" >/dev/null || continue
        plugin_action_supported status || continue
        if ! plugin_dependencies_available >/dev/null 2>&1; then
            continue
        fi
        ((clients_found == 0)) || printf '\n'
        clients_found=1
        printf '[%s]\n' "$(vpn_plugin_label "$CYBEROPS_PLUGIN_PROVIDER")"
        cyberops_plugin_status || ((failures += 1))
    done < <(discover_plugins vpn)

    if ((clients_found == 0)); then
        report_error \
            "No supported VPN client is installed." \
            "Install a VPN provider plugin dependency such as tailscale or expressvpnctl, then retry."
        return 1
    fi
    ((failures == 0))
}

vpn_action_label() {
    local action="$1"

    case "$action" in
        status) printf 'Status' ;;
        connect) printf 'Connect' ;;
        disconnect) printf 'Disconnect' ;;
        background_on) printf 'Background mode on' ;;
        background_off) printf 'Background mode off' ;;
        *) printf '%s' "$action" ;;
    esac
}

vpn_action_hint() {
    local action="$1"

    case "$action" in
        status) printf 'VPN // STATUS' ;;
        connect) printf 'VPN // CONNECT' ;;
        disconnect) printf 'VPN // DISCONNECT' ;;
        background_on) printf 'VPN // HEADLESS ENABLE' ;;
        background_off) printf 'VPN // HEADLESS DISABLE' ;;
        *) printf 'VPN // PLUGIN ACTION' ;;
    esac
}

vpn_plugin_menu() {
    local plugin_id="$1"
    local plugin_path
    local choice=""
    local action
    local index
    local selected_action
    local -a actions=()

    plugin_path="$(plugin_path_for vpn "$plugin_id")" || return 1
    while true; do
        load_plugin vpn "$plugin_path" >/dev/null || return 1
        actions=("${CYBEROPS_PLUGIN_ACTIONS[@]}")
        banner
        ui_section "VPN CONTROL" "$CYBEROPS_PLUGIN_NAME // PLUGIN ACTIONS"
        index=1
        for action in "${actions[@]}"; do
            if plugin_action_requires_sudo "$action"; then
                menu_privileged_item "$index" "$(vpn_action_label "$action")" "$(vpn_action_hint "$action")"
            else
                menu_item "$index" "$(vpn_action_label "$action")" "$(vpn_action_hint "$action")"
            fi
            ((index += 1))
        done
        menu_navigation_item 0 "Return to VPN providers" "NAV // BACK"

        prompt_choice choice "VPN"
        if [[ "$choice" == "0" ]]; then
            return
        fi
        if integer_in_range "$choice" 1 "${#actions[@]}"; then
            selected_action="${actions[$((10#$choice - 1))]}"
            run_vpn_plugin_action "$plugin_id" "$selected_action"
            pause
        else
            invalid_selection
        fi
    done
}

vpn_menu() {
    local choice=""
    local descriptor
    local plugin_id
    local plugin_path
    local index
    local -a plugin_ids=()

    while true; do
        plugin_ids=()
        banner
        ui_section "VPN CONTROL" "ENCRYPTED LINKS // PROVIDER PLUGINS"
        index=1
        while IFS= read -r descriptor; do
            plugin_id="${descriptor#*:}"
            plugin_id="${plugin_id%%:*}"
            plugin_path="${descriptor#*:*:}"
            load_plugin vpn "$plugin_path" >/dev/null || continue
            menu_item "$index" "$CYBEROPS_PLUGIN_NAME" "VPN // $CYBEROPS_PLUGIN_PROVIDER"
            plugin_ids+=("$plugin_id")
            ((index += 1))
        done < <(discover_plugins vpn)
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

        prompt_choice choice "VPN"
        if [[ "$choice" == "0" ]]; then
            return
        fi
        if integer_in_range "$choice" 1 "${#plugin_ids[@]}"; then
            vpn_plugin_menu "${plugin_ids[$((10#$choice - 1))]}"
        else
            invalid_selection
        fi
    done
}
