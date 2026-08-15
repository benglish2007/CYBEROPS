# Changelog

All notable changes to CYBEROPS are documented in this file.

## 2.9 — 2026-08-15

Version 2.9 completes **Roadmap Milestone 9: Release Automation** with guarded,
repeatable validation, annotated tags, changelog-derived GitHub Releases, and
explicit retry and rollback boundaries.

### Release Engineering

- Added guarded `release-check`, `release-preview`, and `release` Makefile targets.
- Added version consistency, clean-tree, synchronized-branch, full-suite, tag conflict, and existing-Release safeguards.
- Blocked normal publishing while post-release work remains under an `Unreleased` changelog section.
- Added annotated tag publishing and GitHub Release notes extracted directly from the matching changelog section.
- Added resumable handling when a correct tag exists but GitHub Release creation did not finish.
- Added mocked release regression coverage and a release/recovery operations guide.

### Validation and Compatibility

- Made destructive-warning alignment regression coverage independent of container locale.
- Cleared ShellCheck and `shfmt` failures so the complete shell-quality job and five-distribution matrix pass.
- Backfilled the v2.8 annotated tag and GitHub Release at the original v2.8 release commit.

### Milestone

- Completed all Roadmap Milestone 9 work and recorded successful end-to-end verification of release preview, historical backfill, GitHub publishing, CI safeguards, and conflict refusal.

## 2.8 — 2026-08-15

Version 2.8 completes **Roadmap Milestone 8: Configuration and
Supportability** with safe user configuration, private operation events, and
privacy-controlled support diagnostics.

### Configuration and Supportability

- Added a strict XDG configuration file parser that never executes configuration as shell code and preserves environment-variable precedence.
- Added `config path`, `config show`, and `config check` command channels with validation and an installable example configuration.
- Added private structured operation events under the XDG state directory, mode-`700`/`600` protections, action-only logging, and `logs path`/`logs tail` commands.
- Added previewable, non-overwriting diagnostics exports with an explicit privacy boundary and mode-`600` archives.
- Added regression coverage for configuration precedence and rejection, log privacy and permissions, diagnostics filtering, and archive overwrite refusal.

### Milestone

- Completed all Roadmap Milestone 8 work and recorded successful manual verification of configuration precedence, operation logging, diagnostics privacy, archive permissions, and overwrite refusal.

## 2.7.1 — 2026-08-15

Version 2.7.1 prevents an unavailable remote mount from delaying or failing the
Admin Ops disk-usage display.

### Admin Operations

- Changed Disk Usage from `df -hT` to local-filesystem-only `df -lhT`, avoiding waits and exit-status failures caused by unreachable network mounts.
- Added regression coverage that preserves local-only disk telemetry.

## 2.7 — 2026-08-15

Version 2.7 completes **Roadmap Milestone 7: Installer and Navigation
Consistency** by moving dependency bootstrap into explicit installer targets
and reserving option zero for navigation throughout the interface.

### Installer

- Moved optional APT dependency bootstrap out of the interactive runtime into explicit `make install-deps` and `make full-install` targets.
- Removed the System Setup module from the launcher and added upgrade cleanup for previously installed copies of `lib/setup.sh`.
- Updated missing-command guidance to point to the installer dependency target.

### Navigation

- Standardized main-menu option `[00]` as Exit Interface.
- Standardized `[00]` as Return to control deck in every feature submenu.
- Added a consistent blank-line separator before every Exit Interface and Return to control deck row.
- Added regression coverage for dependency installation, removal of runtime setup, main-menu dispatch, and every submenu return path.

### Milestone

- Completed all Roadmap Milestone 7 work and recorded successful manual verification of runtime setup removal, zero-key navigation, and navigation-row spacing.

## 2.6 — 2026-08-15

Version 2.6 completes **Roadmap Milestone 6: User Experience and
Documentation** with a terminal-safe command interface, non-interactive
behavior, focused operational guides, and an installed documentation set.

### Command-Line Interface

- Added `--help`, `--version`, and `--no-color`, including support for the standard `NO_COLOR` environment variable.
- Added read-only `cyberops info` and `cyberops docker status` command channels.
- Made non-interactive menu launches fail with actionable usage guidance instead of looping on end-of-input.
- Disabled screen clearing and typewriter delays when output is not attached to a terminal.
- Added regression coverage for options, command dispatch, unknown input, no-color state, and non-interactive refusal.

### Documentation

- Rebuilt the README as a concise project overview, quick start, command reference, documentation index, and safety gate.
- Moved detailed Docker recovery, USB safety, and operation privilege/side-effect guidance into focused documents under `docs/`.
- Added a short, privacy-safe terminal demonstration and included the documentation in system-wide installations.
- Recorded successful manual verification of unknown-option and non-interactive refusal behavior.

### Milestone

- Completed all Roadmap Milestone 6 work and recorded successful manual verification of the command channels, color controls, terminal safeguards, interactive launchers, and installed documentation.

## 2.5 — 2026-08-15

Version 2.5 completes **Roadmap Milestone 5: Installation and Packaging** with
a tested system-wide installer, generated desktop integration, standardized
artwork, upgrade and removal workflows, and an MIT license.

### Installation and Packaging

- Replaced the hardcoded Quickhacks desktop entry with an installer-generated CYBEROPS Terminal entry.
- Standardized the application artwork source and installed filename as `cyberops.png`.
- Installed the application artwork under the standard pixmaps directory, generated its absolute desktop-entry path, refreshed the desktop database when available, and removed the obsolete unindexed icon location during upgrades.
- Added a Makefile that installs and uninstalls the command wrapper, modular runtime, application icon, and desktop entry under a configurable prefix.
- Added isolated regression coverage for the complete install and uninstall layout.
- Documented source launch, system-wide installation, upgrades, custom prefixes, and uninstallation.
- Added the MIT License using a project-level CYBEROPS contributors copyright notice.
- Evaluated native Debian/Ubuntu packaging and deferred it until the command-line interface and documentation stabilize.
- Recorded successful command-line and GNOME application-launch verification of the system-wide installation.

### Milestone

- Completed all Roadmap Milestone 5 work and recorded successful manual verification of the installed command, desktop launcher, and application artwork.

## 2.4.1 — 2026-08-15

Version 2.4.1 adds a fast, explicitly non-secure signature-reset workflow for
removable media while retaining the complete zero-fill operation.

### USB Operations

- Added a separately labeled Quick Reset operation that removes detected filesystem, RAID, and partition-table signatures without claiming to overwrite or securely erase existing file data.
- Reused protected-disk detection, device-identity revalidation, unmount verification, dry-run previews, and two-step destructive confirmation for USB Quick Reset.
- Recorded successful manual verification on disposable removable media.

## 2.4 — 2026-08-15

Version 2.4 completes **Roadmap Milestone 4: Code Structure and Quality** with
a modular runtime, stronger test boundaries, consistent shell formatting, and
documented function contracts.

### Code Structure

- Added a location-independent, fail-closed module loader and extracted release configuration, theme values, operation settings, and shared runtime state into `lib/runtime.sh`.
- Extracted the complete Docker subsystem into `lib/docker.sh` while preserving the established interface and operation behavior.
- Extracted shared command validation, dry-run execution, signal cleanup, and operation-state helpers into `lib/core.sh`.
- Extracted banners, menus, prompts, confirmations, and terminal presentation into `lib/ui.sh` with explicit load-order contracts.
- Extracted the remaining admin, information, VPN, security, quickhacks, USB, setup, and main-menu features into focused modules, leaving `cyberops.sh` as a small launcher.
- Added `shfmt` enforcement to CI and replaced all remaining `echo -e` output with explicit `printf` formatting.
- Documented module contracts and the modular runtime layout, added direct main-menu dispatch tests, and expanded CI syntax and ShellCheck coverage to include `lib/*.sh`.
- Corrected the destructive-protocol warning panel so its header and body borders use a consistent width.

### Milestone

- Completed all Roadmap Milestone 4 work and recorded successful manual verification of the modular interface and existing operation workflows.

## 2.3 — 2026-08-15

Version 2.3 completes **Roadmap Milestone 3: Docker Operations** with selective
Compose maintenance, more accurate health handling, durable recovery evidence,
and stronger boundaries around rollback and image pruning.

### Docker Operations

- Added interactive selection for one, several, or all discovered Compose stacks.
- Added an exact preflight plan showing each selected project, Compose file, update commands, verification steps, and separately confirmed image-pruning behavior before confirmation.
- Expanded health polling to include stopped one-shot containers, accept successful exit-code-zero jobs, reject failed jobs, and follow replacement container IDs created while an update converges.
- Added private per-run recovery reports with before/after container, service, image-reference, immutable image-ID, runtime, exit-code, and health state.
- Documented manual image recovery and made clear that CYBEROPS never performs an automatic rollback.
- Split unused-image pruning into an optional action with its own destructive confirmation after successful stack maintenance.

### Documentation

- Restyled the README as a neon operations dossier using the existing CYBEROPS artwork, build badges, linked navigation, control-node labels, and high-visibility safety callouts.
- Standardized clone instructions and workflow links on the renamed `benglish2007/CYBEROPS` repository.

### Quality

- Added mocked regression coverage for Compose selection, one-shot and replacement-container health handling, recovery-state reports, and separately confirmed image pruning.

### Milestone

- Completed all Roadmap Milestone 3: Docker Operations work and recorded successful disposable-stack manual verification.

## 2.2.3 — 2026-08-14

Version 2.2.3 corrects compatibility and lint failures discovered by the
Milestone 2 distribution matrix.

### Compatibility

- Added runtime detection that selects either `count=<bytes>B` or `iflag=count_bytes`, covering both older GNU and newer `dd` implementations.
- Changed the compatibility test to execute harmless exact-byte probes instead of inspecting implementation-specific help text.

### Quality

- Removed unused theme constants and made menu/path prompt assignments explicit for ShellCheck.
- Reworked literal home-path matching to avoid an ambiguous tilde-expansion warning.

## 2.2.2 — 2026-08-14

Version 2.2.2 adds native file-path completion to interactive workflows.

### Interface

- Added native Tab-completing path prompts for ISO selection and secure file shredding.
- Added safe handling for completion-escaped spaces, pasted quoted paths, and `~` home-directory paths.

## 2.2.1 — 2026-08-14

Version 2.2.1 refreshes the CYBEROPS terminal interface.

### Interface

- Added a cohesive neon cyberpunk control-deck theme across the banner, menus, prompts, pause screens, and destructive-operation warnings.
- Added aligned menu nodes with concise subsystem tags while preserving dependency-free fallback rendering.

### Reliability

- Corrected the Tailscale disconnect command to invoke `sudo tailscale down`.

## 2.2 — 2026-08-14

Version 2.2 completes **Roadmap Milestone 2: General Reliability**.

### Reliability

- Added startup validation and safe bounds for all Docker environment settings.
- Added fail-fast rejection for unsafe stack-root paths and invalid health-check timing relationships.
- Standardized operation-level dependency checks with aggregated missing-command reporting.
- Added regression tests for configuration validation, startup exit behavior, and dependency reporting.
- Added `SIGINT`/`SIGTERM` handling with operation context, partial-state warnings, and registered network-interface restoration.
- Added cleanup regression tests covering signal exit codes and interface recovery.
- Added standardized success, warning, and error reporting across menu operations.
- Preserved command exit statuses and added operation-specific recovery guidance for command failures.
- Added explicit handling for ClamAV findings, Docker diagnostics, USB write/sync failures, VPN operations, and system setup errors.
- Added `DRY_RUN=1` preview mode for every state-changing menu operation, including Docker, USB, networking, package management, and destructive file actions.
- Added shell-escaped command previews and a persistent dry-run banner without reporting unverified execution success.
- Added compatibility tests for the Bash and GNU userland capabilities CYBEROPS relies on.
- Added a GitHub Actions matrix for Ubuntu 22.04, 24.04, and 26.04 LTS plus Debian 12 and 13.
- Documented the supported distribution baseline and the limits of container-based integration testing.

### Milestone

- Completed all Roadmap Milestone 2: General Reliability work.

## 2.1 — 2026-08-14

Version 2.1 completes **Roadmap Milestone 1: Safety and Test Foundation**.

### Safety

- Fixed USB selection so menu output cannot contaminate the selected device path.
- Added device identity recording and revalidation before destructive writes.
- Added fail-closed protection for disks backing `/`, `/boot`, and `/boot/efi`, including mapped and LVM parent disks.
- Added refusal paths for removed, replaced, non-removable, unresolved, and still-mounted targets.
- Added automatic unmounting for whole-disk filesystems and child partitions.
- Bounded zero-fill operations to the target's exact byte capacity.
- Corrected USB wipe terminology to explain flash wear-leveling limitations.
- Restored network interfaces to their original state after MAC-randomization success or failure.

### Quality

- Added a source-safe main guard for automated testing.
- Added mocked regression coverage for USB safety, protected-disk resolution, wipe execution, and MAC restoration.
- Added Bash syntax and ShellCheck validation through GitHub Actions.
- Documented the prioritized improvement roadmap and completed manual verification checklist.

### Verification

- Passed Bash syntax validation and ShellCheck 0.11.0.
- Passed 18 mocked safety assertions.
- Manually verified zero-fill, cancellation, device removal, mounted-device handling, bootable USB creation, and MAC restoration using disposable hardware.

## 2.0

- Integrated Docker Maintenance into the main CYBEROPS interface.
- Added bootable USB creation and consolidated removable-media tools under USB Operations.
