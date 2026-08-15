<div align="center">
  <img src="cyberops.png" alt="CYBEROPS neon skull emblem" width="320">

  <h1>CYBEROPS TERMINAL</h1>

  <p><strong><code>NEON GRID // UNIFIED LINUX OPERATIONS CONSOLE</code></strong></p>

  [![Release](https://img.shields.io/badge/RELEASE-v2.5-ff2d95?style=for-the-badge)](CHANGELOG.md)
  [![Bash](https://img.shields.io/badge/SHELL-BASH_5+-00e5ff?style=for-the-badge&logo=gnubash&logoColor=050816)](cyberops.sh)
  [![Validate](https://github.com/benglish2007/CYBEROPS/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/benglish2007/CYBEROPS/actions/workflows/validate.yml)
  [![Platform](https://img.shields.io/badge/PLATFORM-UBUNTU_%2F_DEBIAN-8b5cf6?style=for-the-badge&logo=linux&logoColor=white)](COMPATIBILITY.md)

  **One interface. Modular Linux operations under control.**

  [OPERATIONS GRID](#operations-grid) · [DOCKER GRID](#docker-grid) · [USB PROTOCOLS](#usb-protocols) · [DEPLOYMENT](#deployment) · [SECURITY](#security-protocols)
</div>

---

> [!IMPORTANT]
> **CYBEROPS Terminal** is a modular, menu-driven Linux administration and
> security toolkit written in Bash. It unifies system administration,
> networking, security, Docker maintenance, VPN control, troubleshooting, and
> removable-media operations behind one neon terminal interface.

CYBEROPS targets **Ubuntu and Debian-based Linux systems**, favoring standard
Linux utilities and native operating-system tools wherever practical. Planned
safety, reliability, packaging, and usability work is tracked in the
[development roadmap](ROADMAP.md).

<a id="current-build"></a>

## `//` CURRENT BUILD

### CYBEROPS Terminal v2.5

Version 2.5 completes the Installation and Packaging milestone with a tested
system-wide Makefile workflow, generated CYBEROPS desktop integration,
standardized application artwork, upgrade and uninstall instructions, and an
MIT license. It builds on the USB Quick Reset in version 2.4.1, the modular
Code Structure and Quality work in version 2.4, the Docker Operations work in
version 2.3, and the earlier reliability and safety releases. Together, these
releases:

* Hardens destructive USB operations with device identity revalidation and protected-system-disk detection
* Correctly handles whole-disk and partition-mounted filesystems
* Bounds zero-fill operations to the device's exact byte capacity
* Restores network interfaces to their original state after MAC-randomization failures
* Adds mocked regression tests, ShellCheck validation, and GitHub Actions CI
* Records successful physical verification of the complete Milestone 1 checklist
* Validates configuration and command dependencies before operations begin
* Adds consistent failure guidance and interruption cleanup
* Adds a safe preview mode for state-changing operations
* Tests the supported Ubuntu and Debian baseline in CI
* Selects one, several, or all discovered Compose stacks for maintenance
* Shows exact Compose files and planned actions before confirmation
* Handles successful one-shot jobs and replacement containers during health checks
* Preserves private before/after container and image state for manual recovery
* Keeps rollback manual and makes image pruning a separate confirmed action
* Loads focused Bash modules through a small, fail-closed launcher
* Documents module contracts and validates menu dispatch and loader failures
* Enforces consistent formatting with `shfmt` and explicit `printf` output
* Offers a separately confirmed USB signature reset without misrepresenting it as a data wipe
* Installs and removes the complete modular runtime through a tested Makefile
* Generates a path-safe CYBEROPS desktop launcher with registered application artwork
* Distributes the project and installed application under the MIT License

Version 2.0 introduced the integrated Docker Maintenance and USB Operations
modules. Consult the [transmission log](CHANGELOG.md) for the full release
history.

CYBEROPS can now act as a more complete Linux operations console rather than simply a collection of security utilities.

---

<a id="operations-grid"></a>

## `//` OPERATIONS GRID

| NODE | MODULE | CONTROL SURFACE |
| :---: | --- | --- |
| `[00]` | System Setup | Optional dependency bootstrap |
| `[01]` | Admin Ops | APT, storage, memory, services, reboot |
| `[02]` | Info Scan | Host, hardware, network, and socket telemetry |
| `[03]` | VPN Control | Tailscale and ExpressVPN links |
| `[04]` | Cyber Defense | Firewall, malware, rootkit, and auth inspection |
| `[05]` | Quickhacks | Diagnostics and rapid-response utilities |
| `[06]` | Docker Ops | Compose maintenance and container status |
| `[07]` | USB Operations | Bootable media, inspection, and zero-fill |

---

### `[00] // SYSTEM SETUP`

Install optional packages used by CYBEROPS.

The setup module uses APT and is intended primarily for Ubuntu/Debian systems.

Optional utilities include:

* `figlet`
* `lolcat`
* `htop`
* `nmap`
* `wavemon`
* `macchanger`
* `lm-sensors`
* `clamav`
* `rkhunter`
* `curl`

Core Linux utilities used by the USB and system-management functions are normally already provided by Ubuntu.

---

### `[01] // ADMIN OPS`

Common Linux system administration tasks.

Current functions include:

* Update APT package lists
* Upgrade installed packages
* Display filesystem usage
* Display memory usage
* Show active systemd services
* Show failed systemd services
* Reboot the system

---

### `[02] // INFO SCAN`

Quick system and network reconnaissance.

Current functions include:

* System summary
* CPU information
* Memory information
* Storage devices
* Network interfaces
* Routing table
* Listening sockets
* Public IP address

Common Linux tools used include:

```bash
hostnamectl
lscpu
free
lsblk
ip
ss
curl
```

---

### `[03] // VPN CONTROL`

Provides quick access to supported VPN and overlay-network tools.

Current support includes:

#### Tailscale Link

* Show status
* Bring Tailscale up
* Bring Tailscale down

#### ExpressVPN Link

* Show status
* Connect
* Disconnect

VPN options automatically report when the corresponding CLI tool is unavailable.

---

### `[04] // CYBER DEFENSE`

Security-oriented system administration and inspection.

Current functions include:

* Display UFW firewall status
* Enable UFW
* Disable UFW
* Scan the home directory with ClamAV
* Run an `rkhunter` check
* Review recent failed SSH authentication attempts

Disabling the firewall requires explicit confirmation.

---

### `[05] // QUICKHACKS`

A collection of useful Linux troubleshooting and administration utilities.

Current functions include:

* Temperature monitoring
* Network ping sweep
* Wi-Fi analysis
* Process termination
* DNS cache flushing
* Secure file shredding
* MAC-address randomization

Depending on the operation, CYBEROPS uses tools such as:

```bash
sensors
nmap
wavemon
kill
resolvectl
shred
macchanger
```

Destructive operations require confirmation before execution.

File-selection prompts support native Tab completion. The secure-shred prompt
starts in the current user's home directory; press `Tab` to complete files and
directories, or `Ctrl-U` to clear the suggested path.

---

<a id="docker-grid"></a>

## `[06] // DOCKER GRID`

Version 2.0 integrates Docker maintenance directly into CYBEROPS.

The Docker updater was previously maintained as a standalone script. It is now built directly into the CYBEROPS interface.

### `01 // STACK DISCOVERY`

By default, CYBEROPS searches:

```text
/srv/stacks
```

Each immediate subdirectory is checked for:

```text
compose.yml
compose.yaml
docker-compose.yml
docker-compose.yaml
```

For example:

```text
/srv/stacks/
├── immich/
│   └── compose.yml
├── jellyfin/
│   └── compose.yml
├── pihole/
│   └── compose.yml
└── portainer/
    └── compose.yml
```

The stack directory can be overridden with the environment variable:

```bash
STACK_ROOT=/another/location cyberops
```

---

### `02 // UPDATE SEQUENCE`

For each discovered Compose stack, CYBEROPS performs:

```text
Discover stack
      │
      ▼
Pull latest images
      │
      ▼
docker compose up -d
      │
      ├── Failure ──► Wait ──► Retry once
      │
      ▼
Check container state
      │
      ▼
Check Docker health status
      │
      ▼
Display stack status
```

After discovery, CYBEROPS lets you select one stack, several numbered stacks,
or every stack. Before confirmation, it prints the exact Compose files and the
`pull` and `up -d --remove-orphans` commands planned for each selection.

The updater:

1. Discovers Docker Compose stacks.
2. Prompts for one, several, or all discovered stacks.
3. Displays the selected projects and exact planned actions.
4. Pulls current container images.
5. Recreates or starts each selected stack.
6. Removes orphaned containers.
7. Retries a failed startup once.
8. Checks container runtime state.
9. Waits for Docker health checks.
10. Displays recent logs when a stack fails.
11. Tracks successful and failed stacks.
12. Produces a final maintenance summary.

Health verification examines all containers in each selected Compose project,
including stopped containers. A completed one-shot container is accepted only
when it exits with status `0`; a nonzero exit is a stack failure. Container IDs
are refreshed during polling so a replacement created while Compose converges
is checked instead of the superseded container.

For real updates, CYBEROPS writes a mode-`600` recovery report under
`${XDG_STATE_HOME:-$HOME/.local/state}/cyberops/docker/`. The report captures
before/after Compose file, service, container, image reference, immutable image
ID, runtime state, exit code, and health information. It intentionally excludes
container environment values and is evidence for manual recovery—not an
automatic rollback mechanism.

---

### `03 // FAILURE CONTAINMENT`

A failure in one stack does **not** stop the remaining stacks from being processed.

At completion, CYBEROPS reports:

```text
DOCKER MAINTENANCE SUMMARY
========================================

Successful stacks: 4
  [OK] immich
  [OK] jellyfin
  [OK] pihole
  [OK] portainer

Failed stacks: 1
  [FAILED] example-stack
```

Recent Compose logs are displayed when startup or health checks fail.

---

### `04 // IMAGE PRUNING`

Unused Docker images are never pruned as an automatic consequence of updating
stacks. When every selected stack succeeds, CYBEROPS offers pruning as a
separate optional action and requires another explicit `YES` confirmation.

If any stack fails:

```text
Unused image pruning skipped because one or more stacks failed.
```

This reduces the chance of removing an image that may be useful while troubleshooting or rolling back a failed update.

---

### `05 // MANUAL RECOVERY`

CYBEROPS does **not** automatically roll back a failed Compose update. Container
images can include migrations or state changes that cannot be reversed safely
without application-specific knowledge.

When a stack fails:

1. Do not prune images.
2. Open the recovery report path printed in the maintenance summary.
3. Compare the stack's `BEFORE` and `AFTER` entries, especially `image_ref`,
   `image_id`, state, exit code, and health.
4. Inspect the current project without changing it:

   ```bash
   docker compose -f /path/to/compose.yml ps --all
   docker compose -f /path/to/compose.yml logs --tail 80 --no-color
   ```

5. If the previous image ID is still present and application documentation says
   an image-only rollback is safe, retag it to the recorded image reference and
   recreate without pulling:

   ```bash
   docker image tag <before-image-id> <recorded-image-reference>
   docker compose -f /path/to/compose.yml up -d --no-build --pull never --remove-orphans
   ```

6. Recheck container state, health, logs, and application data.

Restoring an image does not restore volumes, databases, bind-mounted files,
Compose configuration, secrets, or schema changes. Use the application's own
backup and recovery procedure whenever persistent data may have changed.

---

### `06 // GRID STATUS`

CYBEROPS can also display a quick Docker overview including:

* Running containers
* Container images
* Container status
* Published ports
* Docker disk usage

---

### `07 // CONFIGURATION CHANNELS`

The following environment variables can adjust updater behavior:

```bash
STACK_ROOT=/srv/stacks
RETRY_DELAY=5
HEALTH_TIMEOUT=120
HEALTH_INTERVAL=5
FAILURE_LOG_LINES=80
```

CYBEROPS validates these settings before opening the interface:

| Setting | Accepted value |
| --- | --- |
| `STACK_ROOT` | Safe absolute path other than `/`, without `.` or `..` traversal components |
| `RETRY_DELAY` | Integer from 0 to 3,600 seconds |
| `HEALTH_TIMEOUT` | Integer from 1 to 86,400 seconds |
| `HEALTH_INTERVAL` | Integer from 1 to 3,600 seconds and no greater than `HEALTH_TIMEOUT` |
| `FAILURE_LOG_LINES` | Integer from 1 to 10,000 |
| `DRY_RUN` | `0` for normal operation or `1` for preview mode |

Invalid configuration is reported at startup and exits with status 2 before any menu operation can run.

Example:

```bash
HEALTH_TIMEOUT=180 cyberops
```

---

<a id="preview-protocol"></a>

## `//` PREVIEW PROTOCOL

Set `DRY_RUN=1` to inspect state-changing commands without executing them:

> [!TIP]
> Use preview mode before unfamiliar maintenance or destructive workflows to
> inspect the exact shell-escaped commands CYBEROPS plans to run.

```bash
DRY_RUN=1 ./cyberops.sh
```

The banner clearly identifies dry-run mode. CYBEROPS still performs read-only
discovery and validation so previews use the actual Compose files, network
interfaces, file paths, and removable devices selected by the user. Each
planned command is printed with shell-escaped arguments.

Dry-run coverage includes:

* APT updates, upgrades, and dependency installation
* Reboot, firewall, VPN, DNS, process, file-shred, and MAC-address changes
* Docker image pulls, stack recreation, and image pruning
* USB filesystem unmounts, bootable-image writes, signature resets, zero-fill, and buffer sync

No state-changing command is executed while dry-run mode is enabled. Normal
confirmation and validation steps may still appear where they help produce an
accurate preview. Set `DRY_RUN=0`, or leave it unset, for normal operation.

---

<a id="usb-protocols"></a>

## `[07] // USB PROTOCOLS`

Version 2.0 introduces a dedicated USB Operations module.

It combines:

* Bootable USB creation
* USB quick reset
* USB wipe / zero-fill
* Removable-storage inspection

Because these operations can destroy data, CYBEROPS performs several safety checks before writing to a drive.

---

### `01 // CREATE BOOTABLE USB`

CYBEROPS can write a Linux ISO directly to a removable USB device.

The ISO path prompt supports native Tab completion and starts in `~/Downloads/`
when that directory exists, otherwise in the current user's home directory.
Paths containing spaces, pasted quoted paths, and paths beginning with `~` are
normalized before validation. Press `Ctrl-U` to clear the suggested path.

The implementation intentionally relies on standard Ubuntu/Linux utilities rather than third-party USB-writing applications.

Primary tools include:

```bash
lsblk
findmnt
file
sha256sum
umount
dd
sync
```

---

### `02 // BOOTABLE USB SEQUENCE`

The process is:

```text
Select ISO
    │
    ▼
Validate ISO
    │
    ▼
Optional SHA-256 verification
    │
    ▼
Detect removable disks
    │
    ▼
Select target
    │
    ▼
Record and validate device identity
    │
    ▼
Final destructive confirmation
    │
    ▼
Revalidate identity and unmount target partitions
    │
    ▼
Confirm no filesystems remain mounted
    │
    ▼
Write ISO with dd
    │
    ▼
sync
```

---

### `03 // ISO VERIFICATION`

An expected SHA-256 checksum can optionally be supplied before writing the image.

CYBEROPS calculates:

```bash
sha256sum image.iso
```

and compares the result against the supplied checksum.

If the checksums do not match, the write operation is aborted.

---

### `04 // TARGET SAFETY GATE`

Before writing an image, CYBEROPS attempts to:

* Detect removable or USB-connected disks
* Present the device model and size
* Record the device path, type, transport, removable flag, size, model, serial, and WWN
* Exclude disks backing `/`, `/boot`, or `/boot/efi`
* Require selection of a whole disk instead of a partition
* Display the selected device before writing
* Revalidate the device identity after confirmation
* Unmount mounted target partitions
* Refuse to write if any target filesystem remains mounted
* Require explicit destructive-operation confirmation

The actual image is written using:

```bash
sudo dd if="image.iso" of="/dev/sdX" bs=4M status=progress conv=fsync
```

followed by:

```bash
sync
```

> [!CAUTION]
> Always independently verify the selected device before confirming a
> destructive disk operation.

---

### `05 // QUICK RESET`

Quick Reset removes signatures detected on the selected disk and its
partitions using:

```bash
sudo wipefs --all -- /dev/sdX1 /dev/sdX
```

CYBEROPS unmounts the selected device, revalidates its recorded identity, and
clears child-partition signatures before removing the disk's partition table.
The operation normally completes in seconds and is useful when preparing media
for repartitioning or a new filesystem.

> [!WARNING]
> Quick Reset is not a data wipe. It removes recognized filesystem, RAID, and
> partition-table signatures, but does not overwrite file contents. Existing
> data may remain recoverable until it is overwritten.

Quick Reset requires both an explicit `YES` and an exact device-path
confirmation. Full zero-fill remains available when every addressable byte
should be overwritten.

---

### `06 // WIPE / ZERO-FILL`

CYBEROPS can zero-fill a selected removable disk.

The wipe operation uses:

```bash
sudo dd if=/dev/zero of=/dev/sdX bs=16M count=<device-bytes>B status=progress conv=fsync
```

When byte-suffixed counts are unavailable, CYBEROPS automatically uses:

```bash
sudo dd if=/dev/zero of=/dev/sdX bs=16M count=<device-bytes> iflag=count_bytes status=progress conv=fsync
```

CYBEROPS harmlessly probes the installed `dd` implementation and selects the
supported exact-byte form. It reads the device's exact byte capacity first, so
`dd` stops after the final addressable byte instead of attempting an additional
write and reporting `No space left on device`.

> [!WARNING]
> Zero-filling flash storage is not a guaranteed secure erase. USB flash drives
> and SSDs may retain data in remapped or wear-leveled cells that normal block
> writes cannot address.

Before beginning, CYBEROPS:

* Detects removable disks
* Excludes the detected system disk
* Displays the target device
* Requires an explicit `YES`
* Requires the device path to be entered again
* Unmounts mounted partitions

This operation permanently destroys the existing filesystem and data on the selected device.

---

<a id="control-deck"></a>

## `//` CONTROL DECK

CYBEROPS v2.5 presents the following main interface:

```text
╔══[ CYBEROPS // NEON GRID ]══════════════════[ NODE ONLINE ]══╗
                         CYBEROPS
╚══════════════════════════════════════════════════════════════╝
BUILD 2.5  //  UNIFIED LINUX OPERATIONS CONSOLE  //  SESSION ACTIVE

╭─[ CONTROL DECK ]──────────────────────────────────────────────
│ SELECT AN OPERATIONS NODE
╰──────────────────────────────────────────────────────────

  [00]  System Setup                       BOOTSTRAP // DEPENDENCIES
  [01]  Admin Ops                          SYSTEM // CONTROL
  [02]  Info Scan                          HOST // RECON
  [03]  VPN Control                        NETWORK // TUNNELS
  [04]  Cyber Defense                      SECURITY // DEFENSE
  [05]  Quickhacks                         TOOLS // FIELD KIT
  [06]  Docker Ops                         CONTAINERS // GRID
  [07]  USB Operations                     MEDIA // I/O
  [08]  Exit Interface                     SESSION // DISCONNECT

CYBEROPS >
```

Each major capability is separated into its own themed submenu. The interface
uses ANSI color and Unicode line art, with an internal ASCII logo when `figlet`
is unavailable.

---

<a id="deployment"></a>

## `//` DEPLOYMENT

### `01 // CLONE + LAUNCH`

Clone the repository:

```bash
git clone https://github.com/benglish2007/CYBEROPS.git
cd CYBEROPS
```

Make the script executable:

```bash
chmod +x cyberops.sh
```

Run it directly:

```bash
./cyberops.sh
```

---

### `02 // MODULAR RUNTIME`

The launcher loads its required modules from `lib/` relative to its own
location, so it works even when started from another directory:

```bash
cd /tmp
/path/to/CYBEROPS/cyberops.sh
```

Keep `cyberops.sh` and `lib/` together. Copying only the launcher will fail
closed with a message identifying the missing module.

Current source layout:

```text
cyberops.sh       Thin launcher and module loader
lib/runtime.sh    Version, theme, configuration, and shared state
lib/core.sh       Validation, command execution, dry-run, and cleanup
lib/ui.sh         Banner, menus, prompts, and confirmations
lib/docker.sh     Docker and Compose operations
lib/admin.sh      System administration operations
lib/info.sh       System and network information
lib/vpn.sh        VPN controls
lib/security.sh   Defensive security operations
lib/quickhacks.sh Troubleshooting and field utilities
lib/usb.sh        Removable-media operations and safety checks
lib/setup.sh      Optional dependency setup
lib/menu.sh       Main control-deck dispatcher
```

---

### `03 // SYSTEM-WIDE INSTALL`

Install the command, modular runtime, icon, and CYBEROPS desktop entry under
`/usr/local`:

```bash
sudo make install
```

The installation layout is:

```text
/usr/local/bin/cyberops
/usr/local/lib/cyberops/cyberops.sh
/usr/local/lib/cyberops/lib/*.sh
/usr/local/share/applications/cyberops.desktop
/usr/local/share/pixmaps/cyberops.png
/usr/local/share/doc/cyberops/LICENSE
```

Launch from a terminal with `cyberops`, or open **CYBEROPS Terminal** from the
desktop application menu. Override `PREFIX` when a different installation
root is required:

```bash
sudo make install PREFIX=/opt/cyberops
```

---

### `04 // UPDATE CHANNEL`

Update the repository and reinstall the managed files:

```bash
git pull
sudo make install
```

`make install` safely replaces the files owned by the CYBEROPS installation.
No reinstall is needed when launching directly from the cloned repository.

---

### `05 // UNINSTALL`

Remove every file managed by the default installation:

```bash
sudo make uninstall
```

Use the same `PREFIX` supplied during installation when it was customized:

```bash
sudo make uninstall PREFIX=/opt/cyberops
```

Uninstalling CYBEROPS does not remove optional system packages previously
installed through System Setup and does not remove the cloned repository.

---

<a id="runtime-matrix"></a>

## `//` RUNTIME MATRIX

CYBEROPS supports Ubuntu 22.04 LTS, 24.04 LTS, and 26.04 LTS, plus Debian 12
and Debian 13. The compatibility matrix runs the complete regression suite on
each of these releases. See [COMPATIBILITY.md](COMPATIBILITY.md) for required
runtime capabilities, optional integrations, and the boundary between
container CI and physical-system testing.

Core functionality expects common Linux utilities including:

```text
bash
coreutils
util-linux
systemd
iproute2
procps
findutils
```

Docker functionality additionally requires:

```text
docker
docker compose
```

Some modules require optional software. Each operation checks its complete command set before starting and reports all missing dependencies together rather than failing partway through.

---

<a id="security-protocols"></a>

## `//` SECURITY PROTOCOLS

CYBEROPS deliberately does **not** run the entire script as root.

Instead, individual commands request `sudo` only when elevated privileges are required.

This limits how much of the program executes with root privileges.

Operations requiring particular care include:

* Firewall changes
* System reboot
* Docker administration
* Secure file deletion
* USB wipe / zero-fill
* Bootable USB creation
* Network-interface changes

Destructive operations include additional confirmation prompts where practical.

### `01 // FAILURE REPORTING`

Menu operations use consistent result messages:

* `[OK]` identifies confirmed success
* `[!]` identifies warnings or failures
* Checked command failures include the original exit status
* `Next step:` provides operation-specific recovery guidance

CYBEROPS does not print success after a failed command. Multi-step operations stop dependent steps when prerequisites fail, while noncritical Docker diagnostics are reported without hiding the primary stack result. ClamAV exit status 1 is treated as an infected-file finding rather than a scanner failure.

### `02 // INTERRUPT + CLEANUP`

CYBEROPS handles `SIGINT` and `SIGTERM` as fail-safe exits. When an operation is interrupted, it:

* Reports the operation that was active
* Uses status 130 for `SIGINT` and 143 for `SIGTERM`
* Attempts to restore a network interface that CYBEROPS temporarily brought down
* Warns when a USB device may contain a partial image or incomplete zero-fill
* Warns when Docker stacks may require inspection after an interrupted update

CYBEROPS does not automatically remount written USB media or roll back interrupted Docker updates. Follow the displayed recovery guidance before retrying those operations.

---

## `//` DESIGN DIRECTIVES

CYBEROPS is intended to remain:

### `MODULAR`

Each major capability lives in its own function or submenu.

### `READABLE`

The project favors understandable Bash over unnecessary complexity.

### `PORTABLE`

Where practical, functionality uses standard Linux utilities rather than specialized applications.

### `SAFE`

Potentially destructive operations should:

1. Clearly identify the target.
2. Explain what will happen.
3. Perform reasonable sanity checks.
4. Require explicit confirmation.

### `USEFUL`

Features should solve real Linux administration, troubleshooting, security, or maintenance problems.

The goal is not to add commands simply because they look interesting.

---

## `//` FORWARD ROADMAP

CYBEROPS is evolving from its original security-oriented terminal interface into a broader **personal Linux operations console**.

Potential future modules include:

* SSH security auditing
* Firewall inspection and management
* Backup operations
* SMART/NVMe disk-health monitoring
* Tailscale diagnostics
* Docker cleanup and rollback tools
* Log inspection
* Network diagnostics
* Hardware health monitoring
* Service-management dashboards
* Security baseline checks
* Host-specific configuration
* Backup verification
* System update automation

Longer term, CYBEROPS may support a configuration file allowing the same script to adapt its behavior to different Linux workstations and servers.

---

## `//` DEVELOPMENT PIPELINE

Standalone scripts can still be developed independently when that makes experimentation easier.

Once mature, useful tools can be promoted into CYBEROPS modules.

The development model is therefore:

```text
Idea
  │
  ▼
Standalone Script
  │
  ▼
Test and Refine
  │
  ▼
Integrate into CYBEROPS
  │
  ▼
Maintain as a Module
```

This keeps experimental code separate while allowing proven tools to become part of the main operations console.

---

## `!!` DESTRUCTIVE CAPABILITIES

> [!CAUTION]
> CYBEROPS contains functionality capable of modifying system configuration
> and permanently destroying data.

In particular, commands involving:

```text
dd
shred
firewalls
Docker
network interfaces
storage devices
```

should be treated carefully.

> [!IMPORTANT]
> Review the source before using CYBEROPS on production or important systems.
> You are responsible for verifying device names, paths, commands, and backups
> before performing destructive operations.

---

## `//` LICENSE

CYBEROPS is released under the [MIT License](LICENSE).

---

<div align="center">

  **`CYBEROPS TERMINAL v2.5 // LINK STANDBY`**

  *One terminal. One toolkit. Linux operations under control.*

</div>
