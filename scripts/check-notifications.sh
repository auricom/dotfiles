#!/usr/bin/env bash

# Focused automation checks; all external commands use temporary fixtures.
# Pass a common_utils.sh rendered by chezmoi execute-template or just render.
set -Eeuo pipefail

main() {
    local rendered_common=${1:?Pass the rendered common_utils.sh path}
    local root fixture
    root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
    fixture=$(mktemp -d)
    # The EXIT trap runs after main returns.
    trap 'rm -rf -- "'"${fixture}"'"' EXIT
    mkdir -p "$fixture/home/.local/lib" "$fixture/home/repositories/auricom/agents" "$fixture/bin"
    cp -- "$rendered_common" "$fixture/home/.local/lib/common_utils.sh"
    cp -- "$root/dot_local/lib/notifications.sh" "$fixture/home/.local/lib/notifications.sh"

    cat >"$fixture/home/.local/lib/pushover.sh" <<'EOF'
printf 'loaded\n' >>"$PUSHOVER_LOG"
send_pushover_message() { printf '{"status":1,"request":"fixture"}'; }
EOF
    cat >"$fixture/bin/mock" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case ${0##*/} in
    notify-send)
        printf '%s\n' "$@" >>"$NOTIFY_LOG"
        exit "${NOTIFY_STATUS:-0}"
        ;;
    journalctl)
        printf '%s\n' "$@" >"$JOURNAL_LOG"
        printf '%s' "${JOURNAL_BODY-}"
        exit "${JOURNAL_STATUS:-0}"
        ;;
    chezmoi)
        printf '%s\n' "$@" >>"$CHEZMOI_LOG"
        [[ $1 != "${FAIL_STEP:-none}" ]] || exit 42
        if [[ $1 == status ]]; then
            printf '%s' "${CHEZMOI_STATUS-}"
        fi
        ;;
    git)
        if [[ $1 == status ]]; then
            printf '%s' "${GIT_STATUS-}"
        else
            exit "${GIT_PULL_STATUS:-0}"
        fi
        ;;
esac
EOF
    chmod +x "$fixture/bin/mock"
    local command
    for command in notify-send journalctl chezmoi git; do
        ln -s mock "$fixture/bin/$command"
    done

    export NOTIFY_LOG="$fixture/notify" PUSHOVER_LOG="$fixture/pushover" JOURNAL_LOG="$fixture/journal" CHEZMOI_LOG="$fixture/chezmoi"
    local result=0
    run_case() {
        local expected=$1
        shift
        : >"$NOTIFY_LOG"
        : >"$PUSHOVER_LOG"
        : >"$CHEZMOI_LOG"
        result=0
        env HOME="$fixture/home" PATH="$fixture/bin:$PATH" CHEZMOI_BIN=chezmoi \
            UPDATE_CUSTOM_STEPS='' UPDATE_CUSTOM_SKIP='' "$@" \
            >"$fixture/stdout" 2>"$fixture/stderr" || result=$?
        if [[ $result != "$expected" ]]; then
            printf 'Expected status %s, got %s: %s\n' "$expected" "$result" "$*" >&2
            cat "$fixture/stderr" >&2
            exit 1
        fi
    }

    local notifier="$root/dot_local/bin/executable_notify-service-failure"
    run_case 0 JOURNAL_BODY=$'first\nsecond  message\nthird' bash "$notifier" update-dotfiles.service
    [[ $(<"$NOTIFY_LOG") == *$'--urgency=critical\n--\nupdate-dotfiles.service failed\nfirst second message third'* ]]
    [[ $(<"$JOURNAL_LOG") == *$'-u\nupdate-dotfiles.service\n-n\n3'* ]]
    [[ ! -s $PUSHOVER_LOG && ! -s $fixture/stdout ]]

    local long_body
    printf -v long_body '%300s' ''
    long_body=${long_body// /x}
    run_case 0 JOURNAL_BODY="$long_body" bash "$notifier" update-brew.service
    local -a arguments=()
    mapfile -t arguments <"$NOTIFY_LOG"
    [[ ${#arguments[4]} == 250 ]]

    run_case 0 JOURNAL_STATUS=1 JOURNAL_BODY=partial bash "$notifier" update-flatpak.service
    [[ $(<"$NOTIFY_LOG") == *'No journal details available.'* ]]
    run_case 0 JOURNAL_BODY='' bash "$notifier" update-flatpak.service
    [[ $(<"$NOTIFY_LOG") == *'No journal details available.'* ]]
    run_case 0 NOTIFY_STATUS=1 bash "$notifier" update-flatpak.service
    [[ $(<"$fixture/stderr") == *'Could not send desktop notification'* ]]
    [[ ! -s $PUSHOVER_LOG ]]
    # A missing notify-send has the same nonfatal contract as delivery failure.
    run_case 0 NOTIFY_STATUS=127 bash "$notifier" update-flatpak.service
    [[ $(<"$fixture/stderr") == *'Could not send desktop notification'* ]]
    run_case 0 bash "$notifier" --help
    [[ ! -s $NOTIFY_LOG ]]
    run_case 2 bash "$notifier" --invalid
    [[ ! -s $NOTIFY_LOG ]]
    run_case 2 bash "$notifier"
    run_case 2 bash "$notifier" update-brew.service extra

    local updater="$root/dot_local/bin/executable_update-dotfiles" step
    for step in git status apply; do
        run_case 42 FAIL_STEP="$step" CHEZMOI_STATUS=' M .config/example' bash "$updater"
        [[ ! -s $NOTIFY_LOG ]]
        [[ $(<"$fixture/stderr") != *'No files to update without local changes'* ]]
    done
    run_case 0 CHEZMOI_STATUS='' bash "$updater"
    [[ ! -s $NOTIFY_LOG && ! -s $PUSHOVER_LOG ]]
    run_case 0 CHEZMOI_STATUS=$'M  .config/example\nA  .config/existing' bash "$updater"
    [[ ! -s $NOTIFY_LOG && ! -s $PUSHOVER_LOG ]]
    [[ $(<"$CHEZMOI_LOG") != *apply* ]]
    run_case 0 CHEZMOI_STATUS='MM .config/example' bash "$updater"
    [[ $(<"$NOTIFY_LOG") == *$'--urgency=normal\n--\nDotfiles update skipped files\n1 file(s) skipped due to local changes or deletions: .config/example'* ]]
    [[ -s $PUSHOVER_LOG ]]
    [[ ! -s $fixture/stdout ]]
    [[ $(<"$CHEZMOI_LOG") != *apply* ]]
    run_case 0 NOTIFY_STATUS=1 CHEZMOI_STATUS='MM .config/example' bash "$updater"
    run_case 0 CHEZMOI_STATUS='DA .config/deleted' bash "$updater"
    [[ $(<"$NOTIFY_LOG") == *'local changes or deletions: .config/deleted'* ]]
    [[ $(<"$CHEZMOI_LOG") != *apply* ]]
    run_case 0 CHEZMOI_STATUS=' M .config/example' bash "$updater"
    [[ $(<"$CHEZMOI_LOG") == *$'apply\n'*'/home/.config/example'* ]]
    [[ ! -s $NOTIFY_LOG ]]

    updater="$root/dot_local/bin/executable_update-agents"
    run_case 0 GIT_STATUS=' M example' bash "$updater"
    [[ $(<"$NOTIFY_LOG") == *$'--urgency=normal\n--\nAgents update skipped'* ]]
    [[ ! -s $PUSHOVER_LOG ]]
    run_case 0 NOTIFY_STATUS=1 GIT_STATUS=' M example' bash "$updater"
    run_case 0 GIT_STATUS='' bash "$updater"
    [[ ! -s $NOTIFY_LOG ]]
    run_case 42 GIT_STATUS='' GIT_PULL_STATUS=42 bash "$updater"
    [[ ! -s $NOTIFY_LOG ]]

    printf 'Automation notification checks passed\n'
}

main "$@"
