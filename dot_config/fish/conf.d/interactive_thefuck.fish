if type -q thefuck
    if status is-interactive
        thefuck --alias | source
    end
end
