#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LAUNCHER="$REPO_DIR/cyberops.sh"
TEST_ROOT="$(mktemp -d)"
CONFIG_FILE="$TEST_ROOT/config"
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

printf '%s\n' \
    '# CYBEROPS test configuration' \
    'STACK_ROOT=/config/stacks' \
    'RETRY_DELAY=9' \
    'HEALTH_TIMEOUT=240' \
    'HEALTH_INTERVAL=8' \
    'FAILURE_LOG_LINES=120' \
    'DRY_RUN=1' \
    'CYBEROPS_NO_COLOR=1' \
    'CYBEROPS_HEADER_MAC=0' \
    'CYBEROPS_HEADER_PUBLIC_IP=0' >"$CONFIG_FILE"

config_path_output="$(CYBEROPS_CONFIG_FILE="$CONFIG_FILE" bash "$LAUNCHER" config path)"
record_result "config path prints the active file" "$config_path_output" "$CONFIG_FILE"

config_show_output="$(CYBEROPS_CONFIG_FILE="$CONFIG_FILE" bash "$LAUNCHER" config show)"
if [[ "$config_show_output" == *"Configuration state: loaded"* &&
    "$config_show_output" == *"STACK_ROOT=/config/stacks"* &&
    "$config_show_output" == *"RETRY_DELAY=9"* &&
    "$config_show_output" == *"DRY_RUN=1"* &&
    "$config_show_output" == *"CYBEROPS_HEADER_MAC=0"* ]]; then
    config_show_result=loaded
else
    config_show_result=missing
fi
record_result "config show reports file-backed values" "$config_show_result" loaded

environment_output="$(
    STACK_ROOT=/environment/stacks CYBEROPS_CONFIG_FILE="$CONFIG_FILE" \
        bash "$LAUNCHER" config show
)"
if [[ "$environment_output" == *"STACK_ROOT=/environment/stacks"* ]]; then
    precedence_result=environment
else
    precedence_result=config
fi
record_result "environment variables override configuration values" "$precedence_result" environment

set +e
valid_output="$(CYBEROPS_CONFIG_FILE="$CONFIG_FILE" bash "$LAUNCHER" config check 2>&1)"
valid_status=$?
set -e
record_result "config check accepts a valid file" "$valid_status" 0
if [[ "$valid_output" == *"configuration is valid"* ]]; then
    valid_message=shown
else
    valid_message=missing
fi
record_result "config check confirms valid state" "$valid_message" shown

printf '%s\n' 'UNKNOWN_SETTING=value' >"$CONFIG_FILE"
set +e
invalid_output="$(CYBEROPS_CONFIG_FILE="$CONFIG_FILE" bash "$LAUNCHER" config check 2>&1)"
invalid_status=$?
set -e
record_result "config check rejects unknown settings" "$invalid_status" 2
if [[ "$invalid_output" == *"unknown setting: UNKNOWN_SETTING"* ]]; then
    unknown_result=identified
else
    unknown_result=missing
fi
record_result "config check identifies the unknown key" "$unknown_result" identified

printf '%s\n' 'HEALTH_TIMEOUT' >"$CONFIG_FILE"
set +e
syntax_output="$(CYBEROPS_CONFIG_FILE="$CONFIG_FILE" bash "$LAUNCHER" config check 2>&1)"
syntax_status=$?
set -e
record_result "config check rejects malformed lines" "$syntax_status" 2
if [[ "$syntax_output" == *"KEY=VALUE syntax"* ]]; then
    syntax_result=identified
else
    syntax_result=missing
fi
record_result "config check identifies malformed syntax" "$syntax_result" identified

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
