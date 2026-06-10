if test (id -u) -gt 0
    fish_add_path --global /home/linuxbrew/.linuxbrew/bin
end

if type -q brew
    if test (id -u) -gt 0
        set -gx HOMEBREW_PREFIX /home/linuxbrew/.linuxbrew
        set -gx HOMEBREW_CELLAR /home/linuxbrew/.linuxbrew/Cellar
        set -gx HOMEBREW_REPOSITORY /home/linuxbrew/.linuxbrew
    end

    if status is-interactive
        set HB_CNF_HANDLER (brew --repository)"/Library/Taps/homebrew/homebrew-command-not-found/handler.fish"
        if test -f $HB_CNF_HANDLER
            source $HB_CNF_HANDLER
        end
    end
end
