#!/usr/bin/env bash
# shellcheck disable=SC2034 # Plugin metadata is consumed by the CYBEROPS plugin loader.

CYBEROPS_PLUGIN_ID="protonvpn"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="Proton VPN"
CYBEROPS_PLUGIN_PROVIDER="Proton VPN"
CYBEROPS_PLUGIN_ACTIONS=(status connect disconnect)
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=(protonvpn)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Verify that the Proton VPN CLI is installed and its service is available."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Run 'protonvpn signin' if needed, then verify NetworkManager and the Proton VPN service."
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY="Verify NetworkManager and the Proton VPN service."

cyberops_plugin_status() {
    run_checked "Proton VPN status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" protonvpn status
}

cyberops_plugin_connect() {
    run_mutating_checked "Proton VPN connection" "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" protonvpn connect
}

cyberops_plugin_disconnect() {
    run_mutating_checked "Proton VPN disconnection" "$CYBEROPS_PLUGIN_DISCONNECT_RECOVERY" protonvpn disconnect
}
