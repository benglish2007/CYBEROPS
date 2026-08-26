# CYBEROPS VPN Plugins

CYBEROPS v3 routes VPN status and control operations through `vpn` plugins.
Core CYBEROPS discovers valid provider plugins, renders the provider menu, checks
required commands, and then dispatches the selected plugin action.

## Optional VPN plugins

List and install package-supplied providers with:

```bash
cyberops plugins available vpn
cyberops plugins install vpn tailscale
cyberops plugins uninstall vpn tailscale
```

The interactive VPN Control screen provides separate **Install VPN plugins**
and **Uninstall VPN plugins** submenus. The uninstall menu shows only plugins
owned by the current user.

### Tailscale

Catalog path: `plugins-available/vpn/tailscale/plugin.sh`

Actions:

- `status` -> `tailscale status`
- `connect` -> `sudo tailscale up`
- `disconnect` -> `sudo tailscale down`

`connect` and `disconnect` are rendered with the existing `[SUDO]` marker and
respect `DRY_RUN=1` through `run_mutating_checked`.

### ExpressVPN

Catalog path: `plugins-available/vpn/expressvpn/plugin.sh`

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

### NordVPN

Catalog path: `plugins-available/vpn/nordvpn/plugin.sh`

Actions map to `nordvpn status`, `nordvpn connect`, and `nordvpn disconnect`.

### Proton VPN

Catalog path: `plugins-available/vpn/protonvpn/plugin.sh`

Actions map to the current official Linux CLI commands `protonvpn status`,
`protonvpn connect`, and `protonvpn disconnect`.

### Mullvad VPN

Catalog path: `plugins-available/vpn/mullvad/plugin.sh`

Actions map to `mullvad status`, `mullvad connect`, and `mullvad disconnect`.

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
