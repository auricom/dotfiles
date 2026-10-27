status is-interactive; or return
command -q bat; or return

# Abbreviations show the real command and keep pasted `cat` usage visible.
abbr --add --global -- cat 'bat --pager=never'
