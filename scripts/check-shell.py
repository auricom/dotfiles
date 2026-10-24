#!/usr/bin/env python3
"""Local shell contracts, formatting, lint, template rendering, and helper tests."""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

# These produce prompt data or forward another program's CLI; no UI framework.
EXCEPTIONS = {
    "executable_github-icon": "POSIX git prompt data",
    "executable_fishfy-path": "POSIX path prompt data",
    "executable_relative-time-commit": "POSIX time prompt data",
    "executable_recur-app": "transparent launcher forwarding Recur arguments",
}


def run(*args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, **kwargs)


def contract(path, text):
    """Deliberately narrow rules; ShellCheck handles shell semantics."""
    errors = []
    lifecycle = path.parent.name == ".chezmoiscripts"
    command = path.parent == ROOT / "dot_local/bin"
    if command and path.name in EXCEPTIONS:
        expected = "#!/bin/sh" if "POSIX" in EXCEPTIONS[path.name] else "#!/usr/bin/env bash"
        if not text.startswith(expected + "\n"):
            errors.append("exception must retain its declared interpreter")
        return errors
    if lifecycle:
        if not path.name.startswith("run_") or not path.name.endswith(".sh.tmpl"):
            errors.append("lifecycle scripts must be named run_*.sh.tmpl")
        for name in ("script-header", "script-footer"):
            if f'includeTemplate "{name}" .' not in text:
                errors.append(f"use the shared {name} template")
        if "main() {" not in text:
            errors.append("define main() for the shared footer")
    elif command:
        for required in (
            "#!/usr/bin/env bash\n", "set -Eeuo pipefail",
            'source "${HOME}/.local/lib/common_utils.sh"', 'main() {', 'main "$@"',
        ):
            if required not in text:
                errors.append(f"missing {required!r}")
        if not text.startswith("#!/usr/bin/env bash\n"):
            errors.append("Bash shebang must be the first line")
        if not text.rstrip().endswith('main "$@"'):
            errors.append('entry point must be the final line: main "$@"')
        if not re.search(r"trap '(report_error|notify_error) .*' ERR", text):
            errors.append("install the shared error reporter")
        if "require_no_args " not in text and "--help" not in text:
            errors.append("provide --help before doing work")
    if command or lifecycle:
        if "log_section " not in text:
            errors.append("use log_section for operation headers")
        if re.search(r"^\s*(?:function\s+)?(?:log_\w+|confirm|prompt_input|run_spin)\s*\(\)", text, re.M):
            errors.append("use shared UI helpers instead of redefining them")
        if re.search(r"\bgum\s+(?:confirm|input|choose|style|log|spin)\b", text):
            errors.append("call shared UI helpers instead of gum directly")
        if re.search(r"\\(?:033|e|x1[bB])", text):
            errors.append("keep ANSI styling in the shared library")
        if "$BASH_COMMAND" in text:
            errors.append("error handlers must not execute BASH_COMMAND")
    return errors


def lint(path, text, *, formatted=False):
    dialect = "sh" if text.startswith("#!/bin/sh\n") else "bash"
    run(dialect, "-n", str(path))
    run("shellcheck", "--rcfile=" + str(ROOT / ".shellcheckrc"), "--shell=" + dialect, str(path))
    if formatted:
        # Explicit indent also covers extensionless files in temporary paths.
        run("shfmt", "-d", "-i", "4", str(path))


def render(path, profile, temporary):
    data = {
        "formFactor": profile, "isServer": profile == "server",
        "isDesktop": profile == "workstation", "isLaptop": profile == "laptop",
        "isWorkstation": profile != "server",
    }
    fixture_home = temporary / "home"
    fixture_home.mkdir(exist_ok=True)
    config_tree = fixture_home / "dot_config"
    if not config_tree.exists():
        config_tree.symlink_to(ROOT / "dot_config", target_is_directory=True)
    config = temporary / "config.json"
    config.write_text(json.dumps({"data": data}))
    text = path.read_text()
    # The only network lookup in these scripts: fixture the release tag while
    # leaving its quoting and surrounding shell subject to the real renderer.
    text = text.replace('(gitHubLatestRelease "stanio/Bibata_Cursor").TagName', '"v2.0.7"')
    return run(
        "chezmoi", "--config", str(config), "--source", str(ROOT),
        "--destination", str(temporary / "home"), "--cache", str(temporary / "cache"),
        "--persistent-state", str(temporary / "state.boltdb"),
        "--override-data", json.dumps({"chezmoi": {
            "homeDir": str(fixture_home), "username": "shell-test",
            "hostname": "shell-test", "os": "linux", "arch": "amd64",
        }}),
        "execute-template", input=text, capture_output=True,
    ).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fix", action="store_true", help="format plain shell sources first")
    parser.add_argument("files", nargs="*", help="changed paths; no paths checks everything")
    args = parser.parse_args()
    for tool in ("bash", "sh", "shellcheck", "shfmt", "chezmoi"):
        if not shutil.which(tool):
            parser.error(f"missing {tool}; run mise install and use mise exec --")

    all_paths = sorted(
        [p for p in (ROOT / "dot_local/bin").glob("executable_*") if p.is_file()]
        + list((ROOT / "dot_local/lib").glob("*.sh"))
        + [p for p in (ROOT / ".chezmoiscripts").iterdir() if p.is_file()]
    )
    changed = {(ROOT / name).resolve() for name in args.files}
    # A shared library, data file, renderer, or template change affects consumers.
    full = not changed or any(p not in all_paths or p.parent == ROOT / "dot_local/lib" for p in changed)
    paths = all_paths if full else [p for p in all_paths if p in changed]
    failures = []
    for path in paths:
        for error in contract(path, path.read_text()):
            failures.append(f"{path.relative_to(ROOT)}: {error}")
    header = (ROOT / ".chezmoitemplates/script-header").read_text()
    for required in ("#!/usr/bin/env bash\n", "set -Eeuo pipefail", "chezmoi_utils.sh", 'trap \'report_error "$?" "$LINENO"\' ERR'):
        if required not in header:
            failures.append(f"script-header: missing {required!r}")
    if (ROOT / ".chezmoitemplates/script-footer").read_text().strip().splitlines()[-1] != 'main "$@"':
        failures.append('script-footer: must end with main "$@"')
    if failures:
        raise SystemExit("\n".join(failures))

    with tempfile.TemporaryDirectory(prefix="chezmoi-shell-check-") as directory:
        temporary = Path(directory)
        for path in paths:
            print(f"Checking {path.relative_to(ROOT)}", flush=True)
            if path.suffix == ".tmpl":
                for profile in ("workstation", "laptop", "server"):
                    try:
                        text = render(path, profile, temporary)
                    except subprocess.CalledProcessError as error:
                        print(error.stderr, file=sys.stderr)
                        raise
                    if not text.strip():
                        continue  # Disabled lifecycle script for this profile.
                    rendered = temporary / f"{profile}-{path.stem}"
                    rendered.write_text(text)
                    lint(rendered, text)
            else:
                if args.fix:
                    run("shfmt", "-w", "-i", "4", str(path))
                lint(path, path.read_text(), formatted=True)
    run(sys.executable, "tests/check_shell_helpers.py")
    run(sys.executable, "tests/check_shell_contract.py")
    print(f"Shell validation passed ({len(paths)} sources; templates checked for three profiles).")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from error
