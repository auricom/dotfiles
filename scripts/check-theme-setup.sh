#!/usr/bin/env bash

# Exercise theme triggers with isolated chezmoi state and local archive fixtures.
# No downloads, browser launches, or changes to the real home directory.
set -Eeuo pipefail

main() {
    local root fixture
    root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
    fixture=$(mktemp -d)
    trap 'rm -rf -- "'"$fixture"'"' EXIT
    mkdir -p "$fixture/home/.local/lib" "$fixture/home/.local/bin" \
        "$fixture/source/.chezmoiscripts" "$fixture/source/.chezmoitemplates" \
        "$fixture/bin" "$fixture/icons" "$fixture/colors/src/16x16/places"
    cp "$root/.chezmoiscripts/run_once_after_28_zen.sh.tmpl" \
        "$root/.chezmoiscripts/run_onchange_after_27_papirus.sh.tmpl" "$fixture/source/.chezmoiscripts/"
    cp "$root/.chezmoitemplates/"script-{header,footer} "$fixture/source/.chezmoitemplates/"
    cp "$root/dot_local/lib/chezmoi_utils.sh" "$fixture/home/.local/lib/"
    cat >"$fixture/config.toml" <<'EOF'
[data]
isWorkstation = true
[data.catppuccin]
accent = "mauve"
EOF

    export HOME="$fixture/home" PATH="$fixture/bin:$PATH"
    export THEME_LOG="$fixture/log"
    local -a cm=(chezmoi --config "$fixture/config.toml" --source "$fixture/source"
        --destination "$HOME" --cache "$fixture/cache" --persistent-state "$fixture/state.boltdb" --no-tty)
    "${cm[@]}" execute-template --file "$root/dot_local/lib/common_utils.sh.tmpl" >"$HOME/.local/lib/common_utils.sh"
    local assets="$HOME/.local/share/chezmoi-assets/papirus" theme flavor asset
    mkdir -p "$assets" "$HOME/.local/share/catppuccin/zen"
    for theme in Papirus Papirus-Dark Papirus-Light; do
        mkdir -p "$fixture/icons/papirus-icon-theme-master/$theme"
        printf '[Icon Theme]\nName=%s\n' "$theme" >"$fixture/icons/papirus-icon-theme-master/$theme/index.theme"
    done
    for flavor in mocha latte; do
        printf '<svg/>\n' >"$fixture/colors/src/16x16/places/folder-cat-$flavor-mauve.svg"
        for asset in userChrome.css userContent.css zen-logo.svg; do
            printf '%s %s\n' "$flavor" "$asset" >"$HOME/.local/share/catppuccin/zen/${flavor}_mauve_$asset"
        done
    done
    tar -czf "$assets/icon-theme.tar.gz" -C "$fixture/icons" papirus-icon-theme-master
    tar -czf "$assets/folder-colors.tar.gz" -C "$fixture" colors
    cat >"$HOME/.local/bin/papirus-folders" <<'EOF'
#!/usr/bin/env bash
printf 'papirus\n' >>"$THEME_LOG"
exit "${FAIL_PAPIRUS:-0}"
EOF
    cat >"$fixture/bin/gtk-update-icon-cache" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    cat >"$fixture/bin/zen-browser" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'zen\n' >>"$THEME_LOG"
[[ ${FAIL_ZEN:-0} == 0 ]] || exit 42
mkdir -p "$HOME/.config/zen/abcdefgh.default"
printf '[Profile0]\nPath=abcdefgh.default\n' >"$HOME/.config/zen/profiles.ini"
printf 'user_pref("unrelated", true);\n' >"$HOME/.config/zen/abcdefgh.default/user.js"
EOF
    chmod +x "$HOME/.local/bin/papirus-folders" "$fixture/bin/"*

    local papirus="$HOME/.chezmoiscripts/27_papirus.sh" zen="$HOME/.chezmoiscripts/28_zen.sh" status
    "${cm[@]}" apply "$papirus"
    [[ $(<"$THEME_LOG") == papirus ]]
    status=$("${cm[@]}" status --include scripts)
    [[ $status != *27_papirus.sh* ]]
    "${cm[@]}" apply "$papirus"
    [[ $(<"$THEME_LOG") == papirus ]]

    # Each archive independently invalidates the rendered script hash.
    for asset in icon-theme folder-colors; do
        if [[ $asset == icon-theme ]]; then
            printf '# changed\n' >>"$fixture/icons/papirus-icon-theme-master/Papirus/index.theme"
            tar -czf "$assets/icon-theme.tar.gz" -C "$fixture/icons" papirus-icon-theme-master
        else
            printf '\n' >>"$fixture/colors/src/16x16/places/folder-cat-mocha-mauve.svg"
            tar -czf "$assets/folder-colors.tar.gz" -C "$fixture" colors
        fi
        status=$("${cm[@]}" status --include scripts)
        [[ $status == *27_papirus.sh* ]]
        "${cm[@]}" apply "$papirus"
        status=$("${cm[@]}" status --include scripts)
        [[ $status != *27_papirus.sh* ]]
    done
    [[ $(<"$THEME_LOG") == $'papirus\npapirus\npapirus' ]]

    "${cm[@]}" --override-data '{"catppuccin":{"accent":"blue"}}' apply "$papirus"
    [[ $(<"$assets/installed.sha256") == *folder-color=cat-mocha-blue ]]
    if FAIL_PAPIRUS=42 "${cm[@]}" apply "$papirus"; then
        printf 'Failed Papirus install unexpectedly succeeded\n' >&2
        exit 1
    fi
    status=$("${cm[@]}" status --include scripts)
    [[ $status == *27_papirus.sh* ]]
    "${cm[@]}" apply "$papirus"

    if FAIL_ZEN=42 "${cm[@]}" apply "$zen"; then
        printf 'Failed Zen initialization unexpectedly succeeded\n' >&2
        exit 1
    fi
    status=$("${cm[@]}" status --include scripts)
    [[ $status == *28_zen.sh* ]]
    "${cm[@]}" apply "$zen"
    local prefs="$HOME/.config/zen/abcdefgh.default/user.js"
    [[ $(<"$prefs") == *'user_pref("unrelated", true);'* ]]
    [[ $(<"$prefs") == *'// BEGIN chezmoi Zen theme'* ]]
    [[ -s "$HOME/.config/zen/abcdefgh.default/chrome/userChrome.css" ]]
    # A fresh setup against an existing profile preserves preferences without launching Zen.
    : >"$THEME_LOG"
    "${cm[@]}" --persistent-state "$fixture/existing-state.boltdb" apply "$zen"
    [[ ! -s $THEME_LOG ]]
    [[ $(<"$prefs") == *'user_pref("unrelated", true);'* ]]
    mkdir "$HOME/.config/zen/ijklmnop.later"
    : >"$THEME_LOG"
    "${cm[@]}" apply
    "${cm[@]}" apply
    [[ ! -s $THEME_LOG ]]
    [[ ! -e "$HOME/.config/zen/ijklmnop.later/chrome" ]]
    [[ -z $("${cm[@]}" status --include scripts) ]]
    printf 'Theme setup checks passed\n'
}

main "$@"
