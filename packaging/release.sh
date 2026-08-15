#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

release_usage() {
    cat <<'EOF'
Usage: packaging/release.sh <check|preview|publish> VERSION

  check    Validate a prepared release without changing GitHub.
  preview  Validate and print the exact tag, target commit, and release notes.
  publish  Create/push an annotated tag and create a GitHub Release.

VERSION must omit the v prefix (example: 2.9).
EOF
}

release_error() {
    printf '[!] %s\n' "$1" >&2
    [[ -z "${2:-}" ]] || printf 'Next step: %s\n' "$2" >&2
}

require_release_command() {
    local command_name

    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            release_error "Missing release command: $command_name"
            return 1
        fi
    done
}

validate_release_version() {
    local version="$1"

    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        release_error "VERSION must look like 2.9 or 2.9.1 and must not include a v prefix."
        return 1
    fi
}

extract_release_notes() {
    local version="$1"

    awk -v heading="## $version —" '
        index($0, heading) == 1 { found=1; next }
        found && /^## / { exit }
        found { print }
        END { if (!found) exit 2 }
    ' "$REPO_DIR/CHANGELOG.md"
}

verify_release_metadata() {
    local version="$1"
    local failure=0

    if ! grep -Fqx "VERSION=\"$version\"" "$REPO_DIR/lib/runtime.sh"; then
        release_error "lib/runtime.sh does not declare VERSION=\"$version\"."
        failure=1
    fi
    if ! grep -Fq "RELEASE-v${version}-" "$REPO_DIR/README.md" ||
        ! grep -Fq "CYBEROPS Terminal v$version" "$REPO_DIR/README.md"; then
        release_error "README.md does not consistently identify v$version."
        failure=1
    fi
    if ! grep -Fq "Current release: **v$version" "$REPO_DIR/ROADMAP.md"; then
        release_error "ROADMAP.md does not identify v$version as the current release."
        failure=1
    fi
    if ! grep -Fq "CYBEROPS Terminal $version" "$REPO_DIR/docs/DEMO.md" ||
        ! grep -Fq "CYBEROPS Terminal v$version" "$REPO_DIR/docs/DEMO.md"; then
        release_error "docs/DEMO.md does not consistently identify v$version."
        failure=1
    fi
    if ! grep -Fq "CYBEROPS Terminal $version\"" "$REPO_DIR/tests/test_cli.sh" ||
        ! grep -Fq '"$VERSION" '"$version" "$REPO_DIR/tests/test_modules.sh" ||
        ! grep -Fq "BUILD $version" "$REPO_DIR/tests/test_ui.sh"; then
        release_error "Version assertions under tests/ are not synchronized with v$version."
        failure=1
    fi
    if ! grep -Fq "## $version —" "$REPO_DIR/CHANGELOG.md"; then
        release_error "CHANGELOG.md has no dated v$version release section."
        failure=1
    elif [[ -z "$(extract_release_notes "$version")" ]]; then
        release_error "CHANGELOG.md has no release notes beneath the v$version heading."
        failure=1
    fi

    ((failure == 0))
}

verify_repository_state() {
    local branch
    local divergence

    if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
        release_error "The working tree is not clean." "Commit the prepared release before publishing."
        return 1
    fi
    branch="$(git -C "$REPO_DIR" branch --show-current)"
    if [[ "$branch" != "main" ]]; then
        release_error "Releases must be prepared from main, not $branch."
        return 1
    fi
    if ! git -C "$REPO_DIR" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
        release_error "main has no configured upstream."
        return 1
    fi
    divergence="$(git -C "$REPO_DIR" rev-list --left-right --count '@{upstream}...HEAD')"
    if [[ "$divergence" != $'0\t0' && "$divergence" != '0  0' ]]; then
        release_error "main is not synchronized with its upstream (behind/ahead: $divergence)." \
            "Push or reconcile main before publishing."
        return 1
    fi
}

run_release_suite() {
    local test_script

    if [[ "${CYBEROPS_RELEASE_SKIP_TESTS:-0}" == "1" ]]; then
        printf '[TEST MODE] Full validation suite skipped.\n'
        return 0
    fi
    bash -n "$REPO_DIR/cyberops.sh" "$REPO_DIR"/lib/*.sh \
        "$REPO_DIR"/packaging/*.sh "$REPO_DIR/packaging/cyberops.in" \
        "$REPO_DIR"/tests/*.sh
    for test_script in "$REPO_DIR"/tests/test_*.sh; do
        bash "$test_script" >/dev/null
    done
}

release_check() {
    local version="$1"

    require_release_command git awk grep bash || return 1
    validate_release_version "$version" || return 1
    verify_repository_state || return 1
    verify_release_metadata "$version" || return 1
    run_release_suite || {
        release_error "The release validation suite failed."
        return 1
    }
    printf '[OK] CYBEROPS v%s is prepared for release.\n' "$version"
}

release_preview() {
    local version="$1"

    release_check "$version" || return 1
    printf '\nTag: v%s\n' "$version"
    printf 'Target: %s\n' "$(git -C "$REPO_DIR" rev-parse HEAD)"
    printf 'Title: CYBEROPS v%s\n' "$version"
    printf '\n--- RELEASE NOTES ---\n'
    extract_release_notes "$version"
    printf '%s\n' '--- END RELEASE NOTES ---'
    printf '\nNo tag or GitHub Release was created.\n'
}

local_tag_state() {
    local tag="$1"
    local tag_commit

    if ! git -C "$REPO_DIR" rev-parse --verify --quiet "refs/tags/$tag" >/dev/null; then
        printf 'absent'
        return 0
    fi
    tag_commit="$(git -C "$REPO_DIR" rev-list -n 1 "$tag")"
    if [[ "$tag_commit" == "$(git -C "$REPO_DIR" rev-parse HEAD)" ]]; then
        printf 'current'
    else
        printf 'conflict'
    fi
}

publish_release() {
    local version="$1"
    local tag="v$version"
    local notes_file
    local tag_state

    unset CYBEROPS_RELEASE_SKIP_TESTS
    release_check "$version" || return 1
    require_release_command gh mktemp || return 1
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        release_error "GitHub CLI authentication is unavailable." \
            "Run 'gh auth status'; if needed, restore desktop-keyring access or run 'gh auth login'."
        return 1
    fi
    if gh release view "$tag" >/dev/null 2>&1; then
        release_error "GitHub Release $tag already exists; it will not be overwritten."
        return 1
    fi

    tag_state="$(local_tag_state "$tag")"
    case "$tag_state" in
        absent)
            if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
                release_error "Remote tag $tag already exists; it will not be overwritten."
                return 1
            fi
            git -C "$REPO_DIR" tag -a "$tag" -m "CYBEROPS $version"
            ;;
        current)
            printf '[RESUME] Local tag %s already targets the release commit.\n' "$tag"
            ;;
        conflict)
            release_error "Local tag $tag targets a different commit; it will not be moved."
            return 1
            ;;
    esac

    if ! git -C "$REPO_DIR" push origin "$tag"; then
        release_error "Could not push $tag." \
            "The correct local tag is retained; rerun publish after fixing remote access."
        return 1
    fi

    notes_file="$(mktemp)" || return 1
    chmod 600 -- "$notes_file"
    extract_release_notes "$version" >"$notes_file"
    if ! gh release create "$tag" --verify-tag --title "CYBEROPS v$version" --notes-file "$notes_file"; then
        rm -f -- "$notes_file"
        release_error "Tag $tag is published, but GitHub Release creation failed." \
            "Rerun publish to resume; the existing correct tag will not be replaced."
        return 1
    fi
    rm -f -- "$notes_file"
    printf '[OK] Published CYBEROPS v%s.\n' "$version"
}

main() {
    local action="${1:-}"
    local version="${2:-}"

    if (($# != 2)); then
        release_usage >&2
        return 2
    fi
    case "$action" in
        check) release_check "$version" ;;
        preview) release_preview "$version" ;;
        publish) publish_release "$version" ;;
        *)
            release_usage >&2
            return 2
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
