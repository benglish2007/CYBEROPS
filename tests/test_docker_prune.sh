#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0
confirmation_result=1
docker_calls=""

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

confirm_yes() {
    return "$confirmation_result"
}

docker() {
    docker_calls="$*"
}

DRY_RUN=0
confirmation_result=1
docker_calls=""
decline_output="$(offer_image_prune 2>&1)"
if [[ "$decline_output" == *"Unused image pruning skipped"* && -z "$docker_calls" ]]; then
    decline_result=safe
else
    decline_result=unsafe
fi
record_result "declining prune performs no Docker mutation" "$decline_result" safe

DRY_RUN=1
confirmation_result=0
docker_calls=""
preview_output="$(offer_image_prune 2>&1)"
if [[ "$preview_output" == *"[DRY-RUN] Prune unused Docker images"* &&
      "$preview_output" == *"docker image prune -f"* &&
      -z "$docker_calls" ]]; then
    preview_result=safe
else
    preview_result=unsafe
fi
record_result "dry-run previews separately confirmed pruning" "$preview_result" safe

DRY_RUN=0
confirmation_result=0
docker_calls=""
offer_image_prune >/dev/null
record_result "confirmed prune invokes the exact Docker command" "$docker_calls" "image prune -f"

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
