#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$REPO_DIR/dist}"
PACKAGE_ROOT=""

deb_error() {
    printf '[!] %s\n' "$1" >&2
    [[ -z "${2:-}" ]] || printf 'Next step: %s\n' "$2" >&2
}

cleanup() {
    if [[ -n "$PACKAGE_ROOT" && "$PACKAGE_ROOT" == /tmp/* && -d "$PACKAGE_ROOT" ]]; then
        rm -rf -- "$PACKAGE_ROOT"
    fi
}
trap cleanup EXIT

for command_name in dpkg-deb install make mktemp sed; do
    command -v "$command_name" >/dev/null 2>&1 || {
        deb_error "Missing package-build command: $command_name" \
            "Install dpkg-dev and the standard build utilities."
        exit 1
    }
done

VERSION="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$REPO_DIR/lib/runtime.sh")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
    deb_error "Invalid CYBEROPS package version: $VERSION"
    exit 1
}

mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
PACKAGE_ROOT="$(mktemp -d)"
PACKAGE_FILE="$OUTPUT_DIR/cyberops_${VERSION}_all.deb"

make -s -C "$REPO_DIR" install DESTDIR="$PACKAGE_ROOT" PREFIX=/usr
rm -f -- "$PACKAGE_ROOT/usr/share/applications/mimeinfo.cache"
install -d -m 755 "$PACKAGE_ROOT/DEBIAN"
sed "s|@VERSION@|$VERSION|g" \
    "$SCRIPT_DIR/debian/control.in" >"$PACKAGE_ROOT/DEBIAN/control"
chmod 644 "$PACKAGE_ROOT/DEBIAN/control"
find "$PACKAGE_ROOT" -type d -exec chmod 755 {} +

rm -f -- "$PACKAGE_FILE"
dpkg-deb --root-owner-group --build "$PACKAGE_ROOT" "$PACKAGE_FILE" >/dev/null
printf '[OK] Built %s\n' "$PACKAGE_FILE"
