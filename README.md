<div align="center">
  <img src="cyberops.png" alt="CYBEROPS neon skull emblem" width="320">
  <h1>CYBEROPS TERMINAL</h1>
  <p><strong><code>NEON GRID // UNIFIED LINUX OPERATIONS CONSOLE</code></strong></p>

  [![Release](https://img.shields.io/badge/RELEASE-v2.7-ff2d95?style=for-the-badge)](CHANGELOG.md)
  [![Bash](https://img.shields.io/badge/SHELL-BASH_5+-00e5ff?style=for-the-badge&logo=gnubash&logoColor=050816)](cyberops.sh)
  [![Validate](https://github.com/benglish2007/CYBEROPS/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/benglish2007/CYBEROPS/actions/workflows/validate.yml)
  [![Platform](https://img.shields.io/badge/PLATFORM-UBUNTU_%2F_DEBIAN-8b5cf6?style=for-the-badge&logo=linux&logoColor=white)](COMPATIBILITY.md)

  **One interface. Modular Linux operations under control.**

  [QUICK START](#-quick-start) · [OPERATIONS](#-operations-grid) · [COMMANDS](#-command-channel) · [DOCUMENTATION](#-documentation-grid) · [SAFETY](#-safety-gate)
</div>

---

> [!IMPORTANT]
> CYBEROPS is a modular, menu-driven Linux administration and security toolkit
> for supported Ubuntu and Debian releases. It performs real system changes;
> inspect targets and previews before confirming an operation.

## `//` CURRENT BUILD

### CYBEROPS Terminal v2.7

Version 2.7 completes the Installer and Navigation Consistency milestone.
Optional dependency bootstrap now lives in explicit installer targets rather
than the interactive runtime, option `[00]` consistently exits or returns, and
navigation rows are visually separated from operational choices. See the
[changelog](CHANGELOG.md) and [roadmap](ROADMAP.md) for release history and
planned work.

---

## `//` QUICK START

Clone and launch from the source tree:

```bash
git clone https://github.com/benglish2007/CYBEROPS.git
cd CYBEROPS
chmod +x cyberops.sh
./cyberops.sh
```

Install the command, modular runtime, icon, desktop entry, and license:

```bash
sudo make install
cyberops
```

Optional utilities are installed separately and explicitly through the
installer rather than from the CYBEROPS runtime:

```bash
sudo make install-deps
```

Install optional dependencies and CYBEROPS together with:

```bash
sudo make full-install
```

The installed desktop application is named **CYBEROPS Terminal**.

Upgrade without uninstalling:

```bash
git pull
sudo make install
```

Remove every CYBEROPS-managed file:

```bash
sudo make uninstall
```

A custom root can be selected with `PREFIX`, provided the same value is used
for uninstall:

```bash
sudo make install PREFIX=/opt/cyberops
sudo make uninstall PREFIX=/opt/cyberops
```

---

## `//` OPERATIONS GRID

| NODE | MODULE | CAPABILITIES |
| :---: | --- | --- |
| `[00]` | Exit Interface | Disconnect from the control deck |
| `[01]` | Admin Ops | APT, storage, memory, services, and reboot |
| `[02]` | Info Scan | Host, hardware, network, route, and socket telemetry |
| `[03]` | VPN Control | Tailscale and ExpressVPN status and links |
| `[04]` | Cyber Defense | UFW, ClamAV, `rkhunter`, and authentication inspection |
| `[05]` | Quickhacks | Diagnostics, process, DNS, shred, and MAC utilities |
| `[06]` | Docker Ops | Selective Compose maintenance, recovery evidence, and status |
| `[07]` | USB Operations | ISO writing, signature reset, inspection, and zero-fill |

Every submenu also reserves `[00]` for **Return to control deck**.

Operations check their required commands before starting and report missing
dependencies together. State-changing actions provide confirmation and support
`DRY_RUN=1` previews where applicable.

Detailed behavior, required privilege, and side effects are listed in the
[operation reference](docs/OPERATIONS.md).

---

## `//` COMMAND CHANNEL

```text
Usage:
  cyberops [OPTIONS]
  cyberops [OPTIONS] info
  cyberops [OPTIONS] docker status

Options:
  -h, --help       Show help and exit
  -V, --version    Show the CYBEROPS version and exit
      --no-color   Disable ANSI color output
```

Examples:

```bash
cyberops --help
cyberops --version
cyberops --no-color
NO_COLOR=1 cyberops
cyberops info
cyberops docker status
```

`info` and `docker status` are read-only. The interactive control deck
requires terminal input and output; a redirected invocation without a command
exits with usage guidance instead of waiting indefinitely.

See the [short terminal demonstration](docs/DEMO.md).

---

## `//` PREVIEW PROTOCOL

```bash
DRY_RUN=1 cyberops
```

Preview mode prints shell-escaped state-changing commands without executing
them. Read-only discovery and validation still run so the preview describes
the real Compose files, network interfaces, paths, and removable devices.

Coverage includes package management, reboot, firewall and VPN state, DNS,
process and file operations, MAC changes, Docker maintenance and pruning, and
USB unmount, image-write, signature-reset, zero-fill, and sync operations.

---

## `//` DOCUMENTATION GRID

| GUIDE | CONTENT |
| --- | --- |
| [Docker Operations](docs/DOCKER.md) | Discovery, selective updates, health handling, recovery evidence, configuration, and rollback boundaries |
| [USB Operations](docs/USB.md) | Target safety, ISO writing, Quick Reset, full zero-fill, and flash-storage limits |
| [Privileges and Side Effects](docs/OPERATIONS.md) | Privileges, mutations, network disclosure, previews, and interruption behavior |
| [Terminal Demonstration](docs/DEMO.md) | Short CLI and non-interactive session |
| [Compatibility](COMPATIBILITY.md) | Supported releases, dependencies, and CI boundaries |
| [Module Contracts](lib/README.md) | Runtime loading order and source-safe module rules |
| [Roadmap](ROADMAP.md) | Completed milestones and future work |
| [Changelog](CHANGELOG.md) | Release-by-release transmission log |

---

## `//` RUNTIME MATRIX

Automated compatibility coverage includes Ubuntu 22.04, 24.04, and 26.04 LTS,
plus Debian 12 and 13.

The core runtime expects Bash 5, GNU userland tools, util-linux, systemd,
iproute2, procps, and findutils. Optional operations check for their own tools,
including Docker Compose, Tailscale, ExpressVPN, UFW, ClamAV, `rkhunter`,
`nmap`, `wavemon`, and `macchanger`.

Hardware and host integration remain outside container CI. Physical removable
media, a real Docker daemon, host networking, firewall state, VPN clients,
systemd, sensors, and reboot behavior require targeted manual testing.

---

## `//` SAFETY GATE

CYBEROPS does not run the entire process as root. Individual commands request
`sudo` only when elevated access is necessary.

> [!CAUTION]
> ISO writes, USB Quick Reset, full zero-fill, file shredding, firewall changes,
> process termination, MAC changes, Docker maintenance, package upgrades, and
> reboot can destroy data or interrupt services.

USB operations record and revalidate device identity, exclude protected system
disks, require unmounted targets, and use explicit confirmation. Quick Reset is
not a data wipe. Zero-filling flash media is not a guaranteed secure erase.

Docker recovery is manual. CYBEROPS records before/after evidence but cannot
reverse application migrations, volumes, databases, bind mounts, secrets, or
configuration changes.

Review the [privilege reference](docs/OPERATIONS.md), [Docker guide](docs/DOCKER.md),
and [USB guide](docs/USB.md) before using important systems or media.

---

## `//` DEVELOPMENT

The launcher loads focused modules from `lib/` relative to its own location.
Copying only `cyberops.sh` fails closed because the module tree is required.
The Makefile keeps the installed runtime together under
`/usr/local/lib/cyberops`.

Validation includes Bash syntax, ShellCheck, `shfmt`, mocked regression tests,
installer isolation, and a distribution compatibility matrix. Native `.deb`
packaging is deferred until the command interface and documentation stabilize.

---

## `//` LICENSE

CYBEROPS is released under the [MIT License](LICENSE).

---

<div align="center">

  **`CYBEROPS TERMINAL v2.7 // LINK STANDBY`**

  *One terminal. One toolkit. Linux operations under control.*

</div>
