#!/usr/bin/env bash
# shellcheck disable=SC2329 # Mocks are invoked indirectly by sourced installer code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=packaging/install-dependencies.sh
source "$REPO_DIR/packaging/install-dependencies.sh"

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

dependency_setup_has_root() { return 1; }
set +e
root_output="$(dependency_setup_main 2>&1)"
root_status=$?
set -e
record_result "dependency installer refuses non-root execution" "$root_status" 1
if [[ "$root_output" == *"sudo make install-deps"* ]]; then
    root_message=clear
else
    root_message=unclear
fi
record_result "dependency installer provides the privileged command" "$root_message" clear

dependency_setup_has_root() { return 0; }
apt-get() { printf 'APT_GET:%s\n' "$*"; }
setup_output="$(dependency_setup_main)"
if [[ "$setup_output" == *"APT_GET:update"* &&
    "$setup_output" == *"APT_GET:install --yes"* ]]; then
    apt_result=called
else
    apt_result=missing
fi
record_result "dependency installer updates metadata before installation" "$apt_result" called

if [[ "$setup_output" == *"figlet"* && "$setup_output" == *"clamav"* &&
    "$setup_output" == *"macchanger"* && "$setup_output" == *"wavemon"* ]]; then
    package_result=complete
else
    package_result=incomplete
fi
record_result "dependency installer includes the optional tool set" "$package_result" complete

if make -s -n -C "$REPO_DIR" install-deps | grep -Fq 'install-dependencies.sh'; then
    make_result=available
else
    make_result=missing
fi
record_result "Makefile exposes the dependency installer" "$make_result" available

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
