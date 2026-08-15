# Configuration, Logs, and Diagnostics

## Configuration

CYBEROPS reads `${XDG_CONFIG_HOME:-$HOME/.config}/cyberops/config` when it
exists. The parser accepts only documented `KEY=VALUE` settings; it never
sources or executes the file. Environment variables take precedence.

Start from the installed example or [repository example](cyberops.conf.example):

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/cyberops"
cp docs/cyberops.conf.example "${XDG_CONFIG_HOME:-$HOME/.config}/cyberops/config"
cyberops config check
cyberops config show
```

Supported keys include the operational settings above plus the header controls
documented below. Unknown keys and malformed lines fail validation.

## Live header telemetry

`CYBEROPS_HEADER_TELEMETRY=1` enables the interactive status header. Its local
fields are read-only and do not contact an internet service:

| Setting | Default | Header field |
| --- | --- | --- |
| `CYBEROPS_HEADER_TIME` | `1` | Local date, time, and timezone |
| `CYBEROPS_HEADER_LINK` | `1` | Local default-route and interface state |
| `CYBEROPS_HEADER_VPN` | `1` | Red `[OFF]` or green `[ON // interface]` VPN badge |
| `CYBEROPS_HEADER_IFACE` | `1` | Primary default-route interface |
| `CYBEROPS_HEADER_LOCAL_IP` | `1` | Primary IPv4 address, with IPv6 fallback |
| `CYBEROPS_HEADER_MAC` | `1` | Current MAC and permanent-address comparison badge |

Set any field to `0` to hide it, or set `CYBEROPS_HEADER_TELEMETRY=0` to disable
the entire status area. `ROUTED` means a usable local default route and link
were detected; it does not guarantee that the internet is reachable.

Public-IP lookup is separately controlled by `CYBEROPS_HEADER_PUBLIC_IP` and is
disabled by default. Enabling it sends a request to `api.ipify.org`. The request
uses `CYBEROPS_HEADER_TIMEOUT` seconds (default `2`, allowed `1`–`10`) and a
result or failure is cached in memory for `CYBEROPS_PUBLIC_IP_CACHE_TTL`
seconds (default `300`, allowed `30`–`86400`). Failures are silent so an offline
or filtered network cannot block the control deck.

Tailscale status is verified through a timeout-bounded local backend query;
the persistent `tailscale0` interface alone is not treated as connected after
`tailscale down`. Other supported VPN-style interfaces are detected from their
active local link state.

The MAC badge is red and labeled `[PERMANENT // address]` when the current
address matches the hardware address. It is green and labeled
`[MODIFIED // address]` when they differ. CYBEROPS checks kernel link metadata
and `ethtool`; if the permanent address cannot be established reliably, it
shows a yellow `[UNKNOWN // address]` badge instead of guessing. Color is an
additional cue—the bracketed text remains meaningful in no-color mode.

## Private operation events

When `CYBEROPS_LOGGING=1`, launched operations record UTC time, process ID,
outcome, and a fixed action description in
`${XDG_STATE_HOME:-$HOME/.local/state}/cyberops/operations.log`. The directory
uses mode `700` and the log uses mode `600`. Raw command arguments are not
recorded. Disable logging with `CYBEROPS_LOGGING=0`.

Use `cyberops logs path` or `cyberops logs tail` to inspect it.

## Privacy-filtered diagnostics

Run `cyberops diagnostics preview` before exporting. Then use:

```bash
cyberops diagnostics export
cyberops diagnostics export ./support-bundle.tar.gz
```

The mode-`600` archive contains one plain-text report with the CYBEROPS
version, OS/kernel version, selected dependency versions, non-sensitive timing
settings, anonymous device characteristics, and Docker version availability.
CYBEROPS refuses to overwrite an existing archive.

The bundle excludes usernames, hostnames, home and configuration paths,
environment variables, network addresses, device names/identifiers/mounts,
operation logs, command history, file contents, and Docker workload names.
Inspect `report.txt` yourself before sharing the archive.
