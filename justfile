set shell := ["bash", "-euo", "pipefail", "-c"]

# Run all local validation checks.
# Runs both checks even if one fails, then returns a non-zero exit code if any failed.
validate:
    @status=0; \
    if ! just trunk-check; then status=1; fi; \
    if ! just shell-check; then status=1; fi; \
    exit $status

# Run Trunk checks across the repository.
trunk-check:
    @just _require-trunk
    trunk check --all

# Run shell-focused checks for scripts and chezmoi shell templates.
# Uses Trunk's hermetic shell linters plus a raw Bash syntax check.
shell-check:
    @just _require-trunk
    trunk check --all --filter=shellcheck --filter=shfmt
    bash -n .chezmoiscripts/*.tmpl dot_local/bin/* dot_local/lib/*.sh

_require-trunk:
    @command -v trunk >/dev/null || { echo "trunk is not installed. Install it first: https://trunk.io"; exit 1; }
