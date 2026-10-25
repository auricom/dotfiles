function git-merge-open-prs --description 'Squash and merge open pull requests'
    set -l prs (command gh pr list --state open --limit 100 --json number,title --jq '.[] | "\(.number)\t\(.title)"')
    or return

    if not set -q prs[1]
        echo "No open pull requests."
        return 0
    end

    for pr in $prs
        set -l parts (string split -m 1 \t -- "$pr")
        set -l number $parts[1]
        set -l title $parts[2]

        echo "Merging #$number: $title"
        if not command gh pr merge "$number" --squash --delete-branch
            echo "Failed to merge #$number, stopping."
            return 1
        end
    end

    command git fetch --prune
end
