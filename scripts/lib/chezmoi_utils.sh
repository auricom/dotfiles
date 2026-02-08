#!/usr/bin/env bash

# Chezmoi utility functions library
# This file provides common functions for chezmoi scripts

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# Section header for script output
log_section() {
    echo -e "\n${GREEN}>>>>> $* <<<<<${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if file exists and is readable
file_readable() {
    [[ -f "$1" && -r "$1" ]]
}

# Check if directory exists and is writable
dir_writable() {
    [[ -d "$1" && -w "$1" ]]
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Calculate SHA256 checksum for a file
file_sha256() {
    local file="$1"
    if file_readable "$file"; then
        sha256sum "$file" | awk '{print $1}'
    else
        echo ""
    fi
}

# Calculate SHA256 checksum for a directory (recursive)
dir_sha256() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        (find "${dir}/" -type f -print0 | sort -z | xargs -0 sha256sum;
         find "${dir}/" \( -type f -o -type d \) -print0 | sort -z | xargs -0 stat -c '%n %a') | sha256sum | awk '{print $1}'
    else
        echo ""
    fi
}

# Check if a systemd service is enabled
systemd_service_enabled() {
    local service="$1"
    systemctl --user is-enabled "$service" >/dev/null 2>&1
}

# Check if a systemd service is active
systemd_service_active() {
    local service="$1"
    systemctl --user is-active "$service" >/dev/null 2>&1
}

# Enable and start a systemd service if not already enabled/active
systemd_enable_start() {
    local service="$1"

    if ! systemd_service_enabled "$service"; then
        log_info "Enabling systemd service: $service"
        systemctl --user enable "$service"
    fi

    if ! systemd_service_active "$service"; then
        log_info "Starting systemd service: $service"
        systemctl --user start "$service"
    fi
}

# Install Fisher plugin if not already installed
fisher_install_if_missing() {
    local plugin="$1"
    if ! fisher list 2>/dev/null | grep -q "$plugin"; then
        log_info "Installing Fisher plugin: $plugin"
        fisher install "$plugin"
    else
        log_debug "Fisher plugin already installed: $plugin"
    fi
}

# Clone git repository if it doesn't exist
git_clone_if_missing() {
    local repo_url="$1"
    local target_dir="$2"

    if [[ ! -d "$target_dir" ]]; then
        log_info "Cloning repository: $repo_url -> $target_dir"
        ensure_dir "$(dirname "$target_dir")"
        git clone "$repo_url" "$target_dir"
    else
        log_debug "Repository already exists: $target_dir"
    fi
}

# Create symlink if it doesn't exist
create_symlink_if_missing() {
    local source="$1"
    local target="$2"

    if [[ -L "$target" ]]; then
        log_debug "Symlink already exists: $target"
    elif [[ -e "$target" ]]; then
        log_error "Target exists but is not a symlink: $target"
        return 1
    else
        log_info "Creating symlink: $target -> $source"
        ensure_dir "$(dirname "$target")"
        ln -s "$source" "$target"
    fi
}

# Append line to file if not already present
append_to_file_if_missing() {
    local file="$1"
    local line="$2"

    if [[ ! -f "$file" ]]; then
        log_error "File does not exist: $file"
        return 1
    fi

    if ! grep -qxF "$line" "$file"; then
        log_info "Appending to file: $file"
        echo "$line" >> "$file"
    else
        log_debug "Line already present in file: $file"
    fi
}

# Check if running on desktop environment
is_desktop() {
    [[ "${DESKTOP:-}" == "true" ]] || [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]
}

# Check if running on personal machine
is_personal() {
    [[ "${PERSONAL:-}" == "true" ]]
}

# Retry a command with exponential backoff
retry_with_backoff() {
    local max_attempts="$1"
    local delay="$2"
    local command=("${@:3}")
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "${command[@]}"; then
            return 0
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Command failed after $max_attempts attempts: ${command[*]}"
            return 1
        fi

        log_warn "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# Validate required environment variables
validate_env_vars() {
    local missing_vars=()

    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
}

# Check if script should run based on conditions
should_run() {
    local conditions=("$@")

    for condition in "${conditions[@]}"; do
        case "$condition" in
            "desktop")
                if ! is_desktop; then
                    log_debug "Skipping: not a desktop environment"
                    return 1
                fi
                ;;
            "personal")
                if ! is_personal; then
                    log_debug "Skipping: not a personal machine"
                    return 1
                fi
                ;;
            "command:*")
                local cmd="${condition#command:}"
                if ! command_exists "$cmd"; then
                    log_debug "Skipping: command not found: $cmd"
                    return 1
                fi
                ;;
            *)
                log_warn "Unknown condition: $condition"
                ;;
        esac
    done

    return 0
}
