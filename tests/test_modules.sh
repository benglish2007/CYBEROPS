#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

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

record_result "resolves the launcher directory" "$CYBEROPS_SOURCE_DIR" "$REPO_DIR"
record_result "resolves the default module directory" "$CYBEROPS_LIB_DIR" "$REPO_DIR/lib"
record_result "loads the version from runtime.sh" "$VERSION" 2.5

if declare -F docker_menu >/dev/null && declare -F usb_zero_fill >/dev/null; then
    functions_result=available
else
    functions_result=missing
fi
record_result "keeps feature functions available after modular runtime load" "$functions_result" available

shopt -s extdebug
docker_function_details="$(declare -F docker_menu)"
core_function_details="$(declare -F validate_configuration)"
ui_function_details="$(declare -F banner)"
shopt -u extdebug
docker_function_source="${docker_function_details##* }"
core_function_source="${core_function_details##* }"
ui_function_source="${ui_function_details##* }"
record_result "loads validation functions from lib/core.sh" \
    "$core_function_source" "$REPO_DIR/lib/core.sh"
record_result "loads interface functions from lib/ui.sh" \
    "$ui_function_source" "$REPO_DIR/lib/ui.sh"
record_result "loads Docker functions from lib/docker.sh" \
    "$docker_function_source" "$REPO_DIR/lib/docker.sh"

module_function_pairs=(
    "admin_menu:admin.sh"
    "info_menu:info.sh"
    "vpn_menu:vpn.sh"
    "cyber_defense_menu:security.sh"
    "quickhacks_menu:quickhacks.sh"
    "usb_zero_fill:usb.sh"
    "system_setup:setup.sh"
    "main_menu:menu.sh"
)
for module_function_pair in "${module_function_pairs[@]}"; do
    function_name="${module_function_pair%%:*}"
    module_file="${module_function_pair#*:}"
    shopt -s extdebug
    function_details="$(declare -F "$function_name")"
    shopt -u extdebug
    function_source="${function_details##* }"
    record_result "loads $function_name from $module_file" \
        "$function_source" "$REPO_DIR/lib/$module_file"
done

set +e
missing_output="$(
    CYBEROPS_LIB_DIR=/definitely/missing/cyberops-lib \
        bash -c 'source "$1"' _ "$REPO_DIR/cyberops.sh" 2>&1
)"
missing_status=$?
set -e
record_result "fails closed when a required module is missing" "$missing_status" 1
if [[ "$missing_output" == *"could not load required module"* &&
    "$missing_output" == *"runtime.sh"* ]]; then
    missing_message=clear
else
    missing_message=unclear
fi
record_result "identifies the missing required module" "$missing_message" clear

missing_docker_dir="$(mktemp -d)"
ln -s -- "$REPO_DIR/lib/runtime.sh" "$missing_docker_dir/runtime.sh"
ln -s -- "$REPO_DIR/lib/core.sh" "$missing_docker_dir/core.sh"
ln -s -- "$REPO_DIR/lib/ui.sh" "$missing_docker_dir/ui.sh"
set +e
missing_docker_output="$(
    CYBEROPS_LIB_DIR="$missing_docker_dir" \
        bash -c 'source "$1"' _ "$REPO_DIR/cyberops.sh" 2>&1
)"
missing_docker_status=$?
set -e
record_result "fails closed when the Docker module is missing" \
    "$missing_docker_status" 1
if [[ "$missing_docker_output" == *"could not load required module"* &&
    "$missing_docker_output" == *"docker.sh"* ]]; then
    missing_docker_message=clear
else
    missing_docker_message=unclear
fi
record_result "identifies a missing Docker module" "$missing_docker_message" clear
rm -- "$missing_docker_dir/runtime.sh" "$missing_docker_dir/core.sh" "$missing_docker_dir/ui.sh"
rmdir -- "$missing_docker_dir"

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
