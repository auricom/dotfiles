#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
export HOME="$test_dir/home"
export XDG_CONFIG_HOME="$HOME/.config"
export CLAUDE_CONFIG_DIR="$HOME/.claude"
export CODEX_HOME="$HOME/.codex"
mkdir -p "$test_dir/bin" "$XDG_CONFIG_HOME/k9s/skins" \
    "$XDG_CONFIG_HOME/eza" "$XDG_CONFIG_HOME/starship" \
    "$XDG_CONFIG_HOME/terminal-themes/claude" \
    "$XDG_CONFIG_HOME/terminal-themes/fzf" "$XDG_CONFIG_HOME/bat/themes"

# Keep the check isolated from running desktop applications.
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/pkill"
chmod +x "$test_dir/bin/pkill"
export PATH="$test_dir/bin:$PATH"
touch "$XDG_CONFIG_HOME/k9s/config.yaml"
for flavor in mocha latte; do
    mkdir -p "$XDG_CONFIG_HOME/eza/$flavor"
    touch "$XDG_CONFIG_HOME/eza/$flavor/theme.yml" \
        "$XDG_CONFIG_HOME/starship/$flavor.toml" \
        "$XDG_CONFIG_HOME/terminal-themes/claude/$flavor.json" \
        "$XDG_CONFIG_HOME/terminal-themes/fzf/$flavor.opts"
    printf '%s\n' "$flavor" > "$XDG_CONFIG_HOME/k9s/skins/catppuccin-$flavor-system.yaml"
done
touch "$XDG_CONFIG_HOME/bat/themes/Catppuccin_Mocha.tmTheme" \
    "$XDG_CONFIG_HOME/bat/themes/Catppuccin_Latte.tmTheme"

for mode in dark light dark; do
    sh "$repo_dir/dot_local/bin/executable_terminal-theme" onLightModeChanged "$mode"
    case "$mode" in
        dark) flavor=mocha ;;
        light) flavor=latte ;;
    esac
    cmp "$XDG_CONFIG_HOME/k9s/skins/catppuccin-$flavor-system.yaml" \
        "$XDG_CONFIG_HOME/k9s/skins/catppuccin-system.yaml"
done

# Missing skins must fail before changing any application's active theme.
rm "$XDG_CONFIG_HOME/k9s/skins/catppuccin-latte-system.yaml"
if sh "$repo_dir/dot_local/bin/executable_terminal-theme" onLightModeChanged light 2> "$test_dir/error"; then
    echo 'Expected missing k9s skin to fail' >&2
    exit 1
fi
test "$(readlink "$XDG_CONFIG_HOME/eza/theme.yml")" = "$XDG_CONFIG_HOME/eza/mocha/theme.yml"
cmp "$XDG_CONFIG_HOME/k9s/skins/catppuccin-mocha-system.yaml" \
    "$XDG_CONFIG_HOME/k9s/skins/catppuccin-system.yaml"

# Hosts without k9s should still switch their other terminal themes.
rm -r "$XDG_CONFIG_HOME/k9s"
sh "$repo_dir/dot_local/bin/executable_terminal-theme" onLightModeChanged light
test "$(readlink "$XDG_CONFIG_HOME/eza/theme.yml")" = "$XDG_CONFIG_HOME/eza/latte/theme.yml"
printf 'Terminal theme checks passed\n'
