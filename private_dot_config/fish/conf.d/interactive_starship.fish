if type -q starship
    if status is-interactive
        set -x STARSHIP_CONFIG ~/.config/starship.toml
        starship init fish | source
    end
end
