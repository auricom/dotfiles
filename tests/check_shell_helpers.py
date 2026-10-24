"""Exercise shared shell behavior with fake HOME and commands; no host changes."""

import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


with tempfile.TemporaryDirectory(prefix="shell-helper-test-") as directory:
    home = Path(directory)
    library = home / ".local/lib"
    shutil.copytree(ROOT / "dot_local/lib", library)
    binaries = home / "bin"
    binaries.mkdir()
    for tool in ("bash", "hostname"):
        (binaries / tool).symlink_to(shutil.which(tool))
    gum_binaries = home / "gum-bin"
    gum_binaries.mkdir()
    env = dict(os.environ, HOME=str(home), PATH=str(binaries), TERM="xterm-256color")
    for name in ("NO_COLOR", "DEBUG", "LOG_TIME", "UPDATE_CUSTOM_STEPS", "UPDATE_CUSTOM_SKIP"):
        env.pop(name, None)
    prefix = 'set -Eeuo pipefail; source "$HOME/.local/lib/common_utils.sh"; '

    def shell(code, *, environment=None, terminal=False, answer=b""):
        current_env = env | (environment or {})
        if not terminal:
            return subprocess.run(
                ["/bin/bash", "-c", prefix + code], env=current_env,
                input="", capture_output=True, text=True, timeout=10,
            )
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(
                ["/bin/bash", "-c", prefix + code], env=current_env,
                stdin=slave, stderr=slave, stdout=subprocess.PIPE, text=True,
            )
            os.close(slave)
            slave = None
            if answer:
                os.write(master, answer)
            stdout, _ = process.communicate(timeout=10)
            stderr = b""
            while True:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                stderr += chunk
            return subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr.decode())
        finally:
            os.close(master)
            if slave is not None:
                os.close(slave)

    logs = 'log_section "Title"; log_info "Done" host example; log_warn "Careful"; log_error "Failed"; log_debug "Hidden"'
    expected = "\n== Title ==\nINFO Done host=example\nWARN Careful\nERROR Failed\n"
    result = shell(logs)
    assert result.returncode == 0 and result.stdout == "" and result.stderr == expected, result
    result = shell('log_debug "Shown"', environment={"DEBUG": "1"})
    assert result.stderr == "DEBUG Shown\n", result
    result = shell('source "$HOME/.local/lib/common_utils.sh"; log_info "Twice"')
    assert result.returncode == 0 and result.stderr == "INFO Twice\n", result
    result = shell('run_spin "Work" bash -c "exit 37"')
    assert result.returncode == 37 and result.stderr == "INFO Work\n", result
    result = shell('require_command __missing_shell_test_command__ "test"')
    assert result.returncode == 1 and "is required for test" in result.stderr, result
    for code in ('confirm "Remove?"', 'prompt_input "Name" "default"'):
        result = shell(code)
        assert result.returncode == 2 and result.stdout == "", result
    result = shell('confirm "Remove?"', terminal=True, answer=b"\n")
    assert result.returncode == 1 and "[y/N]" in result.stderr, result
    result = shell('confirm "Remove?"', terminal=True, answer=b"yes\n")
    assert result.returncode == 0, result
    result = shell('prompt_input "Name" "default"', terminal=True, answer=b"\n")
    assert result.returncode == 0 and result.stdout == "default\n", result
    result = shell('log_info "Color"', terminal=True)
    assert "\x1b[" in result.stderr, result

    gum = gum_binaries / "gum"
    gum.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$HOME/gum-calls"\nexit "${GUM_STATUS:-0}"\n')
    gum.chmod(0o755)
    with_gum = {"PATH": f"{gum_binaries}:{binaries}"}
    for extra in ({}, {"NO_COLOR": "1"}, {"TERM": "dumb"}):
        result = shell(logs, environment=with_gum | extra)
        assert result.returncode == 0 and result.stderr == expected, result
    assert not (home / "gum-calls").exists(), "redirected logging must use plain output"
    for extra in ({"NO_COLOR": "1"}, {"TERM": "dumb"}):
        result = shell('log_info "Plain"', terminal=True, environment=with_gum | extra)
        assert "\x1b" not in result.stderr and "INFO Plain" in result.stderr, result
    result = shell('log_section "Title"; log_info "Done"', terminal=True, environment=with_gum)
    assert result.returncode == 0 and "log --structured" in (home / "gum-calls").read_text(), result
    result = shell('confirm "Remove?"', terminal=True, environment=with_gum | {"GUM_STATUS": "130"})
    assert result.returncode == 130, result
    result = shell('run_spin "Work" false', terminal=True, environment=with_gum | {"GUM_STATUS": "37"})
    assert result.returncode == 37, result
    env["PATH"] = str(binaries)

    # A failure executes once, reports once, and retains its original status.
    failing = binaries / "chezmoi"
    failing.write_text('#!/bin/bash\nprintf "called\\n" >> "$HOME/events"\nexit 23\n')
    failing.chmod(0o755)
    result = subprocess.run(
        ["/bin/bash", str(ROOT / "dot_local/bin/executable_update-dotfiles")],
        env=env | {"CHEZMOI_BIN": str(failing)}, capture_output=True, text=True, timeout=10,
    )
    assert result.returncode == 23, result
    assert (home / "events").read_text() == "called\n", result
    assert result.stderr.count("failed status=23") == 1, result
    result = shell('source "$HOME/.local/lib/notifications.sh"; send_pushover_message() { return 99; }; trap \'notify_error "$?" "$LINENO"\' ERR; (exit 23)')
    assert result.returncode == 23, result

    for command in (ROOT / "dot_local/bin").glob("executable_*"):
        if command.suffix == ".tmpl" or "require_no_args " not in command.read_text() and "--help" not in command.read_text():
            continue
        result = subprocess.run(["/bin/bash", str(command), "--help"], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0 and result.stdout.startswith("Usage:") and result.stderr == "", (command, result)
        result = subprocess.run(["/bin/bash", str(command), "--invalid-option"], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 2, (command, result)

print("Shared shell behavior passed (plain/TTY, gum/fallback, prompts, help, original failures).")
