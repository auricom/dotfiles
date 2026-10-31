# dotfiles

Personal [chezmoi](https://chezmoi.io) dotfiles for Linux workstations, laptops,
and servers, with Catppuccin themes and age/SOPS encrypted secrets.

## Setup

Requires chezmoi ≥ 2.40, [Homebrew](https://brew.sh), an SSH key at
`~/.ssh/id_ed25519`, and an age key at `~/.config/sops/age/chezmoi.txt`
(for encrypted workstation/laptop files).

```sh
chezmoi init --apply --ssh auricom
```

Choose `workstation` or `server` when prompted; laptops are detected automatically.
Workstations and laptops include GUI apps and development tools; servers use a
minimal CLI setup. NFS and Distrobox deployment are desktop-only.

```sh
update-dotfiles  # Update and apply
chezmoi apply    # Apply local changes
```

After changing profiles or the config template, run `chezmoi init --data=false`
to regenerate profile flags.

## Where things live

- `dot_config/` — application configuration.
- `dot_local/bin/` — commands; `dot_local/lib/` — shared shell helpers.
- `.chezmoidata/` — package lists (`packages_*.yaml`), repositories, mounts, and themes.
- `.chezmoiscripts/` — automatic setup; details are in each script's header comments.
- `.chezmoitemplates/` — shared templates; `.chezmoiexternals/` — downloaded assets.
- `.chezmoi.toml.tmpl` — profile and encryption settings.

Edit package declarations in `.chezmoidata/`, then run `chezmoi apply`.
Use `list-undeclared-packages` to review installed packages missing from declarations.

Declare Dux Shell plugins in `.chezmoidata/dux.yaml`, then run `chezmoi apply`
to install and enable them on workstations and laptops. Existing plugins are
not updated, disabled, or uninstalled when the list changes.

### Tailscale system extension

On Linux workstations and laptops, `chezmoi apply` configures stable
[Flatcar Tailscale sysext](https://flatcar.github.io/sysext-bakery/tailscale/)
updates using systemd-sysupdate. Versioned images live under `/opt/extensions`,
with `/etc/extensions/tailscale.raw` selecting the image for the next boot.
The user `update-sysexts.service` triggers the root-owned updater using
noninteractive sudo (the workstation passwordless sudo configuration is required).
Its user timer checks daily, with up to 30 minutes of randomized delay and
catch-up after missed runs. `update-all` includes this user service.
Setup runs only when its configuration changes; `chezmoi apply` does not
directly start sysext updates. The timer is enabled after the updater is installed.
Updates only download, prepare and select the next image: they never refresh
sysext mounts, restart Tailscale or reboot. Tailscale's own automatic updater is
disabled so it cannot bypass this boot-only update policy. Servers are excluded.

The extension overlays packaged Tailscale binaries; keep the package for rollback.
Existing identity and settings in `/var/lib/tailscale` are preserved. Local daemon
options belong in `/etc/default/tailscaled`, which overrides the shipped defaults.
For a new node, reboot after installation, then run `sudo tailscale up` interactively.

Download or preparation failure leaves the previous boot image selected.
On SELinux hosts, the script uses `unsquashfs`, `setfiles` and `mksquashfs` to
prepare a local copy under `/opt/extensions/tailscale/selinux/` with the host's
file contexts. Tailscale binaries are unchanged, and the original download stays
intact for sysupdate. Each downloaded version is prepared once; the active
symlink selects the prepared copy. Raw downloads use a separate staging symlink,
so incomplete preparation cannot select an unlabelled boot image. SELinux
enforcement is unchanged. A lock serializes timer and manual updates.
Check `systemd-sysext status`, `tailscale version`,
`systemctl status tailscaled.service`, and `tailscale status` after applying and
again after the next reboot. Check the updater with
`systemctl --user list-timers update-sysexts.timer` and
`journalctl --user -u update-sysexts.service`. Detailed updater logs are in
`journalctl -u update-sysexts.service`. To stage updates manually, run
`systemctl --user start update-sysexts.service`.

To return to the packaged version, first comment out Tailscale in
`.chezmoidata/sysexts.yaml` and run `chezmoi apply` to update the timer's
configuration. Then remove the extension selection and managed drop-in:

```sh
sudo rm -f /etc/extensions/tailscale.raw
sudo rm -f /etc/systemd/system/tailscaled.service.d/20-chezmoi-sysext.conf
```

The packaged version takes over at the next boot. Keep `/var/lib/tailscale`
intact during rollback. Do not remove other extensions
or disable their shared `systemd-sysext.service`.

## Contributing

Follow [AGENTS.md](AGENTS.md) for script conventions. Install check tools and hooks:

```sh
mise trust
mise install
bash scripts/check-script-style.sh
```

Render changed templates with `chezmoi execute-template` before running shell
syntax checks, ShellCheck, or shfmt.

[Unlicense](LICENSE)
