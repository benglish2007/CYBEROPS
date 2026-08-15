#!/usr/bin/env bash

# Security operations contract
# ----------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Firewall, malware, rootkit, authentication, and integrity results.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   May change UFW state only after existing confirmations.
#   Loading this module itself produces no output and performs no mutation.

# ------------------------------------------------------------------------------
# Cyber Defense
# ------------------------------------------------------------------------------

cyber_defense_menu() {
    local choice=""
    local failed_logins
    local journal_output
    local journal_status
    local scan_status

    while true; do
        banner
        ui_section "CYBER DEFENSE" "DEFENSIVE GRID // FIREWALL + THREAT SCANS"
        menu_privileged_item 1 "UFW status" "FIREWALL // STATUS"
        menu_privileged_item 2 "Enable UFW" "FIREWALL // ENABLE"
        menu_privileged_item 3 "Disable UFW" "FIREWALL // DISABLE"
        menu_item 4 "ClamAV scan home directory" "MALWARE // SCAN"
        menu_privileged_item 5 "rkhunter check" "ROOTKIT // SCAN"
        menu_privileged_item 6 "Recent failed SSH logins" "AUTH // EVENTS"
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

        prompt_choice choice "DEFENSE"

        case "$choice" in
            1)
                if require_commands sudo ufw; then
                    run_checked "UFW status query" "Verify UFW is installed and sudo access is available." sudo ufw status verbose
                fi
                pause
                ;;
            2)
                if require_commands sudo ufw; then
                    run_mutating_checked "UFW enable" "Review UFW rules and sudo authorization before retrying." sudo ufw enable
                fi
                pause
                ;;
            3)
                report_warning "Disabling the firewall can expose services to the network."
                if require_commands sudo ufw && confirm_yes "Type YES to disable UFW: "; then
                    run_mutating_checked "UFW disable" "Check sudo authorization and UFW service state." sudo ufw disable
                fi
                pause
                ;;
            4)
                if require_commands clamscan; then
                    clamscan -r -i "$HOME"
                    scan_status=$?
                    case "$scan_status" in
                        0) report_success "ClamAV scan completed with no infected files found." ;;
                        1) report_warning "ClamAV found one or more infected files; review the scan output before taking action." ;;
                        *) report_error \
                            "ClamAV scan failed (exit status $scan_status)." \
                            "Update signatures, verify file access, and retry." ;;
                    esac
                fi
                pause
                ;;
            5)
                if require_commands sudo rkhunter; then
                    run_mutating_checked \
                        "rkhunter check" \
                        "Review the rkhunter log and update its data files before retrying." \
                        sudo rkhunter --check
                fi
                pause
                ;;
            6)
                if require_commands sudo journalctl grep tail; then
                    if journal_output="$(sudo journalctl -u ssh -u sshd --since "7 days ago" --no-pager 2>/dev/null)"; then
                        failed_logins="$(
                            printf '%s\n' "$journal_output" |
                                grep -Ei 'failed password|authentication failure|invalid user' |
                                tail -n 100 || true
                        )"
                        if [[ -n "$failed_logins" ]]; then
                            printf '%s\n' "$failed_logins"
                        else
                            report_success "No failed SSH authentication entries found in the last 7 days."
                        fi
                    else
                        journal_status=$?
                        report_error \
                            "SSH journal query failed (exit status $journal_status)." \
                            "Verify journal access and the ssh/sshd service names."
                    fi
                fi
                pause
                ;;
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
