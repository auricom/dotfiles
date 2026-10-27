#!/usr/bin/env bash

set -Eeuo pipefail

# Repository lint must work before the managed home libraries are installed.
require_markers() {
    local file=$1 text marker status=0
    shift
    text=$(<"$file")
    for marker in "$@"; do
        if [[ $text != *"$marker"* ]]; then
            printf '%s: missing %s\n' "$file" "$marker" >&2
            status=1
        fi
    done
    return "$status"
}

# Match literal shell source, including unexpanded variables.
# shellcheck disable=SC2016
main() {
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
    local file text status=0

    for file in .chezmoiscripts/*.sh.tmpl; do
        require_markers "$file" \
            'includeTemplate "script-header"' \
            'main() {' \
            'includeTemplate "script-footer"' \
            'log_section ' || status=1
    done

    for file in dot_local/bin/executable_*; do
        # These produce prompt data or transparently exec an application.
        case ${file##*/} in
        executable_1password | executable_fishfy-path | executable_github-icon | \
            executable_recur-app | executable_relative-time-commit) continue ;;
        esac
        require_markers "$file" \
            '#!/usr/bin/env bash' \
            'set -Eeuo pipefail' \
            'source "${HOME}/.local/lib/common_utils.sh"' \
            'main() {' \
            'main "$@"' || status=1
        text=$(<"$file")
        if [[ $text == *"trap 'notify_error"* ]]; then
            require_markers "$file" 'source "${HOME}/.local/lib/notifications.sh"' || status=1
        else
            require_markers "$file" "trap 'report_error" || status=1
        fi
    done

    ((status == 0)) || return "$status"
    printf 'Shell framework checks passed\n'
}

main "$@"
