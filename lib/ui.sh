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

    if [[ ! -t 1 || "$delay" == "0" ]]; then
        printf '%s\n' "$text"
        return
    fi

    for ((i = 0; i < ${#text}; i++)); do
        printf '%s' "${text:i:1}"
        sleep "$delay"
    done
    printf '\n'
}

pause() {
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '\n%b[ LINK HOLD ]%b Press Enter to rejoin the command lattice...' \
            "$MAGENTA" "$RESET"
    else
        printf '\n%b[ RETURN ]%b Press Enter to reconnect to the control deck...' \
            "$MAGENTA" "$RESET"
    fi
    read -r _
}

clear_screen() {
    [[ -t 1 ]] || return 0
    command -v clear >/dev/null 2>&1 && clear || printf '\033c'
}

separator() {
    printf '%*s\n' 78 '' | tr ' ' '='
}

ui_repeat() {
    local character="$1"
    local count="$2"
    local index

    for ((index = 0; index < count; index++)); do
        printf '%s' "$character"
    done
}

ui_section() {
    local title="$1"
    local subtitle="${2:-SELECT AN OPERATION}"
    local frame_width=64
    local fill

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        fill=$((frame_width - ${#title} - 7))
        printf '%b╭─┤%b %s %b├' "$MAGENTA" "$CYAN" "$title" "$MAGENTA"
        ui_repeat '─' "$fill"
        printf '╮%b\n' "$RESET"

        fill=$((frame_width - ${#subtitle} - 14))
        ((fill < 1)) && fill=1
        printf '%b│%b  CHANNEL:: %b%s%b' \
            "$MAGENTA" "$RESET" "$MUTED" "$subtitle" "$RESET"
        ui_repeat ' ' "$fill"
        printf '%b│%b\n' "$MAGENTA" "$RESET"

        fill=$((frame_width - 30))
        printf '%b╰─┤%b AWAITING OPERATOR INPUT %b├' \
            "$MAGENTA" "$PURPLE" "$MAGENTA"
        ui_repeat '─' "$fill"
        printf '╯%b\n\n' "$RESET"
    else
        printf '%b╭─[%b %s %b]──────────────────────────────────────────────%b\n' \
            "$MAGENTA" "$CYAN" "$title" "$MAGENTA" "$RESET"
        printf '%b│%b %s%b\n' "$MAGENTA" "$DIM" "$subtitle" "$RESET"
        printf '%b╰──────────────────────────────────────────────────────────%b\n\n' \
            "$MAGENTA" "$RESET"
    fi
}

render_menu_item() {
    local key="$1"
    local label="$2"
    local hint="${3:-}"
    local key_color="${4:-$CYAN}"
    local privilege="${5:-}"

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '  %b├─[%02d]%b %-30s' "$key_color" "$key" "$RESET" "$label"
    else
        printf '  %b[%02d]%b  %-31s' "$key_color" "$key" "$RESET" "$label"
    fi
    if [[ "$privilege" == "sudo" ]]; then
        printf '%b[SUDO]%b ' "$YELLOW" "$RESET"
    else
        printf '       '
    fi
    if [[ -n "$hint" ]]; then
        printf ' %b%s%b' "$DIM" "$hint" "$RESET"
    fi
    printf '\n'
}

menu_item() {
    render_menu_item "$1" "$2" "${3:-}" "$CYAN"
}

menu_privileged_item() {
    render_menu_item "$1" "$2" "${3:-}" "$CYAN" sudo
}

menu_navigation_item() {
    printf '\n'
    render_menu_item "$1" "$2" "${3:-}" "$MAGENTA"
}

prompt_choice() {
    local variable_name="$1"
    local channel="${2:-COMMAND}"
    local response

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '\n%b%s%b%b::%b%bEXEC%b %b❯%b ' \
            "$MAGENTA" "$channel" "$RESET" "$MUTED" "$RESET" \
            "$CYAN" "$RESET" "$MAGENTA" "$RESET"
    else
        printf '\n%b%s%b %b>%b ' "$MAGENTA" "$channel" "$RESET" "$CYAN" "$RESET"
    fi
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

render_vpn_badge() {
    if [[ "$HEADER_VPN" == "NONE" || -z "$HEADER_VPN" ]]; then
        printf '%b[OFF]%b' "$RED" "$RESET"
    else
        printf '%b[ON // %s]%b' "$GREEN" "$HEADER_VPN" "$RESET"
    fi
}

render_mac_badge() {
    case "$HEADER_MAC_STATE" in
        PERMANENT) printf '%b[PERMANENT // %s]%b' "$RED" "$HEADER_MAC" "$RESET" ;;
        MODIFIED) printf '%b[MODIFIED // %s]%b' "$GREEN" "$HEADER_MAC" "$RESET" ;;
        *) printf '%b[UNKNOWN // %s]%b' "$YELLOW" "$HEADER_MAC" "$RESET" ;;
    esac
}

render_signal_row() {
    local label="$1"
    local content="$2"
    local value_color="${3:-$WHITE}"
    local chunk
    local row_label="$label"
    local padding

    while :; do
        chunk="${content:0:56}"
        content="${content:56}"
        padding=$((56 - ${#chunk}))
        printf '%b║%b %b%-5s%b %b│%b %b%s%b' \
            "$MAGENTA" "$RESET" "$CYAN" "$row_label" "$RESET" \
            "$PURPLE" "$RESET" "$value_color" "$chunk" "$RESET"
        ui_repeat ' ' "$padding"
        printf '%b║%b\n' "$MAGENTA" "$RESET"
        [[ -n "$content" ]] || break
        row_label=""
    done
}

render_overdrive_header_telemetry() {
    local width="${COLUMNS:-80}"
    local local_status=""
    local network_status=""
    local vpn_status
    local mac_status
    local vpn_color="$GREEN"
    local mac_color="$YELLOW"

    [[ "$CYBEROPS_HEADER_TELEMETRY" == "1" ]] || return 0
    [[ "$width" =~ ^[0-9]+$ ]] || width=80

    if ((width < 70)); then
        [[ "$CYBEROPS_HEADER_TIME" == "0" ]] || render_signal_row "TIME" "$HEADER_TIME"
        [[ "$CYBEROPS_HEADER_LINK" == "0" ]] || render_signal_row "LINK" "$HEADER_ROUTE_STATE" "$GREEN"
        [[ "$CYBEROPS_HEADER_IFACE" == "0" ]] || render_signal_row "NET" "IFACE $HEADER_IFACE"
        [[ "$CYBEROPS_HEADER_LOCAL_IP" == "0" ]] || render_signal_row "IP" "$HEADER_ADDRESS"
    else
        if [[ "$CYBEROPS_HEADER_TIME" == "1" || "$CYBEROPS_HEADER_LINK" == "1" ]]; then
            local_status=""
            [[ "$CYBEROPS_HEADER_TIME" == "0" ]] || local_status="TIME $HEADER_TIME"
            [[ "$CYBEROPS_HEADER_LINK" == "0" ]] || local_status+="${local_status:+  //  }LINK $HEADER_ROUTE_STATE"
            render_signal_row "LOCAL" "$local_status"
        fi
        network_status=""
        [[ "$CYBEROPS_HEADER_IFACE" == "0" ]] || network_status="IFACE $HEADER_IFACE"
        [[ "$CYBEROPS_HEADER_LOCAL_IP" == "0" ]] || network_status+="${network_status:+  //  }LOCAL $HEADER_ADDRESS"
        [[ -z "$network_status" ]] || render_signal_row "NET" "$network_status"
    fi

    if [[ "$CYBEROPS_HEADER_VPN" == "1" ]]; then
        if [[ "$HEADER_VPN" == "NONE" || -z "$HEADER_VPN" ]]; then
            vpn_status="STATUS [OFF]"
            vpn_color="$RED"
        else
            vpn_status="STATUS [ON // $HEADER_VPN]"
        fi
        if ((width < 70)); then
            render_signal_row "VPN" "$vpn_status" "$vpn_color"
            render_signal_row "V-IP" "$HEADER_VPN_ADDRESS" "$vpn_color"
        else
            render_signal_row "VPN" "$vpn_status  //  LOCAL $HEADER_VPN_ADDRESS" "$vpn_color"
        fi
    fi

    if [[ "$CYBEROPS_HEADER_MAC" == "1" ]]; then
        case "$HEADER_MAC_STATE" in
            PERMANENT)
                mac_status="[PERMANENT // $HEADER_MAC]"
                mac_color="$RED"
                ;;
            MODIFIED)
                mac_status="[MODIFIED // $HEADER_MAC]"
                mac_color="$GREEN"
                ;;
            *) mac_status="[UNKNOWN // $HEADER_MAC]" ;;
        esac
        render_signal_row "L2" "$mac_status" "$mac_color"
    fi

    [[ -z "$HEADER_PUBLIC_IP" ]] || \
        render_signal_row "WAN" "PUBLIC $HEADER_PUBLIC_IP  //  EXTERNAL LOOKUP" "$ORANGE"
}

render_header_telemetry() {
    local width="${COLUMNS:-80}"
    local network_status=""
    local local_fields=0

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        render_overdrive_header_telemetry
        return
    fi

    [[ "$CYBEROPS_HEADER_TELEMETRY" == "1" ]] || return 0
    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    if ((width < 70)); then
        [[ "$CYBEROPS_HEADER_TIME" == "0" ]] || printf '%bTIME%b // %s\n' "$MAGENTA" "$RESET" "$HEADER_TIME"
        [[ "$CYBEROPS_HEADER_LINK" == "0" ]] || printf '%bLINK%b // %s\n' "$MAGENTA" "$RESET" "$HEADER_ROUTE_STATE"
        [[ "$CYBEROPS_HEADER_IFACE" == "0" ]] || printf '%bNET%b  // IFACE %s\n' "$MAGENTA" "$RESET" "$HEADER_IFACE"
        [[ "$CYBEROPS_HEADER_LOCAL_IP" == "0" ]] || printf '%bIP%b   // %s\n' "$MAGENTA" "$RESET" "$HEADER_ADDRESS"
    else
        if [[ "$CYBEROPS_HEADER_TIME" == "1" || "$CYBEROPS_HEADER_LINK" == "1" ]]; then
            printf '%bLOCAL%b // ' "$MAGENTA" "$RESET"
            if [[ "$CYBEROPS_HEADER_TIME" == "1" ]]; then
                printf 'TIME %s' "$HEADER_TIME"
                ((local_fields += 1))
            fi
            if [[ "$CYBEROPS_HEADER_LINK" == "1" ]]; then
                ((local_fields == 0)) || printf ' // '
                printf 'LINK %s' "$HEADER_ROUTE_STATE"
                ((local_fields += 1))
            fi
            printf '\n'
        fi
        [[ "$CYBEROPS_HEADER_IFACE" == "0" ]] || network_status="IFACE $HEADER_IFACE"
        [[ "$CYBEROPS_HEADER_LOCAL_IP" == "0" ]] || network_status+="${network_status:+ // }IP $HEADER_ADDRESS"
        [[ -z "$network_status" ]] || printf '%bNET%b   // %s\n' "$MAGENTA" "$RESET" "$network_status"
    fi
    if [[ "$CYBEROPS_HEADER_VPN" == "1" ]]; then
        printf '%bVPN%b   // STATUS ' "$MAGENTA" "$RESET"
        render_vpn_badge
        if ((width < 70)); then
            printf '\n%bVPN-IP%b // %s\n' "$MAGENTA" "$RESET" "$HEADER_VPN_ADDRESS"
        else
            printf ' // LOCAL IP %s\n' "$HEADER_VPN_ADDRESS"
        fi
    fi
    if [[ "$CYBEROPS_HEADER_MAC" == "1" ]]; then
        printf '%bL2%b    // CURRENT MAC ' "$MAGENTA" "$RESET"
        render_mac_badge
        printf '\n'
    fi
    if [[ -n "$HEADER_PUBLIC_IP" ]]; then
        printf '%bWAN%b   // PUBLIC IP %s // EXTERNAL LOOKUP ENABLED\n' \
            "$MAGENTA" "$RESET" "$HEADER_PUBLIC_IP"
    fi
}

emit_cyberops_logo() {
    if have figlet; then
        figlet -f slant "CYBEROPS"
        return
    fi

    cat <<'EOF'
   ________  ______  __________  ____  ____  ____  _____
  / ____/\ \/ / __ )/ ____/ __ \/ __ \/ __ \/ __ \/ ___/
 / /      \  / __  / __/ / /_/ / / / / /_/ / /_/ /\__ \
/ /___    / / /_/ / /___/ _, _/ /_/ / ____/ ____/___/ /
\____/   /_/_____/_____/_/ |_|\____/_/   /_/    /____/
EOF
}

render_overdrive_logo() {
    local frame_inner_width=65
    local index block_width=0 left_padding right_padding
    local -a plain_lines=()
    local -a colored_lines=()

    mapfile -t plain_lines < <(emit_cyberops_logo)
    if have lolcat && [[ "$CYBEROPS_NO_COLOR" != "1" ]]; then
        # The framed logo is captured before it is printed, so lolcat cannot
        # infer terminal color support from stdout. Force its ANSI palette here.
        mapfile -t colored_lines < <(emit_cyberops_logo | lolcat --force)
    fi
    while ((${#plain_lines[@]} > 0)) &&
        [[ -z "${plain_lines[${#plain_lines[@]} - 1]//[[:space:]]/}" ]]; do
        unset 'plain_lines[${#plain_lines[@]} - 1]'
        ((${#colored_lines[@]} == 0)) || \
            unset 'colored_lines[${#colored_lines[@]} - 1]'
    done
    for index in "${!plain_lines[@]}"; do
        ((${#plain_lines[index]} > block_width)) && \
            block_width=${#plain_lines[index]}
    done
    left_padding=$(((frame_inner_width - block_width) / 2))
    ((left_padding < 0)) && left_padding=0

    for index in "${!plain_lines[@]}"; do
        right_padding=$((frame_inner_width - left_padding - ${#plain_lines[index]}))
        ((right_padding < 0)) && right_padding=0
        printf '%b║%b%*s' "$MAGENTA" "$RESET" "$left_padding" ''
        if ((${#colored_lines[@]} > index)); then
            printf '%s' "${colored_lines[index]}"
        else
            printf '%b%s%b' "$CYAN" "${plain_lines[index]}" "$RESET"
        fi
        printf '%*s%b║%b\n' "$right_padding" '' "$MAGENTA" "$RESET"
    done
    printf '%b║%b%*s%b║%b\n' "$MAGENTA" "$RESET" "$frame_inner_width" '' \
        "$MAGENTA" "$RESET"
}

banner() {
    clear_screen

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b╔═[%b CYBEROPS // NIGHT CITY RELAY %b]═════════[%b THREATGRID: ONLINE %b]═╗%b\n' \
            "$MAGENTA" "$CYAN" "$MAGENTA" "$GREEN" "$MAGENTA" "$RESET"
        printf '%b║%b  SYS://CYBEROPS  %bBUILD://%s%b  OPERATOR://LOCAL  TRUST://ZERO   %b║%b\n' \
            "$MAGENTA" "$RESET" "$PURPLE" "$VERSION" "$RESET" "$MAGENTA" "$RESET"
        printf '%b╠═[%b NEURAL COMMAND FABRIC %b]═══════════════════════════════════════╣%b\n' \
            "$MAGENTA" "$ORANGE" "$MAGENTA" "$RESET"
    else
        printf '%b╔══[%b CYBEROPS // NEON GRID %b]══════════════════[%b NODE ONLINE %b]══╗%b\n' \
            "$MAGENTA" "$CYAN" "$MAGENTA" "$GREEN" "$MAGENTA" "$RESET"
    fi

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        render_overdrive_logo
    elif have figlet; then
        if have lolcat && [[ "$CYBEROPS_NO_COLOR" != "1" ]]; then
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

    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b╠═[%b LIVE SIGNAL MATRIX %b]══════════════════════════════════════════╣%b\n' \
            "$MAGENTA" "$GREEN" "$MAGENTA" "$RESET"
    else
        printf '%b╚══════════════════════════════════════════════════════════════╝%b\n' \
            "$MAGENTA" "$RESET"
        printf '%bBUILD %s%b  //  UNIFIED LINUX OPERATIONS CONSOLE  //  SESSION ACTIVE\n' \
            "$CYAN" "$VERSION" "$RESET"
    fi
    collect_header_telemetry
    render_header_telemetry
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b╚═[%b SESSION LINKED // ICE MONITORING ACTIVE %b]═════════════════════╝%b\n' \
            "$MAGENTA" "$CYAN" "$MAGENTA" "$RESET"
    fi
    if is_dry_run; then
        printf '%b[ PREVIEW PROTOCOL ]%b State-changing commands are simulation-only.\n' \
            "$YELLOW" "$RESET"
    fi
    echo
}

warn_destructive() {
    local protocol="DESTRUCTIVE PROTOCOL"
    [[ "$CYBEROPS_THEME" != "neon-overdrive" ]] || protocol="BLACK ICE // DESTRUCTIVE PROTOCOL"
    printf '%b╔═[ %-34s ]═════════════════════╗%b\n' "$RED" "$protocol" "$RESET"
    printf '%b║ WARNING: THIS OPERATION CAN PERMANENTLY DESTROY DATA.      ║%b\n' \
        "$RED" "$RESET"
    printf '%b╚════════════════════════════════════════════════════════════╝%b\n' \
        "$RED" "$RESET"
}

confirm_yes() {
    local prompt="${1:-Type YES to continue: }"
    local answer
    if [[ "$CYBEROPS_THEME" == "neon-overdrive" ]]; then
        printf '%b[ AUTH GATE ]%b %s' "$RED" "$RESET" "$prompt"
    else
        printf '%bCONFIRM%b // %s' "$RED" "$RESET" "$prompt"
    fi
    read -r answer
    [[ "$answer" == "YES" ]]
}
