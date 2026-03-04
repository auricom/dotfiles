if type -q bat
    if status is-interactive
        alias cat 'bat --pager=never'
        set -x BAT_THEME "Catppuccin_Mocha"
    end
end
