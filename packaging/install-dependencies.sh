#!/usr/bin/env bash

set -o pipefail

dependency_setup_has_root() {
    ((EUID == 0))
}

dependency_setup_main() {
    local -a packages=(
        clamav
        curl
        figlet
        htop
        lm-sensors
        lolcat
        macchanger
        nmap
        rkhunter
        wavemon
    )

    if ! dependency_setup_has_root; then
        printf 'CYBEROPS dependency setup requires root privileges.\n' >&2
        printf "Run 'sudo make install-deps' from the repository.\n" >&2
        return 1
    fi

    command -v apt-get >/dev/null 2>&1 || {
        printf 'CYBEROPS automatic dependency setup requires apt-get.\n' >&2
        return 1
    }

    printf 'Updating APT package metadata...\n'
    apt-get update || return 1
    printf 'Installing optional CYBEROPS dependencies...\n'
    apt-get install --yes "${packages[@]}" || return 1
    printf 'CYBEROPS optional dependency setup complete.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    dependency_setup_main
fi
