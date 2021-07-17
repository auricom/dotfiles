if status is-interactive
    # Commands to run in interactive sessions can go here
    set -g fish_user_abbreviations
    abbr --add --global dnfc sudo dnf clean all
    abbr --add --global dnfh dnf history
    abbr --add --global dnfi sudo dnf install
    abbr --add --global dnfl dnf list
    abbr --add --global dnfL dnf list installed
    abbr --add --global dnfq dnf info
    abbr --add --global dnfr sudo dnf remove
    abbr --add --global dnfs dnf search
    abbr --add --global dnfu sudo dnf upgrade
    abbr --add --global gd "git diff -M"
    abbr --add --global ga "git add"
    abbr --add --global gaa "git add --all ."
    abbr --add --global gbd "git branch -D"
    abbr --add --global gs "git status"
    abbr --add --global gca "git commit -a -m"
    abbr --add --global gm "git merge --no-ff"
    abbr --add --global gpt "git push --tags"
    abbr --add --global gp "git push"
    abbr --add --global grh "git reset --hard"
    abbr --add --global gb "git branch"
    abbr --add --global gcob "git checkout -b"
    abbr --add --global gco "git checkout"
    abbr --add --global gba "git branch -a"
    abbr --add --global gcp "git cherry-pick"
    abbr --add --global gl "git log --pretty=format:\"%Cgreen%h%Creset - %Cblue%an%Creset @ %ar : %s\""
    abbr --add --global gl2 "git log --pretty='format:%Cgreen%h%Creset %an - %s' --graph"
    abbr --add --global glv "git log --stat"
    abbr --add --global gpom "git pull origin master"
    abbr --add --global gcd 'cd "`git rev-parse --show-toplevel`"'
end
