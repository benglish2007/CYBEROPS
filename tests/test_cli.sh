#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2329 # Command helpers are dispatched indirectly by cyberops_main.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LAUNCHER="$REPO_DIR/cyberops.sh"
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

version_output="$(bash "$LAUNCHER" --version)"
record_result "version option prints the release" "$version_output" "CYBEROPS Terminal 2.10"

help_output="$(bash "$LAUNCHER" --help)"
if [[ "$help_output" == *"Usage:"* && "$help_output" == *"--no-color"* &&
    "$help_output" == *"docker status"* && "$help_output" == *"config check"* &&
    "$help_output" == *"diagnostics export"* &&
    "$help_output" == *"interactive terminal"* ]]; then
    help_result=complete
else
    help_result=incomplete
fi
record_result "help option documents invocation modes" "$help_result" complete

set +e
unknown_output="$(bash "$LAUNCHER" --unknown 2>&1)"
unknown_status=$?
set -e
record_result "unknown options return usage status" "$unknown_status" 2
if [[ "$unknown_output" == *"unknown option"* ]]; then
    unknown_result=clear
else
    unknown_result=unclear
fi
record_result "unknown options produce actionable guidance" "$unknown_result" clear

set +e
noninteractive_output="$(bash "$LAUNCHER" </dev/null 2>&1)"
noninteractive_status=$?
set -e
record_result "menu refuses non-interactive input" "$noninteractive_status" 2
if [[ "$noninteractive_output" == *"requires an interactive terminal"* ]]; then
    noninteractive_result=clear
else
    noninteractive_result=unclear
fi
record_result "non-interactive refusal explains the requirement" "$noninteractive_result" clear

export NO_COLOR=1
# shellcheck source=cyberops.sh
source "$LAUNCHER"
if [[ -z "$CYAN" && -z "$MAGENTA" && -z "$RESET" && "$CYBEROPS_NO_COLOR" == "1" ]]; then
    no_color_result=disabled
else
    no_color_result=enabled
fi
record_result "NO_COLOR disables the runtime palette" "$no_color_result" disabled

typewrite_output="$(typewrite "instant output" 9)"
record_result "typewrite skips animation without a terminal" "$typewrite_output" "instant output"

show_system_summary() { printf 'HOST_SUMMARY\n'; }
info_output="$(cyberops_main --no-color info)"
record_result "info command dispatches read-only host telemetry" "$info_output" HOST_SUMMARY

show_docker_status() { printf 'DOCKER_STATUS\n'; }
docker_output="$(cyberops_main docker status)"
record_result "docker status command dispatches read-only telemetry" "$docker_output" DOCKER_STATUS

show_local_disk_usage() { printf 'DISK_STATUS\n'; }
show_memory_usage() { printf 'MEMORY_STATUS\n'; }
show_running_services() { printf 'SERVICE_STATUS\n'; }
show_failed_services() { printf 'FAILURE_STATUS\n'; }
show_storage_devices() { printf 'STORAGE_STATUS\n'; }
show_network_interfaces() { printf 'INTERFACE_STATUS\n'; }
show_routing_table() { printf 'ROUTE_STATUS\n'; }
show_listening_sockets() { printf 'SOCKET_STATUS\n'; }
show_vpn_status() { printf 'VPN_STATUS\n'; }

command_cases=(
    "system disk|DISK_STATUS"
    "system memory|MEMORY_STATUS"
    "system services|SERVICE_STATUS"
    "system failures|FAILURE_STATUS"
    "storage devices|STORAGE_STATUS"
    "network interfaces|INTERFACE_STATUS"
    "network routes|ROUTE_STATUS"
    "network sockets|SOCKET_STATUS"
    "vpn status|VPN_STATUS"
)
for command_case in "${command_cases[@]}"; do
    command_text="${command_case%%|*}"
    expected_output="${command_case#*|}"
    read -r -a command_parts <<<"$command_text"
    command_output="$(cyberops_main "${command_parts[@]}")"
    record_result "dispatches read-only '$command_text' telemetry" \
        "$command_output" "$expected_output"
done

show_memory_usage() { return 7; }
set +e
cyberops_main system memory >/dev/null
telemetry_failure_status=$?
set -e
record_result "preserves telemetry command failure status" "$telemetry_failure_status" 7

set +e
unknown_command_output="$(cyberops_main not-a-command 2>&1)"
unknown_command_status=$?
set -e
record_result "unknown commands return usage status" "$unknown_command_status" 2
if [[ "$unknown_command_output" == *"unknown command"* ]]; then
    unknown_command_result=clear
else
    unknown_command_result=unclear
fi
record_result "unknown commands produce actionable guidance" "$unknown_command_result" clear

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
