"""Run against a rendered installer: python3 tests/check_papirus_installer.py SCRIPT HOME."""

import io
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile


def archive(path, files):
    with tarfile.open(path, "w:gz") as tar:
        for name, content in files.items():
            data = content.encode()
            member = tarfile.TarInfo(name)
            member.size = len(data)
            tar.addfile(member, io.BytesIO(data))


with tempfile.TemporaryDirectory(prefix="papirus-installer-test-") as directory:
    home = Path(directory)
    assets = home / ".local/share/chezmoi-assets/papirus"
    icons = home / ".local/share/icons"
    binaries = home / ".local/bin"
    library = home / ".local/lib"
    for path in (assets, icons, binaries, library):
        path.mkdir(parents=True)
    (library / "chezmoi_utils.sh").write_text(
        'require_command() { command -v "$1" >/dev/null; }\n'
        'log_section() { :; }\nlog_info() { :; }\n'
    )
    script = home / "install.sh"
    script.write_text(Path(sys.argv[1]).read_text().replace(sys.argv[2], str(home)))
    events = home / "events"
    cache = binaries / "gtk-update-icon-cache"
    cache.write_text(f'#!/bin/sh\necho cache >> "{events}"\n')
    cache.chmod(0o755)
    switcher = binaries / "papirus-folders"
    switcher.write_text(
        f'#!/bin/sh\necho restore >> "{events}"\n'
        f'ln -sf folder-cat-mocha-blue.svg "{icons}/Papirus/48x48/places/folder.svg"\n'
    )
    switcher.chmod(0o755)
    environment = dict(os.environ, PATH=f"{binaries}:{os.environ['PATH']}",
                       XDG_CONFIG_HOME=str(home / ".config"))
    base = {f"papirus-icon-theme-master/{theme}/index.theme": "[Icon Theme]\n"
            for theme in ("Papirus", "Papirus-Dark", "Papirus-Light")}
    base["papirus-icon-theme-master/Papirus/48x48/places/folder.svg"] = "default"
    colors = {f"papirus-folders-main/src/48x48/places/folder-cat-{flavor}-blue.svg": "v1"
              for flavor in ("mocha", "latte")}
    archive(assets / "icon-theme.tar.gz", base)
    archive(assets / "folder-colors.tar.gz", colors)
    unrelated = icons / "another-theme"
    unrelated.write_text("preserve")

    def apply():
        subprocess.run(["bash", str(script)], env=environment, check=True)

    apply()
    first_stamp = (assets / "installed.sha256").read_bytes()
    apply()
    assert events.read_text().splitlines() == ["cache"] * 3, "unchanged apply rebuilt caches"
    assert (assets / "installed.sha256").read_bytes() == first_stamp

    keep = home / ".config/papirus-folders/keep"
    keep.parent.mkdir(parents=True)
    keep.write_text("saved color")
    stale = icons / "Papirus/stale.svg"
    stale.write_text("removed upstream")
    archive(assets / "folder-colors.tar.gz", {name: "v2" for name in colors})
    apply()
    assert not stale.exists(), "update left obsolete theme files"
    assert unrelated.read_text() == "preserve"
    assert (icons / "Papirus/48x48/places/folder.svg").is_symlink(), "saved color was not restored"
    assert events.read_text().splitlines() == ["cache"] * 3 + ["restore"] + ["cache"] * 3

    successful_stamp = (assets / "installed.sha256").read_bytes()
    (assets / "folder-colors.tar.gz").write_bytes(b"corrupt archive")
    result = subprocess.run(["bash", str(script)], env=environment, capture_output=True)
    assert result.returncode != 0, "corrupt archive succeeded"
    assert (assets / "installed.sha256").read_bytes() == successful_stamp
    assert (icons / "Papirus/48x48/places/folder.svg").is_symlink()

print("Verified initial install, unchanged apply, updates, color restoration, and failed-download recovery.")
