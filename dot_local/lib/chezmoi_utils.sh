#!/usr/bin/env bash

# Chezmoi utility functions library
# This file provides common functions for chezmoi scripts

set -euo pipefail

# Catppuccin Mocha colors
_C_YELLOW="#f9e2af"
_C_GREEN="#a6e3a1"
_C_PEACH="#fab387"
_C_RED="#f38ba8"
_C_BLUE="#89b4fa"
_C_OVERLAY1="#7f849c"
_C_TEXT="#cdd6f4"

_GUM="$(command -v gum 2>/dev/null || true)"

if [[ -x "${_GUM}" ]]; then
    # LOG_TIME: gum time format for log timestamps (kitchen, ansic, rfc822…). Empty = no timestamp.
    _LOG_TIME="${LOG_TIME:-}"

    # Internal: single gum log call with full Catppuccin styling.
    # Usage: _gum_log <level> <level-color> <message> [key=value ...]
    _gum_log() {
        local level="$1" color="$2"; shift 2
        local -a args=(
            --level               "$level"
            --level.foreground    "$color"
            --message.foreground  "${_C_TEXT}"
            --key.foreground      "${_C_BLUE}"
            --value.foreground    "${_C_OVERLAY1}"
            --separator.foreground "${_C_OVERLAY1}"
        )
        [[ -n "${_LOG_TIME}" ]] && args+=(--time "${_LOG_TIME}" --time.foreground "${_C_OVERLAY1}")
        "${_GUM}" log "${args[@]}" -- "$@" >&2
    }

    log_section() {
        "${_GUM}" style \
            --bold \
            --foreground        "${_C_YELLOW}" \
            --border-foreground "${_C_YELLOW}" \
            --border  rounded \
            --padding "0 1" \
            --margin  "1 0" \
            "▶ $*" >&2
    }
    log_info()  { _gum_log info  "${_C_GREEN}"   "$@"; }
    log_warn()  { _gum_log warn  "${_C_PEACH}"   "$@"; }
    log_error() { _gum_log error "${_C_RED}"     "$@"; }
    log_debug() { [[ "${DEBUG:-}" == "1" ]] && _gum_log debug "${_C_OVERLAY1}" "$@" || true; }
    run_spin()  {
        local title="$1"; shift
        "${_GUM}" spin \
            --spinner           dot \
            --spinner.foreground "${_C_BLUE}" \
            --title.foreground  "${_C_TEXT}" \
            --title             "${title}" \
            --show-error \
            -- "$@"
    }
else
    # Catppuccin Mocha truecolor ANSI fallback
    readonly _A_YELLOW='\033[38;2;249;226;175m' # #f9e2af
    readonly _A_GREEN='\033[38;2;166;227;161m'  # #a6e3a1
    readonly _A_PEACH='\033[38;2;250;179;135m'  # #fab387
    readonly _A_RED='\033[38;2;243;139;168m'    # #f38ba8
    readonly _A_OVL1='\033[38;2;127;132;156m'   # #7f849c
    readonly _A_TEXT='\033[38;2;205;214;244m'   # #cdd6f4
    readonly _A_BOLD='\033[1m'
    readonly _A_NC='\033[0m'

    log_section() { echo -e "\n${_A_BOLD}${_A_YELLOW}▶ $*${_A_NC}" >&2; }
    log_info()    { echo -e "  ${_A_GREEN}✓${_A_NC} ${_A_TEXT}$*${_A_NC}" >&2; }
    log_warn()    { echo -e "  ${_A_PEACH}⚠${_A_NC} ${_A_TEXT}$*${_A_NC}" >&2; }
    log_error()   { echo -e "  ${_A_RED}✗${_A_NC} ${_A_TEXT}$*${_A_NC}" >&2; }
    log_debug()   { [[ "${DEBUG:-}" == "1" ]] && echo -e "  ${_A_OVL1}·${_A_NC} ${_A_TEXT}$*${_A_NC}" >&2 || true; }
    run_spin()    { shift; "$@"; }
fi

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
    [[ -f "$1" && -r "$1" ]] && sha256sum "$1" | awk '{print $1}' || echo ""
}

# Calculate SHA256 checksum for a directory (recursive, includes permissions)
dir_sha256() {
    [[ -d "$1" ]] || { echo ""; return; }
    (find "$1/" -type f -print0 | sort -z | xargs -0 sha256sum
     find "$1/" \( -type f -o -type d \) -print0 | sort -z | xargs -0 stat -c '%n %a'
    ) | sha256sum | awk '{print $1}'
}

# Enable and start a systemd user service if not already enabled/active
systemd_enable_start() {
    local service="$1"
    systemctl --user is-enabled "$service" >/dev/null 2>&1 || {
        log_info "Enabling systemd service: $service"
        systemctl --user enable "$service"
    }
    systemctl --user is-active "$service" >/dev/null 2>&1 || {
        log_info "Starting systemd service: $service"
        systemctl --user start "$service"
    }
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

# Create symlink, fail if target exists as a non-symlink
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

# Append a line to a file if not already present (creates file if missing)
append_to_file_if_missing() {
    local file="$1"
    local line="$2"
    ensure_dir "$(dirname "$file")"
    if grep -qxF "$line" "$file" 2>/dev/null; then
        log_debug "Line already present in file: $file"
    else
        log_info "Appending to file: $file"
        echo "$line" >> "$file"
    fi
}

# Check if running in a desktop environment
is_desktop() {
    [[ "${DESKTOP:-}" == "true" ]] || [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]
}

# Check if running on a personal machine
is_personal() {
    [[ "${PERSONAL:-}" == "true" ]]
}

# Retry a command with exponential backoff
# Usage: retry_with_backoff <max_attempts> <initial_delay_seconds> <cmd> [args...]
retry_with_backoff() {
    local max_attempts="$1"
    local delay="$2"
    local -a cmd=("${@:3}")
    local attempt=1

    until "${cmd[@]}"; do
        if (( attempt >= max_attempts )); then
            log_error "Command failed after $max_attempts attempts: ${cmd[*]}"
            return 1
        fi
        log_warn "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        delay=$(( delay * 2 ))
        (( attempt++ ))
    done
}

# Validate required environment variables are set and non-empty
validate_env_vars() {
    local -a missing=()
    for var in "$@"; do
        [[ -n "${!var:-}" ]] || missing+=("$var")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing required environment variables: ${missing[*]}"
        return 1
    fi
}

# Check if script should run based on named conditions
# Conditions: desktop, personal, command:<name>
should_run() {
    local condition
    for condition in "$@"; do
        case "$condition" in
            desktop)
                is_desktop || { log_debug "Skipping: not a desktop environment"; return 1; }
                ;;
            personal)
                is_personal || { log_debug "Skipping: not a personal machine"; return 1; }
                ;;
            command:*)
                command_exists "${condition#command:}" || { log_debug "Skipping: command not found: ${condition#command:}"; return 1; }
                ;;
            *)
                log_warn "Unknown condition: $condition"
                ;;
        esac
    done
}
