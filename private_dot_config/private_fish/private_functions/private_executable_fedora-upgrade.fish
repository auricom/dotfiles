function fedora-upgrade
    # dnf
    sudo dnf upgrade -y
    # python packages
    pip3 list --outdated --user --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U --user
    # brew
    brew update
    brew upgrade
    # flatpak
    flatpak update
    # snap
    sudo snap refresh
end
