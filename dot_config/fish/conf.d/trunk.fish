
set -l _trunk_hook "$XDG_CACHE_HOME/trunk/shell-hooks/fish.rc"
if not set -q XDG_CACHE_HOME
    set _trunk_hook "$HOME/.cache/trunk/shell-hooks/fish.rc"
end
test -f $_trunk_hook && source $_trunk_hook
