"""Installation EPITA : données sur AFS, exécutables et caches locaux au poste."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


def writable(path: Path) -> None:
    if path.is_symlink():
        return
    path.chmod(path.stat().st_mode | 0o200 | (0o100 if path.is_dir() else 0))
    if path.is_dir():
        for child in path.iterdir():
            writable(child)


def copy_missing(src: Path, dst: Path) -> None:
    """AFS est prioritaire après migration ; aucun conflit local n'est écrasé."""
    if not dst.exists() and not dst.is_symlink():
        if src.is_dir():
            shutil.copytree(src, dst, symlinks=True)
        else:
            shutil.copy2(src, dst, follow_symlinks=False)
    elif src.is_dir() and dst.is_dir():
        for child in src.iterdir():
            copy_missing(child, dst / child.name)


class PersistentHome:
    def __init__(self, home: Path):
        self.home = home
        self.root = home / "afs/.confs/noctalia-config"
        self.root.mkdir(parents=True, exist_ok=True)
        self.backup = self.root / "migration-backups" / time.strftime("%Y%m%d-%H%M%S")

    def link(self, rel: str, directory: bool, prefer_local: bool = False) -> None:
        local, stored = self.home / rel, self.root / "home" / rel
        stored.parent.mkdir(parents=True, exist_ok=True)
        if local.is_symlink() and local.resolve() == stored.resolve():
            return
        if local.exists() and not stored.exists() and not stored.is_symlink():
            # Une première migration ne duplique pas tous les fonds d'écran.
            if local.is_symlink():
                if local.is_dir():
                    shutil.copytree(local, stored, symlinks=True)
                else:
                    shutil.copy2(local, stored)
                local.unlink()
            else:
                shutil.move(str(local), stored)
        if local.exists() or local.is_symlink():
            # Conserver une copie avant de retirer le chemin local, même en cas
            # de conflit avec un réglage déjà enregistré sur un autre poste.
            backup = self.backup / rel
            index = 1
            while backup.exists() or backup.is_symlink():
                backup = self.backup / (rel + f".{index}")
                index += 1
            backup.parent.mkdir(parents=True, exist_ok=True)
            if local.is_dir():
                shutil.copytree(local, backup, symlinks=True, dirs_exist_ok=True)
            else:
                shutil.copy2(local, backup, follow_symlinks=False)
            if prefer_local and not directory:
                shutil.copy2(local, stored)
            else:
                copy_missing(local, stored)
            if local.is_dir() and not local.is_symlink():
                shutil.rmtree(local)
            else:
                local.unlink()
        if directory:
            stored.mkdir(parents=True, exist_ok=True)
        if stored.exists():
            writable(stored)
        local.parent.mkdir(parents=True, exist_ok=True)
        local.symlink_to(stored, target_is_directory=directory)


def write_changed(path: Path, text: str) -> None:
    if path.exists() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def setup_fonts(home: Path, env: Path) -> None:
    fonts = home / ".local/share/fonts"
    fonts.mkdir(parents=True, exist_ok=True)
    for name, target in {"nc-nix-fonts": env / "share/fonts",
                         "MaterialSymbolsRounded.ttf": env / "share/fonts/truetype/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"}.items():
        link = fonts / name
        if not link.exists() or link.is_symlink():
            link.unlink(missing_ok=True)
            link.symlink_to(target)
    subprocess.run([str(env / "bin/fc-cache"), "-f", str(fonts)], check=True,
                   stdout=subprocess.DEVNULL)


def prepare() -> None:
    home = Path.home()
    if not (home / "afs").is_dir():
        raise SystemExit("AFS absent : le dossier ~/afs doit être monté avant de lancer nc-start.")
    source = Path(os.environ["NC_SOURCE_LINK"]).resolve()
    env = Path(os.environ["NC_ENV_LINK"])
    repo = Path(os.environ["NC_FLAKE_DIR"])
    persistent = PersistentHome(home)
    paths = {"Pictures": True, ".local/bin": True,
             ".local/state/noctalia/storage.key": False,
             ".local/state/noctalia-config": True}
    for parent in (".config", ".local/share"):
        for item in (source / "home" / parent).iterdir():
            paths[f"{parent}/{item.name}"] = item.is_dir()
    for name in (".zshrc", ".p10k.zsh", ".face", ".zshrc.perso"):
        paths[name] = False
    for rel, directory in paths.items():
        persistent.link(rel, directory)
    # Reprendre la clé persistée par l'ancienne version du lanceur.
    old_key = home / ".config/nc/storage.key"
    key = home / ".local/state/noctalia/storage.key"
    if old_key.is_file() and not key.exists():
        shutil.copyfile(old_key, key)
        key.chmod(0o600)
    # L'installateur vérifie les polices et lance des services de génération :
    # ils doivent déjà pouvoir trouver les paquets, même hors de Hyprland.
    setup_fonts(home, env)
    subprocess.run([str(env / "bin/systemctl"), "--user", "import-environment",
                    "PATH", "XDG_DATA_DIRS", "ZSH", "ZSH_CUSTOM"], check=True)

    # Une nouvelle source ou adaptation déclenche l'installateur amont, qui
    # remplace les marqueurs et conserve les fichiers personnels.
    fingerprint = hashlib.sha256(
        (str(source) + str(env.resolve())).encode() + Path(__file__).read_bytes()
    ).hexdigest()
    marker = persistent.root / "installed-version"
    if (not marker.exists() or marker.read_text().strip() != fingerprint
            or not (home / ".config/hypr/hyprland.lua").exists()
            or "--reinstall" in sys.argv):
        # Les remplacements atomiques de l'installateur remplacent les liens de
        # fichiers ; les matérialiser pour que ses sauvegardes soient de vrais
        # instantanés, puis rétablir les liens après installation.
        for rel, directory in paths.items():
            local = home / rel
            if not directory and local.is_file() and local.is_symlink():
                temporary = local.with_name(local.name + ".nc-install")
                shutil.copy2(local, temporary)
                temporary.replace(local)
        subprocess.run([str(env / "bin/nc-nixos-install"), "--no-system", "--oui", "--fr"],
                       check=True, stdin=subprocess.DEVNULL, start_new_session=True)
        for rel, directory in paths.items():
            persistent.link(rel, directory, prefer_local=not directory)
        marker.write_text(fingerprint + "\n")

    # Le shell du compte école reste inchangé ; Kitty ouvre le Zsh de la config.
    for name in ("nc-start", "nc-zsh"):
        link = home / "afs/bin" / name
        link.parent.mkdir(parents=True, exist_ok=True)
        target = repo / "epita" / name
        if link.is_symlink() and link.resolve() == target.resolve():
            continue
        if link.exists() or link.is_symlink():
            backup = persistent.backup / "bin" / name
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(link), backup)
        link.symlink_to(target)
    kitty = home / ".config/kitty/kitty.conf"
    content = kitty.read_text()
    include = "include nc-epita.conf"
    if include not in content.splitlines():
        # Le fichier perso garde le dernier mot, comme dans la config amont.
        content = content.replace("globinclude perso.conf", include + "\nglobinclude perso.conf")
        if include not in content.splitlines():
            content += "\n" + include + "\n"
        write_changed(kitty, content)
    write_changed(kitty.with_name("nc-epita.conf"), f'shell "{home}/afs/bin/nc-zsh"\n')
    # Les commandes passent aussi par uwsm-app alors que la session EPITA
    # lance directement Hyprland. Remplacer aussi l'ancien wrapper /tmp.
    app = home / ".local/bin/uwsm-app"
    write_changed(app, f'''#!/usr/bin/env bash
if systemctl --user is-active --quiet 'wayland-session@*.target' 2>/dev/null; then
  exec "{env}/bin/uwsm-app" "$@"
fi
while [ $# -gt 0 ]; do
  case "$1" in --) shift; break ;; -*) shift ;; *) break ;; esac
done
exec "$@"
''')
    app.chmod(0o755)

    # Démarrer systemd une fois les sockets de Hyprland disponibles.
    lua = home / ".config/hypr/hyprland.lua"
    hook = 'require("nc.epita")'
    if hook not in lua.read_text().splitlines():
        write_changed(lua, lua.read_text() + "\n" + hook + "\n")
    command = str(repo / "epita/nc-session")
    write_changed(home / ".config/hypr/nc/epita.lua",
                  'hl.on("hyprland.start", function()\n'
                  f'    hl.exec_cmd({json.dumps(command)})\nend)\n')

    # Les paquets utilisateur ne fournissent pas leurs unités au gestionnaire
    # systemd de NixOS. Les exposer explicitement pour cette session.
    units = home / ".config/systemd/user"
    for parent in (env / "lib/systemd/user", env / "share/systemd/user"):
        if parent.is_dir():
            for unit in parent.glob("xdg-*.service"):
                write_changed(units / unit.name, unit.read_text())
    for unit in units.glob("*.service"):
        content = unit.read_text()
        def executable(match: re.Match) -> str:
            candidate = env / "bin" / match[1]
            return str(candidate) if candidate.exists() else match[0]
        content = re.sub(r"/(?:usr/bin|run/current-system/sw/bin)/([\w.-]+)", executable, content)
        write_changed(unit, content)
    # graphical-session.target refuse les démarrages manuels. Un vrai target
    # de session le tire comme dépendance et le maintient pendant Hyprland.
    write_changed(units / "nc-epita-session.target", """[Unit]
Description=Session graphique Noctalia EPITA
BindsTo=graphical-session.target
After=graphical-session.target
""")
    write_changed(units / "hypridle.service", f"""[Unit]
Description=Hypridle (session EPITA)
PartOf=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY
[Service]
ExecStart={env}/bin/hypridle
Restart=on-failure
[Install]
WantedBy=graphical-session.target
""")
    # AFS ne garantit pas les événements inotify d'un autre client. Un timer
    # assure aussi la synchronisation des couleurs sur ce système de fichiers.
    write_changed(units / "nc-theme-sync.timer", """[Unit]
Description=Synchronisation des couleurs Noctalia sur AFS
PartOf=graphical-session.target
[Timer]
OnActiveSec=1s
OnUnitActiveSec=5s
Unit=nc-theme-sync.service
[Install]
WantedBy=graphical-session.target
""")
    write_changed(units / "nc-theme-sync.service.d/epita.conf", f"""[Service]
ExecStart=
ExecStart={repo}/epita/nc-theme-check
""")
    services = home / ".local/share/dbus-1/services"
    services.mkdir(parents=True, exist_ok=True)
    for service in (env / "share/dbus-1/services").glob("*.service"):
        write_changed(services / service.name, service.read_text())


if __name__ == "__main__":
    prepare()
