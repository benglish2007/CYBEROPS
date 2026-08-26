#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2329 # Mocks are invoked by sourced plugin code.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_PLUGIN_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_PLUGIN_DIR"' EXIT
mkdir -p -- "$TEST_PLUGIN_DIR/builtin" "$TEST_PLUGIN_DIR/user"
CYBEROPS_BUILTIN_PLUGIN_DIR="$TEST_PLUGIN_DIR/builtin"
CYBEROPS_AVAILABLE_PLUGIN_DIR="$REPO_DIR/plugins-available"
CYBEROPS_USER_PLUGIN_DIR="$TEST_PLUGIN_DIR/user"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

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

installed_plugins="$(discover_plugins vpn)"
record_result "ships no preinstalled VPN plugins" "$installed_plugins" ""

available_plugins="$(discover_available_plugins vpn | tr '\n' ' ')"
case "$available_plugins" in
    *"vpn:expressvpn:"*"vpn:mullvad:"*"vpn:nordvpn:"*"vpn:protonvpn:"*"vpn:tailscale:"*) discovery_result=found ;;
    *) discovery_result=missing ;;
esac
record_result "discovers optional VPN plugins" "$discovery_result" found

install_user_plugin vpn tailscale >/dev/null
tailscale_error_file="$(mktemp)"
tailscale_path="$(plugin_path_for vpn tailscale 2>"$tailscale_error_file")"
record_result "installs and resolves a selected VPN plugin" \
    "$tailscale_path" "$TEST_PLUGIN_DIR/user/vpn/tailscale/plugin.sh"
record_result "resolves a plugin without stderr warnings" \
    "$(<"$tailscale_error_file")" ""
rm -f -- "$tailscale_error_file"

if validate_plugin vpn "$tailscale_path" >/dev/null; then
    tailscale_valid=valid
else
    tailscale_valid=invalid
fi
record_result "validates a well-formed VPN plugin" "$tailscale_valid" valid

uninstall_user_plugin vpn tailscale >/dev/null
if [[ ! -e "$tailscale_path" ]]; then
    uninstall_result=removed
else
    uninstall_result=present
fi
record_result "uninstalls a selected user VPN plugin" "$uninstall_result" removed

mkdir -p -- "$TEST_PLUGIN_DIR/user/vpn/broken"
printf 'CYBEROPS_PLUGIN_ID="bad id"\nCYBEROPS_PLUGIN_CATEGORY="vpn"\n' \
    >"$TEST_PLUGIN_DIR/user/vpn/broken/plugin.sh"
set +e
broken_output="$(validate_plugin vpn "$TEST_PLUGIN_DIR/user/vpn/broken/plugin.sh" 2>&1)"
broken_status=$?
set -e
record_result "rejects malformed plugin metadata" "$broken_status" 1
case "$broken_output" in
    *"invalid plugin id"*) broken_message=clear ;;
    *) broken_message=unclear ;;
esac
record_result "explains malformed plugin rejection" "$broken_message" clear

mkdir -p -- "$TEST_PLUGIN_DIR/user/vpn/demo"
cat >"$TEST_PLUGIN_DIR/user/vpn/demo/plugin.sh" <<'PLUGIN'
CYBEROPS_PLUGIN_ID="demo"
CYBEROPS_PLUGIN_CATEGORY="vpn"
CYBEROPS_PLUGIN_NAME="Demo VPN"
CYBEROPS_PLUGIN_PROVIDER="Demo"
CYBEROPS_PLUGIN_ACTIONS=(status connect)
CYBEROPS_PLUGIN_SUDO_ACTIONS=(connect)
CYBEROPS_PLUGIN_REQUIRED_COMMANDS=(democtl)
CYBEROPS_PLUGIN_STATUS_RECOVERY="Install democtl."
CYBEROPS_PLUGIN_CONNECT_RECOVERY="Authenticate democtl."
cyberops_plugin_status() { run_checked "Demo VPN status query" "$CYBEROPS_PLUGIN_STATUS_RECOVERY" democtl status; }
cyberops_plugin_connect() { run_mutating_checked "Demo VPN connection" "$CYBEROPS_PLUGIN_CONNECT_RECOVERY" democtl connect; }
PLUGIN

demo_path="$(plugin_path_for vpn demo)"
record_result "resolves user-installed VPN plugin by id" \
    "$demo_path" "$TEST_PLUGIN_DIR/user/vpn/demo/plugin.sh"

if load_plugin vpn "$demo_path" >/dev/null && plugin_action_supported connect; then
    action_result=supported
else
    action_result=unsupported
fi
record_result "loads supported plugin actions" "$action_result" supported

missing_output="$(run_vpn_plugin_action demo status 2>&1 || true)"
case "$missing_output" in
    *"Missing required command(s): democtl"*) missing_deps=clear ;;
    *) missing_deps=unclear ;;
esac
record_result "reports missing plugin dependencies before execution" "$missing_deps" clear

printf '1..%d\n' "$tests_run"
((tests_failed == 0))
