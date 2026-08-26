#!/usr/bin/env bash
# shellcheck disable=SC2034 # Plugin metadata is consumed by the CYBEROPS plugin loader.

CYBEROPS_PLUGIN_ID="nordvpn"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="NordVPN"
CYBEROPS_PLUGIN_PROVIDER="NordVPN"
CYBEROPS_PLUGIN_ACTIONS=(status connect disconnect)
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=(nordvpn)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Verify that the NordVPN service is running and the client is logged in."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Run 'nordvpn login' if needed, then verify the NordVPN service."
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY="Verify that the NordVPN service is running."

cyberops_plugin_status() {
    run_checked "NordVPN status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" nordvpn status
}

cyberops_plugin_connect() {
    run_mutating_checked "NordVPN connection" "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" nordvpn connect
}

cyberops_plugin_disconnect() {
    run_mutating_checked "NordVPN disconnection" "$CYBEROPS_PLUGIN_DISCONNECT_RECOVERY" nordvpn disconnect
}
