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

clear_screen() {
    return 0
}

have() {
    return 1
}

DRY_RUN=0
banner_output="$(banner | strip_ansi)"
if [[ "$banner_output" == *"CYBEROPS // NEON GRID"* &&
    "$banner_output" == *"BUILD 2.7.1"* &&
    "$banner_output" == *"NODE ONLINE"* ]]; then
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

mapfile -t destructive_box_lines < <(warn_destructive | strip_ansi)
destructive_box_width=${#destructive_box_lines[0]}
if ((${#destructive_box_lines[1]} == destructive_box_width && \
    ${#destructive_box_lines[2]} == destructive_box_width)); then
    destructive_box_result=aligned
else
    destructive_box_result=uneven
fi
record_result "destructive warning box uses consistent border widths" \
    "$destructive_box_result" aligned

item_output="$(menu_item 3 "VPN Control" "NETWORK // TUNNELS" | strip_ansi)"
if [[ "$item_output" == *"[03]"* &&
    "$item_output" == *"VPN Control"* &&
    "$item_output" == *"NETWORK // TUNNELS"* ]]; then
    item_result=aligned
else
    item_result=missing
fi
record_result "menu nodes include zero-padded keys and subsystem tags" "$item_result" aligned

navigation_output="$(menu_navigation_item 0 "Exit Interface" "SESSION // DISCONNECT" | strip_ansi)"
if [[ "$navigation_output" == $'\n  [00]'* &&
    "$navigation_output" == *"Exit Interface"* ]]; then
    navigation_result=separated
else
    navigation_result=joined
fi
record_result "navigation rows are visually separated from operations" \
    "$navigation_result" separated

prompt_result=""
prompt_choice prompt_result "CYBEROPS" <<<"7" >/dev/null
record_result "themed prompt preserves the selected value" "$prompt_result" 7

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

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
