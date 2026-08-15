#!/usr/bin/env bash

# DRY_RUN is consumed by several dynamically loaded feature modules.
# shellcheck disable=SC2034

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0

record_result() {
    local name="$1"
    local actual="$2"
    local expected="$3"

    ((tests_run += 1))
    if [[ "$actual" == "$expected" ]]; then
        printf 'ok %d - %s\n' "$tests_run" "$name"
    else
        printf 'not ok %d - %s (expected %s, got %s)\n' \
            "$tests_run" "$name" "$expected" "$actual"
        ((tests_failed += 1))
    fi
}

mutating_command() {
    printf 'MUTATION_EXECUTED:%s\n' "$*"
    return 42
}

DRY_RUN=1
set +e
dry_output="$(run_mutating_checked "Test mutation" "Test recovery" mutating_command "one two" three 2>&1)"
dry_status=$?
set -e
record_result "dry-run mutation returns success" "$dry_status" 0
if [[ "$dry_output" == *"[DRY-RUN] Test mutation"* &&
    "$dry_output" != *"MUTATION_EXECUTED"* ]]; then
    dry_result=previewed
else
    dry_result=executed
fi
record_result "dry-run previews without executing" "$dry_result" previewed
if [[ "$dry_output" == *"one\\ two"* ]]; then
    quoting_result=escaped
else
    quoting_result=missing
fi
record_result "dry-run shell-escapes command arguments" "$quoting_result" escaped

DRY_RUN=0
set +e
real_output="$(run_mutating_checked "Test mutation" "Test recovery" mutating_command real 2>&1)"
real_status=$?
set -e
record_result "real mutation preserves command failure status" "$real_status" 42
if [[ "$real_output" == *"MUTATION_EXECUTED:real"* ]]; then
    real_result=executed
else
    real_result=missing
fi
record_result "disabled dry-run executes the command" "$real_result" executed

have() {
    return 0
}

# Dry-run assertions verify these functions are never reached through sudo.
# shellcheck disable=SC2032
ip() {
    if [[ "$1 $2" == "link show" ]]; then
        printf '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500\n'
        return 0
    fi
    printf 'IP_MUTATION_EXECUTED:%s\n' "$*"
}

sudo() {
    printf 'SUDO_MUTATION_EXECUTED:%s\n' "$*"
    return 0
}

# shellcheck disable=SC2032
macchanger() {
    printf 'MAC_MUTATION_EXECUTED:%s\n' "$*"
}

DRY_RUN=1
mac_output="$(randomize_mac_address eth0 2>&1)"
if [[ "$mac_output" == *"Bring eth0 down"* &&
    "$mac_output" == *"Restore eth0 to its original up state"* &&
    "$mac_output" != *"MUTATION_EXECUTED"* ]]; then
    mac_result=previewed
else
    mac_result=unsafe
fi
record_result "MAC dry-run previews the full state transition" "$mac_result" previewed

lsblk() {
    printf '/dev/sdb disk\n'
    printf '/dev/sdb1 part\n'
}

device_mountpoints() {
    printf '/run/media/test\n'
}

unmount_output="$(preview_device_unmounts /dev/sdb 2>&1)"
if [[ "$unmount_output" == *"umount"* &&
    "$unmount_output" != *"SUDO_MUTATION_EXECUTED"* ]]; then
    unmount_result=previewed
else
    unmount_result=unsafe
fi
record_result "USB dry-run previews unmounts without executing sudo" "$unmount_result" previewed

docker() {
    printf 'DOCKER_MUTATION_EXECUTED:%s\n' "$*"
    return 0
}

docker_output="$(update_one_stack /srv/stacks/example/compose.yml 2>&1)"
if [[ "$docker_output" == *"docker compose"* &&
    "$docker_output" == *"pull"* &&
    "$docker_output" == *"up -d"* &&
    "$docker_output" != *"DOCKER_MUTATION_EXECUTED"* ]]; then
    docker_result=previewed
else
    docker_result=unsafe
fi
record_result "Docker dry-run previews pull and recreation without execution" "$docker_result" previewed

vpn_choice_index=0
vpn_command=""
vpn_choices=(3 7)

banner() {
    return 0
}

ui_section() {
    return 0
}

menu_item() {
    return 0
}

prompt_choice() {
    local variable_name="$1"
    printf -v "$variable_name" '%s' "${vpn_choices[$vpn_choice_index]}"
    ((vpn_choice_index += 1))
}

require_commands() {
    return 0
}

run_mutating_checked() {
    vpn_command="$*"
    return 0
}

pause() {
    return 0
}

vpn_menu
if [[ "$vpn_command" == *"sudo tailscale down"* ]]; then
    vpn_result=correct
else
    vpn_result=incorrect
fi
record_result "Tailscale disconnect targets the tailscale CLI" "$vpn_result" correct

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
