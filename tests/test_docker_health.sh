#!/usr/bin/env bash

# Health timing overrides are consumed by the dynamically loaded Docker module.
# shellcheck disable=SC2034

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0
compose_mode=""
compose_counter_file=""

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
    case "$compose_mode" in
        empty)
            return 0
            ;;
        completed)
            printf 'job-ok\n'
            ;;
        failed)
            printf 'job-failed\n'
            ;;
        healthy)
            printf 'web-healthy\n'
            ;;
        replacing)
            local count
            count="$(<"$compose_counter_file")"
            count=$((count + 1))
            printf '%s\n' "$count" >"$compose_counter_file"
            if ((count == 1)); then
                printf 'web-old\n'
            else
                printf 'web-new\n'
            fi
            ;;
        pending)
            printf 'web-created\n'
            ;;
    esac
}

docker() {
    local format="$3"
    local cid="$4"

    case "$format:$cid" in
        *State.Status*:job-ok | *State.Status*:job-failed)
            printf 'exited\n'
            ;;
        *State.ExitCode*:job-ok)
            printf '0\n'
            ;;
        *State.ExitCode*:job-failed)
            printf '23\n'
            ;;
        *State.Status*:web-healthy | *State.Status*:web-new)
            printf 'running\n'
            ;;
        *State.Health*:web-healthy | *State.Health*:web-new)
            printf 'healthy\n'
            ;;
        *State.Status*:web-old)
            printf 'running\n'
            ;;
        *State.Health*:web-old)
            printf 'starting\n'
            ;;
        *State.Status*:web-created)
            printf 'created\n'
            ;;
        *)
            printf 'unknown\n'
            return 1
            ;;
    esac
}

date() {
    printf '100\n'
}

sleep() {
    return 0
}

HEALTH_TIMEOUT=1
HEALTH_INTERVAL=1

compose_mode=completed
completed_output="$(check_stack_health /srv/stacks/jobs/compose.yml 2>&1)"
completed_status=$?
record_result "accepts a successful one-shot container" "$completed_status" 0
if [[ "$completed_output" == *"one-shot exit 0"* ]]; then
    completed_message=clear
else
    completed_message=missing
fi
record_result "reports successful one-shot completion" "$completed_message" clear

compose_mode=failed
set +e
failed_output="$(check_stack_health /srv/stacks/jobs/compose.yml 2>&1)"
failed_status=$?
set -e
record_result "rejects a failed one-shot container" "$failed_status" 1
if [[ "$failed_output" == *"status 23"* ]]; then
    failed_message=clear
else
    failed_message=missing
fi
record_result "reports the one-shot exit status" "$failed_message" clear

compose_mode=healthy
check_stack_health /srv/stacks/web/compose.yml >/dev/null
record_result "accepts a healthy running container" "$?" 0

compose_counter_file="$(mktemp)"
printf '0\n' >"$compose_counter_file"
compose_mode=replacing
check_stack_health /srv/stacks/web/compose.yml >/dev/null
replacement_status=$?
replacement_queries="$(<"$compose_counter_file")"
record_result "follows a replacement container during polling" "$replacement_status" 0
record_result "refreshes the Compose container list" "$replacement_queries" 2
rm -f -- "$compose_counter_file"

compose_mode=empty
set +e
empty_output="$(check_stack_health /srv/stacks/empty/compose.yml 2>&1)"
empty_status=$?
set -e
record_result "rejects a project with no containers" "$empty_status" 1
if [[ "$empty_output" == *"No Compose containers detected"* ]]; then
    empty_message=clear
else
    empty_message=missing
fi
record_result "reports a project with no containers" "$empty_message" clear

HEALTH_TIMEOUT=0
compose_mode=pending
set +e
pending_output="$(check_stack_health /srv/stacks/web/compose.yml 2>&1)"
pending_status=$?
set -e
record_result "times out a container that remains pending" "$pending_status" 1
if [[ "$pending_output" == *"Health-check timeout"* ]]; then
    timeout_message=clear
else
    timeout_message=missing
fi
record_result "reports the health-check timeout" "$timeout_message" clear

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
