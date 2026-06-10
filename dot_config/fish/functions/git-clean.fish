function git-clean
    git fetch --prune
    set -l gone_branches (git branch -vv | grep ': gone]' | awk '{print $1}')
    for branch in $gone_branches
        git branch -D "$branch"
    end
end
