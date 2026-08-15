# Changelog

All notable changes to CYBEROPS are documented in this file.

## Unreleased

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
