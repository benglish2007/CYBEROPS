#!/usr/bin/env bash
# shellcheck disable=SC2034 # Plugin metadata variables are consumed by sourced plugins and dispatchers.

# Plugin framework contract
# -------------------------
# Inputs:
#   Runtime directories plus plugin files under built-in and user plugin roots.
# Outputs:
#   Plugin discovery, validation, and action dispatch results.
# Return statuses:
#   Invalid or missing plugins return nonzero and report actionable faults.
# Side effects:
#   Loading a plugin sets the current CYBEROPS_PLUGIN_* metadata variables and
#   defines the plugin action functions from the selected plugin file only.

CYBEROPS_BUILTIN_PLUGIN_DIR="${CYBEROPS_BUILTIN_PLUGIN_DIR:-$CYBEROPS_SOURCE_DIR/plugins}"
CYBEROPS_USER_PLUGIN_DIR="${CYBEROPS_USER_PLUGIN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/cyberops/plugins}"
CYBEROPS_PLUGIN_ID=""
CYBEROPS_PLUGIN_CATEGORY=""
CYBEROPS_PLUGIN_NAME=""
CYBEROPS_PLUGIN_PROVIDER=""
CYBEROPS_PLUGIN_STATUS_RECOVERY=""
CYBEROPS_PLUGIN_CONNECT_RECOVERY=""
CYBEROPS_PLUGIN_DISCONNECT_RECOVERY=""
CYBEROPS_PLUGIN_BACKGROUND_ON_RECOVERY=""
CYBEROPS_PLUGIN_BACKGROUND_OFF_RECOVERY=""
CYBEROPS_PLUGIN_ACTIONS=()
CYBEROPS_PLUGIN_SUDO_ACTIONS=()
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=()
CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS=()

reset_plugin_metadata() {
    CYBEROPS_PLUGIN_ID=""
    CYBEROPS_PLUGIN_CATEGORY=""
    CYBEROPS_PLUGIN_NAME=""
    CYBEROPS_PLUGIN_PROVIDER=""
    CYBEROPS_PLUGIN_STATUS_RECOVERY=""
    CYBEROPS_PLUGIN_CONNECT_RECOVERY=""
    CYBEROPS_PLUGIN_DISCONNECT_RECOVERY=""
    CYBEROPS_PLUGIN_BACKGROUND_ON_RECOVERY=""
    CYBEROPS_PLUGIN_BACKGROUND_OFF_RECOVERY=""
    CYBEROPS_PLUGIN_ACTIONS=()
    CYBEROPS_PLUGIN_SUDO_ACTIONS=()
    CYBEROPS_PLUGIN_REQUIRED_COMMANDS=()
    CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS=()
    unset -f cyberops_plugin_status cyberops_plugin_connect \
        cyberops_plugin_disconnect cyberops_plugin_background_on \
        cyberops_plugin_background_off 2>/dev/null || true
}

plugin_realpath() {
    readlink -f -- "$1" 2>/dev/null
}

plugin_path_allowed() {
    local plugin_path="$1"
    local real_plugin
    local real_builtin
    local real_user

    [[ "$plugin_path" == */plugin.sh ]] || return 1
    [[ "$plugin_path" != *'/../'* && "$plugin_path" != */.. ]] || return 1
    real_plugin="$(plugin_realpath "$plugin_path")" || return 1
    real_builtin="$(plugin_realpath "$CYBEROPS_BUILTIN_PLUGIN_DIR")" || real_builtin=""
    real_user="$(plugin_realpath "$CYBEROPS_USER_PLUGIN_DIR")" || real_user=""

    if [[ -n "$real_builtin" && "$real_plugin" == "$real_builtin"/* ]]; then
        return 0
    fi
    if [[ -n "$real_user" && "$real_plugin" == "$real_user"/* ]]; then
        return 0
    fi
    return 1
}

load_plugin_file() {
    local plugin_path="$1"

    if [[ ! -r "$plugin_path" ]]; then
        report_error "Plugin is not readable: $plugin_path"
        return 1
    fi
    if ! plugin_path_allowed "$plugin_path"; then
        report_error "Plugin path is outside the allowed plugin roots: $plugin_path"
        return 1
    fi
    if ! bash -n "$plugin_path" >/dev/null 2>&1; then
        report_error "Plugin failed shell syntax validation: $plugin_path"
        return 1
    fi

    reset_plugin_metadata
    # Plugin paths are constrained to the built-in and user plugin roots above.
    # shellcheck disable=SC1090
    source "$plugin_path"
}

plugin_action_supported() {
    local requested_action="$1"
    local plugin_action

    for plugin_action in "${CYBEROPS_PLUGIN_ACTIONS[@]}"; do
        [[ "$plugin_action" == "$requested_action" ]] && return 0
    done
    return 1
}

plugin_action_requires_sudo() {
    local requested_action="$1"
    local plugin_action

    for plugin_action in "${CYBEROPS_PLUGIN_SUDO_ACTIONS[@]}"; do
        [[ "$plugin_action" == "$requested_action" ]] && return 0
    done
    return 1
}

validate_loaded_plugin() {
    local expected_category="$1"
    local plugin_action
    local function_name

    if [[ ! "$CYBEROPS_PLUGIN_ID" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        report_error "Plugin has invalid plugin id: ${CYBEROPS_PLUGIN_ID:-<empty>}"
        return 1
    fi
    if [[ "$CYBEROPS_PLUGIN_CATEGORY" != "$expected_category" ]]; then
        report_error "Plugin category mismatch for $CYBEROPS_PLUGIN_ID: expected $expected_category, got ${CYBEROPS_PLUGIN_CATEGORY:-<empty>}"
        return 1
    fi
    if [[ -z "$CYBEROPS_PLUGIN_NAME" || -z "$CYBEROPS_PLUGIN_PROVIDER" ]]; then
        report_error "Plugin $CYBEROPS_PLUGIN_ID must declare display name and provider."
        return 1
    fi
    if ((${#CYBEROPS_PLUGIN_ACTIONS[@]} == 0)); then
        report_error "Plugin $CYBEROPS_PLUGIN_ID must declare at least one supported action."
        return 1
    fi
    for plugin_action in "${CYBEROPS_PLUGIN_ACTIONS[@]}"; do
        if [[ ! "$plugin_action" =~ ^[a-z][a-z0-9_]*$ ]]; then
            report_error "Plugin $CYBEROPS_PLUGIN_ID has invalid action: $plugin_action"
            return 1
        fi
        function_name="cyberops_plugin_$plugin_action"
        if ! declare -F "$function_name" >/dev/null; then
            report_error "Plugin $CYBEROPS_PLUGIN_ID action '$plugin_action' does not define $function_name."
            return 1
        fi
    done
}

validate_plugin() {
    local expected_category="$1"
    local plugin_path="$2"

    load_plugin_file "$plugin_path" || return 1
    validate_loaded_plugin "$expected_category"
}

load_plugin() {
    local expected_category="$1"
    local plugin_path="$2"

    validate_plugin "$expected_category" "$plugin_path"
}

discover_plugins() {
    local category="$1"
    local root
    local plugin_path
    local seen_ids=" "

    for root in "$CYBEROPS_BUILTIN_PLUGIN_DIR" "$CYBEROPS_USER_PLUGIN_DIR"; do
        [[ -d "$root/$category" ]] || continue
        while IFS= read -r plugin_path; do
            [[ -n "$plugin_path" ]] || continue
            if validate_plugin "$category" "$plugin_path" >/dev/null 2>&1; then
                if [[ "$seen_ids" != *" $CYBEROPS_PLUGIN_ID "* ]]; then
                    printf '%s:%s:%s\n' "$category" "$CYBEROPS_PLUGIN_ID" "$plugin_path"
                    seen_ids+="$CYBEROPS_PLUGIN_ID "
                fi
            fi
        done < <(find "$root/$category" -mindepth 2 -maxdepth 2 -name plugin.sh -type f | sort)
    done
}

plugin_path_for() {
    local category="$1"
    local requested_id="$2"
    local descriptor
    local plugin_id
    local plugin_path

    while IFS= read -r descriptor; do
        plugin_id="${descriptor#*:}"
        plugin_id="${plugin_id%%:*}"
        plugin_path="${descriptor#*:*:}"
        if [[ "$plugin_id" == "$requested_id" ]]; then
            printf '%s\n' "$plugin_path"
            return 0
        fi
    done < <(discover_plugins "$category")

    report_error "No $category plugin found with id: $requested_id"
    return 1
}

plugin_dependencies_available() {
    local command_name
    local any_command
    local found_any=0
    local -a missing=()

    for command_name in "${CYBEROPS_PLUGIN_REQUIRED_COMMANDS[@]}"; do
        have "$command_name" || missing+=("$command_name")
    done
    if ((${#CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS[@]} > 0)); then
        for any_command in "${CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS[@]}"; do
            if have "$any_command"; then
                found_any=1
                break
            fi
        done
        if ((found_any == 0)); then
            missing+=("one of: ${CYBEROPS_PLUGIN_REQUIRED_ANY_COMMANDS[*]}")
        fi
    fi

    if ((${#missing[@]} > 0)); then
        report_error \
            "Missing required command(s): ${missing[*]}" \
            "Install the missing tools for the ${CYBEROPS_PLUGIN_NAME:-selected} plugin, then retry."
        return 1
    fi
    return 0
}

list_plugins() {
    local category_filter="${1:-}"
    local category
    local descriptor
    local plugin_path

    if [[ -n "$category_filter" ]]; then
        categories=("$category_filter")
    else
        categories=(vpn)
    fi

    for category in "${categories[@]}"; do
        while IFS= read -r descriptor; do
            plugin_path="${descriptor#*:*:}"
            load_plugin "$category" "$plugin_path" >/dev/null || continue
            printf '%s\t%s\t%s\t%s\n' \
                "$CYBEROPS_PLUGIN_CATEGORY" "$CYBEROPS_PLUGIN_ID" \
                "$CYBEROPS_PLUGIN_NAME" "${CYBEROPS_PLUGIN_ACTIONS[*]}"
        done < <(discover_plugins "$category")
    done
}

validate_all_plugins() {
    local category_filter="${1:-}"
    local category
    local root
    local plugin_path
    local failures=0

    if [[ -n "$category_filter" ]]; then
        categories=("$category_filter")
    else
        categories=(vpn)
    fi

    for category in "${categories[@]}"; do
        for root in "$CYBEROPS_BUILTIN_PLUGIN_DIR" "$CYBEROPS_USER_PLUGIN_DIR"; do
            [[ -d "$root/$category" ]] || continue
            while IFS= read -r plugin_path; do
                [[ -n "$plugin_path" ]] || continue
                if validate_plugin "$category" "$plugin_path" >/dev/null; then
                    printf 'valid\t%s\n' "$plugin_path"
                else
                    printf 'invalid\t%s\n' "$plugin_path"
                    ((failures += 1))
                fi
            done < <(find "$root/$category" -mindepth 2 -maxdepth 2 -name plugin.sh -type f | sort)
        done
    done
    ((failures == 0))
}
