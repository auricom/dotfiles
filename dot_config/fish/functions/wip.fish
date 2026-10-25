function wip --description 'Stage all changes, amend the current commit, and force push'
    command git add --all; or return
    command git commit --amend --no-edit; or return
    command git push --force
end
