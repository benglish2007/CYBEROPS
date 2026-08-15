# CYBEROPS v3 Readiness Gate

CYBEROPS v3.0 will promote the proven v2 operational surface into a stable
major-version contract. Milestone 15 is a stabilization gate, not a feature
expansion milestone.

## Stable contracts

The v3 release candidate must preserve these public behaviors unless a change
is explicitly documented as a v3 migration:

- `cyberops --help`, `--version`, `--no-color`, and documented read-only command channels
- configuration-file syntax, environment-variable precedence, and fail-closed validation
- `[00]` navigation, visible `[SUDO]` markers, dry-run previews, and destructive confirmations
- operation logging and diagnostics privacy boundaries
- package name `cyberops`, `/usr` Debian layout, desktop identity, and in-place APT upgrades
- classic, Neon Overdrive, narrow-terminal, and no-color presentation modes

## Automated gate

Run from the repository root:

```bash
make check
make deb
make deb-inspect
```

`make check` matches the shell-quality and regression layers enforced by the
GitHub Actions validation job. The compatibility matrix remains authoritative
for Ubuntu 22.04, 24.04, and 26.04 LTS plus Debian 12 and 13.
The regression layer includes an isolated staged upgrade that verifies obsolete
managed files are removed while user-owned configuration and state survive.

## Manual release-candidate gate

Use disposable supported systems and disposable removable media where needed:

1. Upgrade an installed v2 package to the v3 candidate without uninstalling it.
2. Verify command, desktop launcher, icon, configuration, and operation-log continuity.
3. Exercise help, version, invalid-option, noninteractive, no-color, classic-theme,
   narrow-terminal, and representative read-only command paths.
4. Exercise Docker, VPN, MAC-policy, and destructive-media workflows only on
   appropriate disposable test targets.
5. Remove the package and confirm package-managed files disappear while
   user-owned configuration and state remain.

## Release decision

The runtime and package metadata may be prepared as `3.0` for an untagged local
release candidate so the real v2-to-v3 upgrade can be tested. Do not create the
v3.0 tag or GitHub Release until the automated matrix and manual gate are
recorded as complete in `ROADMAP.md`. Deferred plugin discovery and unsupported
package-manager portability are not v3 blockers.
