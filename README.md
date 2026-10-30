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
