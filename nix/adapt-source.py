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

diag = root / "home/.local/bin/nc-diag"
if diag.is_file():
    txt = diag.read_text()
    old_depot = """    if depot and os.path.isdir(os.path.join(depot, ".git")):
        rev, _ = sortie(["git", "-C", depot, "log", "-1", T("--format=%h du %cd", "--format=%h (%cd)"),
                         T("--date=format:%d/%m/%Y", "--date=short")])
        b.ok(T(f"noctalia-config : version {rev}", f"noctalia-config: version {rev}"))
    else:"""
    new_depot = """    if depot and os.path.isdir(os.path.join(depot, ".git")):
        rev, _ = sortie(["git", "-C", depot, "log", "-1", T("--format=%h du %cd", "--format=%h (%cd)"),
                         T("--date=format:%d/%m/%Y", "--date=short")])
        b.ok(T(f"noctalia-config : version {rev}", f"noctalia-config: version {rev}"))
    elif os.path.exists(os.path.join(HOME, ".config/nc/version-amont-nix")):
        rev = open(os.path.join(HOME, ".config/nc/version-amont-nix")).read().strip()[:7]
        b.ok(T(f"noctalia-config : version {rev} (NixOS)", f"noctalia-config: version {rev} (NixOS)"))
    else:"""
    if old_depot in txt:
        diag.write_text(txt.replace(old_depot, new_depot, 1))

verrou = root / "home/.local/bin/nc-verrou-place"
if verrou.is_file():
    vtxt = verrou.read_text()
    old_ecrans = '    ecrans = [e for e in ecrans if not e.get("disabled")]'
    new_ecrans = '    ecrans = [e for e in ecrans if not e.get("disabled") and e.get("name") != "FALLBACK" and not str(e.get("name", "")).startswith("HEADLESS")]'
    if old_ecrans in vtxt:
        verrou.write_text(vtxt.replace(old_ecrans, new_ecrans, 1))

ile_etat = root / "home/.local/bin/nc-ile-etat"
if ile_etat.is_file():
    itxt = ile_etat.read_text()
    old_wifi_fn = "wifi() {\n  local connus"
    new_wifi_fn = """wifi() {
  if ! command -v nmcli >/dev/null 2>&1; then
    local eth_if
    eth_if="$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}')"
    [ -n "$eth_if" ] && printf "net=1\\tEthernet (%s)\\t100\\t1\\t1\\n" "$eth_if"
    return
  fi
  local connus"""
    old_wifi_st = """echo "wifi=$(noctalia msg wifi-status 2>/dev/null)"
echo "reseau=$(timeout 3 nmcli -t -f NAME,TYPE con show --active 2>/dev/null | grep -v -e ':loopback' -e ':bridge' | head -1 | cut -d: -f1)"
echo "bluetooth=$(noctalia msg bluetooth-status 2>/dev/null)"
echo "dnd=$(noctalia msg notification-dnd-status 2>/dev/null)"
echo "profil=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
  --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed -nE "s/^\\(<'([a-z-]+)'>,\\)$/\\1/p")" """.strip()
    new_wifi_st = """w_st="$(noctalia msg wifi-status 2>/dev/null)"
r_nm="$(timeout 3 nmcli -t -f NAME,TYPE con show --active 2>/dev/null | grep -v -e ':loopback' -e ':bridge' | head -1 | cut -d: -f1)"
if [ -z "$r_nm" ] || [[ "$w_st" == error* ]]; then
  eth_if="$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}')"
  if [ -n "$eth_if" ]; then
    w_st="on"
    r_nm="Ethernet ($eth_if)"
  fi
fi
echo "wifi=$w_st"
echo "reseau=$r_nm"
echo "bluetooth=$(noctalia msg bluetooth-status 2>/dev/null)"
echo "dnd=$(noctalia msg notification-dnd-status 2>/dev/null)"
p_act="$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
  --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed -nE "s/^\\(<'([a-z-]+)'>,\\)$/\\1/p")"
echo "profil=${p_act:-balanced}" """.strip()
    itxt = itxt.replace(old_wifi_fn, new_wifi_fn, 1).replace(old_wifi_st, new_wifi_st, 1)
    ile_etat.write_text(itxt)




gpu_regle = root / "home/.local/bin/nc-gpu-regle"
if gpu_regle.is_file():
    gtxt = gpu_regle.read_text()
    old_g = """nc_profil_courant() {
  if [ -n "${NC_PROFIL:-}" ]; then printf '%s\n' "$NC_PROFIL"; return 0; fi
  { gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
      --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null || :; } \\
    | sed -n "s/^(<'\([a-z-]*\)'>,)$/\1/p"
}"""
    new_g = """nc_profil_courant() {
  if [ -n "${NC_PROFIL:-}" ]; then printf '%s\n' "$NC_PROFIL"; return 0; fi
  _ncg_p=$({ gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
      --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null || :; } \\
    | sed -n "s/^(<'\([a-z-]*\)'>,)$/\1/p")
  if [ -n "$_ncg_p" ]; then
    printf '%s\n' "$_ncg_p"
  elif [ -r "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nc-profil-manuel" ]; then
    cat "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nc-profil-manuel"
  else
    printf 'balanced\n'
  fi
  unset _ncg_p
}"""
    if old_g in gtxt:
        gpu_regle.write_text(gtxt.replace(old_g, new_g, 1))

psync = root / "home/.local/bin/nc-profile-sync"
if psync.is_file():
    ptxt = psync.read_text()
    old_p1 = """set_profile() {
  noctalia msg power-set "$1" >/dev/null 2>&1 ||
    gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
      --method org.freedesktop.DBus.Properties.Set net.hadess.PowerProfiles ActiveProfile "<'$1'>" >/dev/null 2>&1
}"""
    new_p1 = """set_profile() {
  noctalia msg power-set "$1" >/dev/null 2>&1 ||
    gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
      --method org.freedesktop.DBus.Properties.Set net.hadess.PowerProfiles ActiveProfile "<'$1'>" >/dev/null 2>&1 ||
    printf '%s\n' "$1" > "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nc-profil-manuel"
}"""
    old_p2 = """  gdbus monitor --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower &
  wait"""
    new_p2 = """  gdbus monitor --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower &
  inotifywait -m -q -e close_write,create "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" --include '/nc-profil-manuel$' &
  wait"""
    ptxt = ptxt.replace(old_p1, new_p1, 1).replace(old_p2, new_p2, 1)
    psync.write_text(ptxt)

smsg = root / "home/.local/bin/nc-shell-msg"
if smsg.is_file():
    stxt = smsg.read_text()
    old_s = "  power-cycle)     nmsg power-cycle ;;"
    new_s = """  power-cycle)
    if gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
         --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile >/dev/null 2>&1; then
      nmsg power-cycle
    fi
    f="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nc-profil-manuel"
    cur="$(cat "$f" 2>/dev/null || echo balanced)"
    case "$cur" in
      balanced) nxt=performance; lbl="Performance" ;;
      performance) nxt=power-saver; lbl="Économie" ;;
      *) nxt=balanced; lbl="Équilibré" ;;
    esac
    printf '%s\n' "$nxt" > "$f"
    notify-send -a "Énergie" -t 2000 "Profil d'énergie" "$lbl" 2>/dev/null || true
    exit 0 ;;
  power-set)
    nxt="${2:-balanced}"
    if gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \\
         --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile >/dev/null 2>&1; then
      nmsg power-set "$nxt"
    fi
    f="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nc-profil-manuel"
    printf '%s\n' "$nxt" > "$f"
    exit 0 ;;"""
    if old_s in stxt:
        smsg.write_text(stxt.replace(old_s, new_s, 1))

eth_dir = root / "home/.local/share/noctalia/plugins/nc-ethernet"
eth_dir.mkdir(parents=True, exist_ok=True)
(eth_dir / "plugin.toml").write_text("""id          = "nc/ethernet"
name        = "Ethernet"
version     = "1.0.0"
plugin_api  = 32
author      = "noctalia-config"
license     = "MIT"
description = "Icône Ethernet dans la barre (état de l'interface filaire)."

[[widget]]
id = "ethernet"
entry = "ethernet.luau"
""")
(eth_dir / "ethernet.luau").write_text("""--!nonstrict
local dernier = nil

local function estConnecte()
  local dirs = noctalia.listDir("/sys/class/net") or {}
  for _, nom in ipairs(dirs) do
    if string.sub(nom, 1, 1) == "e" then
      local st = noctalia.readFile("/sys/class/net/" .. nom .. "/operstate")
      if st and string.match(st, "up") then return true end
    end
  end
  return false
end

local function rendre()
  local ok = estConnecte()
  if ok == dernier then return end
  dernier = ok
  barWidget.render(ui.glyph({
    name = ok and "ethernet" or "ethernet-off",
    size = 15,
    color = ok and "on_surface" or "on_surface_variant",
  }))
end

function update() rendre() end
function onClick() noctalia.runAsync({ "qs", "-c", "nc-ile", "ipc", "call", "ile", "centre" }) end

rendre()
noctalia.setUpdateInterval(10000)
""")

# Fixes UI / Quickshell / Noctalia / Hyprland pour postes EPITA
fiche = root / "home/.config/quickshell/nc-ile/Fiche.qml"
if fiche.is_file():
    ftxt = fiche.read_text()
    old_f = '    function section(r) { return r.mien !== "" ? "Mes raccourcis" : (r.aide || "Système") }'
    new_f = """    readonly property var sectionCanon: ({
        "Apps & Bar": "Applis et barre", "Apps and Bar": "Applis et barre",
        "Windows": "Fenêtres", "Desktops": "Bureaux", "Mouse": "Souris",
        "System": "Système", "AI": "IA", "My Shortcuts": "Mes raccourcis"
    })
    function section(r) {
        if (r.mien !== "") return "Mes raccourcis"
        var a = r.aide || "Système"
        return sectionCanon[a] || a
    }"""
    if old_f in ftxt:
        fiche.write_text(ftxt.replace(old_f, new_f, 1))

etat_qml = root / "home/.config/quickshell/nc-ile/Etat.qml"
if etat_qml.is_file():
    etxt = etat_qml.read_text()
    old_e1 = """    readonly property int profil: PowerProfiles.profile
    onProfilChanged: if (!jeuEnCours) activite("profil")
    function choisirProfil(p) { PowerProfiles.profile = p }
    // Le service de profils propose Performance (sans lui, ou sans ce profil : pas de bouton Performance dans Santé)
    readonly property bool performanceDisponible: PowerProfiles.hasPerformanceProfile"""
    new_e1 = """    property int profilManuel: PowerProfile.Balanced
    readonly property bool profilDbus: PowerProfiles.hasPerformanceProfile || (sys.profil_dbus === "1")
    readonly property int profil: profilDbus ? PowerProfiles.profile : profilManuel
    onProfilChanged: if (!jeuEnCours) activite("profil")
    function choisirProfil(p) {
        if (profilDbus) { PowerProfiles.profile = p; return }
        profilManuel = p
        var nom = p === PowerProfile.PowerSaver ? "power-saver" : (p === PowerProfile.Performance ? "performance" : "balanced")
        Quickshell.execDetached([bin + "nc-shell-msg", "power-set", nom])
    }
    readonly property bool performanceDisponible: true"""
    old_e2 = "            etat.sys = t\n            reac.confirmer()"
    new_e2 = """            etat.sys = t
            if (!etat.profilDbus && t.profil) {
                etat.profilManuel = t.profil === "power-saver" ? PowerProfile.PowerSaver : (t.profil === "performance" ? PowerProfile.Performance : PowerProfile.Balanced)
            }
            reac.confirmer()"""
    etxt = etxt.replace(old_e1, new_e1, 1).replace(old_e2, new_e2, 1)
    etat_qml.write_text(etxt)

centre = root / "home/.config/quickshell/nc-ile/Centre.qml"
if centre.is_file():
    ctxt = centre.read_text()
    ctxt = ctxt.replace(
        '{ cle: "wifi", icone: "wifi", nom: "Wi-Fi", page: "reseau" }',
        '{ cle: "wifi", icone: (centre.s.reseau || "").indexOf("Ethernet") === 0 ? "lan" : "wifi", nom: (centre.s.reseau || "").indexOf("Ethernet") === 0 ? "Ethernet" : "Wi-Fi", page: "reseau" }',
        1,
    )
    centre.write_text(ctxt)

ep_qml = root / "home/.config/quickshell/nc-ile/EnergieProfils.qml"
if ep_qml.is_file():
    ep_qml.write_text(ep_qml.read_text().replace(
        "    visible: etat.disponible === true",
        "    visible: etat.disponible === true && etat.assistant_root === true",
        1,
    ))

ecrans = root / "home/.config/hypr/nc/ecrans.lua"
if ecrans.is_file():
    ec_txt = ecrans.read_text()
    old_ec = """hl.on("monitor.added", function()
    tout()
    demander_infos()
    -- Écran de verrouillage recentré sur l'écran (sa taille réelle, échelle comprise)
    hl.exec_cmd("sleep 2; ~/.local/bin/nc-verrou-place")
end)"""
    new_ec = """hl.on("monitor.added", function(m)
    tout()
    demander_infos()
    -- Écran de verrouillage recentré sur l'écran (sa taille réelle, échelle comprise)
    if not (m and m.name and virtuel(m)) then
        hl.exec_cmd("sleep 2; ~/.local/bin/nc-verrou-place")
    end
end)"""
    if old_ec in ec_txt:
        ecrans.write_text(ec_txt.replace(old_ec, new_ec, 1))
