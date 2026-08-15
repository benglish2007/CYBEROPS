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

Supported keys are `STACK_ROOT`, `RETRY_DELAY`, `HEALTH_TIMEOUT`,
`HEALTH_INTERVAL`, `FAILURE_LOG_LINES`, `DRY_RUN`, `CYBEROPS_NO_COLOR`, and
`CYBEROPS_LOGGING`. Unknown keys and malformed lines fail validation.

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
