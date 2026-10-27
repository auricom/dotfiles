status is-interactive; or return
command -q rg; or return

# rg flags differ from grep; abbreviations show the swap before it runs.
abbr --add --global -- grep rg
abbr --add --global -- egrep rg
abbr --add --global -- fgrep 'rg -F'
abbr --add --global -- xzgrep 'rg -z'
abbr --add --global -- xzegrep 'rg -z'
abbr --add --global -- xzfgrep 'rg -z -F'
