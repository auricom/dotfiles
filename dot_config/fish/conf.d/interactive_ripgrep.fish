if type -q rg
    if status is-interactive
        alias grep='rg' 2>/dev/null
        alias egrep='rg' 2>/dev/null
        alias fgrep='rg -F' 2>/dev/null
        alias xzgrep='rg -z' 2>/dev/null
        alias xzegrep='rg -z' 2>/dev/null
        alias xzfgrep='rg -z -F' 2>/dev/null
    end
end
