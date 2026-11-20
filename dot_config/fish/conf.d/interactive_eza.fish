status is-interactive; or return
command -q eza; or return

# The desktop's LS_COLORS would otherwise override the Catppuccin theme.
function eza --wraps=eza
    set -lx LS_COLORS ''
    command eza $argv
end

alias ll 'eza -l --icons=auto --group-directories-first'
alias l. 'eza -d .*'
alias ls eza
alias l1 'eza -1'
