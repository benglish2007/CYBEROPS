#!/usr/bin/env bash

# These declarations are consumed by the launcher and feature modules after
# this file is sourced; independent-file analysis cannot observe those reads.
# shellcheck disable=SC2034

# Runtime contract
# ----------------
# Inputs:
#   Optional environment overrides documented in README.md.
# Outputs:
#   No standard output or standard error during a successful load.
# Side effects:
#   Initializes mutable process-wide CYBEROPS configuration and operation state.
# Callers:
#   This file must be sourced by cyberops.sh; it is not a standalone command.

VERSION="2.5"

CYAN='\033[1;96m'
MAGENTA='\033[1;95m'
YELLOW='\033[1;93m'
RED='\033[1;91m'
GREEN='\033[1;92m'
DIM='\033[2m'
RESET='\033[0m'

# Docker updater defaults
STACK_ROOT="${STACK_ROOT:-/srv/stacks}"
RETRY_DELAY="${RETRY_DELAY:-5}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"
FAILURE_LOG_LINES="${FAILURE_LOG_LINES:-80}"
DRY_RUN="${DRY_RUN:-0}"

# Shared operation state. Modules communicate selected targets and registered
# cleanup work through these variables; functions that mutate them must state
# that side effect in their contract.
SELECTED_USB_DEVICE=""
SELECTED_USB_IDENTITY=""
ACTIVE_OPERATION=""
INTERRUPT_WARNING=""
NETWORK_RESTORE_INTERFACE=""
DOCKER_REPORT_FILE=""
