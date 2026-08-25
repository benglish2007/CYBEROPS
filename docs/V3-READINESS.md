# CYBEROPS v3 Readiness Gate

CYBEROPS v3.0 promotes the proven v2 operational surface into a stable
major-version contract and introduces the first extensibility point: guarded VPN
provider plugins.

The v2.14.1 maintenance release repaired and verified the ExpressVPN integration.
The v3 candidate keeps that behavior by moving ExpressVPN and Tailscale into
built-in VPN plugins while preserving command behavior, dry-run previews,
operation logging, menu styling, and Debian packaging.

## Stable contracts

The v3 release candidate must preserve these public behaviors unless a change
is explicitly documented as a v3 migration:

- `cyberops --help`, `--version`, `--no-color`, and documented read-only command channels
- configuration-file syntax, environment-variable precedence, and fail-closed validation
- `[00]` navigation, visible `[SUDO]` markers, dry-run previews, and destructive confirmations
- operation logging and diagnostics privacy boundaries
- package name `cyberops`, `/usr` Debian layout, desktop identity, and in-place APT upgrades
- classic, Neon Overdrive, narrow-terminal, and no-color presentation modes
- deterministic plugin discovery from built-in and user plugin roots
- fail-closed plugin validation before plugin actions are executed

## Plugin gate

The v3 plugin contract must be verified before release:

1. Built-in `vpn/tailscale` and `vpn/expressvpn` plugins are discovered.
2. User plugins under `${XDG_DATA_HOME:-$HOME/.local/share}/cyberops/plugins`
   are discovered without contaminating built-in state.
3. Malformed plugins are rejected and omitted from runtime menus.
4. Missing provider commands are reported before actions execute.
5. VPN menu rows are generated from plugin metadata and preserve `[SUDO]`
   markers for privileged actions.
6. `cyberops plugins list`, `cyberops plugins validate`, and
   `cyberops vpn status <plugin-id>` remain documented and tested.

## Automated gate

Run from the repository root:

```bash
make check
make deb
make deb-inspect
```

`make check` matches the shell-quality and regression layers enforced by the
GitHub Actions validation job. The compatibility matrix remains authoritative
for Ubuntu 22.04, 24.04, and 26.04 LTS plus Debian 12 and 13. The regression
layer includes plugin discovery, validation, VPN dispatch, and an isolated staged
upgrade that verifies obsolete managed files are removed while user-owned
configuration, state, and plugins survive.

## Manual release-candidate gate

Use disposable supported systems and disposable removable media where needed:

1. Upgrade an installed v2 package to the v3 candidate without uninstalling it.
2. Verify command, desktop launcher, icon, configuration, plugin, and operation-log continuity.
3. Exercise help, version, invalid-option, noninteractive, no-color, classic-theme,
   narrow-terminal, plugin-listing, and representative read-only command paths.
4. Exercise Docker, VPN, MAC-policy, and destructive-media workflows only on
   appropriate disposable test targets.
5. Install a disposable user VPN plugin, validate it, then remove it and confirm
   built-in plugins still load.
6. Remove the package and confirm package-managed files disappear while
   user-owned configuration, state, and plugins remain.

## Release decision

The runtime and package metadata may be prepared as `3.0` for an untagged local
release candidate so the real v2-to-v3 upgrade can be tested. Do not create the
v3.0 tag or GitHub Release until the automated matrix and manual gate are
recorded as complete in `ROADMAP.md`.
