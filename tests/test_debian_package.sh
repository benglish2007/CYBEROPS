#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
OUTPUT_DIR="$TEST_ROOT/output"
EXTRACT_DIR="$TEST_ROOT/extract"
VERSION="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$REPO_DIR/lib/runtime.sh")"
PACKAGE_FILE="$OUTPUT_DIR/cyberops_${VERSION}_all.deb"
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

bash "$REPO_DIR/packaging/build-deb.sh" "$OUTPUT_DIR" >/dev/null
[[ -f "$PACKAGE_FILE" ]] && build_result=built || build_result=missing
record_result "builds a versioned architecture-independent package" "$build_result" built

package_name="$(dpkg-deb -f "$PACKAGE_FILE" Package)"
package_version="$(dpkg-deb -f "$PACKAGE_FILE" Version)"
package_architecture="$(dpkg-deb -f "$PACKAGE_FILE" Architecture)"
package_dependencies="$(dpkg-deb -f "$PACKAGE_FILE" Depends)"
package_suggestions="$(dpkg-deb -f "$PACKAGE_FILE" Suggests)"
record_result "declares the CYBEROPS package name" "$package_name" cyberops
record_result "uses the runtime version as package version" "$package_version" "$VERSION"
record_result "declares architecture-independent content" "$package_architecture" all
if [[ "$package_dependencies" == *ethtool* && "$package_dependencies" == *iproute2* ]]; then
    telemetry_dependencies=declared
else
    telemetry_dependencies=missing
fi
record_result "declares network telemetry dependencies" "$telemetry_dependencies" declared
if [[ "$package_suggestions" == *network-manager* &&
    "$package_suggestions" == *macchanger* ]]; then
    mac_dependencies=suggested
else
    mac_dependencies=missing
fi
record_result "suggests dependencies for optional MAC controls" \
    "$mac_dependencies" suggested

mkdir -p -- "$EXTRACT_DIR"
dpkg-deb -x "$PACKAGE_FILE" "$EXTRACT_DIR"
if [[ -x "$EXTRACT_DIR/usr/bin/cyberops" &&
    -x "$EXTRACT_DIR/usr/lib/cyberops/cyberops.sh" &&
    -f "$EXTRACT_DIR/usr/share/applications/cyberops.desktop" &&
    -f "$EXTRACT_DIR/usr/share/pixmaps/cyberops.png" ]]; then
    layout_result=complete
else
    layout_result=incomplete
fi
record_result "installs the complete application beneath /usr" "$layout_result" complete

if [[ -f "$EXTRACT_DIR/usr/share/doc/cyberops/NEON-OVERDRIVE.md" &&
    -f "$EXTRACT_DIR/usr/share/doc/cyberops/V3-READINESS.md" ]]; then
    readiness_docs_result=included
else
    readiness_docs_result=missing
fi
record_result "packages interface and v3 readiness documentation" \
    "$readiness_docs_result" included

if grep -Fq 'exec "/usr/lib/cyberops/cyberops.sh"' "$EXTRACT_DIR/usr/bin/cyberops" &&
    ! grep -R -Fq '@CYBEROPS_' "$EXTRACT_DIR/usr"; then
    template_result=resolved
else
    template_result=unresolved
fi
record_result "resolves installed launcher and desktop templates" "$template_result" resolved

if [[ ! -e "$EXTRACT_DIR/usr/lib/cyberops/lib/setup.sh" &&
    ! -e "$EXTRACT_DIR/usr/share/applications/mimeinfo.cache" ]]; then
    generated_result=clean
else
    generated_result=contaminated
fi
record_result "excludes installer and host-generated cache files" "$generated_result" clean

if make -s -n -C "$REPO_DIR" deb | grep -Fq 'packaging/build-deb.sh' &&
    make -s -n -C "$REPO_DIR" deb-inspect | grep -Fq 'dpkg-deb --contents'; then
    target_result=available
else
    target_result=missing
fi
record_result "Makefile exposes package build and inspection targets" "$target_result" available

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
