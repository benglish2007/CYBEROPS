#!/usr/bin/env bash

# MAC address controls contract
# -----------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Active NetworkManager connection policies and MAC-operation results.
# Return statuses:
#   Read-only queries preserve failures; menus contain operation failures.
# Side effects:
#   May temporarily change an interface MAC behind existing safety controls.
#   Loading this module itself produces no output and performs no mutation.

MAC_CONNECTION_UUID=""
MAC_CONNECTION_NAME=""
MAC_CONNECTION_TYPE=""
MAC_CONNECTION_DEVICE=""
MAC_CONNECTION_PROPERTY=""
MAC_CONNECTION_POLICY=""
MAC_CONNECTION_POLICY_RAW=""
SELECTED_MAC_CONNECTION_UUID=""

mac_policy_property_for_type() {
    case "$1" in
        802-11-wireless | wifi) printf '802-11-wireless.cloned-mac-address' ;;
        802-3-ethernet | ethernet) printf '802-3-ethernet.cloned-mac-address' ;;
        *) return 1 ;;
    esac
}

load_mac_connection() {
    local connection_uuid="$1"

    MAC_CONNECTION_UUID=""
    MAC_CONNECTION_NAME=""
    MAC_CONNECTION_TYPE=""
    MAC_CONNECTION_DEVICE=""
    MAC_CONNECTION_PROPERTY=""
    MAC_CONNECTION_POLICY=""
    MAC_CONNECTION_POLICY_RAW=""

    [[ -n "$connection_uuid" ]] || return 1
    MAC_CONNECTION_NAME="$(nmcli -g connection.id connection show "$connection_uuid" 2>/dev/null)" || return 1
    MAC_CONNECTION_TYPE="$(nmcli -g connection.type connection show "$connection_uuid" 2>/dev/null)" || return 1
    MAC_CONNECTION_PROPERTY="$(mac_policy_property_for_type "$MAC_CONNECTION_TYPE" 2>/dev/null)" || return 1
    MAC_CONNECTION_DEVICE="$(nmcli -g GENERAL.DEVICES connection show "$connection_uuid" 2>/dev/null || true)"
    MAC_CONNECTION_POLICY_RAW="$(nmcli -g "$MAC_CONNECTION_PROPERTY" connection show "$connection_uuid" 2>/dev/null)" || return 1

    [[ -n "$MAC_CONNECTION_DEVICE" && "$MAC_CONNECTION_DEVICE" != "--" ]] || MAC_CONNECTION_DEVICE="inactive"
    MAC_CONNECTION_POLICY="${MAC_CONNECTION_POLICY_RAW:-default}"
    MAC_CONNECTION_UUID="$connection_uuid"
}

select_mac_connection() {
    local require_active="${1:-0}"
    local connection_uuid_output
    local connection_uuid
    local choice
    local selected_index
    local -a connection_uuids=()
    local -a supported_uuids=()
    local -a supported_names=()
    local -a supported_types=()
    local -a supported_devices=()
    local -a supported_policies=()

    SELECTED_MAC_CONNECTION_UUID=""
    require_commands nmcli || return 1

    if ! connection_uuid_output="$(nmcli -g UUID connection show 2>/dev/null)"; then
        report_error \
            "Unable to query saved NetworkManager connections." \
            "Verify NetworkManager is running and retry with 'nmcli connection show'."
        return 1
    fi

    [[ -n "$connection_uuid_output" ]] || {
        report_warning "No saved NetworkManager connections were found."
        return 1
    }
    mapfile -t connection_uuids <<<"$connection_uuid_output"

    for connection_uuid in "${connection_uuids[@]}"; do
        [[ -n "$connection_uuid" ]] || continue
        if load_mac_connection "$connection_uuid"; then
            if [[ "$require_active" == "1" && "$MAC_CONNECTION_DEVICE" == "inactive" ]]; then
                continue
            fi
            supported_uuids+=("$MAC_CONNECTION_UUID")
            supported_names+=("$MAC_CONNECTION_NAME")
            supported_types+=("$MAC_CONNECTION_TYPE")
            supported_devices+=("$MAC_CONNECTION_DEVICE")
            supported_policies+=("$MAC_CONNECTION_POLICY")
        fi
    done

    if ((${#supported_uuids[@]} == 0)); then
        report_warning "No supported wired or wireless NetworkManager profiles were found."
        return 1
    fi

    if [[ "$require_active" == "1" ]]; then
        printf '\nSupported active NetworkManager profiles:\n\n'
    else
        printf '\nSupported NetworkManager profiles:\n\n'
    fi
    for ((selected_index = 0; selected_index < ${#supported_uuids[@]}; selected_index++)); do
        printf '%d. %s  device=%s  type=%s  policy=%s\n' \
            "$((selected_index + 1))" \
            "${supported_names[selected_index]}" \
            "${supported_devices[selected_index]}" \
            "${supported_types[selected_index]}" \
            "${supported_policies[selected_index]}"
        printf '   UUID: %s\n' "${supported_uuids[selected_index]}"
    done

    printf '\n'
    read -r -p "Select connection number: " choice || return 1
    if ! integer_in_range "$choice" 1 "${#supported_uuids[@]}"; then
        report_warning "Invalid connection selection."
        return 1
    fi

    selected_index=$((10#$choice - 1))
    SELECTED_MAC_CONNECTION_UUID="${supported_uuids[selected_index]}"
    load_mac_connection "$SELECTED_MAC_CONNECTION_UUID"
}

set_mac_connection_policy() {
    local connection_uuid="$1"
    local requested_policy="$2"
    local action

    require_commands sudo nmcli || return 1
    [[ "$requested_policy" == "random" || "$requested_policy" == "permanent" ]] || {
        report_error "Unsupported MAC policy request: $requested_policy"
        return 1
    }

    if ! load_mac_connection "$connection_uuid"; then
        report_error \
            "The selected connection is unavailable or does not support MAC policy changes." \
            "Select a saved wired or wireless NetworkManager profile and retry."
        return 1
    fi

    if [[ "$MAC_CONNECTION_POLICY" == "$requested_policy" ]]; then
        report_warning "Connection '$MAC_CONNECTION_NAME' already uses the '$requested_policy' MAC policy."
        return 0
    fi

    printf 'CONNECTION: %s\n' "$MAC_CONNECTION_NAME"
    printf 'UUID:       %s\n' "$MAC_CONNECTION_UUID"
    printf 'DEVICE:     %s\n' "$MAC_CONNECTION_DEVICE"
    printf 'CHANGE:     %s -> %s\n' "$MAC_CONNECTION_POLICY" "$requested_policy"
    printf 'EFFECT:     Applies the next time this connection activates.\n\n'

    # Re-read the UUID and connection type immediately before mutation so a
    # stale or replaced profile cannot inherit the selected change.
    if ! load_mac_connection "$connection_uuid"; then
        report_error \
            "The selected connection changed or disappeared before modification." \
            "Review saved profiles with 'nmcli connection show' and retry."
        return 1
    fi

    action="Set MAC policy '$requested_policy' for $MAC_CONNECTION_NAME"
    if ! run_mutating_checked \
        "$action" \
        "Inspect the profile with 'nmcli connection show $MAC_CONNECTION_UUID'." \
        sudo nmcli connection modify "$MAC_CONNECTION_UUID" \
        "$MAC_CONNECTION_PROPERTY" "$requested_policy"; then
        return 1
    fi

    if ! is_dry_run; then
        report_success "MAC policy set to '$requested_policy' for '$MAC_CONNECTION_NAME'."
        report_warning "Reconnect this profile when ready for the new policy to take effect."
    fi
}

configure_selected_mac_policy() {
    local requested_policy="$1"

    select_mac_connection || return 1
    set_mac_connection_policy "$SELECTED_MAC_CONNECTION_UUID" "$requested_policy"
}

restore_permanent_mac_now() {
    local connection_uuid="$1"
    local previous_policy
    local current_mac
    local permanent_mac

    require_commands sudo nmcli ip macchanger || return 1
    if ! load_mac_connection "$connection_uuid" || [[ "$MAC_CONNECTION_DEVICE" == "inactive" ]]; then
        report_error \
            "Permanent MAC restoration requires an active wired or wireless profile." \
            "Activate the intended NetworkManager profile and retry."
        return 1
    fi

    previous_policy="$MAC_CONNECTION_POLICY_RAW"
    current_mac="$(telemetry_current_mac "$MAC_CONNECTION_DEVICE" 2>/dev/null || true)"
    permanent_mac="$(telemetry_permanent_mac "$MAC_CONNECTION_DEVICE" 2>/dev/null || true)"
    if [[ -z "$current_mac" || -z "$permanent_mac" ]]; then
        report_error \
            "Unable to verify current and permanent MAC addresses for $MAC_CONNECTION_DEVICE." \
            "Inspect the device with 'ip -d link show $MAC_CONNECTION_DEVICE' and 'ethtool -P $MAC_CONNECTION_DEVICE'."
        return 1
    fi

    if [[ "$current_mac" == "$permanent_mac" && "$MAC_CONNECTION_POLICY" == "permanent" ]]; then
        report_warning "Connection '$MAC_CONNECTION_NAME' already uses its permanent MAC address and policy."
        return 0
    fi

    printf 'CONNECTION:    %s\n' "$MAC_CONNECTION_NAME"
    printf 'UUID:          %s\n' "$MAC_CONNECTION_UUID"
    printf 'DEVICE:        %s\n' "$MAC_CONNECTION_DEVICE"
    printf 'CURRENT MAC:   %s\n' "$current_mac"
    printf 'PERMANENT MAC: %s\n' "$permanent_mac"
    printf 'POLICY:        %s -> permanent\n' "$MAC_CONNECTION_POLICY"
    printf 'EFFECT:        Briefly disconnects and reactivates this profile.\n\n'

    if is_dry_run; then
        preview_command "Set permanent MAC policy for $MAC_CONNECTION_NAME" \
            sudo nmcli connection modify "$MAC_CONNECTION_UUID" \
            "$MAC_CONNECTION_PROPERTY" permanent
        preview_command "Deactivate $MAC_CONNECTION_NAME" \
            sudo nmcli connection down "$MAC_CONNECTION_UUID"
        preview_command "Bring $MAC_CONNECTION_DEVICE down for hardware restoration" \
            sudo ip link set dev "$MAC_CONNECTION_DEVICE" down
        preview_command "Restore permanent MAC on $MAC_CONNECTION_DEVICE" \
            sudo macchanger -p "$MAC_CONNECTION_DEVICE"
        preview_command "Reactivate $MAC_CONNECTION_NAME" \
            sudo nmcli connection up "$MAC_CONNECTION_UUID"
        return 0
    fi

    begin_operation \
        "Permanent MAC restoration for $MAC_CONNECTION_NAME" \
        "The selected connection may need manual reactivation."
    register_connection_restore \
        "$MAC_CONNECTION_UUID" "$MAC_CONNECTION_PROPERTY" "$previous_policy"

    if ! run_checked \
        "Set permanent MAC policy for $MAC_CONNECTION_NAME" \
        "Inspect the selected profile and restore its previous policy if needed." \
        sudo nmcli connection modify "$MAC_CONNECTION_UUID" \
        "$MAC_CONNECTION_PROPERTY" permanent; then
        perform_connection_cleanup || true
        end_operation
        return 1
    fi

    if ! run_checked \
        "Deactivate $MAC_CONNECTION_NAME" \
        "Reconnect the profile manually if it is no longer active." \
        sudo nmcli connection down "$MAC_CONNECTION_UUID"; then
        perform_connection_cleanup || true
        end_operation
        return 1
    fi
    mark_connection_for_reactivation

    if ! run_checked \
        "Bring $MAC_CONNECTION_DEVICE down for hardware restoration" \
        "Reactivate the selected connection manually if recovery does not succeed." \
        sudo ip link set dev "$MAC_CONNECTION_DEVICE" down; then
        perform_connection_cleanup || true
        end_operation
        return 1
    fi

    if ! run_checked \
        "Restore permanent MAC on $MAC_CONNECTION_DEVICE" \
        "Verify driver support and reactivate the connection manually." \
        sudo macchanger -p "$MAC_CONNECTION_DEVICE"; then
        perform_connection_cleanup || true
        end_operation
        return 1
    fi

    if ! run_checked \
        "Reactivate $MAC_CONNECTION_NAME" \
        "Run manually: sudo nmcli connection up $MAC_CONNECTION_UUID" \
        sudo nmcli connection up "$MAC_CONNECTION_UUID"; then
        perform_connection_cleanup || true
        end_operation
        return 1
    fi

    current_mac="$(telemetry_current_mac "$MAC_CONNECTION_DEVICE" 2>/dev/null || true)"
    if [[ "$current_mac" != "$permanent_mac" ]]; then
        report_error \
            "The reactivated interface did not report its permanent MAC address." \
            "Inspect the connection and device state before retrying."
        perform_connection_cleanup || true
        end_operation
        return 1
    fi

    clear_connection_restore
    end_operation
    report_success "Permanent MAC restored for '$MAC_CONNECTION_NAME'."
}

restore_selected_permanent_mac() {
    select_mac_connection 1 || return 1
    restore_permanent_mac_now "$SELECTED_MAC_CONNECTION_UUID"
}

show_mac_address_policies() {
    local connection_uuid
    local connection_name
    local connection_type
    local connection_device
    local policy_property
    local policy
    local connection_uuid_output
    local -a connection_uuids=()

    require_commands nmcli || return 1

    if ! connection_uuid_output="$(nmcli -g UUID connection show --active 2>/dev/null)"; then
        report_error \
            "Unable to query active NetworkManager connections." \
            "Verify NetworkManager is running and retry with 'nmcli connection show --active'."
        return 1
    fi

    if [[ -z "$connection_uuid_output" ]]; then
        report_warning "No active NetworkManager connections were found."
        return 0
    fi
    mapfile -t connection_uuids <<<"$connection_uuid_output"

    printf '%-20s %-16s %-18s %s\n' "CONNECTION" "DEVICE" "TYPE" "MAC POLICY"
    for connection_uuid in "${connection_uuids[@]}"; do
        [[ -n "$connection_uuid" ]] || continue
        connection_name="$(nmcli -g connection.id connection show "$connection_uuid" 2>/dev/null || printf 'UNKNOWN')"
        connection_type="$(nmcli -g connection.type connection show "$connection_uuid" 2>/dev/null || printf 'UNKNOWN')"
        connection_device="$(nmcli -g GENERAL.DEVICES connection show "$connection_uuid" 2>/dev/null || printf 'UNAVAILABLE')"

        if policy_property="$(mac_policy_property_for_type "$connection_type" 2>/dev/null)"; then
            policy="$(nmcli -g "$policy_property" connection show "$connection_uuid" 2>/dev/null || true)"
            [[ -n "$policy" ]] || policy="default"
        else
            policy="not applicable"
        fi

        printf '%-20s %-16s %-18s %s\n' \
            "$connection_name" "$connection_device" "$connection_type" "$policy"
    done
}

randomize_mac_address() {
    local iface="$1"
    local was_up=0
    local result=0

    require_commands sudo ip macchanger grep head || return 1

    if ! ip link show dev "$iface" >/dev/null 2>&1; then
        report_error \
            "Network interface not found: $iface" \
            "List interfaces with 'ip -brief link' and retry with an exact name."
        return 1
    fi

    if ip link show dev "$iface" | head -n 1 | grep -qE '<[^>]*\bUP\b[^>]*>'; then
        was_up=1
    fi

    if is_dry_run; then
        preview_command "Bring $iface down" sudo ip link set dev "$iface" down
        preview_command "Randomize the MAC address for $iface" sudo macchanger -r "$iface"
        if ((was_up == 1)); then
            preview_command "Restore $iface to its original up state" sudo ip link set dev "$iface" up
        fi
        return 0
    fi

    begin_operation \
        "MAC randomization on $iface" \
        "The interface state may need manual verification."
    register_network_restore "$iface" "$was_up"

    if ! sudo ip link set dev "$iface" down; then
        report_error \
            "Unable to bring $iface down." \
            "Check sudo authorization and whether another service manages the interface."
        result=1
    elif ! sudo macchanger -r "$iface"; then
        report_error \
            "MAC randomization failed for $iface." \
            "Verify the driver supports address changes and retry while disconnected."
        result=1
    fi

    if ! perform_registered_cleanup; then
        result=1
    fi

    end_operation
    return "$result"
}

randomize_selected_mac_for_session() {
    select_mac_connection 1 || return 1
    randomize_mac_address "$MAC_CONNECTION_DEVICE"
}

mac_address_menu() {
    local choice=""

    while true; do
        banner
        ui_section "MAC CONTROLS" "IDENTITY // CONNECTION POLICY"
        menu_item 1 "Show active MAC policies" "NETWORKMANAGER // READ-ONLY"
        menu_privileged_item 2 "Randomize MAC for this session" "IDENTITY // TEMPORARY"
        menu_privileged_item 3 "Enable automatic MAC randomization" "PROFILE // EVERY CONNECT"
        menu_privileged_item 4 "Disable automatic MAC randomization" "PROFILE // PERMANENT"
        menu_privileged_item 5 "Restore permanent MAC now" "IDENTITY // RECONNECT"
        menu_navigation_item 0 "Return to Quickhacks" "NAV // BACK"

        prompt_choice choice "MAC"

        case "$choice" in
            1)
                show_mac_address_policies
                pause
                ;;
            2)
                randomize_selected_mac_for_session
                pause
                ;;
            3)
                configure_selected_mac_policy random
                pause
                ;;
            4)
                configure_selected_mac_policy permanent
                pause
                ;;
            5)
                restore_selected_permanent_mac
                pause
                ;;
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
