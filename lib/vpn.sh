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
            "No supported VPN provider is ready." \
            "Run 'cyberops plugins available vpn', install a provider plugin and its client, then retry."
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

vpn_plugin_install_menu() {
    local choice=""
    local descriptor
    local plugin_id
    local plugin_path
    local index
    local installed_ids
    local -a plugin_ids=()

    while true; do
        plugin_ids=()
        installed_ids=" "
        while IFS= read -r descriptor; do
            plugin_id="${descriptor#*:}"
            plugin_id="${plugin_id%%:*}"
            installed_ids+="$plugin_id "
        done < <(discover_plugins vpn)

        banner
        ui_section "VPN PLUGIN INSTALL" "OPTIONAL PROVIDER CATALOG"
        index=1
        while IFS= read -r descriptor; do
            plugin_id="${descriptor#*:}"
            plugin_id="${plugin_id%%:*}"
            [[ "$installed_ids" == *" $plugin_id "* ]] && continue
            plugin_path="${descriptor#*:*:}"
            load_plugin vpn "$plugin_path" >/dev/null || continue
            menu_item "$index" "$CYBEROPS_PLUGIN_NAME" "VPN // INSTALL"
            plugin_ids+=("$plugin_id")
            ((index += 1))
        done < <(discover_available_plugins vpn)
        if ((${#plugin_ids[@]} == 0)); then
            printf '  All available VPN plugins are installed.\n'
        fi
        menu_navigation_item 0 "Return to VPN control" "NAV // BACK"

        prompt_choice choice "VPN INSTALL"
        if [[ "$choice" == "0" ]]; then
            return
        fi
        if integer_in_range "$choice" 1 "${#plugin_ids[@]}"; then
            install_user_plugin vpn "${plugin_ids[$((10#$choice - 1))]}"
            pause
        else
            invalid_selection
        fi
    done
}

vpn_plugin_uninstall_menu() {
    local choice=""
    local plugin_path
    local plugin_id
    local index
    local -a plugin_ids=()

    while true; do
        plugin_ids=()
        banner
        ui_section "VPN PLUGIN UNINSTALL" "USER PROVIDERS // REMOVE"
        index=1
        if [[ -d "$CYBEROPS_USER_PLUGIN_DIR/vpn" ]]; then
            while IFS= read -r plugin_path; do
                [[ -n "$plugin_path" ]] || continue
                validate_plugin vpn "$plugin_path" >/dev/null 2>&1 || continue
                plugin_id="$CYBEROPS_PLUGIN_ID"
                menu_item "$index" "$CYBEROPS_PLUGIN_NAME" "VPN // UNINSTALL"
                plugin_ids+=("$plugin_id")
                ((index += 1))
            done < <(find "$CYBEROPS_USER_PLUGIN_DIR/vpn" \
                -mindepth 2 -maxdepth 2 -name plugin.sh -type f | sort)
        fi
        if ((${#plugin_ids[@]} == 0)); then
            printf '  No user-installed VPN plugins are available to remove.\n'
        fi
        menu_navigation_item 0 "Return to VPN control" "NAV // BACK"

        prompt_choice choice "VPN UNINSTALL"
        if [[ "$choice" == "0" ]]; then
            return
        fi
        if integer_in_range "$choice" 1 "${#plugin_ids[@]}"; then
            uninstall_user_plugin vpn "${plugin_ids[$((10#$choice - 1))]}"
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
    local install_index
    local uninstall_index

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
        menu_item "$index" "Install VPN plugins" "VPN // PLUGIN CATALOG"
        install_index="$index"
        ((index += 1))
        menu_item "$index" "Uninstall VPN plugins" "VPN // USER PLUGINS"
        uninstall_index="$index"
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

        prompt_choice choice "VPN"
        if [[ "$choice" == "0" ]]; then
            return
        fi
        if [[ "$choice" == "$install_index" ]]; then
            vpn_plugin_install_menu
        elif [[ "$choice" == "$uninstall_index" ]]; then
            vpn_plugin_uninstall_menu
        elif integer_in_range "$choice" 1 "${#plugin_ids[@]}"; then
            vpn_plugin_menu "${plugin_ids[$((10#$choice - 1))]}"
        else
            invalid_selection
        fi
    done
}
