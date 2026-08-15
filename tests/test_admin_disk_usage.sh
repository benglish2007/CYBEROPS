#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked indirectly by sourced admin code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0
checked_command=""

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

require_commands() {
    [[ "$*" == "df" ]]
}

run_checked() {
    shift 2
    checked_command="$*"
}

if show_local_disk_usage; then
    query_result=success
else
    query_result=failure
fi
record_result "local disk usage query succeeds through checked execution" "$query_result" success
record_result "local disk usage excludes remote filesystems" "$checked_command" "df -lhT"

mutating_commands=()
choices=(2 0)
choice_index=0
banner() { :; }
ui_section() { :; }
menu_item() { :; }
menu_navigation_item() { :; }
pause() { :; }
require_commands() { return 0; }
prompt_choice() {
    local -n destination="$1"
    destination="${choices[choice_index]}"
    ((choice_index += 1))
}
run_mutating_checked() {
    shift 2
    mutating_commands+=("$*")
}

admin_menu >/dev/null
record_result "package upgrade accepts APT confirmation automatically" \
    "${mutating_commands[*]}" "sudo apt update sudo apt upgrade -y"

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
