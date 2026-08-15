#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

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

compose_for_file() {
    printf 'container-one\n'
    printf 'container-two\n'
}

docker() {
    local cid="$4"
    printf 'container=/%s service=%s image_ref=example/%s:latest image_id=sha256:%s state=running exit=0 health=healthy\n' \
        "$cid" "$cid" "$cid" "$cid"
}

date() {
    case "${1:-}" in
        +%s) printf '100\n' ;;
        +%Y%m%d-%H%M%S) printf '20260815-120000\n' ;;
        *) printf '2026-08-15 12:00:00\n' ;;
    esac
}

test_state_home="$(mktemp -d)"
XDG_STATE_HOME="$test_state_home"
STACK_ROOT=/srv/stacks
create_docker_state_report >/dev/null
create_status=$?
record_result "creates a Docker recovery report" "$create_status" 0
case "$DOCKER_REPORT_FILE" in
    "$test_state_home"/cyberops/docker/*) report_location=private-state-dir ;;
    *) report_location=unexpected ;;
esac
record_result "stores reports under the private state directory" "$report_location" private-state-dir

capture_stack_state "BEFORE example" /srv/stacks/example/compose.yml
capture_status=$?
report_content="$(<"$DOCKER_REPORT_FILE")"

record_result "captures Compose state successfully" "$capture_status" 0
if [[ "$report_content" == *"[BEFORE example]"* &&
      "$report_content" == *"Compose file: /srv/stacks/example/compose.yml"* ]]; then
    header_result=present
else
    header_result=missing
fi
record_result "records phase and Compose file" "$header_result" present

if [[ "$report_content" == *"container=/container-one"* &&
      "$report_content" == *"image_id=sha256:container-one"* &&
      "$report_content" == *"container=/container-two"* &&
      "$report_content" == *"health=healthy"* ]]; then
    state_result=complete
else
    state_result=incomplete
fi
record_result "records container and immutable image state" "$state_result" complete

report_mode="$(stat -c '%a' "$DOCKER_REPORT_FILE")"
record_result "test recovery report is private" "$report_mode" 600

rm -f -- "$DOCKER_REPORT_FILE"
rmdir -- "$test_state_home/cyberops/docker" "$test_state_home/cyberops" "$test_state_home"

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
