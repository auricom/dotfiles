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

### System extensions

Sysexts are declared in `.chezmoidata/sysexts.yaml` (Flatcar images such as
Tailscale, plus Fedora images from [auricom/sysexts](https://github.com/auricom/sysexts):
`1password-gui`, `zen-browser`, `recur`). `chezmoi apply` installs
`update-sysexts.service` and its daily user timer; the root-owned updater downloads
images with systemd-sysupdate into `/opt/extensions/<name>/` and selects them via
`/etc/extensions/<name>.raw` for the next boot. It never merges images, restarts
services or reboots, and a failed update keeps the previous image. Reboot to
activate newly staged images. `update-all` includes the service; servers are excluded.

- Stage manually: `systemctl --user start update-sysexts.service`.
- Logs: `journalctl -u update-sysexts.service`; status: `systemd-sysext status`.
- On SELinux hosts, Flatcar images are relabelled with the host's file contexts
  under `/opt/extensions/<name>/selinux/`. Fedora images are used as downloaded.
- Auricom images are built per Fedora release; after a major rebase the extension
  returns once the updater stages the new release's image and you reboot.
- Tailscale: its own auto-updater is disabled; for a new node run
  `sudo tailscale up` after the first reboot.
- 1Password: the launcher, autostart, Quick Access keybind and `onepassword://`
  handlers use `/usr/bin/1password`. The helper needs the `onepassword` group; if
  `getent group onepassword` is empty after a reboot, run `sudo systemd-sysusers`.
  Step 04 writes `/etc/1password/custom_allowed_browsers` (`zen-bin`); browser
  integration works with the sysext Zen, not the Flatpak.
- Recur: `recur-app` runs `/usr/bin/recur` on the host; `recur-app --dev` still
  enters the `recur-dev` distrobox.

To remove a sysext, drop it from `.chezmoidata/sysexts.yaml`, run `chezmoi apply`,
then `sudo rm -f /etc/extensions/<name>.raw` and reboot. For Tailscale also
`sudo rm -f /etc/systemd/system/tailscaled.service.d/20-chezmoi-sysext.conf` and keep
`/var/lib/tailscale`. Do not disable the shared `systemd-sysext.service`.

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
