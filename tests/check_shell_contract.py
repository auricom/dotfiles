"""Ensure the convention checker catches new-script drift."""

import importlib.util
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_shell", ROOT / "scripts/check-shell.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)

path = ROOT / "dot_local/bin/executable_new-command"
valid = (ROOT / "dot_local/bin/executable_update-pikvm").read_text()
assert checker.contract(path, valid) == []
for before, after in (
    ("#!/usr/bin/env bash", "#!/bin/bash"),
    ("set -Eeuo pipefail", "set -e"),
    ("common_utils.sh", "other_utils.sh"),
    ('main "$@"', "main"),
    ("require_no_args", "other_parser"),
    ("log_section", "other_header"),
    ("trap 'report_error", "trap 'other_reporter"),
):
    assert checker.contract(path, valid.replace(before, after)), (before, after)
for addition in ('gum confirm "Continue?"', 'log_info() { echo "$*"; }', "printf '\\033[31m'", '$BASH_COMMAND'):
    assert checker.contract(path, valid.replace('main "$@"', addition + '\nmain "$@"')), addition
lifecycle = ROOT / ".chezmoiscripts/run_once_after_new.sh.tmpl"
assert checker.contract(ROOT / ".chezmoiscripts/run_new", '{{ includeTemplate "script-header" . }}\n{{ includeTemplate "script-footer" . }}'), "new lifecycle scripts cannot escape checks by dropping the extension"
assert checker.contract(lifecycle, 'main() { :; }'), "lifecycle templates must use the shared header/footer"
assert checker.contract(ROOT / "dot_local/bin/executable_new-posix", "#!/bin/sh\ntrue\n"), "exceptions must be explicit"

# --destination does not change chezmoi.homeDir. Keep all built-in identity
# fields under fixtures too, so optional installer tests cannot touch real HOME.
with tempfile.TemporaryDirectory(prefix="shell-render-test-") as directory:
    temporary = Path(directory)
    template = temporary / "identity.tmpl"
    template.write_text("{{ .chezmoi.homeDir }}|{{ .chezmoi.username }}|{{ .isWorkstation }}|{{ .isLaptop }}|{{ .isServer }}")
    for profile, flags in (
        ("workstation", "true|false|false"),
        ("laptop", "true|true|false"),
        ("server", "false|false|true"),
    ):
        assert checker.render(template, profile, temporary) == f"{temporary / 'home'}|shell-test|{flags}"
print("Script convention regression checks passed.")
