#!/usr/bin/env bash

# Notifications are optional; ordinary commands never load credentials.
# shellcheck source=common_utils.sh
source "${HOME}/.local/lib/common_utils.sh"

notify_message() {
    if ! declare -F send_pushover_message >/dev/null; then
        if [[ ! -r ${HOME}/.local/lib/pushover.sh ]]; then
            log_warn "Pushover is unavailable; notification skipped"
            return 0
        fi
        # Encrypted, machine-local integration; never needed by lint or tests.
        # shellcheck source=/dev/null
        source "${HOME}/.local/lib/pushover.sh"
    fi
    send_pushover_message "$@"
}

notify_error() {
    local status="$1" line="$2"
    report_error "${status}" "${line}" || true
    notify_message "${HOSTNAME:-unknown}: ${0##*/} failed (status ${status}, line ${line})" || true
    return "${status}"
}
