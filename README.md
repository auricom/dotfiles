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

### System extensions (Tailscale)

On Linux workstations and laptops, `chezmoi apply` configures stable
[Flatcar Tailscale sysext](https://flatcar.github.io/sysext-bakery/tailscale/)
updates using systemd-sysupdate. Versioned images live under `/opt/extensions`,
with `/etc/extensions/tailscale.raw` selecting the image for the next boot.
The user `update-sysexts.service` triggers the root-owned updater using
noninteractive sudo (the workstation passwordless sudo configuration is required).
Its user timer checks daily, with up to 30 minutes of randomized delay and
catch-up after missed runs. `update-all` includes this user service.
Setup runs only when its configuration changes. It stages sysexts that have no
`/etc/extensions/<name>.raw` selection yet (first install or a newly added
sysext); otherwise `chezmoi apply` does not start sysext updates. Reboot to
activate newly staged images. The timer is enabled after the updater is installed.
Updates only download, prepare and select the next image: they never refresh
sysext mounts, restart Tailscale or reboot. Tailscale's own automatic updater is
disabled so it cannot bypass this boot-only update policy. Servers are excluded.

The extension overlays packaged Tailscale binaries; keep the package for rollback.
Existing identity and settings in `/var/lib/tailscale` are preserved. Local daemon
options belong in `/etc/default/tailscaled`, which overrides the shipped defaults.
For a new node, reboot after installation, then run `sudo tailscale up` interactively.

Download or preparation failure leaves the previous boot image selected.
On SELinux hosts, the script uses `systemd-dissect` (squashfs or erofs), `setfiles` and `mksquashfs`
to prepare a local copy under `/opt/extensions/<name>/selinux/` with the host's
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

### 1Password system extension

`1password-gui` comes from the
[fedora-sysexts community](https://fedora-sysexts.github.io/community/) repository,
a third-party build of the official 1Password RPM with the application moved to
`/usr/lib/1Password` and launchers in `/usr/bin`. The same updater stages it under
`/opt/extensions/1password-gui` and selects it with
`/etc/extensions/1password-gui.raw`; only Tailscale gets boot-time service setup.
The launcher, autostart entry, Quick Access keybind and `onepassword://` handlers
use `/usr/bin/1password`.

Community images are built per Fedora release, so the image name includes the
host's `VERSION_ID`. After a major Fedora rebase the previous image no longer
merges; it returns once the updater stages the new release's image and you
reboot again. If the community repository has not published that release yet,
the updater fails and sends one desktop alert.

To migrate from the distrobox: run `chezmoi apply`, which stages the image,
then reboot. Next run
`distrobox rm 1password` followed by `chezmoi apply` again, because distrobox
removes `~/.local/share/applications/1password.desktop`. Settings in
`~/.config/1Password` and the SSH agent socket carry over. To roll back, restore
the old 1Password files from git, remove `1password-gui` from
`.chezmoidata/sysexts.yaml`, run `sudo rm -f /etc/extensions/1password-gui.raw`
and reboot.

### Zen Browser system extension

`zen-browser` comes from [auricom/sysexts](https://github.com/auricom/sysexts), a
build of the `sneexy/zen-browser` COPR package with Zen moved to `/usr/lib/zen`.
Its `zen-browser.conf` and images are published in that repository's `zen-browser`
release and staged by the same updater as the other sysexts. Images are built per
Fedora release, so the 1Password note about major Fedora rebases applies. To remove
it, drop `zen-browser` from `.chezmoidata/sysexts.yaml`, run
`sudo rm -f /etc/extensions/zen-browser.raw` and reboot.

### Recur system extension

`recur` comes from [auricom/sysexts](https://github.com/auricom/sysexts), a build of
the [celestiaorg/recur-releases](https://github.com/celestiaorg/recur-releases)
package with Recur moved to `/usr/lib/recur`. Its `recur.conf` and images are
published in that repository's `recur` release and staged by the same updater as the
other sysexts. Images are built per Fedora release, so the 1Password note about major
Fedora rebases applies.

`recur-app` still enters the `recur` distrobox. After `chezmoi apply` and a reboot,
check that `/usr/bin/recur` runs on the host; once it does, point `recur-app` at it
and remove the `recur` box. To remove the sysext, drop `recur` from
`.chezmoidata/sysexts.yaml`, run `sudo rm -f /etc/extensions/recur.raw` and reboot.

### Resilio Sync system extension

`resilio-sync` comes from [auricom/sysexts](https://github.com/auricom/sysexts), built
from the upstream signed `resilio-sync` RPM. Its `resilio-sync.conf` and images are
published in that repository's `resilio-sync` release and staged by the same updater
as the other sysexts. Images are built per Fedora release (currently only 45 on
x86-64), so the 1Password note about major Fedora rebases applies.

Nothing is enabled by default and the distrobox-based `resilio-sync.service` stays in
place. After `chezmoi apply` and a reboot, run `sudo systemd-sysusers` and
`sudo systemd-tmpfiles --create`, then switch from the distrobox service to the
packaged one. To remove the sysext, drop `resilio-sync` from
`.chezmoidata/sysexts.yaml`, run `sudo rm -f /etc/extensions/resilio-sync.raw` and
reboot.

## Contributing

Follow [AGENTS.md](AGENTS.md) for script conventions. Install check tools and hooks:

```sh
mise trust
mise install
just check
```

`just check` runs the script-style check, renders shell templates for the
server, workstation, and laptop form factors, and runs ShellCheck and shfmt
on the rendered shell. Pass one form factor to check that profile only.
Laptop rendering supplies a fake DMI chassis type because laptops are detected
from the chassis, not chosen at the prompt. Rendered output is written under
`build/rendered/` and is not applied.

[Unlicense](LICENSE)
