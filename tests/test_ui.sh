#!/usr/bin/env bash

# DRY_RUN is consumed by the dynamically loaded UI module.
# shellcheck disable=SC2034

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

strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

normalize_box_borders() {
    sed -e 's/╔/+/g' -e 's/╗/+/g' -e 's/╚/+/g' -e 's/╝/+/g' \
        -e 's/═/-/g' -e 's/║/|/g'
}

clear_screen() {
    return 0
}

have() {
    return 1
}

DRY_RUN=0
banner_output="$(banner | strip_ansi)"
if [[ "$banner_output" == *"CYBEROPS // NIGHT CITY RELAY"* &&
    "$banner_output" == *"BUILD://2.13"* &&
    "$banner_output" == *"THREATGRID: ONLINE"* &&
    "$banner_output" == *"LIVE SIGNAL MATRIX"* ]]; then
    banner_result=themed
else
    banner_result=missing
fi
record_result "banner exposes the cyberpunk control-deck theme" "$banner_result" themed

section_output="$(ui_section "CONTROL DECK" "SELECT AN OPERATIONS NODE" | strip_ansi)"
if [[ "$section_output" == *"CONTROL DECK"* &&
    "$section_output" == *"SELECT AN OPERATIONS NODE"* ]]; then
    section_result=themed
else
    section_result=missing
fi
record_result "section headers include title and subsystem context" "$section_result" themed

mapfile -t destructive_box_lines < <(warn_destructive | strip_ansi | normalize_box_borders)
destructive_box_width=${#destructive_box_lines[0]}
if ((${#destructive_box_lines[1]} == destructive_box_width && \
    ${#destructive_box_lines[2]} == destructive_box_width)); then
    destructive_box_result=aligned
else
    destructive_box_result=uneven
fi
record_result "destructive warning box uses consistent border widths" \
    "$destructive_box_result" aligned
destructive_wording="$(warn_destructive | strip_ansi)"
if [[ "$destructive_wording" == *"BLACK ICE // DESTRUCTIVE PROTOCOL"* ]]; then
    destructive_language=themed
else
    destructive_language=generic
fi
record_result "overdrive destructive boundary uses explicit themed language" \
    "$destructive_language" themed

item_output="$(menu_item 3 "VPN Control" "NETWORK // TUNNELS" | strip_ansi)"
if [[ "$item_output" == *"[03]"* &&
    "$item_output" == *"VPN Control"* &&
    "$item_output" == *"NETWORK // TUNNELS"* ]]; then
    item_result=aligned
else
    item_result=missing
fi
record_result "menu nodes include zero-padded keys and subsystem tags" "$item_result" aligned

privileged_output="$(menu_privileged_item 2 "Upgrade packages" "APT // UPGRADE" | strip_ansi)"
if [[ "$privileged_output" == *"[02]"* && "$privileged_output" == *"[SUDO]"* &&
    "$privileged_output" == *"APT // UPGRADE"* ]]; then
    privilege_result=visible
else
    privilege_result=missing
fi
record_result "privileged menu rows include a text-safe sudo marker" \
    "$privilege_result" visible

if [[ "$item_output" != *"[SUDO]"* ]]; then
    ordinary_privilege_result=clean
else
    ordinary_privilege_result=marked
fi
record_result "ordinary menu rows omit the sudo marker" "$ordinary_privilege_result" clean

saved_magenta="$MAGENTA"
saved_cyan="$CYAN"
MAGENTA='<NAV>'
CYAN='<ITEM>'
navigation_colored_output="$(menu_navigation_item 0 "Exit Interface" "SESSION // DISCONNECT")"
MAGENTA="$saved_magenta"
CYAN="$saved_cyan"
navigation_output="$(printf '%s\n' "$navigation_colored_output" | strip_ansi | sed 's/<NAV>//g')"
if [[ "$navigation_output" == $'\n  ├─[00]'* &&
    "$navigation_output" == *"Exit Interface"* ]]; then
    navigation_result=separated
else
    navigation_result=joined
fi
record_result "navigation rows are visually separated from operations" \
    "$navigation_result" separated
if [[ "$navigation_colored_output" == *'<NAV>├─[00]'* &&
    "$navigation_colored_output" != *'<ITEM>├─[00]'* ]]; then
    navigation_color_result=distinct
else
    navigation_color_result=shared
fi
record_result "navigation keys use a distinct palette color" \
    "$navigation_color_result" distinct

prompt_result=""
prompt_choice prompt_result "CYBEROPS" <<<"7" >/dev/null
record_result "themed prompt preserves the selected value" "$prompt_result" 7

set +e
confirmation_output="$(confirm_yes "Type YES to continue: " <<<'YES' | strip_ansi)"
confirmation_status=$?
set -e
if [[ "$confirmation_status" == "0" &&
    "$confirmation_output" == *"[ AUTH GATE ] Type YES to continue:"* ]]; then
    confirmation_result=themed
else
    confirmation_result=missing
fi
record_result "destructive confirmation uses the overdrive auth gate" \
    "$confirmation_result" themed

CYBEROPS_THEME=classic
classic_banner_output="$(banner | strip_ansi)"
if [[ "$classic_banner_output" == *"CYBEROPS // NEON GRID"* &&
    "$classic_banner_output" == *"NODE ONLINE"* ]]; then
    classic_result=available
else
    classic_result=missing
fi
record_result "classic presentation remains available for comparison" \
    "$classic_result" available
CYBEROPS_THEME=neon-overdrive

HEADER_TIME='2088-08-15 23:59:59 AMM'
HEADER_ROUTE_STATE=ROUTED
HEADER_IFACE=enp7s0
HEADER_ADDRESS=192.0.2.13
HEADER_VPN=tailscale0
HEADER_VPN_ADDRESS=100.64.0.13
HEADER_MAC=02:13:37:aa:bb:cc
HEADER_MAC_STATE=MODIFIED
COLUMNS=80
signal_output="$(render_header_telemetry | strip_ansi)"
if [[ "$signal_output" == *"║ LOCAL │ TIME 2088-08-15"* &&
    "$signal_output" == *"║ NET   │ IFACE enp7s0"* &&
    "$signal_output" == *"║ VPN   │ STATUS [ON // tailscale0]"* &&
    "$signal_output" == *"║ L2    │ [MODIFIED // 02:13:37:aa:bb:cc]"* ]]; then
    signal_result=legible
else
    signal_result=unstructured
fi
record_result "overdrive signal matrix uses aligned instrument rows" \
    "$signal_result" legible

COLUMNS=50
narrow_signal_output="$(render_header_telemetry | strip_ansi)"
if [[ "$narrow_signal_output" == *"║ TIME  │ 2088-08-15"* &&
    "$narrow_signal_output" == *"║ LINK  │ ROUTED"* &&
    "$narrow_signal_output" == *"║ NET   │ IFACE enp7s0"* &&
    "$narrow_signal_output" == *"║ IP    │ 192.0.2.13"* &&
    "$narrow_signal_output" == *"║ VPN   │ STATUS [ON // tailscale0]"* &&
    "$narrow_signal_output" == *"║ V-IP  │ 100.64.0.13"* &&
    "$narrow_signal_output" == *"║ L2    │ [MODIFIED // 02:13:37:aa:bb:cc]"* ]]; then
    narrow_signal_result=legible
else
    narrow_signal_result=compressed
fi
record_result "narrow terminals split telemetry into legible instrument rows" \
    "$narrow_signal_result" legible
COLUMNS=80

completed_path=""
prompt_path completed_path "FILE PATH" <<<"$HOME/My\ File.iso" >/dev/null
record_result "path completion escapes resolve to literal spaces" \
    "$completed_path" "$HOME/My File.iso"

completed_file=""
prompt_path completed_file "FILE PATH" <<<"$SCRIPT_DIR/../README.md " >/dev/null
record_result "Readline completion separator is removed from existing files" \
    "$completed_file" "$SCRIPT_DIR/../README.md"

quoted_path=""
prompt_path quoted_path "FILE PATH" <<<'"~/My File.iso"' >/dev/null
record_result "quoted tilde paths are normalized safely" \
    "$quoted_path" "$HOME/My File.iso"

path_prompt_output="$(prompt_path ignored_path "FILE PATH" <<<"/tmp/example" | strip_ansi)"
if [[ "$path_prompt_output" == *"TAB autocomplete"* &&
    "$path_prompt_output" == *"CTRL-U clear path"* ]]; then
    path_hint_result=visible
else
    path_hint_result=missing
fi
record_result "path prompt explains completion controls" "$path_hint_result" visible

DRY_RUN=1
preview_output="$(banner | strip_ansi)"
if [[ "$preview_output" == *"PREVIEW PROTOCOL"* ]]; then
    preview_result=visible
else
    preview_result=missing
fi
record_result "dry-run state remains visible in the themed banner" "$preview_result" visible

disable_color
plain_feedback_output="$(
    report_success "Operation complete."
    report_warning "Verify the uplink."
    report_error "Uplink unavailable." "Inspect the active route."
)"
if [[ "$plain_feedback_output" == *"[ ACK ] Operation complete."* &&
    "$plain_feedback_output" == *"[ CAUTION ] Verify the uplink."* &&
    "$plain_feedback_output" == *"[ FAULT ] Uplink unavailable."* &&
    "$plain_feedback_output" == *"RECOVERY:: Inspect the active route."* &&
    "$plain_feedback_output" != *$'\033['* ]]; then
    plain_feedback_result=legible
else
    plain_feedback_result=styled
fi
record_result "no-color mode preserves the feedback vocabulary without escapes" \
    "$plain_feedback_result" legible

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
