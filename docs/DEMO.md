# Short Terminal Demonstration

```console
$ cyberops --version
CYBEROPS Terminal 3.0

$ cyberops --help
CYBEROPS Terminal v3.0
Unified Linux Operations Console

Usage:
  cyberops [OPTIONS]
  cyberops [OPTIONS] info
  cyberops [OPTIONS] vpn status [PLUGIN_ID]
  cyberops [OPTIONS] plugins <list|validate|available> [CATEGORY]
  cyberops [OPTIONS] plugins <install|uninstall> CATEGORY PLUGIN_ID
  cyberops [OPTIONS] docker status

$ cyberops info
Hostname: pearl
Kernel:   6.x.y-generic
Uptime:   up 3 hours, 12 minutes

$ cyberops docker status
NAMES       IMAGE             STATUS          PORTS
example     example:latest    Up 2 hours      0.0.0.0:8080->80/tcp

TYPE            TOTAL   ACTIVE   SIZE      RECLAIMABLE
Images          8       4        3.1GB     900MB

$ cyberops </dev/null
CYBEROPS: the control deck requires an interactive terminal.
Use 'cyberops --help' to view non-interactive options.
```

Hostnames, versions, container names, and resource values above are illustrative.
The interactive `cyberops` command opens the neon control deck when both input
and output are attached to a terminal.
