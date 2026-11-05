"""Adaptations de chemins isolées du dépôt amont, appliquées dans le Nix store."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
paths = {
    "/usr/local/bin/nc-energie-root": "/run/current-system/sw/bin/nc-energie-root",
    "/usr/local/bin/nc-limite-charge": "/run/current-system/sw/bin/nc-limite-charge",
    "/usr/local/bin/nc-vpn-root": "/run/current-system/sw/bin/nc-vpn-root",
}
for directory in (root / "home/.local/bin", root / "home/.config/quickshell"):
    for path in directory.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        try:
            old = path.read_text()
        except UnicodeDecodeError:
            continue
        new = old
        for before, after in paths.items():
            new = new.replace(before, after)
        if new != old:
            path.write_text(new)
