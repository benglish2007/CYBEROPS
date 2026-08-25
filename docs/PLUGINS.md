# CYBEROPS Plugin Architecture

CYBEROPS v3 loads optional capabilities through category-scoped plugins. The
first stable category is `vpn`, which lets VPN providers ship independently from
core menu and command dispatch code.

## Plugin roots

CYBEROPS discovers plugins from two roots, in deterministic sorted order:

1. Built-in plugins shipped with CYBEROPS:
   `/usr/lib/cyberops/plugins` when installed, or `./plugins` from source.
2. User plugins:
   `${XDG_DATA_HOME:-$HOME/.local/share}/cyberops/plugins`.

A plugin lives at:

```text
plugins/<category>/<plugin-id>/plugin.sh
```

For example:

```text
plugins/vpn/tailscale/plugin.sh
plugins/vpn/expressvpn/plugin.sh
~/.local/share/cyberops/plugins/vpn/mullvad/plugin.sh
```

## Safety model

Plugin loading is intentionally conservative:

- plugin files must be named `plugin.sh`;
- plugin paths must resolve inside the built-in or user plugin roots;
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
```

`plugins list` prints tab-separated rows:

```text
category    id    display name    actions
```

`plugins validate` prints `valid` or `invalid` with each plugin path and returns
nonzero if any discovered plugin is malformed.

## Packaging

Built-in plugins are installed beneath `/usr/lib/cyberops/plugins` and included
in the Debian package. User plugins remain user-owned and are never removed by
package upgrades or uninstalls.
