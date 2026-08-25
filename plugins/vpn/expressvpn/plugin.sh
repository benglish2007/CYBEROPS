#!/usr/bin/env bash
# shellcheck disable=SC2034 # Plugin metadata is consumed by the CYBEROPS plugin loader.

CYBEROPS_PLUGIN_ID="expressvpn"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="ExpressVPN"
CYBEROPS_PLUGIN_PROVIDER="ExpressVPN"
CYBEROPS_PLUGIN_ACTIONS=(status connect disconnect background_on background_off)
CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS=(expressvpnctl expressvpn)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Open the ExpressVPN GUI or enable background mode, then verify the daemon is running."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Open the ExpressVPN GUI or enable background mode, then verify login and daemon status."
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY="Verify the ExpressVPN daemon is running."
CYBEROPS_PLUGIN_BACKGROUND_ON_RECOVERY="Verify the current ExpressVPN GUI client is installed and logged in."
CYBEROPS_PLUGIN_BACKGROUND_OFF_RECOVERY="Open the ExpressVPN GUI before reconnecting; disabling background mode may disconnect the VPN."

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

cyberops_plugin_status() {
    select_expressvpn_cli || return 1
    run_checked "ExpressVPN status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" "$EXPRESSVPN_CLI" status
}

cyberops_plugin_connect() {
    select_expressvpn_cli || return 1
    run_mutating_checked "ExpressVPN connection" "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" "$EXPRESSVPN_CLI" connect
}

cyberops_plugin_disconnect() {
    select_expressvpn_cli || return 1
    run_mutating_checked "ExpressVPN disconnection" "$CYBEROPS_PLUGIN_DISCONNECT_RECOVERY" "$EXPRESSVPN_CLI" disconnect
}

cyberops_plugin_background_on() {
    require_commands expressvpnctl || return 1
    run_mutating_checked "ExpressVPN background-mode enablement" "$CYBEROPS_PLUGIN_BACKGROUND_ON_RECOVERY" expressvpnctl background enable
}

cyberops_plugin_background_off() {
    require_commands expressvpnctl || return 1
    run_mutating_checked "ExpressVPN background-mode disablement" "$CYBEROPS_PLUGIN_BACKGROUND_OFF_RECOVERY" expressvpnctl background disable
}
