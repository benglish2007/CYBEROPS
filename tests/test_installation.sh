#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
PREFIX=/usr/local
tests_run=0
tests_failed=0

cleanup() {
    if [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/* && -d "$TEST_ROOT" ]]; then
        rm -rf -- "$TEST_ROOT"
    fi
}
trap cleanup EXIT

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

make -s -C "$REPO_DIR" install DESTDIR="$TEST_ROOT" PREFIX="$PREFIX"

installed_launcher="$TEST_ROOT$PREFIX/lib/cyberops/cyberops.sh"
installed_wrapper="$TEST_ROOT$PREFIX/bin/cyberops"
installed_desktop="$TEST_ROOT$PREFIX/share/applications/cyberops.desktop"
installed_icon="$TEST_ROOT$PREFIX/share/pixmaps/cyberops.png"
installed_license="$TEST_ROOT$PREFIX/share/doc/cyberops/LICENSE"
installed_operations_guide="$TEST_ROOT$PREFIX/share/doc/cyberops/OPERATIONS.md"

[[ -x "$installed_launcher" ]] && launcher_result=installed || launcher_result=missing
record_result "installs the modular launcher as executable" "$launcher_result" installed

module_count="$(find "$TEST_ROOT$PREFIX/lib/cyberops/lib" -maxdepth 1 -name '*.sh' -type f | wc -l)"
source_module_count="$(find "$REPO_DIR/lib" -maxdepth 1 -name '*.sh' -type f | wc -l)"
record_result "installs every runtime module" "$module_count" "$source_module_count"

if [[ ! -e "$TEST_ROOT$PREFIX/lib/cyberops/lib/setup.sh" ]]; then
    setup_module_result=absent
else
    setup_module_result=installed
fi
record_result "keeps dependency setup out of the installed runtime" "$setup_module_result" absent

[[ -x "$installed_wrapper" ]] && wrapper_result=installed || wrapper_result=missing
record_result "installs the command wrapper as executable" "$wrapper_result" installed

if grep -Fq "exec \"$PREFIX/lib/cyberops/cyberops.sh\"" "$installed_wrapper"; then
    wrapper_target_result=resolved
else
    wrapper_target_result=unresolved
fi
record_result "resolves the wrapper's installed launcher path" "$wrapper_target_result" resolved

if grep -Fxq "Name=CYBEROPS Terminal" "$installed_desktop" &&
    grep -Fxq "Exec=$PREFIX/bin/cyberops" "$installed_desktop" &&
    grep -Fxq "Icon=$PREFIX/share/pixmaps/cyberops.png" "$installed_desktop" &&
    ! grep -Fq '@CYBEROPS_' "$installed_desktop"; then
    desktop_result=generated
else
    desktop_result=invalid
fi
record_result "generates a branded path-safe desktop entry" "$desktop_result" generated

[[ -f "$installed_icon" ]] && icon_result=installed || icon_result=missing
record_result "installs the CYBEROPS application icon" "$icon_result" installed

if [[ -f "$installed_license" ]] && grep -Fxq "MIT License" "$installed_license"; then
    license_result=installed
else
    license_result=missing
fi
record_result "installs the MIT license with the application" "$license_result" installed

if [[ -f "$installed_operations_guide" ]] &&
    grep -Fq "Operation Privileges and Side Effects" "$installed_operations_guide"; then
    documentation_result=installed
else
    documentation_result=missing
fi
record_result "installs the operation documentation" "$documentation_result" installed

make -s -C "$REPO_DIR" uninstall DESTDIR="$TEST_ROOT" PREFIX="$PREFIX"

if [[ ! -e "$installed_launcher" && ! -e "$installed_wrapper" &&
    ! -e "$installed_desktop" && ! -e "$installed_icon" &&
    ! -e "$installed_license" && ! -e "$installed_operations_guide" ]]; then
    uninstall_result=removed
else
    uninstall_result=remaining
fi
record_result "uninstall removes every CYBEROPS-managed file" "$uninstall_result" removed

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
