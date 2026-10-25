function limactl-docker --description 'Start Lima Docker and select its Docker context'
    set -l status_output (command limactl list docker 2>/dev/null)
    if test $status -ne 0
        command limactl create --name=docker --yes https://raw.githubusercontent.com/tulilirockz/carinata/refs/heads/main/docker-carinata-rootful.yaml
        or return
        command limactl start docker; or return
    else if string match -q '*Stopped*' -- $status_output
        command limactl start docker; or return
    end

    if not command docker context inspect lima-docker >/dev/null 2>&1
        command docker context create lima-docker --docker "host=unix://$HOME/.lima/docker/sock/docker.sock"
        or return
    end

    set -l current_context (command docker context show 2>/dev/null)
    or return
    if test "$current_context" != lima-docker
        command docker context use lima-docker
    end
end
