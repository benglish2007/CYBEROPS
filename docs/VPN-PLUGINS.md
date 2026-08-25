# CYBEROPS VPN Plugins

CYBEROPS v3 routes VPN status and control operations through `vpn` plugins.
Core CYBEROPS discovers valid provider plugins, renders the provider menu, checks
required commands, and then dispatches the selected plugin action.

## Built-in VPN plugins

### Tailscale

Path: `plugins/vpn/tailscale/plugin.sh`

Actions:

- `status` -> `tailscale status`
- `connect` -> `sudo tailscale up`
- `disconnect` -> `sudo tailscale down`

`connect` and `disconnect` are rendered with the existing `[SUDO]` marker and
respect `DRY_RUN=1` through `run_mutating_checked`.

### ExpressVPN

Path: `plugins/vpn/expressvpn/plugin.sh`

Actions:

- `status` -> `expressvpnctl status`, falling back to `expressvpn status`
- `connect` -> `expressvpnctl connect`, falling back to `expressvpn connect`
- `disconnect` -> `expressvpnctl disconnect`, falling back to
  `expressvpn disconnect`
- `background_on` -> `expressvpnctl background enable`
- `background_off` -> `expressvpnctl background disable`

The current `expressvpnctl` command is preferred. The legacy `expressvpn`
command remains a compatibility fallback for status, connect, and disconnect.
Background-mode actions require `expressvpnctl`.

## VPN plugin contract

A VPN plugin must declare metadata and action functions in `plugin.sh`:

```bash
CYBEROPS_PLUGIN_ID="examplevpn"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="ExampleVPN"
CYBEROPS_PLUGIN_PROVIDER="ExampleVPN"
CYBEROPS_PLUGIN_ACTIONS=(status connect disconnect)
CYBEROPS_PLUGIN_SUDO_ACTIONS=(connect disconnect)
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=(examplevpnctl)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Verify the ExampleVPN daemon is running."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Authenticate ExampleVPN, then retry."
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY="Verify the ExampleVPN daemon is running."

cyberops_plugin_status() {
    run_checked "ExampleVPN status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" \
        examplevpnctl status
}

cyberops_plugin_connect() {
    run_mutating_checked "ExampleVPN connection" \
        "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" examplevpnctl connect
}

cyberops_plugin_disconnect() {
    run_mutating_checked "ExampleVPN disconnection" \
        "$CYBEROPS_PLUGIN_DISCONNECT_RECOVERY" examplevpnctl disconnect
}
```

Supported action names are intentionally simple Bash identifiers. Current VPN
menus render friendly labels for `status`, `connect`, `disconnect`,
`background_on`, and `background_off`; unknown valid actions still render as
plugin actions.

Use `CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS=(command-a command-b)` when a plugin
can use one of several provider CLIs.

## User-installed plugin example

Install a custom plugin at:

```text
~/.local/share/cyberops/plugins/vpn/examplevpn/plugin.sh
```

Then validate and list it:

```bash
cyberops plugins validate vpn
cyberops plugins list vpn
```

If validation passes, the provider appears in the interactive VPN menu and can
be addressed by id through:

```bash
cyberops vpn status examplevpn
```
