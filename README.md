# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), supporting workstation, laptop, and server environments. Uses age/SOPS encryption for secrets, Go templates for conditional profiles, and automated post-apply scripts for full system setup.

## Features

- **Three form factors** — `workstation`/`laptop` (GUI, Kubernetes tools, fonts) and `server` (minimal CLI); laptops auto-detected via DMI chassis type, workstation/server prompted once at init
- **Encrypted secrets** — age-based encryption with SOPS for API tokens, keys, and sensitive configs
- **Catppuccin Mocha** theme across all supported applications
- **Automated setup** — post-apply scripts handle Homebrew bundles, AppImages, Distrobox services, systemd services, NFS mounts, and git repo cloning
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
update-dotfiles
# or manually:
chezmoi apply
```

> **Note:** `formFactor` drives a set of derived flags (`isServer`, `isDesktop`,
> `isLaptop`, `isWorkstation`) generated into the config's `[data]` section. If you
> change the profile, or if `chezmoi` warns that the config template has changed,
> re-run `chezmoi init --data=false` once to regenerate `~/.config/chezmoi/chezmoi.toml`.
> `isDesktop` selects desktop machines (`formFactor = "workstation"`);
> `isWorkstation` includes both desktops and laptops. NFS and Distrobox deployment
> remain desktop-only.

## Repository Structure

```text
.
├── .chezmoi.toml.tmpl          # Config template (profile, derived flags, age key)
├── .chezmoiignore              # Excludes paths per formFactor profile
├── .chezmoiexternals/          # External assets (Catppuccin themes, cursors, keyboard)
├── .chezmoidata/               # Template data (packages, repos, NFS mounts, flavours)
├── .chezmoiscripts/            # Post-apply automation scripts
├── .chezmoitemplates/          # Shared template snippets (script header/footer, externals, palette)
├── dot_config/         # ~/.config — app configurations
│   ├── fish/                   # Fish shell (modular conf.d files per tool)
│   ├── git/                    # Git config with delta, GPG signing
│   ├── niri/                   # Niri compositor (form-factor-aware layout)
│   ├── foot/                   # Terminal emulator
│   ├── k9s/                    # Kubernetes dashboard (workstation/laptop)
│   ├── atuin/                  # Shell history
│   ├── distrobox/              # Declarative Distrobox containers (workstation)
│   ├── rclone/                 # Cloud storage (encrypted config fragments)
│   ├── sops/                   # age keys (encrypted)
│   ├── systemd/                # User systemd services (workstation/laptop)
│   └── ...
├── dot_local/
│   ├── bin/                    # Custom scripts (update-dotfiles, fishfy-path, …)
│   ├── lib/                    # Shared shell libraries (chezmoi_utils, common_utils)
│   └── libexec/                # Container/install helpers
├── dot_ssh/                    # SSH config
├── dot_talos/                  # Talos config (encrypted)
└── Brewfile.tmpl               # Homebrew packages rendered from chezmoidata
```

Package definitions live in `.chezmoidata/packages_brew.yaml`, `.chezmoidata/packages_cask.yaml`, `.chezmoidata/packages_flatpak.yaml`, and `.chezmoidata/packages_appimage.yaml`. Homebrew packages are rendered into `Brewfile.tmpl`; Flatpaks are installed per-user by a separate chezmoi script; AppImages are reconciled through Gear Lever.

## Local script checks

The repository uses the same Lefthook + mise setup as `home-ops`, including
`home-operations/.github`'s shared hooks. Install the pinned tools and Git hooks
from this checkout:

```sh
mise trust
mise install
```

Use the native tools directly for local checks:

```bash
mise exec -- shellcheck dot_local/lib/*.sh
mise exec -- shfmt -d -i 4 dot_local/lib/*.sh
fish_indent --check dot_config/fish/conf.d/*.fish dot_config/fish/functions/*.fish
for file in dot_config/fish/{conf.d,functions}/*.fish; do
    fish --no-execute "$file" || exit
done
```

Render chezmoi templates before passing their output to shell syntax checks,
ShellCheck, or shfmt; Go template sources are not shell syntax.

### Script contracts

Fish configuration stays modular in `dot_config/fish/conf.d/`, with autoloaded
helpers in `functions/`. `00-interactive.fish` sets shell and plugin preferences;
`00-mise.fish` initializes managed tools before the remaining integrations.
Interactive snippets return immediately in noninteractive shells. Shared static
environment variables live in `dot_config/environment.d/`; only terminal-specific
`GPG_TTY` stays in Fish. The Fisher zoxide plugin owns the `cd` integration.

Bash initializes mise before the other integrations and uses mise shims in
noninteractive shells. Interactive Bash enables fzf, Atuin (after fzf so Atuin
owns Ctrl-R), zoxide's `cd` integration, direnv, thefuck, Starship, and eza when
installed.

Interactive commands use Bash, four-space indentation, explicit strict mode,
the shared library, and a final `main "$@"` entry point. Start new commands with:

```bash
#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=common_utils.sh
source "${HOME}/.local/lib/common_utils.sh"
trap 'report_error "$?" "$LINENO"' ERR

main() {
    require_no_args "Describe what this command does." "$@"
    require_command example "describe why it is needed"
    log_section "Operation title"
    example
    log_info "Operation completed"
}

main "$@"
```

Commands with options implement `--help` and return status 2 for invalid usage
before dependencies or side effects. Use `log_section`, `log_info`, `log_warn`,
`log_error`, `log_debug`, and `run_spin` for presentation. Keep human diagnostics
on stderr and pipeable results on stdout. Logging is plain when redirected,
when `NO_COLOR` is nonempty, or when `TERM=dumb`; gum is optional.

Use `confirm` and `prompt_input` rather than direct gum calls. Confirmation
defaults to no: status 0 means yes, 1 means no, and greater than 1 means input
is unavailable or interrupted. Handle those statuses explicitly before doing
work. Input requires terminal stdin and stderr. Error traps report the original
status and line without re-executing the failed command. Notification support
is opt-in through `notifications.sh`; ordinary scripts never load Pushover.

Chezmoi lifecycle scripts retain their own framework: include `script-header`,
define `main`, and include `script-footer` inside any profile condition. Use
`chezmoi_utils.sh` for lifecycle operations; it loads the same generic helpers.
Keep operations idempotent and skip optional interactive setup without a terminal.

The POSIX prompt-data utilities (`github-icon`, `fishfy-path`, `relative-time-commit`)
and the transparent `recur-app` launcher do not use the interactive framework.

## Profiles

| Feature                                        | Workstation | Laptop | Server |
| ---------------------------------------------- | ----------- | ------ | ------ |
| Kubernetes tools (flux, helm, k9s, talosctl)   | ✓           | ✓      |        |
| GUI apps via Flatpak (Zen, Slack, Zed, Steam…) | ✓           | ✓      |        |
| Fonts (Nerd Fonts, JetBrains Mono, IBM Plex)   | ✓           | ✓      |        |
| VSCodium + extensions                          | ✓           | ✓      |        |
| SOPS/age encryption                            | ✓           | ✓      |        |
| Systemd user services                          | ✓           | ✓      |        |
| NFS mounts                                     | ✓           | ✓      |        |
| Niri — wider columns & tighter gaps            |             | ✓      |        |
| ZFS rebalance script                           |             |        | ✓      |
| Core CLI tools                                 | ✓           | ✓      | ✓      |

## Packages

Package inventories are intentionally not duplicated in this README to avoid drift. The source of truth lives in `.chezmoidata/packages_brew.yaml`, `.chezmoidata/packages_cask.yaml`, `.chezmoidata/packages_flatpak.yaml`, and `.chezmoidata/packages_appimage.yaml`.

Run `list-undeclared-packages` to list installed packages missing from these
declarations. It reports explicitly installed Homebrew formulas that no installed
formula or cask depends on (`brew leaves --installed-on-request`), casks, and
Flatpak apps in user and system installations separately. It reads live chezmoi
data across all profiles. Without options, it only lists packages.

On workstation and laptop profiles (`isWorkstation`), `review-packages.timer`
runs weekly and catches up missed runs. A desktop notification offers Review
or Later when undeclared packages exist. Review opens Foot with a fresh scan
and the full package list; removal requires a final confirmation in the terminal
(No by default). Homebrew dependency checks remain enabled and Flatpak app data
is preserved. Servers do not install the timer or service.

Run `list-undeclared-packages --notify` for a review now, or
`list-undeclared-packages --cleanup` to go directly to the terminal confirmation.
The notification and terminal remain open while waiting for your response.

Run `list-undeclared-packages --notify-test` to show the real package report in
a Yes/No desktop notification. The terminal prints your choice. This is a
simulation: even choosing Yes does not uninstall anything. No notification is
sent when there are no undeclared packages. Notifications omit empty groups
and preview up to four packages per group; the terminal keeps the complete list.

## Post-Apply Scripts

Scripts in `.chezmoiscripts/` run automatically after `chezmoi apply`:

| Script                                      | Trigger                  | Description                                                                          |
| ------------------------------------------- | ------------------------ | ------------------------------------------------------------------------------------ |
| `run_once_after_01_sudo_config.sh`          | once                     | Sudo configuration                                                                   |
| `run_once_after_10_system.sh`               | once                     | System setup per profile                                                             |
| `run_once_after_11_udev_rules.sh`           | once                     | udev rules                                                                           |
| `run_once_after_13_timesync.sh`             | once                     | systemd-timesyncd ownership/UTC fix                                                  |
| `run_once_after_20_fish.sh`                 | once                     | Fish shell setup                                                                     |
| `run_once_after_21_atuin.sh`                | once                     | Atuin history sync setup                                                             |
| `run_once_after_27_cursors.sh`              | once                     | Bibata cursor installation                                                           |
| `run_after_27_papirus.sh`                   | archive content change   | Install Papirus and Catppuccin folder colors, restore selected color, rebuild caches |
| `run_once_after_28_tailscale.sh`            | once                     | Enable/start `tailscaled`                                                            |
| `run_onchange_after_00_flatpak.sh`          | Flatpak data change      | Add user Flathub remote and install Flatpaks without sudo                            |
| `run_onchange_after_00_homebrew.sh`         | Brewfile change          | Configure brew-proxy access and run `brew bundle install`                            |
| `run_onchange_after_01_appimages.sh`        | AppImage data change     | Reconcile Gear Lever AppImages                                                       |
| `run_onchange_after_03_dcal.sh`             | Script change            | Grant Dux Calendar read access to Dux Shell theme colors                             |
| `run_onchange_after_12_nfs_mounts.sh`       | nfs.yaml change          | Configure NFS mounts                                                                 |
| `run_onchange_after_22_dms.sh`              | theme change             | Dux Shell theme setup                                                                |
| `run_onchange_after_23_git_repositories.sh` | repos.yaml change        | Clone repos & symlinks                                                               |
| `run_onchange_after_24_distrobox.sh`        | Distrobox/service change | Create/update declarative Distroboxes                                                |
| `run_onchange_after_24_systemd.sh`          | systemd change           | Enable/reload services                                                               |
| `run_onchange_after_25_rclone.sh`           | rclone change            | Cloud storage mounts                                                                 |
| `run_onchange_after_26_bat.sh`              | bat theme change         | Rebuild syntax theme cache                                                           |
| `run_onchange_after_27_sysexts.sh`          | sysexts.yaml change      | Install Flatcar system extensions                                                    |

On workstations, `papirus-folders --list` lists the installed folder colors.
Select one with `papirus-folders -C cat-mocha-blue --theme Papirus-Dark`
or `papirus-folders -C cat-latte-blue --theme Papirus-Light`.
Papirus and all Mocha/Latte colors are managed by `.chezmoiexternals/papirus.toml.tmpl`,
following upstream branches with a weekly cache refresh during apply.
Only two archives and the color switcher are tracked by chezmoi; the installer
uses `rsync` to reconcile the three Papirus themes when archive checksums change.
Unchanged archives skip installation and cache rebuilding.
Use `chezmoi apply --refresh-externals` to fetch updates immediately.
The saved folder color is restored after installation.

Run `chezmoi apply` to install both Homebrew and Flatpak packages. Flatpaks use
`--user` for the Flathub remote, installation, and scheduled updates. After
successful installation, matching system copies of declared apps are removed
only when the same architecture and branch exist in the user installation.
Application data is preserved. System-only apps and unlisted apps are left alone.
The script checks the local user inventory first and installs only missing apps;
when all declared apps are present, it skips remote setup and installation.
Flatpaks run outside Homebrew because `brew-proxy` executes Homebrew as the
`linuxbrew` account, which does not have your user's Flatpak authorization.

When `brew-proxy` is installed, the Homebrew script adds your account to the
`linuxbrew` group, allowing all Homebrew commands without authentication in an
active local session. The initial setup may require sudo authentication.
Authorization is checked by brew-proxy/Polkit. Its D-Bus checks can still see
stale process groups when the user service manager survives a logout. In that
case, run `sg linuxbrew -c 'chezmoi apply'` to activate the group for the command;
a reboot refreshes groups for the whole session. Homebrew commands use `BREW_PROXY_NONINTERACTIVE=1`
and fail instead of prompting if authorization is unavailable. The built-in
brew-proxy policy does not grant this access to SSH or background sessions.

## Managed Git Repositories

Defined in `.chezmoidata/repositories.yaml`, cloned automatically on workstation and laptop.

## Encryption

Sensitive files use [age](https://age-encryption.org) encryption managed via [SOPS](https://github.com/getsops/sops). The age key path is configured in `.chezmoi.toml.tmpl`. Files with the `.age` extension are encrypted at rest.

## License

[Unlicense](https://github.com/auricom/dotfiles/blob/main/LICENSE)
