# CYBEROPS Plugin Architecture

CYBEROPS v3 loads optional capabilities through category-scoped plugins. The
first stable category is `vpn`, which lets VPN providers ship independently from
core menu and command dispatch code.

## Plugin roots

CYBEROPS keeps optional providers separate from active plugins:

1. Package-supplied, inactive choices:
   `/usr/lib/cyberops/plugins-available` when installed, or
   `./plugins-available` from source.
2. Active user plugins:
   `${XDG_DATA_HOME:-$HOME/.local/share}/cyberops/plugins`.

The reserved `/usr/lib/cyberops/plugins` root remains supported for
administrator-managed plugins, but the standard package installs no active VPN
provider there.

A plugin lives at:

```text
plugins/<category>/<plugin-id>/plugin.sh
```

For example:

```text
plugins-available/vpn/tailscale/plugin.sh
plugins-available/vpn/expressvpn/plugin.sh
~/.local/share/cyberops/plugins/vpn/mullvad/plugin.sh
```

## Safety model

Plugin loading is intentionally conservative:

- plugin files must be named `plugin.sh`;
- plugin paths must resolve inside the available, administrator, or user plugin roots;
- plugin files must pass `bash -n` before sourcing;
- plugin ids must match `^[a-z][a-z0-9_-]*$`;
- category metadata must match the discovery category;
- display name, provider, and at least one action are required;
- every declared action must define the matching `cyberops_plugin_<action>`
  function;
- invalid plugins are not shown in menus and are reported by
  `cyberops plugins validate`.

Plugins should never use `eval`. Use direct command calls and CYBEROPS helpers
such as `require_commands`, `run_checked`, and `run_mutating_checked` so dry-run,
logging, and error reporting remain consistent.

## Commands

```bash
cyberops plugins list
cyberops plugins list vpn
cyberops plugins validate
cyberops plugins validate vpn
cyberops plugins available vpn
cyberops plugins install vpn tailscale
cyberops plugins uninstall vpn tailscale
```

`plugins list` prints tab-separated rows:

```text
category    id    display name    actions
```

`plugins validate` prints `valid` or `invalid` with each plugin path and returns
nonzero if any discovered plugin is malformed.

`plugins available` lists package-supplied choices. `plugins install` copies the
selected provider into the current user's plugin root; `plugins uninstall`
removes it from that root. Neither operation requires root. Administrator-managed
plugins are never removed by the user uninstall command.

## Packaging

Optional plugins are packaged beneath `/usr/lib/cyberops/plugins-available` but
are inactive until selected. User plugins remain user-owned and are never
removed by package upgrades or uninstalls.
