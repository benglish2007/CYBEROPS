# CYBEROPS Improvement Roadmap

This document tracks proposed improvements discovered during the initial CYBEROPS v2 review. Items are grouped by priority so safety and reliability work lands before new features.

Current release: **v2.14 — Milestone 14 complete.**

## Milestone 1: Safety and Test Foundation

- [x] Fix USB selection so user-interface output cannot contaminate the selected device path.
- [x] Record and revalidate a USB device's path, type, transport, removable flag, size, model, serial number, and WWN immediately before destructive operations.
- [x] Refuse devices backing `/`, `/boot`, or `/boot/efi`, including mapped/LVM parent disks.
- [x] Refuse targets that disappear, change identity, stop being removable/USB, or have mounted filesystems.
- [x] Unmount filesystems attached directly to a whole-disk image as well as child partitions.
- [x] Bound zero-fill to the device's exact byte capacity so normal completion is reported as success.
- [x] Rename USB "sanitization" to "wipe/zero-fill" and explain that flash wear leveling prevents a guaranteed secure erase.
- [x] Ensure MAC randomization always attempts to restore the interface to its original up/down state after a failure.
- [x] Add mocked regression tests for USB selection and safety checks.
- [x] Add ShellCheck validation in GitHub Actions.

### Manual verification — 2026-08-14

- [x] Completed a full zero-fill on disposable USB media.
- [x] Verified cancellation at both destructive confirmation prompts without writing.
- [x] Verified safe refusal after removing the selected device.
- [x] Verified automatic handling of mounted whole-disk and partition filesystems.
- [x] Created and tested bootable USB media, including checksum handling.
- [x] Verified MAC randomization restores the interface's original state.

## Milestone 2: General Reliability

- [x] Validate numeric environment configuration such as `HEALTH_TIMEOUT`, `HEALTH_INTERVAL`, `RETRY_DELAY`, and `FAILURE_LOG_LINES`.
- [x] Apply consistent dependency checks before invoking external commands.
- [x] Add signal handling and cleanup traps for interrupted operations.
- [x] Standardize command failures and provide actionable error messages.
- [x] Review command compatibility across supported Ubuntu and Debian releases.
- [x] Add a dry-run or preview mode for operations that change system state.

Compatibility is exercised in CI across Ubuntu 22.04, 24.04, and 26.04 LTS
plus Debian 12 and 13. See [COMPATIBILITY.md](COMPATIBILITY.md) for the tested
runtime capabilities and integration-testing boundaries.

## Milestone 3: Docker Operations

- [x] Allow users to select individual Compose stacks instead of only updating every stack.
- [x] Show the exact Compose projects and planned actions before confirmation.
- [x] Improve health-check handling for one-shot services and containers created during an update.
- [x] Preserve useful before/after state for failure recovery.
- [x] Document rollback procedures and avoid implying automatic rollback.
- [x] Make image pruning an explicit, separately confirmed action.

### Manual verification — 2026-08-15

- [x] Verified numbered, multi-stack, all-stack, invalid-selection, cancellation, and deduplication paths.
- [x] Verified the dry-run preflight lists only selected projects and exact planned actions.
- [x] Updated a healthy long-running service and a successful one-shot service on disposable Compose stacks.
- [x] Verified a nonzero one-shot exit is reported as a failed stack with recovery guidance.
- [x] Verified recovery reports use mode `600` and contain useful before/after container and image state.
- [x] Verified replacement containers created during an update are health-checked.
- [x] Verified image pruning is separately confirmed, safely previewed, and can be declined.

## Milestone 4: Code Structure and Quality

- [x] Split the monolithic script into a small launcher and focused modules under `lib/`.
- [x] Add a main-entry guard so functions can be sourced safely by tests.
- [x] Expand Bats or shell-based tests for menus, validators, and failure paths.
- [x] Add formatting checks with `shfmt`.
- [x] Prefer consistent `printf` output over `echo -e`.
- [x] Add clear function contracts for output, return values, and side effects.

Suggested layout:

```text
cyberops.sh
lib/runtime.sh
lib/core.sh
lib/ui.sh
lib/admin.sh
lib/info.sh
lib/vpn.sh
lib/security.sh
lib/quickhacks.sh
lib/docker.sh
lib/usb.sh
lib/menu.sh
tests/
```

### Manual verification — 2026-08-15

- [x] Launched the modular runtime from the repository and from an unrelated working directory.
- [x] Opened each control-deck node, returned through its submenu, and exited cleanly.
- [x] Verified representative read-only and dry-run operations after module extraction.
- [x] Verified native path completion and cancellation behavior at file and ISO prompts.
- [x] Verified Docker and removable-media workflows retained their expected behavior.
- [x] Verified missing modules fail closed and identify the required module.
- [x] Corrected and visually verified the destructive-protocol warning-panel alignment.

## Milestone 5: Installation and Packaging

- [x] Replace hardcoded paths in `Quickhacks.desktop` with an installer-generated desktop entry.
- [x] Rename desktop-facing branding from Quickhacks to CYBEROPS.
- [x] Add an installer or Makefile for the executable, icon, and desktop entry.
- [x] Add uninstall and upgrade instructions.
- [x] Add an actual `LICENSE` file or remove the README's license reference.
- [x] Consider packaging for Debian/Ubuntu after the interface stabilizes.

Native Debian/Ubuntu package generation was evaluated and intentionally
deferred until the command-line interface and documentation stabilize. The
Makefile provides the supported Milestone 5 installation path in the meantime.

### Manual verification — 2026-08-15

- [x] Installed CYBEROPS under `/usr/local` with `sudo make install`.
- [x] Launched the installed modular runtime with the `cyberops` command.
- [x] Opened CYBEROPS Terminal from the GNOME application drawer.
- [x] Verified the generated desktop entry displays the installed CYBEROPS artwork.

## Milestone 6: User Experience and Documentation

- [x] Add `--help`, `--version`, and `--no-color` options.
- [x] Consider non-interactive commands such as `cyberops info` and `cyberops docker status`.
- [x] Detect non-interactive terminals and degrade animation/color cleanly.
- [x] Shorten the README quick start and move detailed operational material into `docs/`.
- [x] Document privilege requirements and side effects per operation.
- [x] Add screenshots or a short terminal demonstration.

### Manual verification — 2026-08-15

- [x] Verified unsupported options return status 2 with help guidance.
- [x] Verified a control-deck launch without interactive input refuses safely instead of looping.
- [x] Verified help, version, no-color, host information, and Docker status command channels.
- [x] Verified normal terminal and GNOME desktop launches still open the interactive control deck.
- [x] Verified the focused documentation is included in the system-wide installation.

## Milestone 7: Installer and Navigation Consistency

- [x] Move optional dependency bootstrap out of the interactive runtime.
- [x] Add explicit installer targets for optional dependencies and a combined full installation.
- [x] Remove the obsolete System Setup runtime module and clean it during upgrades.
- [x] Reserve main-menu option `0` for Exit Interface.
- [x] Reserve submenu option `0` for Return to control deck across every module.
- [x] Add regression coverage for installer dependency setup and zero-key navigation.

### Manual verification — 2026-08-15

- [x] Verified System Setup is absent from the installed control deck.
- [x] Verified main-menu option `[00]` exits the interface.
- [x] Verified submenu option `[00]` returns to the control deck across all modules.
- [x] Verified blank-line separation visually distinguishes navigation from operations.

## Milestone 8: Configuration and Supportability

- [x] Add safe XDG configuration-file support with environment-variable overrides.
- [x] Add validation and effective-configuration command channels.
- [x] Record private structured maintenance events without raw command arguments.
- [x] Add operation-log path and tail command channels.
- [x] Export a privacy-filtered diagnostics bundle only after previewing its explicit boundary.
- [x] Protect state directories, logs, and diagnostics archives with private permissions.

### Manual verification — 2026-08-15

- [x] Verified configuration path, effective settings, and validation commands.
- [x] Verified configuration-file loading and environment-variable precedence.
- [x] Verified private structured operation-log creation and inspection.
- [x] Previewed, exported, inspected, and permission-checked a diagnostics bundle.
- [x] Confirmed diagnostics omit private identity, path, network, device, log, and workload data.
- [x] Verified diagnostics export refuses to overwrite an existing archive.

## Milestone 9: Release Automation

- [x] Validate a clean, synchronized `main` branch before publishing.
- [x] Enforce consistent runtime, README, roadmap, and changelog versions.
- [x] Run syntax and regression checks through a dedicated release gate.
- [x] Preview the exact tag, commit, title, and changelog-derived release notes.
- [x] Publish annotated version tags and verified GitHub Releases.
- [x] Refuse to overwrite or move existing releases and conflicting tags.
- [x] Support safe retry when tag publication succeeds but Release creation fails.
- [x] Document release preparation, publishing, recovery, and rollback boundaries.
- [x] Add mocked regression coverage that never changes GitHub.

### Manual verification — 2026-08-15

- [x] Ran the real clean-tree release check and exact no-mutation preview.
- [x] Confirmed stale-version publishing is blocked when post-release notes exist.
- [x] Backfilled annotated tag and GitHub Release v2.8 at its historical release commit.
- [x] Verified ShellCheck, formatting, all regression tests, and all five compatibility jobs in GitHub Actions.
- [x] Verified GitHub CLI keyring authentication and Release API access.

## Milestone 10: Read-Only Command Expansion

- [x] Expose local disk, memory, active-service, and failed-unit telemetry.
- [x] Expose block-device telemetry through a dedicated storage command.
- [x] Expose local interface, route, and listening-socket telemetry.
- [x] Expose combined status for installed supported VPN clients.
- [x] Reuse the same read-only helpers between menus and command channels.
- [x] Preserve dependency and operation failure statuses for automation.
- [x] Keep public-IP lookup, privileged firewall inspection, and every mutation outside the new command surface.
- [x] Add dispatch, exact-command, missing-client, and failure-status regression coverage.
- [x] Document privilege, privacy, and external-network boundaries.

### Manual verification — 2026-08-15

- [x] Verified every new command returns directly without opening the interactive control deck.
- [x] Verified local disk usage remains responsive with remote mounts excluded.
- [x] Verified service telemetry does not open a pager.
- [x] Verified network commands remain local and read-only.
- [x] Verified supported VPN-client status reporting.
- [x] Verified the new command channels do not request `sudo` or change system state.
- [x] Verified the corresponding interactive menu operations still work.
- [x] Verified invalid command combinations return status 2 with usage guidance.

## Milestone 11: Native Debian Packaging

- [x] Reuse the Makefile `DESTDIR` contract to stage a native architecture-independent `.deb`.
- [x] Install the launcher, modules, desktop entry, icon, documentation, and license beneath Debian's `/usr` hierarchy.
- [x] Derive package metadata from the runtime version and declare required versus optional dependencies.
- [x] Provide unprivileged package build and inspection targets without changing the host installation.
- [x] Add isolated regression coverage for metadata, file layout, resolved templates, and excluded build artifacts.
- [x] Document package installation, in-place upgrades, removal, user-data retention, and Makefile coexistence boundaries.
- [x] Manually validate installation, dependency resolution, command execution, and desktop integration on a supported system.

### Manual verification — 2026-08-15

- [x] Built and inspected the package as an unprivileged user.
- [x] Installed the package through APT and resolved its declared dependency set.
- [x] Verified `/usr/bin/cyberops`, version reporting, interactive launch, and desktop integration.
- [x] Confirmed the local-file `_apt` sandbox notice is harmless when repository parent directories are private.

## Pre-Milestone 11 Interface Polish

- [x] Give every `[00]` Exit Interface and Return to control deck key a distinct navigation color.
- [x] Preserve navigation separation and readability when color is disabled.
- [x] Add a visible `[SUDO]` marker to every audited menu operation that invokes `sudo`.
- [x] Use a text marker in addition to color so privilege requirements remain visible with `NO_COLOR` and `--no-color`.
- [x] Keep normal and privilege-marked rows aligned across the control deck.
- [x] Add UI and cross-menu regression coverage for navigation color and privilege-marker consistency.

### Manual verification — 2026-08-15

- [x] Verified distinct `[00]` navigation styling across the control deck.
- [x] Verified `[SUDO]` indicators, row alignment, and no-color readability.

## Milestone 12: Live Header Telemetry

- [x] Add local time, default-route state, primary interface, and local address to the interactive header.
- [x] Display the current MAC address of the primary routed interface.
- [x] Compare the current MAC with the permanent hardware address and render explicit permanent, modified, or unknown state badges.
- [x] Detect common active VPN-style interfaces without invoking vendor clients or contacting external services.
- [x] Give VPN state a dedicated status row with the active interface's local VPN address.
- [x] Render bracketed red VPN-off/permanent-MAC states and green VPN-on/modified-MAC states without relying on color alone.
- [x] Keep public-IP discovery disabled by default, bounded by a short timeout, and cached between menu redraws when enabled.
- [x] Allow the entire status area and every individual field to be disabled through configuration.
- [x] Distinguish local route availability from verified internet reachability.
- [x] Preserve readable output in narrow terminals and when color is disabled.
- [x] Add mocked coverage for routed, offline, VPN, MAC, public-IP, cache, narrow-terminal, and disabled states.
- [x] Manually verify live values, MAC state transitions, and accurate Tailscale on/off behavior.

### Manual verification — 2026-08-15

- [x] Verified the current MAC and its permanent/modified badge state.
- [x] Verified MAC randomization updates the header state correctly.
- [x] Verified Tailscale on/off badges and removal of the stale-interface false positive after `tailscale down`.

## Milestone 13: Persistent MAC Address Controls

- [x] Replace the one-off Quickhacks entry with a dedicated MAC control panel and numbered active-profile selection for temporary session randomization.
- [x] Add a read-only view of active NetworkManager connections and their effective cloned-MAC policy.
- [x] Select a specific supported NetworkManager connection by stable UUID before changing persistent policy.
- [x] Enable per-connection MAC randomization on every activation with explicit profile selection and dry-run preview.
- [x] Disable automatic randomization for a selected connection by explicitly applying its permanent-address policy.
- [x] Restore the permanent hardware MAC immediately, verify the result, and reconcile the selected connection profile safely.
- [x] Detect unavailable NetworkManager state and unsupported connection types and fail without mutation.
- [x] Add mocked lifecycle, rollback, dry-run, menu, interruption-recovery, and packaging coverage.
- [x] Document temporary randomization, persistent connection policy, reconnection effects, and recovery.
- [x] Manually verify enable, reconnect/randomize, disable, and permanent restoration across supported Ethernet and Wi-Fi hardware.

### Manual verification — 2026-08-15

- [x] Verified read-only policy reporting for the active `netplan-enp7s0` Ethernet profile.
- [x] Verified numbered active-profile selection without manual interface entry.
- [x] Verified persistent randomization enablement and the resulting modified-MAC header state after reconnection.
- [x] Verified persistent randomization disablement and immediate permanent-MAC restoration with successful reconnection.
- [x] Downloaded and installed the released v2.13 `.deb` on a separate Wi-Fi laptop and verified the Wi-Fi MAC-control workflow successfully.

## Milestone 14: Neon Overdrive Interface

- [x] Add an optional, configuration-backed interface theme with a classic fallback.
- [x] Introduce the Night City Relay banner, framed signal matrix, rail menus, and command-deck vocabulary.
- [x] Preserve explicit operation names, privilege markers, destructive warnings, and recovery guidance.
- [x] Preserve accessible no-color behavior and adapt telemetry for narrow terminals.
- [x] Frame and center the rainbow CYBEROPS logo without distorting its FIGlet geometry.
- [x] Add regression coverage for theme selection, layout, feedback signals, narrow terminals, and no-color rendering.
- [x] Manually verify standard-width, narrow-width, full-color, and no-color presentation.

## Deferred: Controlled Extensibility and Portability

Plugin discovery is intentionally postponed. CYBEROPS will retain its explicit,
reviewed module list until there is a concrete need for third-party or optional
feature packages and an appropriate trust model.

- [ ] Reconsider constrained plugin discovery only when a real extension use case exists.
- [ ] Treat additional package-manager and distribution support as a separate future evaluation.
- [ ] Claim portability only where CI can enforce the complete runtime and installer contract.

## Release Gate

Before calling the next release stable:

1. All items assigned to the release's completed milestones should be complete.
2. Bash syntax, ShellCheck, and the mocked safety tests should pass in CI.
3. Destructive operations should be manually tested with disposable virtual block devices, never important physical media.
4. Documentation should accurately describe limitations and recovery expectations.
