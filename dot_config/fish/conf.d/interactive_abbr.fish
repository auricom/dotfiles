status is-interactive; or return

# Fish has no `!!`; expand it to the previous command anywhere on the line.
function __abbr_last_history_item
    echo -- $history[1]
end
abbr --add --global --position anywhere --function __abbr_last_history_item -- !!

# Join a pasted multi-line block into one line.
bind alt-j flatten_commandline
