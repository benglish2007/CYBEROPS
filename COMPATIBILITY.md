# CYBEROPS Compatibility

CYBEROPS targets actively maintained Ubuntu and Debian releases with Bash 5
and GNU userland tools. The automated compatibility matrix covers:

| Distribution | Release | Support status |
| --- | --- | --- |
| Ubuntu | 22.04 LTS | Supported |
| Ubuntu | 24.04 LTS | Supported |
| Ubuntu | 26.04 LTS | Supported |
| Debian | 12 | Supported while covered by Debian LTS |
| Debian | 13 | Supported |

The release selections follow the official [Ubuntu release
list](https://ubuntu.com/project/docs/release-team/list-of-releases/) and
[Debian release information](https://www.debian.org/releases/).

## Required Runtime Capabilities

The core script requires:

- Bash 5 or newer
- GNU Coreutils or uutils with a `dd` exact-byte mode (`count=<bytes>B` or
  `iflag=count_bytes`), plus `sort -z`
- GNU Findutils with `find -print0`
- util-linux with `lsblk`, `findmnt`, and the `lsblk` `MOUNTPOINTS` column
- GNU `grep`, `sed`, and `awk`
- `readlink -f` canonical-path support
- APT and systemd for the package-management and service-management modules

Individual operations check their own command dependencies before starting.
Optional features require their corresponding tools, such as Docker Compose,
Tailscale, ExpressVPN, UFW, ClamAV, `rkhunter`, `nmap`, `wavemon`, or
`macchanger`.

## Automated Coverage

GitHub Actions runs Bash syntax validation and the complete shell regression
suite inside each supported distribution image. The compatibility test also
exercises the specific Bash and GNU command capabilities used by CYBEROPS.

The matrix verifies that the script can be parsed, sourced, and tested on the
supported base systems. It does not claim that every optional integration is
installed in each container image.

## Integration and Hardware Coverage

Container-based CI cannot safely or meaningfully exercise every host-level
operation. The following still require targeted testing on an appropriate
system:

- A live Docker daemon and real Compose stacks
- Host systemd services, firewall rules, VPN clients, and network interfaces
- APT upgrades and reboot behavior
- Physical removable-media discovery, unmounting, image writing, and zero-fill
- Hardware-specific commands such as sensors and Wi-Fi monitoring

Destructive removable-media tests must use disposable hardware and must never
target important data. Milestone 1 records the completed physical safety tests
in [ROADMAP.md](ROADMAP.md).

## Other Linux Distributions

CYBEROPS may partially work elsewhere, but non-Debian package managers,
non-systemd service managers, BusyBox userlands, and macOS are outside the
supported baseline. Contributions that extend portability should include a CI
environment and regression coverage for the new platform.
