#!/usr/bin/env bash

# Privacy-filtered diagnostics contract
# -------------------------------------
# Produces an explicitly scoped support archive. It never includes operation
# logs, environment variables, host/user identity, network addresses, device
# identifiers, mount paths, or Docker workload names.

diagnostics_preview() {
    cat <<'EOF'
CYBEROPS privacy-filtered diagnostics bundle

Included:
  - CYBEROPS version and UTC collection time
  - OS name/version, kernel name/release, and architecture
  - Presence and versions of selected CYBEROPS dependencies
  - Non-sensitive effective settings (timeouts, dry-run, color, logging)
  - Anonymous block-device size/type/filesystem/transport/removable summary
  - Docker client/server versions when Docker is available

Excluded:
  - Username, hostname, home directory, and environment variables
  - IP addresses, MAC addresses, and network configuration
  - Device names, models, serial numbers, WWNs, labels, and mount paths
  - STACK_ROOT, configuration/state/log paths, and operation-log contents
  - Docker container, image, volume, network, and stack names
  - File contents and command history
EOF
}

diagnostics_command_version() {
    local command_name="$1"
    local version_line

    if ! have "$command_name"; then
        printf '%s: unavailable\n' "$command_name"
        return 0
    fi

    case "$command_name" in
        bash) version_line="$(bash --version 2>/dev/null | head -n 1)" ;;
        curl) version_line="$(curl --version 2>/dev/null | head -n 1)" ;;
        docker) version_line="$(docker version --format '{{.Client.Version}}' 2>/dev/null)" ;;
        lsblk) version_line="$(lsblk --version 2>/dev/null | head -n 1)" ;;
        *) version_line="available" ;;
    esac
    [[ -n "$version_line" ]] || version_line="available (version unavailable)"
    printf '%s: %s\n' "$command_name" "$version_line"
}

write_diagnostics_report() {
    local report_file="$1"
    local os_name=unknown
    local os_version=unknown
    local command_name

    if [[ -r /etc/os-release ]]; then
        while IFS='=' read -r key value; do
            value="${value%\"}"
            value="${value#\"}"
            case "$key" in
                NAME) os_name="$value" ;;
                VERSION_ID) os_version="$value" ;;
            esac
        done </etc/os-release
    fi

    {
        printf 'CYBEROPS diagnostics\n'
        printf 'version=%s\n' "$VERSION"
        printf 'collected_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'os_name=%s\n' "$os_name"
        printf 'os_version=%s\n' "$os_version"
        printf 'kernel=%s\n' "$(uname -srm)"
        printf '\n[dependencies]\n'
        for command_name in bash curl docker lsblk; do
            diagnostics_command_version "$command_name"
        done
        printf '\n[settings]\n'
        printf 'RETRY_DELAY=%s\n' "$RETRY_DELAY"
        printf 'HEALTH_TIMEOUT=%s\n' "$HEALTH_TIMEOUT"
        printf 'HEALTH_INTERVAL=%s\n' "$HEALTH_INTERVAL"
        printf 'FAILURE_LOG_LINES=%s\n' "$FAILURE_LOG_LINES"
        printf 'DRY_RUN=%s\n' "$DRY_RUN"
        printf 'CYBEROPS_NO_COLOR=%s\n' "$CYBEROPS_NO_COLOR"
        printf 'CYBEROPS_LOGGING=%s\n' "$CYBEROPS_LOGGING"
        printf '\n[anonymous_block_devices]\n'
        if have lsblk; then
            lsblk -dn -o SIZE,TYPE,FSTYPE,TRAN,RM 2>/dev/null || printf 'unavailable\n'
        else
            printf 'lsblk unavailable\n'
        fi
        printf '\n[docker_versions]\n'
        if have docker; then
            docker version --format 'client={{.Client.Version}} server={{.Server.Version}}' 2>/dev/null ||
                printf 'Docker daemon unavailable\n'
        else
            printf 'Docker unavailable\n'
        fi
    } >"$report_file"
}

export_diagnostics_bundle() {
    local requested_output="${1:-}"
    local output_path
    local output_parent
    local temporary_dir
    local archive_name

    if ! validate_configuration; then
        return 2
    fi
    require_commands date uname mktemp tar chmod || return 1

    if [[ -z "$requested_output" ]]; then
        requested_output="cyberops-diagnostics-$(date -u '+%Y%m%dT%H%M%SZ').tar.gz"
    fi
    output_parent="$(dirname -- "$requested_output")"
    archive_name="$(basename -- "$requested_output")"
    if [[ ! -d "$output_parent" || ! -w "$output_parent" ]]; then
        report_error "Diagnostics output directory is not writable: $output_parent" \
            "Choose an output path in an existing writable directory."
        return 1
    fi
    if [[ -e "$requested_output" ]]; then
        report_error "Diagnostics output already exists: $requested_output" \
            "Choose a new output filename; CYBEROPS will not overwrite it."
        return 1
    fi
    output_path="$(cd -- "$output_parent" && pwd -P)/$archive_name"

    temporary_dir="$(mktemp -d)" || return 1
    chmod 700 -- "$temporary_dir"
    if ! write_diagnostics_report "$temporary_dir/report.txt" ||
        ! (umask 077 && tar -C "$temporary_dir" -czf "$output_path" report.txt); then
        rm -f -- "$temporary_dir/report.txt"
        rmdir -- "$temporary_dir"
        report_error "Diagnostics export failed." "Verify that the destination has free space and retry."
        return 1
    fi
    if ! chmod 600 -- "$output_path"; then
        rm -f -- "$output_path" "$temporary_dir/report.txt"
        rmdir -- "$temporary_dir"
        report_error "Could not protect the diagnostics archive." \
            "Verify destination permissions and retry."
        return 1
    fi
    rm -f -- "$temporary_dir/report.txt"
    rmdir -- "$temporary_dir"
    write_operation_log info "Privacy-filtered diagnostics export" 0
    printf 'Diagnostics bundle created: %s\n' "$output_path"
}
