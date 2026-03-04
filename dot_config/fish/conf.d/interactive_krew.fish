if type -q krew
    if status is-interactive
        set -gx PATH  $PATH ~/.krew/bin
    end
end
