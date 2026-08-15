#!/usr/bin/env bash
# shellcheck disable=SC2329 # Mocks are invoked indirectly by sourced release code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$(mktemp -d)"
MOCK_LOG="$TEST_DIR/publish.log"
trap 'rm -f -- "$MOCK_LOG"; rmdir -- "$TEST_DIR"' EXIT

# shellcheck source=packaging/release.sh
source "$REPO_DIR/packaging/release.sh"

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

validate_release_version 2.9
record_result "accepts a two-component release version" "$?" 0
validate_release_version 2.9.1
record_result "accepts a patch release version" "$?" 0
set +e
validate_release_version v2.9 >/dev/null 2>&1
invalid_version_status=$?
set -e
record_result "rejects a version with a v prefix" "$invalid_version_status" 1

set +e
verify_release_metadata 2.14 >/dev/null 2>&1
metadata_status=$?
set -e
if grep -Fqx '## Unreleased' "$REPO_DIR/CHANGELOG.md"; then
    expected_metadata_status=1
    metadata_test_name="blocks publishing during post-release development"
else
    expected_metadata_status=0
    metadata_test_name="accepts synchronized release metadata"
fi
record_result "$metadata_test_name" "$metadata_status" "$expected_metadata_status"
notes="$(extract_release_notes 2.14)"
[[ "$notes" == *"Neon Overdrive Interface"* &&
    "$notes" != *"## 2.13"* ]]
record_result "extracts only the prepared release notes" "$?" 0

if grep -Fq 'release-check:' "$REPO_DIR/Makefile" &&
    grep -Fq 'release-preview:' "$REPO_DIR/Makefile" &&
    grep -Fq 'release:' "$REPO_DIR/Makefile"; then
    make_targets=present
else
    make_targets=missing
fi
record_result "Makefile exposes check, preview, and publish targets" "$make_targets" present

release_check() { return 0; }
require_release_command() { return 0; }
build_release_artifact() { printf '%s/cyberops_2.14_all.deb' "$TEST_DIR"; }
local_tag_state() { printf 'absent'; }
git() {
    case "$*" in
        *"ls-remote"*) return 1 ;;
        *" tag -a "* | *" push origin "*) printf 'git %s\n' "$*" >>"$MOCK_LOG" ;;
    esac
    return 0
}
gh() {
    case "$1 $2" in
        "auth status") return 0 ;;
        "release view") return 1 ;;
        "release create") printf 'gh %s\n' "$*" >>"$MOCK_LOG" ;;
    esac
    return 0
}

publish_release 2.14 >/dev/null
record_result "publishes a validated release" "$?" 0
grep -Fq 'tag -a v2.14' "$MOCK_LOG"
record_result "creates an annotated version tag" "$?" 0
grep -Fq 'push origin v2.14' "$MOCK_LOG"
record_result "pushes only the version tag" "$?" 0
grep -Fq 'release create v2.14 --verify-tag' "$MOCK_LOG"
record_result "creates a release from the verified tag" "$?" 0
grep -Fq 'cyberops_2.14_all.deb#CYBEROPS v2.14 Debian package' "$MOCK_LOG"
record_result "attaches the native Debian package to the release" "$?" 0

: >"$MOCK_LOG"
gh() {
    case "$1 $2" in
        "auth status") return 0 ;;
        "release view") return 0 ;;
    esac
    return 0
}
set +e
publish_release 2.14 >/dev/null 2>&1
existing_release_status=$?
set -e
record_result "refuses to overwrite an existing GitHub Release" \
    "$existing_release_status" 1
if [[ -s "$MOCK_LOG" ]]; then
    overwrite_result=mutated
else
    overwrite_result=clean
fi
record_result "existing-release refusal makes no Git mutation" "$overwrite_result" clean

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
