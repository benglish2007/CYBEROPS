#!/usr/bin/env bash

# UI contract
# -----------
# Inputs:
#   Theme/version state from lib/runtime.sh and dry-run helpers from lib/core.sh.
# Outputs:
#   Human-facing banners, menus, prompts, warnings, and confirmations.
# Return statuses:
#   Confirmation helpers return success only for the exact required response;
#   prompts write their result into the caller-provided variable name.
# Side effects:
#   Reads interactive input and may clear the terminal. Loading this module
#   produces no output and performs no terminal mutation.

typewrite() {
    local text="$1"
    local delay="${2:-0.008}"
    local i
    for ((i = 0; i < ${#text}; i++)); do
        printf '%s' "${text:i:1}"
        sleep "$delay"
    done
    printf '\n'
}

pause() {
    printf '\n%b[ RETURN ]%b Press Enter to reconnect to the control deck...' \
        "$MAGENTA" "$RESET"
    read -r _
}

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear || printf '\033c'
}

separator() {
    printf '%*s\n' 78 '' | tr ' ' '='
}

ui_section() {
    local title="$1"
    local subtitle="${2:-SELECT AN OPERATION}"

    printf '%b╭─[%b %s %b]──────────────────────────────────────────────%b\n' \
        "$MAGENTA" "$CYAN" "$title" "$MAGENTA" "$RESET"
    printf '%b│%b %s%b\n' "$MAGENTA" "$DIM" "$subtitle" "$RESET"
    printf '%b╰──────────────────────────────────────────────────────────%b\n\n' \
        "$MAGENTA" "$RESET"
}

menu_item() {
    local key="$1"
    local label="$2"
    local hint="${3:-}"

    printf '  %b[%02d]%b  %-34s' "$CYAN" "$key" "$RESET" "$label"
    if [[ -n "$hint" ]]; then
        printf ' %b%s%b' "$DIM" "$hint" "$RESET"
    fi
    printf '\n'
}

prompt_choice() {
    local variable_name="$1"
    local channel="${2:-COMMAND}"
    local response

    printf '\n%b%s%b %b>%b ' "$MAGENTA" "$channel" "$RESET" "$CYAN" "$RESET"
    IFS= read -r response
    printf -v "$variable_name" '%s' "$response"
}

prompt_path() {
    local variable_name="$1"
    local label="${2:-FILE PATH}"
    local initial_path="${3:-$HOME/}"
    local first_character
    local last_character
    local response

    printf '%bTAB%b autocomplete  //  %bCTRL-U%b clear path\n' \
        "$CYAN" "$RESET" "$MAGENTA" "$RESET"
    printf '%b%s%b %b>%b ' "$MAGENTA" "$label" "$RESET" "$CYAN" "$RESET"

    if [[ -t 0 ]]; then
        # Readline inserts backslashes when completing paths containing spaces.
        # Omitting -r lets read convert those escapes back to the real path.
        # shellcheck disable=SC2162
        IFS= read -e -i "$initial_path" response
    else
        # Keep noninteractive input consistent with Readline's escaped paths.
        # shellcheck disable=SC2162
        IFS= read response
    fi

    if ((${#response} >= 2)); then
        first_character="${response:0:1}"
        last_character="${response: -1}"
        if [[ "$first_character" == '"' && "$last_character" == '"' ]] ||
            [[ "$first_character" == "'" && "$last_character" == "'" ]]; then
            response="${response:1:${#response}-2}"
        fi
    fi

    case "$response" in
        \~) response="$HOME" ;;
        \~/*) response="$HOME/${response:2}" ;;
    esac

    # Readline appends a separator space after uniquely completing a file.
    # Remove it only when it is not part of a real path.
    if [[ "$response" == *' ' && ! -e "$response" && -e "${response% }" ]]; then
        response="${response% }"
    fi

    printf -v "$variable_name" '%s' "$response"
}

invalid_selection() {
    report_error "Unknown command channel." "Select one of the numbered access nodes."
    sleep 1
}

banner() {
    clear_screen

    printf '%b╔══[%b CYBEROPS // NEON GRID %b]══════════════════[%b NODE ONLINE %b]══╗%b\n' \
        "$MAGENTA" "$CYAN" "$MAGENTA" "$GREEN" "$MAGENTA" "$RESET"

    if have figlet; then
        if have lolcat; then
            figlet -f slant "CYBEROPS" | lolcat
        else
            printf '%b\n' "$CYAN"
            figlet -f slant "CYBEROPS"
            printf '%b\n' "$RESET"
        fi
    else
        printf '%b\n' "$CYAN"
        cat <<'EOF'
   ________  ______  __________  ____  ____  ____  _____
  / ____/\\ \/ / __ )/ ____/ __ \/ __ \/ __ \/ __ \/ ___/
 / /      \  / __  / __/ / /_/ / / / / /_/ / /_/ /\__ \
/ /___    / / /_/ / /___/ _, _/ /_/ / ____/ ____/___/ /
\____/   /_/_____/_____/_/ |_|\____/_/   /_/    /____/
EOF
        printf '%b\n' "$RESET"
    fi

    printf '%b╚══════════════════════════════════════════════════════════════╝%b\n' \
        "$MAGENTA" "$RESET"
    printf '%bBUILD %s%b  //  UNIFIED LINUX OPERATIONS CONSOLE  //  SESSION ACTIVE\n' \
        "$CYAN" "$VERSION" "$RESET"
    if is_dry_run; then
        printf '%b[ PREVIEW PROTOCOL ]%b State-changing commands are simulation-only.\n' \
            "$YELLOW" "$RESET"
    fi
    echo
}

warn_destructive() {
    printf '%b╔═[ DESTRUCTIVE PROTOCOL ]═══════════════════════════════════╗%b\n' \
        "$RED" "$RESET"
    printf '%b║ WARNING: THIS OPERATION CAN PERMANENTLY DESTROY DATA.      ║%b\n' \
        "$RED" "$RESET"
    printf '%b╚════════════════════════════════════════════════════════════╝%b\n' \
        "$RED" "$RESET"
}

confirm_yes() {
    local prompt="${1:-Type YES to continue: }"
    local answer
    printf '%bCONFIRM%b // %s' "$RED" "$RESET" "$prompt"
    read -r answer
    [[ "$answer" == "YES" ]]
}
