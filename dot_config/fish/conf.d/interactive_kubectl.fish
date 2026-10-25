status is-interactive; or return
command -q kubectl; or return

abbr --add --global -- k kubectl
abbr --add --global -- kdpf 'kubectl delete pod --force --grace-period 0'
