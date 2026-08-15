# Operation Privileges and Side Effects

CYBEROPS does not run the entire process as root. Individual operations request
`sudo` only when required. Read the confirmation and command preview before
approving any state change.

| Area | Operation | Privilege | Primary side effect |
| --- | --- | --- | --- |
| Setup | Install optional dependencies | `sudo` | Updates APT metadata and installs packages |
| Admin | Update or upgrade packages | `sudo` | Changes package metadata or installed packages |
| Admin | Filesystem, memory, and service status | User; some details may be restricted | Read-only telemetry |
| Admin | Reboot | `sudo` | Terminates the session and restarts the host |
| Info | Host, CPU, memory, storage, network, route, socket status | User | Read-only local telemetry |
| Info | Public IP lookup | User and network access | Sends a request to `api.ipify.org` |
| VPN | Status | User | Read-only client telemetry |
| VPN | Connect, disconnect, up, or down | Client-dependent | Changes VPN or overlay-network connectivity |
| Security | UFW status | `sudo` | Read-only firewall telemetry |
| Security | Enable or disable UFW | `sudo` | Changes host firewall state |
| Security | ClamAV home scan | User | Reads files beneath the current home directory |
| Security | `rkhunter` check | `sudo` | Reads system files and may update tool-maintained logs |
| Security | Failed SSH authentication review | `sudo` | Reads authentication logs |
| Quickhacks | Sensors, ping sweep, and Wi-Fi analysis | Tool-dependent | Reads hardware/network state; scans the selected local subnet |
| Quickhacks | Kill process | User or `sudo` depending on owner | Terminates the selected process |
| Quickhacks | Flush DNS cache | `sudo` | Clears local resolver caches |
| Quickhacks | Shred file | File permissions; may request `sudo` | Overwrites and removes the selected file; storage behavior may limit guarantees |
| Quickhacks | Randomize MAC address | `sudo` | Temporarily drops a network link and changes its MAC address |
| Docker | Status | Docker socket access | Read-only container and disk-usage telemetry |
| Docker | Compose maintenance | Docker socket access | Pulls images and recreates selected containers |
| Docker | Image prune | Docker socket access plus separate confirmation | Removes unused images |
| USB | Storage listing | User | Read-only device telemetry |
| USB | ISO write | `sudo` | Unmounts and overwrites the selected removable disk |
| USB | Quick Reset | `sudo` | Unmounts media and removes recognized storage signatures; file contents may remain |
| USB | Full zero-fill | `sudo` | Unmounts and overwrites every addressable byte on the selected disk |

## Preview boundary

`DRY_RUN=1` prevents state-changing commands from executing and prints their
shell-escaped form. Discovery, validation, dependency checks, and other
read-only queries still run so previews describe real targets.

## Failure and interruption behavior

- Checked failures include the exit status and a suggested next step.
- Dependent steps stop after a failure.
- `SIGINT` exits with 130 and `SIGTERM` with 143.
- CYBEROPS attempts to restore a network interface it temporarily brought down.
- Interrupted USB and Docker operations report that manual inspection may be required.
- CYBEROPS never remounts written USB media or automatically rolls back Docker updates.
