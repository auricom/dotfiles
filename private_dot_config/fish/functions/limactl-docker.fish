function limactl-docker
    set -l status_output (limactl list docker 2>/dev/null)
    if test $status -ne 0
        limactl create --name=docker --yes https://raw.githubusercontent.com/tulilirockz/carinata/refs/heads/main/docker-carinata-rootful.yaml
        limactl start docker
    else if echo $status_output | grep -q "Stopped"
        limactl start docker
    end

    if not docker context ls --format '{{.Name}}' 2>/dev/null | grep -q '^lima-docker$'
        docker context create lima-docker --docker "host=unix:///var/home/auricom/.lima/docker/sock/docker.sock"
    end

    if not docker context ls --format '{{.Name}} {{.Current}}' 2>/dev/null | grep -q '^lima-docker true$'
        docker context use lima-docker
    end
end
