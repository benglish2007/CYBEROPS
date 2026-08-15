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

available_stacks=(
    "/srv/stacks/alpha/compose.yml"
    "/srv/stacks/beta/docker-compose.yaml"
    "/srv/stacks/gamma/compose.yaml"
)
selected_stacks=()

select_compose_stacks available_stacks selected_stacks <<<"2, 1 2" >/dev/null
if ((${#selected_stacks[@]} == 2)) &&
    [[ "${selected_stacks[0]}" == "${available_stacks[1]}" ]] &&
    [[ "${selected_stacks[1]}" == "${available_stacks[0]}" ]]; then
    selection_result=selected
else
    selection_result=incorrect
fi
record_result "selects numbered stacks and removes duplicates" "$selection_result" selected

selected_stacks=()
select_compose_stacks available_stacks selected_stacks <<<"A" >/dev/null
record_result "selects every stack with A" "${#selected_stacks[@]}" 3

selected_stacks=()
set +e
select_compose_stacks available_stacks selected_stacks <<<"Q" >/dev/null
cancel_status=$?
set -e
record_result "cancels stack selection with Q" "$cancel_status" 1

selected_stacks=()
select_compose_stacks available_stacks selected_stacks <<<$'9\n3' >/dev/null
retry_output="$(select_compose_stacks available_stacks selected_stacks <<<$'9\n3')"
if [[ "$retry_output" == *"Invalid stack selection"* ]] &&
    ((${#selected_stacks[@]} == 1)) &&
    [[ "${selected_stacks[0]}" == "${available_stacks[2]}" ]]; then
    retry_result=recovered
else
    retry_result=incorrect
fi
record_result "re-prompts after an invalid selection" "$retry_result" recovered

selected_stacks=("${available_stacks[1]}")
plan_output="$(show_docker_update_plan selected_stacks)"
if [[ "$plan_output" == *"PROJECT: beta"* ]] &&
    [[ "$plan_output" == *"${available_stacks[1]}"* ]] &&
    [[ "$plan_output" == *"pull"* ]] &&
    [[ "$plan_output" == *"up -d --remove-orphans"* ]] &&
    [[ "$plan_output" == *"docker image prune -f"* ]] &&
    [[ "$plan_output" == *"separate confirmation"* ]] &&
    [[ "$plan_output" != *"PROJECT: alpha"* ]]; then
    plan_result=exact
else
    plan_result=incomplete
fi
record_result "preflight plan lists only selected projects and actions" "$plan_result" exact

selection_output="$(select_compose_stacks available_stacks selected_stacks <<<"Q" || true)"
if [[ "$selection_output" == *"[01] alpha"* &&
    "$selection_output" == *"[02] beta"* &&
    "$selection_output" == *"[03] gamma"* ]]; then
    discovery_result=listed
else
    discovery_result=incomplete
fi
record_result "selection menu lists discovered project paths" "$discovery_result" listed

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
