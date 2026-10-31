status is-interactive; or return
command -q git; or return

abbr --add --global -- ga 'git add'
abbr --add --global -- gaa 'git add --all'
abbr --add --global -- gb 'git branch'
abbr --add --global -- gbd 'git branch --delete --force'
abbr --add --global -- gcfd 'git clean -fd'
# Cursor sits between the quotes, ready for the message.
abbr --add --global --set-cursor -- gcm 'git commit -m "%"'
abbr --add --global -- gcma 'git commit --amend --no-edit'
abbr --add --global -- gcmf 'git commit --fixup'
abbr --add --global -- gco 'git switch'
abbr --add --global -- gcob 'git switch -c'
abbr --add --global -- glol 'git log --graph --decorate --pretty=oneline --abbrev-commit --topo-order'
abbr --add --global -- glola 'git log --graph --decorate --pretty=oneline --abbrev-commit --topo-order --all'
abbr --add --global -- gm 'git merge --no-ff'
abbr --add --global -- gpl 'git pull'
abbr --add --global -- gplom 'git pull origin main'
# "gpr" reads like a pull or a PR. This resets the worktree, so the name is grh.
if abbr --query gpr
    abbr --erase gpr
end
abbr --add --global -- grh 'git reset --hard'
abbr --add --global -- gps 'git push'
abbr --add --global -- gpsf 'git push --force'
abbr --add --global -- gpt 'git push --tags'
abbr --add --global -- gri 'git rebase --interactive HEAD'
abbr --add --global -- gs 'git status --short'
