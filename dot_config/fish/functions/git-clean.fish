function git-clean --description 'Delete local branches whose upstream is gone'
    command git fetch --prune; or return
    set -l branches (command git for-each-ref --format='%(refname:lstrip=2) %(upstream:track)' refs/heads)
    or return

    for branch in $branches
        set -l fields (string split -m 1 ' ' -- "$branch")
        if test "$fields[2]" = '[gone]'
            command git branch -D -- "$fields[1]"; or return
        end
    end
end
