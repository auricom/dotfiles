status is-interactive; or return
command -q brew; or return

set -l handler (brew --repository)/Library/Taps/homebrew/homebrew-command-not-found/handler.fish
if test -f "$handler"
    source "$handler"
end
