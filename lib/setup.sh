#!/usr/bin/env bash

# System setup contract
# ---------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Dependency availability and installation results.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   May install packages through the dry-run-aware confirmed setup path.
#   Loading this module itself produces no output and performs no mutation.

# ------------------------------------------------------------------------------
# System Setup
# ------------------------------------------------------------------------------

system_setup() {
    banner
    ui_section "SYSTEM SETUP" "BOOTSTRAP // OPTIONAL DEPENDENCIES"
    echo "This installs optional CYBEROPS utilities using APT."
    echo "Core commands used by Docker/USB operations are provided by Ubuntu packages."
    echo

    if ! require_commands sudo apt; then
        echo "Automatic setup currently targets Ubuntu/Debian."
        pause
        return
    fi

    if ! confirm_yes "Type YES to install/update CYBEROPS dependencies: "; then
        echo "Setup cancelled."
        pause
        return
    fi

    if ! run_mutating_checked \
        "Dependency package-list update" \
        "Check network connectivity and APT repository configuration, then retry." \
        sudo apt update; then
        pause
        return
    fi

    local -a packages=(
        figlet
        lolcat
        htop
        nmap
        wavemon
        macchanger
        lm-sensors
        clamav
        rkhunter
        curl
    )

    if run_mutating_checked \
        "CYBEROPS dependency installation" \
        "Review unavailable or conflicting packages in the APT output, then retry." \
        sudo apt install -y "${packages[@]}"; then
        if ! is_dry_run; then
            echo
            report_success "CYBEROPS dependency setup complete."
        fi
    fi
    pause
}
