# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), supporting workstation, laptop, and server environments. Uses age/SOPS encryption for secrets, Go templates for conditional profiles, and automated post-apply scripts for full system setup.

## Features

- **Three form factors** — `workstation`/`laptop` (GUI, Kubernetes tools, fonts) and `server` (minimal CLI); laptops auto-detected via DMI chassis type, workstation/server prompted once at init
- **Encrypted secrets** — age-based encryption with SOPS for SSH keys, API tokens, and sensitive configs
- **Catppuccin Mocha** theme across all supported applications
- **Automated setup** — post-apply scripts handle Homebrew bundles, Distrobox services, systemd services, NFS mounts, and git repo cloning
- **External assets** — Catppuccin themes, Bibata cursors, and keyboard layouts fetched via `.chezmoiexternals`

## Prerequisites

- [chezmoi](https://chezmoi.io/install) ≥ 2.40.0
- [Homebrew](https://brew.sh) (Linuxbrew)
- SSH key at `~/.ssh/id_ed25519`
- age key at `~/.config/sops/age/chezmoi.txt` (for encrypted files, workstation/laptop only)

## Installation

```sh
chezmoi init --apply --ssh auricom
```

You will be prompted for:
- `formFactor` — `workstation` or `server` (laptops are auto-detected via DMI chassis type and never prompted)

To re-apply after changes:

```sh
dotfiles-update
# or manually:
chezmoi apply
```

## Repository Structure

```text
.
├── .chezmoi.toml.tmpl          # Config template (profile selection, age key)
├── .chezmoiignore              # Excludes paths per formFactor profile
├── .chezmoiexternals/          # External assets (Catppuccin themes, cursors, keyboard)
├── .chezmoidata/               # Template data (packages, repos, NFS mounts, AppImages)
├── .chezmoiscripts/            # Post-apply automation scripts
├── dot_config/         # ~/.config — app configurations
│   ├── fish/                   # Fish shell (modular conf.d files per tool)
│   ├── git/                    # Git config with delta, GPG signing
│   ├── niri/                   # Niri compositor (form-factor-aware layout)
│   ├── zellij/                 # Terminal multiplexer
│   ├── foot/                   # Terminal emulator
│   ├── k9s/                    # Kubernetes dashboard (workstation/laptop)
│   ├── atuin/                  # Shell history
│   ├── distrobox/              # Declarative Distrobox containers (workstation)
│   ├── systemd/                # User systemd services (workstation/laptop)
│   ├── DankMaterialShell/      # GNOME shell theme (workstation/laptop)
│   ├── gtk-3.0/                # GTK3 theme (workstation/laptop)
│   ├── gtk-4.0/                # GTK4 theme (workstation/laptop)
│   ├── qt6ct/                  # Qt6 theme (workstation/laptop)
│   └── ...
├── dot_local/
│   ├── bin/                    # Custom scripts (dotfiles-update, fishfy-path, …)
│   └── lib/                    # Shared shell libraries (chezmoi_utils, common_utils)
├── private_dot_ssh/            # SSH config (encrypted)
└── Brewfile.tmpl               # Homebrew packages rendered from chezmoidata
```

Package definitions live in `.chezmoidata/packages_brew.yaml`, `.chezmoidata/packages_cask.yaml`, and `.chezmoidata/packages_flatpak.yaml`, and are rendered into `Brewfile.tmpl` by chezmoi.

## Profiles

| Feature | Workstation | Laptop | Server |
|---|---|---|---|
| Kubernetes tools (flux, helm, k9s, talosctl) | ✓ | ✓ | |
| GUI apps via Flatpak (Zen, Slack, Zed, Steam…) | ✓ | ✓ | |
| Fonts (Nerd Fonts, JetBrains Mono, IBM Plex) | ✓ | ✓ | |
| VSCodium + extensions | ✓ | ✓ | |
| SOPS/age encryption | ✓ | ✓ | |
| Systemd user services | ✓ | ✓ | |
| NFS mounts | ✓ | ✓ | |
| Niri — wider columns & tighter gaps | | ✓ | |
| ZFS rebalance script | | | ✓ |
| Core CLI tools | ✓ | ✓ | ✓ |

## Packages

Package inventories are intentionally not duplicated in this README to avoid drift. The source of truth lives in `.chezmoidata/packages_brew.yaml`, `.chezmoidata/packages_cask.yaml`, and `.chezmoidata/packages_flatpak.yaml`, with `Brewfile.tmpl` rendering the Homebrew Bundle configuration from that data.

## Post-Apply Scripts

Scripts in `.chezmoiscripts/` run automatically after `chezmoi apply`:

| Script | Trigger | Description |
|---|---|---|
| `run_once_after_01_sudo_config.sh` | once | Sudo configuration |
| `run_once_after_10_system.sh` | once | System setup per profile |
| `run_once_after_11_udev_rules.sh` | once | udev rules |
| `run_once_after_12_intel_xe.sh` | once | Intel XE graphics driver (force xe over i915) |
| `run_once_after_20_fish.sh` | once | Fish shell setup |
| `run_once_after_21_atuin.sh` | once | Atuin history sync setup |
| `run_once_after_27_cursors.sh` | once | Bibata cursor installation |
| `run_onchange_after_00_homebrew.sh` | Brewfile change | `brew bundle install` |
| `run_onchange_after_12_nfs_mounts.sh` | nfs.yaml change | Configure NFS mounts |
| `run_onchange_after_22_dms.sh` | theme change | DankMaterialShell theme setup |
| `run_onchange_after_23_git_repositories.sh` | repos.yaml change | Clone repos & symlinks |
| `run_onchange_after_24_distrobox.sh` | Distrobox/service change | Create/update declarative Distroboxes |
| `run_onchange_after_24_systemd.sh` | systemd change | Enable/reload services |
| `run_onchange_after_25_rclone.sh` | rclone change | Cloud storage mounts |
| `run_onchange_after_26_bat.sh` | bat change | Install syntax themes |

## Managed Git Repositories

Defined in `.chezmoidata/repositories.yaml`, cloned automatically on workstation and laptop.

## Encryption

Sensitive files use [age](https://age-encryption.org) encryption managed via [SOPS](https://github.com/getsops/sops). The age key path is configured in `.chezmoi.toml.tmpl`. Files with the `.age` extension or `private_` prefix are encrypted at rest.

## License

[Unlicense](https://github.com/auricom/dotfiles/blob/main/LICENSE)
