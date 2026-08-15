# CYBEROPS Improvement Roadmap

This document tracks proposed improvements discovered during the initial CYBEROPS v2 review. Items are grouped by priority so safety and reliability work lands before new features.

Current release: **v2.9.2 — Milestone 9 complete.**

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

## Planned Milestone 10: Read-Only Command Expansion

- [ ] Expose additional safe control-deck telemetry through non-interactive commands.

## Planned Milestone 11: Native Debian Packaging

- [ ] Build and validate a native `.deb` without replacing the supported Makefile path prematurely.

## Planned Milestone 12: Controlled Extensibility

- [ ] Design constrained plugin discovery for experimental modules.
- [ ] Evaluate additional package managers only where CI can enforce portability.

## Release Gate

Before calling the next release stable:

1. All items assigned to the release's completed milestones should be complete.
2. Bash syntax, ShellCheck, and the mocked safety tests should pass in CI.
3. Destructive operations should be manually tested with disposable virtual block devices, never important physical media.
4. Documentation should accurately describe limitations and recovery expectations.
