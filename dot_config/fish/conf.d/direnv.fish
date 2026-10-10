if type -q direnv
    if status is-interactive
        set -l direnv_path (command -s direnv)
        set -l direnv_resolved_path (path resolve $direnv_path)
        direnv hook fish | string replace --all -- $direnv_resolved_path $direnv_path | source
        set -g direnv_fish_mode eval_on_arrow # trigger direnv at prompt, and on every arrow-based directory change (default)
    end
end
