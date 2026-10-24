#!/usr/bin/env bash

# Chezmoi operations use the same presentation as interactive commands.
# shellcheck source=common_utils.sh
source "${HOME}/.local/lib/common_utils.sh"

# Enable and start a systemd user service if not already enabled/active
systemd_enable_start() {
    local service="$1"
    systemctl --user is-enabled "${service}" >/dev/null 2>&1 || {
        log_info "Enabling systemd service: ${service}"
        systemctl --user enable "${service}"
    }
    systemctl --user is-active "${service}" >/dev/null 2>&1 || {
        log_info "Starting systemd service: ${service}"
        systemctl --user start "${service}"
    }
}

# Enable and start a systemd system service if not already enabled/active
systemd_system_enable_start() {
    local service="$1"
    systemctl is-enabled "${service}" >/dev/null 2>&1 || {
        log_info "Enabling systemd service: ${service}"
        sudo systemctl enable "${service}"
    }
    systemctl is-active "${service}" >/dev/null 2>&1 || {
        log_info "Starting systemd service: ${service}"
        sudo systemctl start "${service}"
    }
}

# Clone git repository if it doesn't exist
git_clone_if_missing() {
    local repo_url="$1"
    local target_dir="$2"
    if [[ ! -d ${target_dir} ]]; then
        log_info "Cloning repository: ${repo_url} -> ${target_dir}"
        ensure_dir "$(dirname "${target_dir}")"
        git clone "${repo_url}" "${target_dir}"
    else
        log_debug "Repository already exists: ${target_dir}"
    fi
}

# Create symlink, fail if target exists as a non-symlink
create_symlink_if_missing() {
    local source="$1"
    local target="$2"
    if [[ -L ${target} ]]; then
        log_debug "Symlink already exists: ${target}"
    elif [[ -e ${target} ]]; then
        log_error "Target exists but is not a symlink: ${target}"
        return 1
    else
        log_info "Creating symlink: ${target} -> ${source}"
        ensure_dir "$(dirname "${target}")"
        ln -s "${source}" "${target}"
    fi
}

# Append a line to a file if not already present (creates file if missing)
append_to_file_if_missing() {
    local file="$1"
    local line="$2"
    ensure_dir "$(dirname "${file}")"
    if grep -qxF "${line}" "${file}" 2>/dev/null; then
        log_debug "Line already present in file: ${file}"
    else
        log_info "Appending to file: ${file}"
        echo "${line}" >>"${file}"
    fi
}
