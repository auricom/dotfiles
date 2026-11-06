#!/usr/bin/env bash

# Check the modify-template with isolated state; never apply to the real home.
set -Eeuo pipefail

main() {
    local root fixture
    root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
    fixture=$(mktemp -d)
    trap 'rm -rf -- "'"${fixture}"'"' EXIT
    mkdir -p "$fixture/source" "$fixture/dest" "$fixture/cache"
    printf '[data.catppuccin]\naccent = "blue"\n' >"$fixture/config.toml"
    local -a render=(
        chezmoi --source "$fixture/source" --destination "$fixture/dest"
        --cache "$fixture/cache" --persistent-state "$fixture/state.boltdb"
        --config "$fixture/config.toml"
        execute-template --with-stdin --file "$root/dot_config/dms/modify_settings.json"
    )

    # Preserve application formatting byte for byte when managed values match.
    printf '%s' '{"unmanaged":42, "registryThemeVariants":{"catppuccin":{"light":{"accent":"blue"},"dark":{"accent":"blue"}}}}' >"$fixture/input"
    "${render[@]}" <"$fixture/input" >"$fixture/output"
    cmp "$fixture/input" "$fixture/output"
    printf '\n\n' >>"$fixture/input"
    "${render[@]}" <"$fixture/input" >"$fixture/output"
    cmp "$fixture/input" "$fixture/output"

    printf '%s\n' '{"unmanaged":{"keep":true},"registryThemeVariants":{"catppuccin":{"dark":{"accent":"red","flavor":"mocha"}}}}' >"$fixture/input"
    "${render[@]}" <"$fixture/input" >"$fixture/output"
    jq -e '.unmanaged.keep and .registryThemeVariants.catppuccin.dark.flavor == "mocha" and .registryThemeVariants.catppuccin.dark.accent == "blue" and .registryThemeVariants.catppuccin.light.accent == "blue"' "$fixture/output" >/dev/null
    "${render[@]}" <"$fixture/output" >"$fixture/again"
    cmp "$fixture/output" "$fixture/again"

    "${render[@]}" </dev/null >"$fixture/output"
    jq -e '.registryThemeVariants.catppuccin | .dark.accent == "blue" and .light.accent == "blue"' "$fixture/output" >/dev/null
    printf 'DMS settings checks passed\n'
}

main "$@"
