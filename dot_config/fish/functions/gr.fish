function gr --description 'cd to the root of the current git repository'
    set -l root (command git rev-parse --show-toplevel); or return
    cd $root
end
