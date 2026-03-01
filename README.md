# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), supporting both desktop and server environments. Uses age/SOPS encryption for secrets, Go templates for conditional profiles, and automated post-apply scripts for full system setup.

## Features

- **Dual profiles** — desktop (GUI, Kubernetes tools, fonts) and server (minimal CLI) via a single flag at init
- **Encrypted secrets** — age-based encryption with SOPS for SSH keys, API tokens, and sensitive configs
- **Catppuccin Mocha** theme across all supported applications
- **Automated setup** — post-apply scripts handle Homebrew bundles, systemd services, NFS mounts, and git repo cloning
- **External assets** — Catppuccin themes, Bibata cursors, and keyboard layouts fetched via `.chezmoiexternals`

## Prerequisites

- [chezmoi](https://chezmoi.io/install) ≥ 2.40.0
- [Homebrew](https://brew.sh) (Linuxbrew)
- SSH key at `~/.ssh/id_ed25519`
- age key at `~/.config/sops/age/chezmoi.txt` (for encrypted files, desktop only)

## Installation

```sh
chezmoi init --apply --ssh auricom
```

You will be prompted for:
- `desktop` — `true` for a desktop machine, `false` for a server

To re-apply after changes:

```sh
dotfiles-update
# or manually:
chezmoi apply
```

## Repository Structure

```
.
├── .chezmoi.toml.tmpl          # Config template (profile selection, age key)
├── .chezmoiignore              # Excludes desktop/server-only paths per profile
├── .chezmoiexternals/          # External assets (Catppuccin themes, cursors, keyboard)
├── .chezmoidata/               # Template data (repos, NFS mounts, AppImages)
├── .chezmoiscripts/            # Post-apply automation scripts
├── private_dot_config/         # ~/.config — app configurations
│   ├── fish/                   # Fish shell (modular conf.d files per tool)
│   ├── git/                    # Git config with delta, GPG signing
│   ├── zellij/                 # Terminal multiplexer
│   ├── k9s/                    # Kubernetes dashboard (desktop)
│   ├── atuin/                  # Shell history
│   ├── containers/             # Podman/Quadlet services (desktop)
│   ├── systemd/                # User systemd services (desktop)
│   └── ...
├── dot_local/
│   ├── bin/                    # Custom scripts (dotfiles-update, import-dji-osmo, …)
│   └── lib/                    # Shared shell libraries
├── private_dot_ssh/            # SSH config (encrypted)
└── Brewfile.tmpl               # Homebrew packages (conditional by profile)
```

## Profiles

| Feature | Desktop | Server |
|---|---|---|
| Kubernetes tools (flux, helm, k9s, talosctl) | ✓ | |
| GUI apps via Flatpak (Zen, Slack, Zed, Steam…) | ✓ | |
| Fonts (Nerd Fonts, JetBrains Mono, IBM Plex) | ✓ | |
| VSCodium + extensions | ✓ | |
| SOPS/age encryption | ✓ | |
| Systemd user services | ✓ | |
| NFS mounts | ✓ | |
| ZFS rebalance script | | ✓ |
| Core CLI tools | ✓ | ✓ |

## Key Packages

**Core (all profiles):** fish, starship, atuin, zoxide, zellij, bat, eza, fd, fzf, ripgrep, duf, mise, git, gh, age, sops, ansible, docker, yq

**Desktop only:** flux, helm, helmfile, k9s, kubernetes-cli, talosctl, talhelper, kubeconform, VSCodium, Claude Code, Codex, Goose, ramalama

## Post-Apply Scripts

Scripts in `.chezmoiscripts/` run automatically after `chezmoi apply`:

| Script | Trigger | Description |
|---|---|---|
| `run_once_after_00_sudo_config.sh` | once | Sudo configuration |
| `run_once_after_10_system.sh` | once | System setup per profile |
| `run_once_after_11_udev_rules.sh` | once | udev rules |
| `run_once_after_20_fish.sh` | once | Fish shell setup |
| `run_once_after_21_atuin.sh` | once | Atuin history sync setup |
| `run_onchange_after_01_homebrew.sh` | Brewfile change | `brew bundle install` |
| `run_onchange_after_12_nfs_mounts.sh` | nfs.yaml change | Configure NFS mounts |
| `run_onchange_after_23_git_repositories.sh` | repos.yaml change | Clone repos & symlinks |
| `run_onchange_after_24_systemd.sh` | systemd change | Enable/reload services |
| `run_onchange_after_25_rclone.sh` | rclone change | Cloud storage mounts |
| `run_onchange_after_26_bat.sh` | bat change | Install syntax themes |

## Managed Git Repositories

Defined in `.chezmoidata/repositories.yaml`, cloned automatically on desktop.

## Encryption

Sensitive files use [age](https://age-encryption.org) encryption managed via [SOPS](https://github.com/getsops/sops). The age key path is configured in `.chezmoi.toml.tmpl`. Files with the `.age` extension or `private_` prefix are encrypted at rest.

## License

[Unlicence](https://github.com/auricom/dotfiles/blob/main/LICENSE)
