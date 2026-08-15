# Debian Package Build and Validation

CYBEROPS can be built as an architecture-independent Debian binary package.
The package reuses the supported `make install` staging layout, so the Makefile
and `.deb` do not maintain separate copies of the runtime contract.

## Build without installing

From a clean repository checkout:

```bash
make deb
```

The resulting file is written to `dist/cyberops_<version>_all.deb`. Building
does not require root access and does not install or remove host files.

Inspect the package metadata and complete file manifest with:

```bash
make deb-inspect
```

## Install, upgrade, and remove

Install the locally built package through APT so required dependencies are
resolved:

```bash
sudo apt install ./dist/cyberops_<version>_all.deb
```

Installing a newer package upgrades the existing package in place; a prior
uninstall is not required. Remove the packaged application with:

```bash
sudo apt remove cyberops
```

User configuration and operation logs live beneath the user's XDG config and
state directories. Package removal does not delete that user-owned data.

## Coexistence boundary

Do not combine a `/usr` Makefile installation with the Debian package because
the package manager cannot track files installed directly by Make. The default
Makefile prefix remains `/usr/local`, so its files do not overwrite packaged
`/usr` files. However, `/usr/local/bin/cyberops` normally appears earlier in
`PATH` and can shadow `/usr/bin/cyberops`. Run `sudo make uninstall` once when
migrating from the default source installation to the package; user settings
and logs are not removed.

The package declares the non-optional command baseline as dependencies.
Feature-specific tools such as ClamAV, `nmap`, `macchanger`, and `wavemon` are
suggestions because CYBEROPS checks them only when their operation is used.
Docker and vendor VPN clients remain separate integrations.

## Manual validation checklist

Use a disposable Ubuntu or Debian virtual machine:

1. Run `make deb` and `make deb-inspect` as an unprivileged user.
2. If migrating from `sudo make install`, run `sudo make uninstall` once.
3. Install with `sudo apt install ./dist/cyberops_<version>_all.deb` and run
   `hash -r` in any terminal that previously resolved `cyberops`.
4. Confirm `command -v cyberops` prints `/usr/bin/cyberops`, then run
   `cyberops --version`, `cyberops --help`, and open the application menu.
5. Confirm the desktop launcher uses the CYBEROPS icon.
6. Reinstall the rebuilt package with `sudo apt install --reinstall
   ./dist/cyberops_<version>_all.deb` and confirm settings and logs remain.
7. Run `sudo apt remove cyberops`; confirm the command and desktop launcher are
   removed while user-owned configuration and logs remain untouched.
