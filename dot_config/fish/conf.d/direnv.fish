status is-interactive; or return
command -q direnv; or return

# .envrc only. .env belongs to autoenv.fish, and mise.toml [env] belongs to mise.
# Keep the hook on Homebrew's stable symlink across package upgrades.
set -l direnv_path (command -s direnv)
set -l direnv_resolved_path (path resolve $direnv_path)
direnv hook fish | string replace --all -- $direnv_resolved_path $direnv_path | source
set -g direnv_fish_mode eval_on_arrow
