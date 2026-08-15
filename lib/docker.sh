#!/usr/bin/env bash

# Docker module contract
# ----------------------
# Inputs:
#   STACK_ROOT, RETRY_DELAY, HEALTH_TIMEOUT, HEALTH_INTERVAL,
#   FAILURE_LOG_LINES, and DRY_RUN from lib/runtime.sh.
# Outputs:
#   Interactive status, preflight, health, recovery, and summary text.
# Return statuses:
#   Public menu functions contain operation failures and return to the launcher;
#   focused helpers return nonzero when selection, health, capture, or mutation
#   requirements are not satisfied.
# Side effects:
#   May pull/recreate Compose projects, write mode-600 recovery reports, and
#   prune images only after the existing confirmations. DRY_RUN prevents Docker
#   mutations and report creation.
# Dependencies:
#   Uses shared UI, validation, command, and operation helpers supplied by the
#   launcher. Loading this module itself performs no system mutation.

# ------------------------------------------------------------------------------
# Docker Maintenance
# ------------------------------------------------------------------------------

compose_for_file() {
    local compose_file="$1"
    docker compose -f "$compose_file" "${@:2}"
}

discover_compose_files() {
    find "$STACK_ROOT" -mindepth 2 -maxdepth 2 -type f \
        \( -name 'compose.yml' -o -name 'compose.yaml' -o -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \) \
        -print0 2>/dev/null | sort -z
}

compose_stack_name() {
    basename "$(dirname "$1")"
}

select_compose_stacks() {
    local available_name="$1"
    local selected_name="$2"
    local -n available_ref="$available_name"
    local -n selected_ref="$selected_name"
    local selection=""
    local token
    local index
    local invalid=0
    local -a tokens=()
    local -A selected_indices=()

    selected_ref=()

    while true; do
        echo "Discovered ${#available_ref[@]} Compose stack(s):"
        for index in "${!available_ref[@]}"; do
            printf '  [%02d] %-24s %s\n' \
                "$((index + 1))" \
                "$(compose_stack_name "${available_ref[$index]}")" \
                "${available_ref[$index]}"
        done

        echo
        echo "Enter stack numbers separated by spaces or commas."
        echo "Type A for every stack or Q to cancel."
        if ! read -r -p "Stack selection: " selection; then
            return 1
        fi

        case "${selection,,}" in
            a | all)
                selected_ref=("${available_ref[@]}")
                return 0
                ;;
            q | quit)
                return 1
                ;;
        esac

        selection="${selection//,/ }"
        read -r -a tokens <<<"$selection"
        selected_ref=()
        selected_indices=()
        invalid=0

        if ((${#tokens[@]} == 0)); then
            invalid=1
        fi

        for token in "${tokens[@]}"; do
            if ! integer_in_range "$token" 1 "${#available_ref[@]}"; then
                invalid=1
                break
            fi

            index=$((10#$token - 1))
            if [[ -z "${selected_indices[$index]+selected}" ]]; then
                selected_ref+=("${available_ref[$index]}")
                selected_indices[$index]=1
            fi
        done

        if ((invalid == 0)) && ((${#selected_ref[@]} > 0)); then
            return 0
        fi

        selected_ref=()
        report_warning "Invalid stack selection; choose listed numbers, A, or Q."
        echo
    done
}

show_docker_update_plan() {
    local selected_name="$1"
    # selected_name is contractually the name of an indexed array.
    # shellcheck disable=SC2178
    local -n selected_ref="$selected_name"
    local compose_file
    local stack_name
    local index=0

    echo
    separator
    echo "DOCKER UPDATE PLAN"
    separator
    echo "Selected Compose projects: ${#selected_ref[@]}"

    for compose_file in "${selected_ref[@]}"; do
        ((index += 1))
        stack_name="$(compose_stack_name "$compose_file")"
        printf '\n  [%02d] PROJECT: %s\n' "$index" "$stack_name"
        printf '       Compose file: %s\n' "$compose_file"
        printf '       Pull:   docker compose -f %q pull\n' "$compose_file"
        printf '       Deploy: docker compose -f %q up -d --remove-orphans\n' "$compose_file"
        printf '       Verify: container state, health status, and docker compose ps\n'
    done

    echo
    echo "Optional post-action: docker image prune -f, offered with a separate confirmation"
    echo "only if every selected stack succeeds."
    echo "Recovery evidence: save before/after container and image state in a private report."
}

offer_image_prune() {
    echo
    report_warning "Image pruning can remove cached images that may be useful for manual recovery."
    if ! confirm_yes "Type YES to prune unused Docker images as a separate action: "; then
        echo "Unused image pruning skipped."
        return 0
    fi

    run_mutating_checked \
        "Prune unused Docker images" \
        "Run 'docker image prune' manually after checking daemon access." \
        docker image prune -f
}

create_docker_state_report() {
    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    local report_dir="$state_home/cyberops/docker"

    DOCKER_REPORT_FILE=""
    if ! mkdir -p -- "$report_dir"; then
        report_error \
            "Could not create the Docker recovery-report directory: $report_dir" \
            "Check directory ownership and available disk space."
        return 1
    fi

    DOCKER_REPORT_FILE="$(mktemp "$report_dir/update-$(date '+%Y%m%d-%H%M%S').XXXXXX.log")" || {
        report_error \
            "Could not create a Docker recovery report under $report_dir." \
            "Check directory ownership and available disk space."
        return 1
    }

    if ! chmod 600 -- "$DOCKER_REPORT_FILE"; then
        report_error \
            "Could not restrict access to Docker recovery report: $DOCKER_REPORT_FILE" \
            "Correct the file permissions before running Docker maintenance."
        DOCKER_REPORT_FILE=""
        return 1
    fi

    {
        printf 'CYBEROPS Docker recovery report\n'
        printf 'Started: %s\n' "$(timestamp)"
        printf 'Stack root: %s\n' "$STACK_ROOT"
        printf 'Note: This report records state for manual recovery; CYBEROPS does not automatically roll back.\n'
    } >>"$DOCKER_REPORT_FILE"
}

capture_stack_state() {
    local phase="$1"
    local compose_file="$2"
    local cid
    local inspect_format
    local -a containers=()

    [[ -n "$DOCKER_REPORT_FILE" ]] || return 1

    {
        printf '\n[%s] %s\n' "$phase" "$(timestamp)"
        printf 'Compose file: %s\n' "$compose_file"
    } >>"$DOCKER_REPORT_FILE" || return 1

    mapfile -t containers < <(
        compose_for_file "$compose_file" ps --all --quiet 2>/dev/null
    )

    if ((${#containers[@]} == 0)); then
        printf 'Containers: none\n' >>"$DOCKER_REPORT_FILE"
        return 0
    fi

    inspect_format='container={{.Name}} service={{index .Config.Labels "com.docker.compose.service"}} image_ref={{.Config.Image}} image_id={{.Image}} state={{.State.Status}} exit={{.State.ExitCode}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'
    for cid in "${containers[@]}"; do
        if ! docker inspect -f "$inspect_format" "$cid" >>"$DOCKER_REPORT_FILE" 2>&1; then
            printf 'container=%s inspection=failed\n' "$cid" >>"$DOCKER_REPORT_FILE"
            return 1
        fi
    done
}

stack_header() {
    local stack_name="$1"
    echo
    separator
    echo "STACK: $stack_name"
    separator
}

show_failure_logs() {
    local compose_file="$1"

    echo
    printf '%bRecent container logs:%b\n' "$YELLOW" "$RESET"
    if ! compose_for_file "$compose_file" logs \
        --tail "$FAILURE_LOG_LINES" \
        --no-color 2>&1; then
        report_warning "Recent logs were unavailable; run docker compose logs manually for $compose_file."
    fi
}

check_stack_health() {
    local compose_file="$1"
    local start_time
    local elapsed
    local cid
    local state
    local exit_code
    local health
    local unhealthy=0
    local pending=0
    local -a containers=()

    start_time="$(date +%s)"

    while true; do
        unhealthy=0
        pending=0
        containers=()

        # Refresh the full project container set on every pass. Compose may
        # replace container IDs while an update is still converging, and
        # successful one-shot services are visible only with --all.
        mapfile -t containers < <(
            compose_for_file "$compose_file" ps --all --quiet 2>/dev/null
        )

        if ((${#containers[@]} == 0)); then
            echo "No Compose containers detected."
            return 1
        fi

        for cid in "${containers[@]}"; do
            state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo unknown)"

            case "$state" in
                running)
                    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo unknown)"
                    case "$health" in
                        healthy | none) ;;
                        starting)
                            pending=1
                            ;;
                        *)
                            echo "Container ${cid:0:12} health: $health"
                            unhealthy=1
                            ;;
                    esac
                    ;;
                exited)
                    exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$cid" 2>/dev/null || echo unknown)"
                    if [[ "$exit_code" == "0" ]]; then
                        echo "Container ${cid:0:12} completed successfully (one-shot exit 0)."
                    else
                        echo "Container ${cid:0:12} exited with status $exit_code."
                        unhealthy=1
                    fi
                    ;;
                created | restarting | removing)
                    echo "Container ${cid:0:12} state: $state"
                    pending=1
                    ;;
                *)
                    echo "Container ${cid:0:12} state: $state"
                    unhealthy=1
                    ;;
            esac
        done

        ((unhealthy == 0 && pending == 0)) && return 0
        ((unhealthy != 0)) && return 1

        elapsed=$(($(date +%s) - start_time))
        if ((elapsed >= HEALTH_TIMEOUT)); then
            echo "Health-check timeout after ${HEALTH_TIMEOUT}s."
            return 1
        fi

        sleep "$HEALTH_INTERVAL"
    done
}

update_one_stack() {
    local compose_file="$1"
    local stack_dir
    local stack_name

    stack_dir="$(dirname "$compose_file")"
    stack_name="$(basename "$stack_dir")"

    stack_header "$stack_name"
    echo "Compose file: $compose_file"

    if is_dry_run; then
        preview_command "Pull images for $stack_name" docker compose -f "$compose_file" pull
        preview_command "Start/recreate $stack_name" docker compose -f "$compose_file" up -d --remove-orphans
        echo "Would check container state and Docker health status after recreation."
        return 0
    fi

    if ! capture_stack_state "BEFORE $stack_name" "$compose_file"; then
        report_error \
            "Could not preserve before-state for $stack_name; the stack was not changed." \
            "Check the Docker recovery report and filesystem permissions."
        return 1
    fi

    echo
    echo "[1/4] Pulling images..."
    if ! run_checked \
        "Image pull for $stack_name" \
        "Check registry authentication, image names, and network connectivity." \
        compose_for_file "$compose_file" pull; then
        capture_stack_state "AFTER FAILED PULL $stack_name" "$compose_file" || true
        return 1
    fi

    echo
    echo "[2/4] Starting/recreating stack..."
    if ! run_checked \
        "Initial stack start for $stack_name" \
        "CYBEROPS will retry once after ${RETRY_DELAY}s." \
        compose_for_file "$compose_file" up -d --remove-orphans; then
        report_warning "Initial start failed. Retrying once in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"

        if ! run_checked \
            "Stack start retry for $stack_name" \
            "Review the Compose configuration and recent container logs below." \
            compose_for_file "$compose_file" up -d --remove-orphans; then
            capture_stack_state "AFTER FAILED DEPLOY $stack_name" "$compose_file" || true
            show_failure_logs "$compose_file"
            return 1
        fi
    fi

    echo
    echo "[3/4] Checking container health..."
    if ! run_checked \
        "Health check for $stack_name" \
        "Inspect container state and health-check output before retrying." \
        check_stack_health "$compose_file"; then
        run_checked \
            "Failed-stack status query" \
            "Run docker compose ps manually for $compose_file." \
            compose_for_file "$compose_file" ps || true
        capture_stack_state "AFTER FAILED HEALTH CHECK $stack_name" "$compose_file" || true
        show_failure_logs "$compose_file"
        return 1
    fi

    echo
    echo "[4/4] Stack status:"
    if ! run_checked \
        "Stack status query for $stack_name" \
        "Run docker compose ps manually for $compose_file." \
        compose_for_file "$compose_file" ps; then
        capture_stack_state "AFTER FAILED STATUS QUERY $stack_name" "$compose_file" || true
        return 1
    fi

    if ! capture_stack_state "AFTER SUCCESS $stack_name" "$compose_file"; then
        report_warning "Stack succeeded, but its after-state could not be appended to $DOCKER_REPORT_FILE."
    fi

    report_success "Stack updated successfully: $stack_name"
    return 0
}

docker_update_stacks() {
    local -a compose_files=()
    local -a selected_compose_files=()
    local -a successful_stacks=()
    local -a failed_stacks=()
    local compose_file
    local confirmation_prompt
    local stack_name

    DOCKER_REPORT_FILE=""

    banner
    ui_section "DOCKER MAINTENANCE" "CONTAINER GRID // FULL STACK DEPLOYMENT"
    echo "Started: $(timestamp)"
    echo "Stack root: $STACK_ROOT"
    echo

    if ! require_commands docker find sort date sleep basename dirname tr mkdir mktemp chmod; then
        pause
        return
    fi

    if ! is_dry_run && ! docker info >/dev/null 2>&1; then
        report_error \
            "Docker daemon is unavailable or your user lacks access." \
            "Run 'sudo systemctl status docker' and verify Docker group membership."
        pause
        return
    fi

    if ! docker compose version >/dev/null 2>&1; then
        report_error \
            "Docker Compose v2 plugin is unavailable." \
            "Install the Docker Compose v2 plugin and verify 'docker compose version'."
        pause
        return
    fi

    if [[ ! -d "$STACK_ROOT" ]]; then
        report_error \
            "Stack root does not exist: $STACK_ROOT" \
            "Create the directory or set STACK_ROOT to the correct absolute path."
        pause
        return
    fi

    mapfile -d '' -t compose_files < <(discover_compose_files)

    if ((${#compose_files[@]} == 0)); then
        report_warning "No Compose stacks found under $STACK_ROOT."
        pause
        return
    fi

    if ! select_compose_stacks compose_files selected_compose_files; then
        echo "Docker maintenance cancelled."
        pause
        return
    fi

    show_docker_update_plan selected_compose_files

    echo
    confirmation_prompt="Type YES to update the selected Compose stacks: "
    if is_dry_run; then
        confirmation_prompt="Type YES to preview the selected Compose stack updates: "
    fi
    if ! confirm_yes "$confirmation_prompt"; then
        echo "Docker maintenance cancelled."
        pause
        return
    fi

    if ! is_dry_run; then
        if ! create_docker_state_report; then
            pause
            return
        fi
        echo "Recovery report: $DOCKER_REPORT_FILE"
        begin_operation \
            "Docker Compose stack maintenance" \
            "One or more stacks may be mid-update; inspect Docker status and $DOCKER_REPORT_FILE before retrying."
    fi

    for compose_file in "${selected_compose_files[@]}"; do
        stack_name="$(compose_stack_name "$compose_file")"

        if update_one_stack "$compose_file"; then
            successful_stacks+=("$stack_name")
        else
            failed_stacks+=("$stack_name")
        fi
    done

    if ! is_dry_run; then
        end_operation
    fi

    echo
    separator
    echo "DOCKER MAINTENANCE SUMMARY"
    separator
    echo "Successful stacks: ${#successful_stacks[@]}"
    for stack_name in "${successful_stacks[@]}"; do
        echo "  [OK] $stack_name"
    done

    echo
    echo "Failed stacks: ${#failed_stacks[@]}"
    for stack_name in "${failed_stacks[@]}"; do
        echo "  [FAILED] $stack_name"
    done

    if [[ -n "$DOCKER_REPORT_FILE" ]]; then
        echo
        echo "Recovery report: $DOCKER_REPORT_FILE"
    fi

    if ((${#failed_stacks[@]} == 0)); then
        if is_dry_run; then
            offer_image_prune || true
            echo
            report_success "Docker maintenance preview completed."
        else
            offer_image_prune || true

            echo
            echo "Final Docker status:"
            run_checked \
                "Final Docker status query" \
                "Run 'docker ps' manually and verify daemon access." \
                docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true

            echo
            report_success "Docker maintenance completed successfully."
        fi
        echo "Finished: $(timestamp)"
    else
        echo
        report_error \
            "Docker maintenance completed with errors." \
            "Review each failed stack above before running maintenance again."
        echo "No automatic rollback was attempted."
        if [[ -n "$DOCKER_REPORT_FILE" ]]; then
            echo "Use the before/after image IDs in $DOCKER_REPORT_FILE for manual recovery."
        fi
        echo "Unused image pruning skipped because one or more stacks failed."
        echo "Finished: $(timestamp)"
    fi

    pause
}

docker_status() {
    banner
    ui_section "DOCKER STATUS" "CONTAINER GRID // RUNTIME TELEMETRY"

    if ! require_commands docker; then
        pause
        return
    fi

    if run_checked \
        "Docker container status query" \
        "Verify the Docker daemon is running and your user has access." \
        docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'; then
        echo
        run_checked \
            "Docker disk-usage query" \
            "Verify the Docker daemon is running and your user has access." \
            docker system df
    fi
    pause
}

docker_menu() {
    local choice=""

    while true; do
        banner
        ui_section "DOCKER OPS" "CONTAINER GRID // COMPOSE MAINTENANCE"
        printf '  %bSTACK ROOT%b  %s\n\n' "$MAGENTA" "$RESET" "$STACK_ROOT"
        menu_item 1 "Select/update Compose stacks" "GRID // DEPLOY"
        menu_item 2 "Container/status overview" "GRID // STATUS"
        menu_item 3 "Return to control deck" "NAV // BACK"

        prompt_choice choice "DOCKER"

        case "$choice" in
            1) docker_update_stacks ;;
            2) docker_status ;;
            3) return ;;
            *) invalid_selection ;;
        esac
    done
}
