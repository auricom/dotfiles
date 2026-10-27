function killport --description 'Pick a listening TCP port with fzf and kill its process; extra arguments go to kill'
    set -l line (ss -ltnpH | fzf --prompt 'port> '); or return
    set -l pids (string match --regex --groups-only --all 'pid=(\d+)' -- $line)
    if test (count $pids) -eq 0
        echo 'killport: no visible process; it may belong to another user' >&2
        return 1
    end
    kill $argv $pids
end
