"""Check an installation: python3 tests/check_papirus.py ICONS_DIR PAPIRUS_FOLDERS."""

from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

icons = Path(sys.argv[1]).resolve()
switcher = str(Path(sys.argv[2]).resolve())
colors = "blue flamingo green lavender maroon mauve peach pink red rosewater sapphire sky teal yellow".split()
expected = {f"cat-{flavor}-{color}" for flavor in ("mocha", "latte") for color in colors}

for theme in ("Papirus", "Papirus-Dark", "Papirus-Light"):
    directory = icons / theme
    result = subprocess.run(
        ["bash", switcher, "--list", "--theme", str(directory)],
        check=True, capture_output=True, text=True,
    )
    available = {line.split()[-1] for line in result.stdout.splitlines() if line.strip()}
    assert {name for name in available if name.startswith("cat-")} == expected
    for size in (22, 24, 32, 48, 64):
        for color in expected:
            ET.parse(directory / f"{size}x{size}/places/folder-{color}-documents.svg")

print("Verified all 28 colors in all three themes at five icon sizes.")
