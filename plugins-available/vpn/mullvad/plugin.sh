#!/usr/bin/env bash
# shellcheck disable=SC2034 # Plugin metadata is consumed by the CYBEROPS plugin loader.

CYBEROPS_PLUGIN_ID="mullvad"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="Mullvad VPN"
CYBEROPS_PLUGIN_PROVIDER="Mullvad VPN"
CYBEROPS_PLUGIN_ACTIONS=(status connect disconnect)
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=(mullvad)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Verify that the Mullvad daemon is running and the app is logged in."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Log in with 'mullvad account login', then verify the Mullvad daemon."
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY="Verify that the Mullvad daemon is running."

cyberops_plugin_status() {
    run_checked "Mullvad VPN status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" mullvad status
}

cyberops_plugin_connect() {
    run_mutating_checked "Mullvad VPN connection" "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" mullvad connect
}

cyberops_plugin_disconnect() {
    run_mutating_checked "Mullvad VPN disconnection" "$CYBEROPS_PLUGIN_DISCONNECT_RECOVERY" mullvad disconnect
}
