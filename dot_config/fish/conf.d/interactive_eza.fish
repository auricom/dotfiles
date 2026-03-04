if type -q eza
    if status is-interactive
        alias ll='eza -l --icons=auto --group-directories-first' 2>/dev/null
        alias l.='eza -d .*' 2>/dev/null
        alias ls='eza' 2>/dev/null
        alias l1='eza -1'
    end
end
