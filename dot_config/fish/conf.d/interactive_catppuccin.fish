status is-interactive; or return

# Fish 4.3 copies old universal colors here once. Those globals shadow
# `fish_config theme choose` and pin a single light or dark variant.
set -l frozen_theme "$__fish_config_dir/conf.d/fish_frozen_theme.fish"
if test -f "$frozen_theme"
    rm -f "$frozen_theme"
end

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
