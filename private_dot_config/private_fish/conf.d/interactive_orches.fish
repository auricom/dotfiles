if test -d /var/lib/orches
    if status is-interactive
        abbr --add --global -- orchessync 'sudo podman exec systemd-orches orches sync'
        abbr --add --global -- orchesstat 'sudo podman exec systemd-orches orches status'
        abbr --add --global -- orcheslog 'sudo podman logs --tail 50 systemd-orches'
    end
end
