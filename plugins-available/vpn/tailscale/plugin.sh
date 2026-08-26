#!/usr/bin/env bash
# shellcheck disable=SC2034 # Plugin metadata is consumed by the CYBEROPS plugin loader.

CYBEROPS_PLUGIN_ID="tailscale"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="Tailscale"
CYBEROPS_PLUGIN_PROVIDER="Tailscale"
CYBEROPS_PLUGIN_ACTIONS=(status connect disconnect)
CYBEROPS_PLUGIN_SUDO_ACTIONS=(connect disconnect)
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=(tailscale)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Verify the Tailscale daemon is running."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Review Tailscale authentication and daemon status."
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY="Verify the Tailscale daemon is running."

cyberops_plugin_status() {
    run_checked "Tailscale status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" tailscale status
}

cyberops_plugin_connect() {
    run_mutating_checked "Tailscale connection" "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" sudo tailscale up
}

cyberops_plugin_disconnect() {
    run_mutating_checked "Tailscale disconnection" "$CYBEROPS_PLUGIN_DISCONNECT_RECOVERY" sudo tailscale down
}
