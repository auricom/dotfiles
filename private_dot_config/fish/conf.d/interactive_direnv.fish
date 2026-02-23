if type -q direnv
    if status is-interactive
        direnv hook fish | source
        set -g direnv_fish_mode eval_on_arrow # trigger direnv at prompt, and on every arrow-based directory change (default)
    end
end
