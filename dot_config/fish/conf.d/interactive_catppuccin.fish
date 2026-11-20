status is-interactive; or return

if not test -r "$__fish_config_dir/themes/catppuccin.theme"
    return
end

# terminal-theme sets terminal_theme_mode when dankHooks switches light/dark.
# Foot does not emit CSI 2031, so Fish does not see that switch itself.
# Fish 4.3 then picks the theme file's [light] or [dark] section.
functions -e __catppuccin_apply_theme
function __catppuccin_apply_theme --on-variable terminal_theme_mode
    switch "$terminal_theme_mode"
        case light dark
            fish_config theme choose catppuccin --color-theme="$terminal_theme_mode"
        case '*'
            fish_config theme choose catppuccin
    end
end

__catppuccin_apply_theme
