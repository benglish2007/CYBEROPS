<div align="center">
  <img src="cyberops.png" alt="CYBEROPS neon skull emblem" width="320">
  <h1>CYBEROPS TERMINAL</h1>
  <p><strong><code>NEON GRID // UNIFIED LINUX OPERATIONS CONSOLE</code></strong></p>

  [![Release](https://img.shields.io/badge/RELEASE-v2.13-ff2d95?style=for-the-badge)](CHANGELOG.md)
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

### CYBEROPS Terminal v2.13

Version 2.13 adds dedicated MAC controls with numbered NetworkManager profile
selection, temporary session randomization, persistent per-connection
randomization, explicit disablement, and verified permanent-MAC restoration
with rollback and reconnection recovery. See the
[changelog](CHANGELOG.md) and [roadmap](ROADMAP.md) for release history and
planned work.
The VPN and MAC fields use accessible bracketed state badges: inactive VPN and
permanent MAC states are red, while active VPN and modified MAC states are
green; the text remains explicit when color is disabled.

---

## `//` QUICK START

Choose the workflow that matches how you use CYBEROPS.

### Option 1: Normal installation

New users should download `cyberops_2.13_all.deb` from the
[latest GitHub Release](https://github.com/benglish2007/CYBEROPS/releases/latest),
then install it through APT so required dependencies are resolved:

```bash
cd /tmp
wget https://github.com/benglish2007/CYBEROPS/releases/download/v2.13/cyberops_2.13_all.deb
sudo apt install ./cyberops_2.13_all.deb
cyberops
```

The installed desktop application is named **CYBEROPS Terminal**. To upgrade,
download the newer release package and install it over the existing version:

```bash
sudo apt install ./cyberops_<new-version>_all.deb
```

APT upgrades CYBEROPS in place; uninstalling first is unnecessary, and
user-owned configuration and operation logs remain intact. CYBEROPS does not
yet provide an APT repository, so new releases must currently be downloaded
from GitHub rather than discovered by `apt upgrade`.

### Option 2: Development and testing

Contributors and testers can run the latest source directly without changing
the installed package:

```bash
git clone https://github.com/benglish2007/CYBEROPS.git
cd CYBEROPS
chmod +x cyberops.sh
./cyberops.sh
```

After the initial clone, update and test subsequent revisions with:

```bash
git pull
./cyberops.sh
```

No uninstall or package reinstall is needed for ordinary source testing. When
testing package installation or desktop integration, build and reinstall the
current development package:

```bash
make deb
make deb-inspect
sudo apt install --reinstall ./dist/cyberops_2.13_all.deb
hash -r
cyberops --version
```

When the development version has increased, the normal `apt install` command
can be used without `--reinstall`.

### Source-install fallback

The original Makefile installation remains available under `/usr/local`:

```bash
sudo make install
cyberops
```

Optional utilities can be installed explicitly with:

```bash
sudo make install-deps
```

Remove a Makefile installation once before migrating to the `.deb`; otherwise
`/usr/local/bin/cyberops` may shadow the packaged `/usr/bin/cyberops` command.
See the [packaging guide](docs/PACKAGING.md) for package inspection, removal,
upgrade, and coexistence details.

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

Every submenu also reserves `[00]` for **Return to control deck**. Navigation
keys use a distinct palette color, and operations whose CYBEROPS command path
invokes elevated privileges display an aligned `[SUDO]` marker. Both cues remain
readable when color is disabled.

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
  cyberops [OPTIONS] system <disk|memory|services|failures>
  cyberops [OPTIONS] storage devices
  cyberops [OPTIONS] network <interfaces|routes|sockets>
  cyberops [OPTIONS] vpn status
  cyberops [OPTIONS] docker status
  cyberops [OPTIONS] config <path|show|check>
  cyberops [OPTIONS] logs <path|tail>
  cyberops [OPTIONS] diagnostics <preview|export> [OUTPUT]

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
cyberops system disk
cyberops system memory
cyberops system services
cyberops system failures
cyberops storage devices
cyberops network interfaces
cyberops network routes
cyberops network sockets
cyberops vpn status
cyberops docker status
cyberops config check
cyberops logs tail
cyberops diagnostics preview
cyberops diagnostics export
```

The system, storage, network, VPN, info, and Docker status channels are
read-only. Network telemetry remains local; none of the new Milestone 10
commands performs a public-IP lookup. Diagnostics export only creates a new
private archive and refuses to overwrite an existing file. The interactive control deck
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
| [Configuration, Logs, and Diagnostics](docs/CONFIGURATION.md) | Safe XDG configuration, private operation events, and privacy-filtered support bundles |
| [Release Operations](docs/RELEASING.md) | Validation, preview, publishing, retry, and rollback boundaries |
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
installer and Debian-package isolation, and a distribution compatibility
matrix. Releases use annotated tags, changelog-derived notes, and a guarded
preview/publish workflow.

---

## `//` LICENSE

CYBEROPS is released under the [MIT License](LICENSE).

---

<div align="center">

  **`CYBEROPS TERMINAL v2.13 // LINK STANDBY`**

  *One terminal. One toolkit. Linux operations under control.*

</div>
