if type -q zoxide
    if status is-interactive
        zoxide init --cmd cd fish | source
    end
end
