if type -q podman
    if status is-interactive
        abbr --add --global -- quadcheck 'sudo /usr/lib/systemd/system-generators/podman-system-generator  --dryrun > /dev/null'
        abbr --add --global -- quadchecku '/usr/lib/systemd/system-generators/podman-system-generator  --user --dryrun > /dev/null'
    end
end
