function git-merge-open-prs
    set -l prs (gh pr list --state open --limit 100 --json number,headRefName,title --jq '.[] | "\(.number)\t\(.headRefName)\t\(.title)"')

    if test -z "$prs"
        echo "No open pull requests."
        return 0
    end

    for pr in $prs
        set -l parts (string split \t $pr)
        set -l number $parts[1]
        set -l branch $parts[2]
        set -l title $parts[3]

        echo "Merging #$number: $title"
        if not gh pr merge $number --squash --delete-branch
            echo "Failed to merge #$number, stopping."
            return 1
        end
    end

    git fetch --prune
end
