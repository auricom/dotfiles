status is-interactive; or return
command -q starship; or return

# Clear the previous per-shell selector when reloading an existing session.
functions -e __starship_apply_theme
set -eg STARSHIP_CONFIG

starship init fish | source
