if type -q kubectl
    if status is-interactive
        abbr --add --global -- k 'kubectl'
        abbr --add --global -- kdpf 'kubectl delete pod --force --grace-period 0'
    end
end
