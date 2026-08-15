#!/usr/bin/env bash

# USB safety and operations contract
# ----------------------------------
# Inputs:
#   Runtime state plus shared core and UI helpers loaded by cyberops.sh.
# Outputs:
#   Device discovery, identity, mount, imaging, quick-reset, and zero-fill results.
# Return statuses:
#   Menu functions contain operation failures and return control to their caller.
# Side effects:
#   May unmount or overwrite removable media only after identity validation and confirmations.
#   Loading this module itself produces no output and performs no mutation.

system_disk() {
    local root_source
    local parent

    root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    [[ -n "$root_source" ]] || return 1

    # Resolve mapper/LVM devices to the underlying physical disk when possible.
    parent="$(lsblk -no PKNAME "$root_source" 2>/dev/null | head -n1 || true)"

    if [[ -n "$parent" ]]; then
        # Walk upward until there is no parent.
        while true; do
            local next
            next="$(lsblk -no PKNAME "/dev/$parent" 2>/dev/null | head -n1 || true)"
            [[ -n "$next" ]] || break
            parent="$next"
        done
        printf '/dev/%s\n' "$parent"
        return 0
    fi

    if [[ "$root_source" == /dev/* ]]; then
        printf '%s\n' "$root_source"
        return 0
    fi

    return 1
}

resolve_device_path() {
    readlink -f -- "$1" 2>/dev/null
}

is_block_device() {
    [[ -b "$1" ]]
}

block_property() {
    local device="$1"
    local property="$2"

    lsblk -dn -o "$property" -- "$device" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

block_size_bytes() {
    lsblk -bdn -o SIZE -- "$1" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

device_mountpoints() {
    lsblk -nr -o MOUNTPOINTS -- "$1" 2>/dev/null | sed '/^[[:space:]]*$/d'
}

usb_device_identity() {
    local device
    local type
    local transport
    local removable
    local size
    local model
    local serial
    local wwn

    device="$(resolve_device_path "$1")" || return 1
    [[ "$device" == /dev/* ]] || return 1
    is_block_device "$device" || return 1

    type="$(block_property "$device" TYPE)"
    transport="$(block_property "$device" TRAN)"
    removable="$(block_property "$device" RM)"
    size="$(block_size_bytes "$device")"
    model="$(block_property "$device" MODEL)"
    serial="$(block_property "$device" SERIAL)"
    wwn="$(block_property "$device" WWN)"

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$device" "$type" "$transport" "$removable" "$size" "$model" "$serial" "$wwn"
}

is_removable_usb_disk() {
    local device="$1"
    local type
    local transport
    local removable

    type="$(block_property "$device" TYPE)"
    transport="$(block_property "$device" TRAN)"
    removable="$(block_property "$device" RM)"

    [[ "$type" == "disk" ]] && [[ "$transport" == "usb" || "$removable" == "1" ]]
}

protected_system_disks() {
    local mountpoint
    local source

    for mountpoint in / /boot /boot/efi; do
        source="$(findmnt -n -o SOURCE --target "$mountpoint" 2>/dev/null || true)"
        source="${source%%\[*}"
        [[ "$source" == /dev/* ]] || continue

        lsblk -slnp -o NAME,TYPE -- "$source" 2>/dev/null |
            awk '$2 == "disk" { print $1 }'
    done | sort -u
}

system_disk_protection_ready() {
    local root_source
    local root_disks

    root_source="$(findmnt -n -o SOURCE --target / 2>/dev/null)" || return 1
    root_source="${root_source%%\[*}"
    [[ "$root_source" == /dev/* ]] || return 1

    root_disks="$(lsblk -slnp -o NAME,TYPE -- "$root_source" 2>/dev/null |
        awk '$2 == "disk" { print $1 }')"
    [[ -n "$root_disks" ]]
}

is_protected_system_disk() {
    local target="$1"
    local protected

    while read -r protected; do
        [[ -n "$protected" ]] || continue
        protected="$(resolve_device_path "$protected")" || continue
        [[ "$target" == "$protected" ]] && return 0
    done < <(protected_system_disks)

    return 1
}

validate_usb_target() {
    local target="$1"
    local expected_identity="$2"
    local require_unmounted="${3:-0}"
    local resolved
    local current_identity
    local mounts

    resolved="$(resolve_device_path "$target")" || {
        report_error \
            "REFUSING: target device is unavailable." \
            "Reconnect the device and select it again."
        return 1
    }

    if [[ "$resolved" != /dev/* ]] || ! is_block_device "$resolved"; then
        report_error \
            "REFUSING: target is not a block device under /dev." \
            "Select a whole removable disk reported by the USB menu."
        return 1
    fi

    if ! is_removable_usb_disk "$resolved"; then
        report_error \
            "REFUSING: target is not a whole removable/USB disk." \
            "Select a removable disk, not an internal disk or partition."
        return 1
    fi

    if ! system_disk_protection_ready; then
        report_error \
            "REFUSING: unable to resolve the disks backing the running system." \
            "Verify findmnt and lsblk can resolve the root filesystem before retrying."
        return 1
    fi

    if is_protected_system_disk "$resolved"; then
        report_error \
            "REFUSING: target backs /, /boot, or /boot/efi." \
            "Choose a different removable disk."
        return 1
    fi

    current_identity="$(usb_device_identity "$resolved")" || {
        report_error \
            "REFUSING: unable to read the target device identity." \
            "Reconnect the device and select it again."
        return 1
    }

    if [[ "$current_identity" != "$expected_identity" ]]; then
        report_error \
            "REFUSING: target device identity changed after selection." \
            "Return to device selection and verify the intended target."
        return 1
    fi

    if [[ "$require_unmounted" == "1" ]]; then
        mounts="$(device_mountpoints "$resolved")"
        if [[ -n "$mounts" ]]; then
            report_error \
                "REFUSING: target still has mounted filesystems." \
                "Close applications using the paths below, unmount them, and retry."
            printf '%s\n' "$mounts"
            return 1
        fi
    fi

    return 0
}

# ------------------------------------------------------------------------------
# USB Operations
# ------------------------------------------------------------------------------

list_usb_candidates() {
    local device
    local type

    while read -r device; do
        [[ -n "$device" ]] || continue
        device="$(resolve_device_path "$device")" || continue
        type="$(block_property "$device" TYPE)"

        [[ "$type" == "disk" ]] || continue
        is_removable_usb_disk "$device" || continue
        is_protected_system_disk "$device" && continue

        printf '%s\n' "$device"
    done < <(lsblk -dn -o PATH 2>/dev/null)
}

select_usb_device() {
    local -a candidates=()
    local dev
    local i
    local size
    local model
    local transport
    local mounts
    local selection

    SELECTED_USB_DEVICE=""
    SELECTED_USB_IDENTITY=""
    mapfile -t candidates < <(list_usb_candidates)

    if ((${#candidates[@]} == 0)); then
        report_error \
            "No removable/USB disks were detected." \
            "Connect the target device and verify it appears in lsblk."
        return 1
    fi

    echo "Detected removable disks:"
    echo

    for i in "${!candidates[@]}"; do
        dev="${candidates[$i]}"
        size="$(block_property "$dev" SIZE)"
        model="$(block_property "$dev" MODEL)"
        transport="$(block_property "$dev" TRAN)"
        mounts="$(device_mountpoints "$dev" | paste -sd ',' -)"
        printf "  %d. %-12s %-8s %-24s transport=%-7s mounts=%s\n" \
            "$((i + 1))" "$dev" "${size:-unknown}" "${model:-Unknown}" \
            "${transport:-unknown}" "${mounts:-not mounted}"
    done

    echo
    read -r -p "Select target disk number: " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] ||
        ((selection < 1 || selection > ${#candidates[@]})); then
        report_error "Invalid disk selection." "Choose one of the displayed disk numbers."
        return 1
    fi

    dev="${candidates[$((selection - 1))]}"
    SELECTED_USB_IDENTITY="$(usb_device_identity "$dev")" || {
        report_error \
            "Unable to record the selected device identity." \
            "Reconnect the device and select it again."
        return 1
    }
    SELECTED_USB_DEVICE="$dev"
}

unmount_device_filesystems() {
    local device="$1"
    local node
    local mounts
    local i
    local -a nodes=()

    mapfile -t nodes < <(
        lsblk -ln -o PATH,TYPE -- "$device" 2>/dev/null |
            awk '$2 == "disk" || $2 == "part" { print $1 }'
    )

    # Unmount child partitions before the parent disk. Some hybrid images, such
    # as Tails, mount an ISO9660 filesystem directly from the whole disk.
    for ((i = ${#nodes[@]} - 1; i >= 0; i--)); do
        node="${nodes[$i]}"
        mounts="$(device_mountpoints "$node")"
        [[ -n "$mounts" ]] || continue

        echo "Unmounting $node ..."
        printf '%s\n' "$mounts" | sed 's/^/  /'
        sudo umount -- "$node" || return 1
    done
}

preview_device_unmounts() {
    local device="$1"
    local node
    local mounts
    local i
    local found=0
    local -a nodes=()

    mapfile -t nodes < <(
        lsblk -ln -o PATH,TYPE -- "$device" 2>/dev/null |
            awk '$2 == "disk" || $2 == "part" { print $1 }'
    )

    for ((i = ${#nodes[@]} - 1; i >= 0; i--)); do
        node="${nodes[$i]}"
        mounts="$(device_mountpoints "$node")"
        [[ -n "$mounts" ]] || continue
        preview_command "Unmount filesystems on $node" sudo umount -- "$node"
        found=1
    done

    if ((found == 0)); then
        echo "No mounted target filesystems would need to be unmounted."
    fi
}

dd_byte_count_mode() {
    if dd if=/dev/zero of=/dev/null bs=16M count=1B 2>/dev/null; then
        printf 'suffix\n'
    elif dd if=/dev/zero of=/dev/null bs=16M count=1 \
        iflag=count_bytes 2>/dev/null; then
        printf 'count_bytes\n'
    else
        return 1
    fi
}

zero_fill_device() {
    local target="$1"
    local count_mode
    local target_bytes

    target_bytes="$(block_size_bytes "$target")"
    if ! [[ "$target_bytes" =~ ^[1-9][0-9]*$ ]]; then
        report_error \
            "Unable to determine a valid byte capacity for $target." \
            "Reconnect the device, verify it with lsblk, and select it again."
        return 1
    fi

    count_mode="$(dd_byte_count_mode)" || {
        report_error \
            "Installed dd cannot express an exact byte-count write." \
            "Install a supported GNU Coreutils or uutils dd implementation."
        return 1
    }

    case "$count_mode" in
        suffix)
            sudo dd if=/dev/zero of="$target" bs=16M count="${target_bytes}B" \
                status=progress conv=fsync
            ;;
        count_bytes)
            sudo dd if=/dev/zero of="$target" bs=16M count="$target_bytes" \
                iflag=count_bytes status=progress conv=fsync
            ;;
        *)
            report_error \
                "Unable to select a supported dd byte-count mode." \
                "Verify the installed dd implementation and retry."
            return 1
            ;;
    esac
}

quick_reset_nodes() {
    local target="$1"
    local node
    local i
    local -a nodes=()

    mapfile -t nodes < <(
        lsblk -ln -o PATH,TYPE -- "$target" 2>/dev/null |
            awk '$2 == "disk" || $2 == "part" { print $1 }'
    )

    # Erase child signatures before the disk's partition table makes those
    # child device nodes disappear from the kernel's view.
    for ((i = ${#nodes[@]} - 1; i >= 0; i--)); do
        node="${nodes[$i]}"
        [[ "$node" == "$target" || "$node" == "$target"[0-9]* ||
            "$node" == "$target"p[0-9]* ]] || {
            report_error \
                "REFUSING: unexpected device node discovered during quick reset." \
                "Reconnect the device and select it again."
            return 1
        }
        printf '%s\n' "$node"
    done

    ((${#nodes[@]} > 0)) || {
        report_error \
            "Unable to enumerate the selected device for quick reset." \
            "Reconnect the device, verify it with lsblk, and select it again."
        return 1
    }
}

quick_reset_device() {
    local target="$1"
    local reset_node_output
    local -a reset_nodes=()

    reset_node_output="$(quick_reset_nodes "$target")" || return 1
    mapfile -t reset_nodes <<<"$reset_node_output"

    sudo wipefs --all -- "${reset_nodes[@]}"
}

validate_iso() {
    local iso="$1"

    [[ -f "$iso" ]] || {
        report_error \
            "ISO file does not exist: $iso" \
            "Verify the path and file permissions before retrying."
        return 1
    }

    if [[ "$(file -b --mime-type "$iso" 2>/dev/null)" != "application/x-iso9660-image" ]]; then
        report_warning "File does not identify as an ISO9660 image."
        if ! confirm_yes "Type YES to continue anyway: "; then
            return 1
        fi
    fi

    return 0
}

build_bootable_usb() {
    local iso
    local iso_start
    local target
    local target_identity
    local expected_hash
    local actual_hash

    banner
    ui_section "CREATE BOOTABLE USB" "REMOVABLE MEDIA // ISO FLASH PROTOCOL"
    echo "Uses Ubuntu-native tools: lsblk, findmnt, sha256sum, umount, dd, sync."
    echo

    if ! require_commands readlink lsblk findmnt awk sed sort paste file sha256sum sudo umount dd sync; then
        pause
        return
    fi

    iso_start="$HOME/Downloads/"
    [[ -d "$iso_start" ]] || iso_start="$HOME/"
    prompt_path iso "ISO PATH" "$iso_start"

    validate_iso "$iso" || {
        pause
        return
    }

    echo
    read -r -p "Expected SHA-256 (optional; press Enter to skip): " expected_hash

    if [[ -n "$expected_hash" ]]; then
        actual_hash="$(sha256sum "$iso" | awk '{print $1}')"

        echo "Expected: $expected_hash"
        echo "Actual:   $actual_hash"

        if [[ "${actual_hash,,}" != "${expected_hash,,}" ]]; then
            report_error \
                "SHA-256 verification failed; the write was aborted." \
                "Download the ISO again or verify the expected checksum source."
            pause
            return
        fi

        report_success "SHA-256 verification passed."
    fi

    echo
    if ! select_usb_device; then
        pause
        return
    fi

    target="$SELECTED_USB_DEVICE"
    target_identity="$SELECTED_USB_IDENTITY"

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo
    warn_destructive
    echo
    echo "ISO:    $iso"
    echo "TARGET: $target"
    echo
    if ! run_checked \
        "Selected-device detail query" \
        "Reconnect the device and select it again." \
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "$target"; then
        pause
        return
    fi
    echo
    echo "EVERYTHING on $target will be overwritten."

    if is_dry_run; then
        echo
        preview_device_unmounts "$target"
        preview_command \
            "Write the ISO image to $target" \
            sudo dd if="$iso" of="$target" bs=4M status=progress conv=fsync
        preview_command "Flush filesystem buffers" sync
        report_success "Bootable USB preview completed; no device state was changed."
        pause
        return
    fi

    if ! confirm_yes "Type YES to write the ISO to $target: "; then
        echo "Operation cancelled."
        pause
        return
    fi

    echo
    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo "Unmounting target partitions..."
    if ! run_checked \
        "Target filesystem unmount" \
        "Close applications using the device, unmount it, and retry." \
        unmount_device_filesystems "$target"; then
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity" 1; then
        pause
        return
    fi

    echo
    echo "Writing image..."
    echo "Command: sudo dd if=\"$iso\" of=\"$target\" bs=4M status=progress conv=fsync"
    echo

    begin_operation \
        "Bootable USB write to $target" \
        "The target may contain an incomplete image and must be rewritten before use."

    if run_checked \
        "Bootable USB image write" \
        "Inspect the connection and rewrite the target before use; it may contain an incomplete image." \
        sudo dd if="$iso" of="$target" bs=4M status=progress conv=fsync; then
        if run_checked \
            "Filesystem buffer sync" \
            "Keep the USB connected and run 'sync' again before ejecting it." \
            sync; then
            end_operation
            echo
            report_success "Bootable USB creation completed successfully."
            echo "You may now safely eject $target."
        else
            end_operation
        fi
    else
        end_operation
    fi

    pause
}

usb_quick_reset() {
    local final_target
    local target
    local target_identity
    local reset_node_output
    local -a reset_nodes=()

    banner
    ui_section "USB QUICK RESET" "REMOVABLE MEDIA // SIGNATURE CLEAR"
    warn_destructive
    echo "This function removes detected filesystem, RAID, and partition-table signatures."
    printf '%bTHIS IS NOT A DATA WIPE. FILE CONTENTS MAY REMAIN RECOVERABLE.%b\n' \
        "$YELLOW" "$RESET"
    echo

    if ! require_commands readlink lsblk findmnt awk sed sort paste sudo umount wipefs sync; then
        pause
        return
    fi

    if ! select_usb_device; then
        pause
        return
    fi

    target="$SELECTED_USB_DEVICE"
    target_identity="$SELECTED_USB_IDENTITY"

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo
    echo "TARGET: $target"
    if ! run_checked \
        "Selected-device detail query" \
        "Reconnect the device and select it again." \
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "$target"; then
        pause
        return
    fi
    echo
    printf '%bFILESYSTEM AND PARTITION SIGNATURES WILL BE REMOVED.%b\n' "$RED" "$RESET"
    echo "Existing file data will not be overwritten and may remain recoverable."

    if is_dry_run; then
        reset_node_output="$(quick_reset_nodes "$target")" || {
            pause
            return
        }
        mapfile -t reset_nodes <<<"$reset_node_output"
        echo
        preview_device_unmounts "$target"
        preview_command \
            "Remove detected signatures from $target and its partitions" \
            sudo wipefs --all -- "${reset_nodes[@]}"
        preview_command "Flush filesystem buffers" sync
        report_success "USB quick-reset preview completed; no device state was changed."
        pause
        return
    fi

    if ! confirm_yes "Type YES to continue: "; then
        echo "Operation cancelled."
        pause
        return
    fi

    read -r -p "For final confirmation, type the device path exactly ($target): " final_target

    if [[ "$final_target" != "$target" ]]; then
        printf '%bDevice confirmation did not match. Aborting.%b\n' "$YELLOW" "$RESET"
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    if ! run_checked \
        "Target filesystem unmount" \
        "Close applications using the device, unmount it, and retry." \
        unmount_device_filesystems "$target"; then
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity" 1; then
        pause
        return
    fi

    echo
    echo "Removing signatures from $target ..."
    begin_operation \
        "USB quick reset on $target" \
        "The target may have only some signatures removed; inspect it before reuse."

    if run_checked \
        "USB quick reset" \
        "Inspect the target and repeat the quick reset before reuse; some signatures may remain." \
        quick_reset_device "$target"; then
        if run_checked \
            "Filesystem buffer sync" \
            "Keep the USB connected and run 'sync' again before ejecting it." \
            sync; then
            end_operation
            echo
            report_success "USB quick reset completed."
            report_warning "This removed signatures only; it did not overwrite existing file data."
        else
            end_operation
        fi
    else
        end_operation
    fi

    pause
}

usb_zero_fill() {
    local count_mode
    local final_target
    local target
    local target_identity
    local target_bytes

    banner
    ui_section "USB WIPE / ZERO-FILL" "REMOVABLE MEDIA // DESTRUCTIVE PROTOCOL"
    warn_destructive
    echo "This function overwrites the selected removable drive with zeroes."
    echo "On flash storage, wear leveling means this is not a guaranteed secure erase."
    echo

    if ! require_commands readlink lsblk findmnt awk sed sort paste sudo umount dd sync; then
        pause
        return
    fi

    if ! select_usb_device; then
        pause
        return
    fi

    target="$SELECTED_USB_DEVICE"
    target_identity="$SELECTED_USB_IDENTITY"

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    echo
    echo "TARGET: $target"
    if ! run_checked \
        "Selected-device detail query" \
        "Reconnect the device and select it again." \
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "$target"; then
        pause
        return
    fi
    echo
    printf '%bALL DATA ON THIS DEVICE WILL BE DESTROYED.%b\n' "$RED" "$RESET"

    if is_dry_run; then
        target_bytes="$(block_size_bytes "$target")"
        if ! [[ "$target_bytes" =~ ^[1-9][0-9]*$ ]]; then
            report_error \
                "Unable to determine a valid byte capacity for $target." \
                "Reconnect the device, verify it with lsblk, and select it again."
            pause
            return
        fi

        count_mode="$(dd_byte_count_mode)" || {
            report_error \
                "Installed dd cannot express an exact byte-count write." \
                "Install a supported GNU Coreutils or uutils dd implementation."
            pause
            return
        }

        echo
        preview_device_unmounts "$target"
        if [[ "$count_mode" == "suffix" ]]; then
            preview_command \
                "Zero-fill $target" \
                sudo dd if=/dev/zero of="$target" bs=16M count="${target_bytes}B" \
                status=progress conv=fsync
        else
            preview_command \
                "Zero-fill $target" \
                sudo dd if=/dev/zero of="$target" bs=16M count="$target_bytes" \
                iflag=count_bytes status=progress conv=fsync
        fi
        preview_command "Flush filesystem buffers" sync
        report_success "USB zero-fill preview completed; no device state was changed."
        pause
        return
    fi

    if ! confirm_yes "Type YES to continue: "; then
        echo "Operation cancelled."
        pause
        return
    fi

    read -r -p "For final confirmation, type the device path exactly ($target): " final_target

    if [[ "$final_target" != "$target" ]]; then
        printf '%bDevice confirmation did not match. Aborting.%b\n' "$YELLOW" "$RESET"
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity"; then
        pause
        return
    fi

    if ! run_checked \
        "Target filesystem unmount" \
        "Close applications using the device, unmount it, and retry." \
        unmount_device_filesystems "$target"; then
        pause
        return
    fi

    if ! validate_usb_target "$target" "$target_identity" 1; then
        pause
        return
    fi

    echo
    echo "Zero-filling $target ..."
    begin_operation \
        "USB zero-fill on $target" \
        "The target may be only partially overwritten; verify it before reuse."

    if run_checked \
        "USB zero-fill" \
        "Inspect the connection and repeat the wipe before reuse; the target may be partially overwritten." \
        zero_fill_device "$target"; then
        if run_checked \
            "Filesystem buffer sync" \
            "Keep the USB connected and run 'sync' again before ejecting it." \
            sync; then
            end_operation
            echo
            report_success "USB zero-fill completed."
        else
            end_operation
        fi
    else
        end_operation
    fi

    pause
}

usb_menu() {
    local choice=""

    while true; do
        banner
        ui_section "USB OPERATIONS" "REMOVABLE MEDIA // WRITE + WIPE"
        menu_item 1 "Create bootable USB from ISO" "MEDIA // FLASH"
        menu_item 2 "Quick reset USB signatures" "MEDIA // FAST CLEAR"
        menu_item 3 "Wipe / zero-fill USB drive" "MEDIA // DESTROY"
        menu_item 4 "List removable storage" "MEDIA // SCAN"
        menu_navigation_item 0 "Return to control deck" "NAV // BACK"

        prompt_choice choice "USB"

        case "$choice" in
            1) build_bootable_usb ;;
            2) usb_quick_reset ;;
            3) usb_zero_fill ;;
            4)
                echo
                if require_commands lsblk; then
                    run_checked \
                        "Removable-storage query" \
                        "Verify sysfs is mounted and storage devices are accessible." \
                        lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,TRAN,RM
                fi
                pause
                ;;
            0) return ;;
            *) invalid_selection ;;
        esac
    done
}
