# Operation Privileges and Side Effects

CYBEROPS does not run the entire process as root. Individual operations request
`sudo` only when required. Read the confirmation and command preview before
approving any state change.

Interactive menu rows marked `[SUDO]` invoke `sudo` in their CYBEROPS command
path. The marker is always printed as text, with color used only as an
additional cue. Operations without the marker may still depend on user,
device, Docker-socket, or client-specific permissions documented below.

The live header reads time, routes, interface addresses, current MAC address,
link state, and VPN-style interface names locally without `sudo`. Its `ROUTED`
label describes local routing, not verified internet access. Optional public-IP
display is disabled by default and contacts `api.ipify.org` only when enabled.
VPN and MAC status use bracketed text as well as color: VPN off and a permanent
MAC are red; an identified VPN interface and a modified MAC are green. Unknown
permanent-address state is yellow rather than being misreported as modified.

| Area | Operation | Privilege | Primary side effect |
| --- | --- | --- | --- |
| Installer | `make install-deps` | Root (`sudo`) | Updates APT metadata and installs optional packages before runtime use |
| Packaging | `make deb`, `make deb-inspect` | User | Creates or inspects `dist/cyberops_<version>_all.deb`; does not install host files |
| Packaging | `apt install ./dist/cyberops_<version>_all.deb` | Root (`sudo`) | Installs or upgrades tracked CYBEROPS files and resolves required dependencies |
| Support | Configuration and operation-log inspection | User | Reads CYBEROPS-owned settings or private structured events |
| Support | Diagnostics export | User | Creates a new mode-`600`, privacy-filtered archive; never overwrites |
| Command channel | `system disk`, `system memory` | User | Read-only local filesystem, memory, and swap telemetry |
| Command channel | `system services`, `system failures` | User | Read-only systemd unit telemetry with paging disabled |
| Command channel | `storage devices` | User | Read-only block-device names, sizes, filesystems, mounts, models, and transport |
| Command channel | `network interfaces`, `network routes`, `network sockets` | User | Read-only local addresses, routes, and listening sockets; does not contact an external service |
| Command channel | `vpn status` | User | Queries local status from installed Tailscale and/or ExpressVPN clients |
| Admin | Update or upgrade packages | `sudo` | Changes package metadata or installed packages |
| Admin | Local filesystem, memory, and service status | User; some details may be restricted | Read-only telemetry; Disk Usage excludes remote mounts |
| Admin | Reboot | `sudo` | Terminates the session and restarts the host |
| Info | Host, CPU, memory, storage, network, route, socket status | User | Read-only local telemetry |
| Info | Public IP lookup | User and network access | Sends a request to `api.ipify.org` |
| VPN | Status | User | Read-only Tailscale or ExpressVPN client telemetry |
| VPN | Connect, disconnect, up, or down | Client-dependent | Changes VPN or overlay-network connectivity |
| VPN | ExpressVPN background mode | User | Allows or prevents the ExpressVPN daemon from remaining active without its GUI; disabling it may disconnect an active VPN |
| Security | UFW status | `sudo` | Read-only firewall telemetry |
| Security | Enable or disable UFW | `sudo` | Changes host firewall state |
| Security | ClamAV home scan | User | Reads files beneath the current home directory |
| Security | `rkhunter` check | `sudo` | Reads system files and may update tool-maintained logs |
| Security | Failed SSH authentication review | `sudo` | Reads authentication logs |
| Quickhacks | Sensors, ping sweep, and Wi-Fi analysis | Tool-dependent | Reads hardware/network state; scans the selected local subnet |
| Quickhacks | Kill process | User or `sudo` depending on owner | Terminates the selected process |
| Quickhacks | Flush DNS cache | `sudo` | Clears local resolver caches |
| Quickhacks | Shred file | Current-user file permissions | Overwrites and removes the selected file; storage behavior may limit guarantees |
| Quickhacks | Show active MAC policies | User | Reads active NetworkManager profile and cloned-MAC settings |
| Quickhacks | Randomize MAC for this session | `sudo` | Temporarily drops a network link and changes its MAC address |
| Quickhacks | Enable automatic MAC randomization | `sudo` | Sets only the selected wired or wireless profile to use a random MAC on activation |
| Quickhacks | Disable automatic MAC randomization | `sudo` | Sets only the selected profile to use its permanent hardware address on activation |
| Quickhacks | Restore permanent MAC now | `sudo` | Briefly disconnects one selected active profile, restores its hardware MAC, and reconnects it |
| Docker | Status | Docker socket access | Read-only container and disk-usage telemetry |
| Docker | Compose maintenance | Docker socket access | Pulls images and recreates selected containers |
| Docker | Image prune | Docker socket access plus separate confirmation | Removes unused images |
| USB | Storage listing | User | Read-only device telemetry |
| USB | ISO write | `sudo` | Unmounts and overwrites the selected removable disk |
| USB | Quick Reset | `sudo` | Unmounts media and removes recognized storage signatures; file contents may remain |
| USB | Full zero-fill | `sudo` | Unmounts and overwrites every addressable byte on the selected disk |

## MAC control boundary

The Quickhacks MAC control panel separates temporary interface changes from
persistent connection policy. Its policy view is read-only and queries active
NetworkManager profiles by UUID. An empty cloned-MAC value is reported as
`default`; connection types without a supported wired or wireless cloned-MAC
setting are reported as `not applicable`. These controls require `nmcli` from
the suggested `network-manager` package. CYBEROPS does not install NetworkManager
automatically because replacing a host's network-management stack can interrupt
connectivity.

The existing session randomizer remains temporary. It uses the same numbered
active-profile selector as immediate restoration, resolves the selected
profile to its current device, drops only that interface, requests a random
address through `macchanger`, and restores the interface's original up/down
state. Manual interface-name entry is not required.

Persistent controls list only saved wired and wireless profiles and select the
target by its stable UUID. Enable sets NetworkManager's cloned-MAC policy to
`random`; disable sets it to `permanent`. Selecting the profile is the action's
authorization point, so there is no redundant second `YES` prompt. CYBEROPS
shows the connection, UUID, device, current policy, and requested policy, then
revalidates the profile immediately before changing it. No other connection is
modified. The new policy applies on the next activation: CYBEROPS does not
disconnect or reconnect the profile automatically. Use the read-only status
view after reconnecting to verify the effective policy.

Immediate restoration lists only active supported profiles. It records the
profile's previous policy, applies `permanent`, deactivates the connection,
explicitly brings its link down, uses `macchanger -p` on the device, reactivates
it, and verifies the current address against the detected permanent address.
If restoration, activation, or verification fails, CYBEROPS restores the
previous profile policy and attempts connection recovery. Registered policy
and reactivation state are also handled by the signal cleanup path. This
operation briefly interrupts networking; do not run it through the connection
being used for a remote administrative session.

## Preview boundary

`DRY_RUN=1` prevents state-changing commands from executing and prints their
shell-escaped form. Discovery, validation, dependency checks, and other
read-only queries still run so previews describe real targets.

## Non-interactive telemetry boundary

Milestone 10 command channels reuse the same read-only helpers as the
interactive menus. They never enable services, change networking, install
packages, scan external hosts, or request a public IP address. Commands preserve
dependency and query failure statuses for scripts. Storage, address, route,
socket, service, and VPN output can still contain locally sensitive system
details; review it before sharing.

## Failure and interruption behavior

- Checked failures include the exit status and a suggested next step.
- Dependent steps stop after a failure.
- `SIGINT` exits with 130 and `SIGTERM` with 143.
- CYBEROPS attempts to restore a network interface it temporarily brought down.
- Interrupted USB and Docker operations report that manual inspection may be required.
- CYBEROPS never remounts written USB media or automatically rolls back Docker updates.

See [Configuration, Logs, and Diagnostics](CONFIGURATION.md) for the exact
support-bundle privacy boundary.

## ExpressVPN control boundary

CYBEROPS prefers the current `expressvpnctl` client and retains the retired
`expressvpn` executable only as a v2 compatibility fallback for status,
connection, and disconnection. A normal connection uses the region already
selected in ExpressVPN. The GUI must be running unless background mode has been
enabled.

The background-mode menu entries call `expressvpnctl background enable` and
`expressvpnctl background disable`. Enabling it allows the daemon and VPN link
to remain active without the GUI and is required for command-line autoconnect.
Disabling it may disconnect the VPN and deactivate Split Tunnel when the GUI is
not running. These controls do not change Network Lock, protocol, selected
region, advanced protection, or account state.
