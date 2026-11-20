#!/usr/bin/env bash

# Exercise real chezmoi script scheduling with isolated state and system commands.
set -Eeuo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
export HOME="$fixture/home" BREW_TEST_LOG="$fixture/calls"
src="$fixture/source"
units="$src/dot_config/systemd/user"
mkdir -p "$HOME/.local/lib" "$src/.chezmoiscripts" "$src/.chezmoitemplates" "$units" "$fixture/bin"
cp .chezmoiscripts/run_once_after_23_brew_maintenance.sh.tmpl \
    .chezmoiscripts/run_onchange_after_24_systemd.sh.tmpl "$src/.chezmoiscripts/"
cp .chezmoitemplates/script-{header,footer} "$src/.chezmoitemplates/"
cp dot_local/lib/{chezmoi_utils,notifications}.sh "$HOME/.local/lib/"
cp dot_config/systemd/user/update-fisher.timer "$units/"
printf '[data]\nisWorkstation = true\n[data.catppuccin]\naccent = "mauve"\n' >"$fixture/config.toml"

cat >"$fixture/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -eu
echo "systemctl $*" >>"$BREW_TEST_LOG"
case "$1" in
    --user) exit 0 ;;
    show)
        case "${MIGRATED:-0}:$3" in
            1:*) echo 'ActiveState=inactive' ;;
            *:brew-update.timer) printf 'ActiveState=active\nUnitFileState=enabled\n' ;;
            *:brew-upgrade.timer) printf 'UnitFileState=disabled\nActiveState=active\n' ;;
            *:brew-update.service) echo 'ActiveState=activating' ;;
            *:brew-upgrade.service) exit 4 ;;
        esac
        ;;
    *) exit 1 ;;
esac
EOF
cat >"$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -eu
echo "sudo $*" >>"$BREW_TEST_LOG"
case "$1" in
    systemctl | mkdir) ;;
    cmp) cmp -s - "$HOME/installed.rules" ;;
    install) [[ ${FAIL_INSTALL:-0} == 0 ]] && cat >"$HOME/installed.rules" ;;
    *) exit 1 ;;
esac
EOF
cat >"$fixture/bin/fixture-chezmoi" <<'EOF'
#!/usr/bin/env bash
exec chezmoi --config "$HOME/../config.toml" --source "$HOME/../source" \
    --destination "$HOME" --cache "$HOME/../cache" --persistent-state "$HOME/../state" --no-tty "$@"
EOF
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
ln -s /bin/true "$fixture/bin/brew-proxy"
fixture-chezmoi execute-template --file dot_local/lib/common_utils.sh.tmpl >"$HOME/.local/lib/common_utils.sh"

if FAIL_INSTALL=1 fixture-chezmoi apply; then
    echo 'Failed rule installation unexpectedly succeeded' >&2
    exit 1
fi
[[ $(fixture-chezmoi status --include scripts) == *23_brew_maintenance.sh* ]]
: >"$BREW_TEST_LOG"
fixture-chezmoi apply
calls=$(<"$BREW_TEST_LOG")
[[ $calls == *'sudo systemctl disable --now brew-update.timer'* ]]
[[ $calls == *'sudo systemctl stop brew-upgrade.timer'* ]]
[[ $calls == *'sudo systemctl stop brew-update.service'* ]]
[[ $calls == *'sudo install '*$'\nsystemctl --user daemon-reload'* ]]
grep -Fq 'sh.brew.BrewProxy.upgrade' "$HOME/installed.rules"

: >"$BREW_TEST_LOG"
fixture-chezmoi apply
[[ ! -s $BREW_TEST_LOG ]]
echo '# changed' >>"$units/update-fisher.timer"
CHEZMOI_BIN=fixture-chezmoi UPDATE_CUSTOM_STEPS=chezmoi_apply_clean bash dot_local/bin/executable_update-dotfiles
grep -q '^# changed$' "$HOME/.config/systemd/user/update-fisher.timer"
grep -qx 'systemctl --user daemon-reload' "$BREW_TEST_LOG"
[[ $(<"$BREW_TEST_LOG") != *brew* && $(<"$BREW_TEST_LOG") != *sudo* ]]

# A migrated laptop entering this hook for the first time only compares the rule.
: >"$BREW_TEST_LOG"
MIGRATED=1 fixture-chezmoi --override-data '{"formFactor":"laptop"}' \
    --persistent-state "$fixture/laptop" apply
grep -q '^sudo cmp ' "$BREW_TEST_LOG"
[[ $(<"$BREW_TEST_LOG") != *'sudo install'* && $(<"$BREW_TEST_LOG") != *'sudo systemctl'* ]]

: >"$BREW_TEST_LOG"
fixture-chezmoi --override-data '{"isWorkstation":false}' --persistent-state "$fixture/server" apply
[[ ! -s $BREW_TEST_LOG ]]

# Limit PATH so a host-provided brew-proxy cannot leak into the no-proxy case.
mkdir "$fixture/no-proxy"
for tool in bash cat chezmoi systemctl sudo; do
    ln -s "$(command -v "$tool")" "$fixture/no-proxy/$tool"
done
MIGRATED=1 PATH="$fixture/no-proxy" \
    "$fixture/bin/fixture-chezmoi" --persistent-state "$fixture/no-proxy-state" apply "$HOME/.chezmoiscripts/23_brew_maintenance.sh"
grep -q 'systemctl show' "$BREW_TEST_LOG"
[[ $(<"$BREW_TEST_LOG") != *sudo* ]]
printf 'Brew maintenance checks passed\n'
