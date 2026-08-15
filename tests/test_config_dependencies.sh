#!/usr/bin/env bash

# Runtime configuration is consumed by functions loaded through the dynamic
# module manifest, which independent-file analysis cannot follow.
# shellcheck disable=SC2034

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cyberops.sh
source "$SCRIPT_DIR/../cyberops.sh"

tests_run=0
tests_failed=0
AVAILABLE_COMMANDS=""

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

expect_config_success() {
    local name="$1"

    if validate_configuration >/dev/null 2>&1; then
        record_result "$name" success success
    else
        record_result "$name" failure success
    fi
}

expect_config_failure() {
    local name="$1"

    if validate_configuration >/dev/null 2>&1; then
        record_result "$name" success failure
    else
        record_result "$name" failure failure
    fi
}

set_valid_configuration() {
    STACK_ROOT=/srv/stacks
    RETRY_DELAY=5
    HEALTH_TIMEOUT=120
    HEALTH_INTERVAL=5
    FAILURE_LOG_LINES=80
    DRY_RUN=0
    CYBEROPS_NO_COLOR=0
    CYBEROPS_LOGGING=1
    CYBEROPS_HEADER_TELEMETRY=1
    CYBEROPS_HEADER_TIME=1
    CYBEROPS_HEADER_LINK=1
    CYBEROPS_HEADER_VPN=1
    CYBEROPS_HEADER_IFACE=1
    CYBEROPS_HEADER_LOCAL_IP=1
    CYBEROPS_HEADER_MAC=1
    CYBEROPS_HEADER_PUBLIC_IP=0
    CYBEROPS_HEADER_TIMEOUT=2
    CYBEROPS_PUBLIC_IP_CACHE_TTL=300
}

set_valid_configuration
expect_config_success "accepts the default configuration"

DRY_RUN=1
expect_config_success "accepts enabled dry-run mode"

set_valid_configuration
DRY_RUN=yes
expect_config_failure "rejects an invalid dry-run value"

set_valid_configuration
RETRY_DELAY=08
expect_config_success "accepts base-10 integers with leading zeroes"

set_valid_configuration
STACK_ROOT=/
expect_config_failure "rejects the filesystem root as STACK_ROOT"

set_valid_configuration
STACK_ROOT=relative/stacks
expect_config_failure "rejects a relative STACK_ROOT"

set_valid_configuration
STACK_ROOT=/srv/../
expect_config_failure "rejects parent traversal in STACK_ROOT"

set_valid_configuration
RETRY_DELAY=-1
expect_config_failure "rejects a negative retry delay"

set_valid_configuration
RETRY_DELAY=999999999999999999999999
expect_config_failure "rejects oversized integer input without overflow"

set_valid_configuration
HEALTH_TIMEOUT=0
expect_config_failure "rejects a zero health timeout"

set_valid_configuration
HEALTH_INTERVAL=121
expect_config_failure "rejects an interval longer than the timeout"

set_valid_configuration
FAILURE_LOG_LINES=many
expect_config_failure "rejects a nonnumeric log-line limit"

set_valid_configuration
CYBEROPS_HEADER_TELEMETRY=yes
expect_config_failure "rejects an invalid header telemetry toggle"

set_valid_configuration
CYBEROPS_HEADER_PUBLIC_IP=yes
expect_config_failure "rejects an invalid public-IP toggle"

set_valid_configuration
CYBEROPS_HEADER_TIMEOUT=0
expect_config_failure "rejects an unbounded header timeout"

set_valid_configuration
CYBEROPS_PUBLIC_IP_CACHE_TTL=10
expect_config_failure "rejects an undersized public-IP cache interval"

have() {
    local candidate

    for candidate in $AVAILABLE_COMMANDS; do
        [[ "$candidate" == "$1" ]] && return 0
    done
    return 1
}

AVAILABLE_COMMANDS="alpha beta gamma"
if require_commands alpha beta gamma >/dev/null 2>&1; then
    dependency_result=success
else
    dependency_result=failure
fi
record_result "accepts a complete dependency set" "$dependency_result" success

AVAILABLE_COMMANDS="alpha gamma"
dependency_output="$(require_commands alpha beta gamma delta 2>&1 || true)"
if [[ "$dependency_output" == *"beta delta"* ]]; then
    dependency_result=reported
else
    dependency_result=missing
fi
record_result "reports every missing dependency together" "$dependency_result" reported

set_valid_configuration
if STACK_ROOT=/ bash "$SCRIPT_DIR/../cyberops.sh" >/dev/null 2>&1; then
    startup_status=0
else
    startup_status=$?
fi
record_result "invalid startup configuration exits with status 2" "$startup_status" 2

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
