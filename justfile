# Render shell templates for each form factor and lint the rendered shell.
# Server and workstation answer the config template's form-factor prompt.
# Laptops are chosen from DMI, so rendering laptop uses a fake chassis type.

set shell := ["bash", "-euo", "pipefail", "-c"]
set minimum-version := "1.55.0"
set default-list

root := justfile_directory()
render_root := root / "build" / "rendered"
profiles := "server workstation laptop"

# Render shell templates for one form factor into build/rendered/<profile>.
render profile:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{ root }}
    profile={{ quote(profile) }}
    case "$profile" in
        server | workstation) chassis=3 ;;
        laptop) chassis=10 ;;
        *)
            printf 'unknown form factor: %s\nexpected server, workstation, or laptop\n' "$profile" >&2
            exit 2
            ;;
    esac
    command -v chezmoi >/dev/null 2>&1 || {
        printf 'missing chezmoi\n' >&2
        exit 1
    }

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    mkdir -p "$work/bin" "$work/dest" "$work/cache"
    cat >"$work/bin/cat" <<'EOF'
    #!/bin/sh
    if [ "${1-}" = "/sys/class/dmi/id/chassis_type" ]; then
        printf '%s\n' "${CHASSIS_TYPE:?}"
        exit 0
    fi
    exec /usr/bin/cat "$@"
    EOF
    chmod +x "$work/bin/cat"

    raw=$work/config.raw
    CHASSIS_TYPE=$chassis PATH="$work/bin:$PATH" \
        chezmoi \
        --source {{ root }} \
        --destination "$work/dest" \
        --cache "$work/cache" \
        --persistent-state "$work/state.boltdb" \
        --no-pager \
        --color=false \
        execute-template \
        --init \
        --stdinisatty \
        --promptString="formFactor (workstation/server)=$profile" \
        --file .chezmoi.toml.tmpl >"$raw"
    awk 'f { print } /^encryption =/ { f = 1; print }' "$raw" >"$work/config.toml"

    out={{ render_root }}/"$profile"
    rm -rf "$out"
    mkdir -p "$out"
    shopt -s nullglob
    templates=(
        .chezmoiscripts/*.sh.tmpl
        dot_local/bin/*.tmpl
        dot_local/lib/*.sh.tmpl
        executable_dot_bashrc.tmpl
        .chezmoitemplates/sysext-updater
    )
    rendered=0
    for src in "${templates[@]}"; do
        rel=${src#./}
        if [[ $rel == *.tmpl ]]; then
            dest=$out/${rel%.tmpl}
        else
            dest=$out/$rel
        fi
        mkdir -p "$(dirname "$dest")"
        if ! chezmoi \
            --source {{ root }} \
            --destination "$work/dest" \
            --cache "$work/cache" \
            --persistent-state "$work/state.boltdb" \
            --config "$work/config.toml" \
            --no-pager \
            --color=false \
            execute-template --file "$src" >"$dest" 2>"$work/err"; then
            printf 'render failed: %s (%s)\n' "$src" "$profile" >&2
            cat "$work/err" >&2
            exit 1
        fi
        if [[ ! -s $dest ]] || [[ -z $(tr -d '[:space:]' <"$dest") ]]; then
            rm -f "$dest"
            continue
        fi
        rendered=$((rendered + 1))
    done
    printf 'rendered %s shell files for %s\n' "$rendered" "$profile" >&2

# Run ShellCheck and shfmt on shell rendered for one form factor.
lint profile: (render profile)
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{ root }}
    profile={{ quote(profile) }}
    case "$profile" in
        server | workstation | laptop) ;;
        *)
            printf 'unknown form factor: %s\nexpected server, workstation, or laptop\n' "$profile" >&2
            exit 2
            ;;
    esac
    for tool in shellcheck shfmt; do
        command -v "$tool" >/dev/null 2>&1 || {
            printf 'missing %s\n' "$tool" >&2
            exit 1
        }
    done
    out={{ render_root }}/"$profile"
    [[ -d $out ]] || {
        printf 'nothing rendered for %s\n' "$profile" >&2
        exit 1
    }
    mapfile -d '' files < <(find "$out" -type f -print0 | sort -z)
    if ((${#files[@]} == 0)); then
        printf 'no rendered shell for %s\n' "$profile" >&2
        exit 1
    fi
    status=0
    for file in "${files[@]}"; do
        line=$(head -n 1 "$file")
        case $line in
            '#!'*'/sh' | '#!'*'/sh '*) shell=sh ;;
            *) shell=bash ;;
        esac
        rel=${file#"$out"/}
        printf 'lint %s (%s)\n' "$rel" "$shell" >&2
        shellcheck --rcfile={{ root }}/.shellcheckrc --shell="$shell" \
            --source-path="$out/dot_local/lib" \
            "$file" || status=1
        # -ci matches the indented case arms used in these scripts.
        shfmt -d -i 4 -ci -ln "$shell" "$file" || status=1
    done
    ((status == 0)) || exit "$status"
    printf 'linted %s rendered shell files for %s\n' "${#files[@]}" "$profile" >&2

# Render and lint one form factor, then run the repository script-style check.
# With no form factor, check server, workstation, and laptop.
check profile="":
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{ root }}
    bash scripts/check-script-style.sh
    profile={{ quote(profile) }}
    if [[ -n $profile ]]; then
        just lint "$profile"
    else
        for profile in {{ profiles }}; do
            just lint "$profile"
        done
    fi
