if type -q brew
    if test "$(id -u)" -gt "0"
        if not command -v brew > /dev/null
            set -gx PATH  $PATH /home/linuxbrew/.linuxbrew/bin
        end
        if command -v brew > /dev/null
            set -gx HOMEBREW_PREFIX /home/linuxbrew/.linuxbrew
            set -gx HOMEBREW_CELLAR /home/linuxbrew/.linuxbrew/Cellar
            set -gx HOMEBREW_REPOSITORY /home/linuxbrew/.linuxbrew
        end
    end

    if status is-interactive
        set HB_CNF_HANDLER (brew --repository)"/Library/Taps/homebrew/homebrew-command-not-found/handler.fish"
        if test -f $HB_CNF_HANDLER
            source $HB_CNF_HANDLER
        end
    end
end
