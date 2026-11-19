# Session utilisateur EPITA : le compte garde bash comme shell de connexion.
{ epitaEnv, zshCustom, source, epitaScripts }:
{ pkgs, ... }: {
  name = "noctalia-epita";
  nodes.machine = { ... }: {
    hardware.graphics.enable = true;
    security.polkit.enable = true;
    security.pam.services.noctalia = {};
    services.pipewire = { enable = true; pulse.enable = true; };
    services.speechd.enable = false;
    users.users.testeur = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "video" "render" ];
      password = "vm-only";
    };
    services.getty.autologinUser = "testeur";
    programs.bash.loginShellInit = ''
      if [ "$(tty)" = /dev/tty1 ] && [ "$USER" = testeur ]; then
        while [ ! -e "$HOME/ready" ]; do sleep 0.2; done
        export NC_FLAKE_DIR="$HOME/afs/.confs/noctalia-config-nixos"
        . "$NC_FLAKE_DIR/epita/env.sh"
        export XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=Hyprland
        trap '"$NC_FLAKE_DIR/epita/nc-session" --stop' EXIT
        Hyprland > "$HOME/hyprland.log" 2>&1
      fi
    '';
    environment.sessionVariables = {
      LIBGL_ALWAYS_SOFTWARE = "1";
      GALLIUM_DRIVER = "llvmpipe";
      AQ_NO_MODIFIERS = "1";
      QT_QUICK_BACKEND = "software";
    };
    environment.systemPackages = [ pkgs.python3 ];
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 8192;
      qemu.options = [ "-vga none -device virtio-gpu-pci" ];
    };
    system.stateVersion = "26.05";
  };
  testScript = ''
    import datetime
    import json
    import shlex

    def user(command):
        return "su - testeur -c " + shlex.quote(
            "export XDG_RUNTIME_DIR=/run/user/1000; "
            "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; "
            "export NC_FLAKE_DIR=$HOME/afs/.confs/noctalia-config-nixos; "
            ". $NC_FLAKE_DIR/epita/env.sh; "
            "export WAYLAND_DISPLAY=$(systemctl --user show-environment | sed -n 's/^WAYLAND_DISPLAY=//p'); "
            "export HYPRLAND_INSTANCE_SIGNATURE=$(systemctl --user show-environment | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p'); " + command)

    start_all()
    machine.wait_for_unit("user@1000.service")
    try:
        machine.succeed("mkdir -p /home/testeur/afs/.confs/noctalia-config-nixos")
        machine.succeed("cp -R ${epitaScripts} /home/testeur/afs/.confs/noctalia-config-nixos/epita")
        machine.succeed("touch /home/testeur/afs/.confs/noctalia-config-nixos/flake.nix")
        machine.succeed("chmod -R u+w /home/testeur/afs; chown -R testeur:users /home/testeur/afs")
        with subtest("installation complète, fichiers modifiables et persistants"):
            machine.succeed(user("ln -s ${epitaEnv} $NC_ENV_LINK; ln -s ${source} $NC_SOURCE_LINK; ln -s ${zshCustom} $NC_ZSH_LINK"))
            machine.succeed(user("python3 $NC_FLAKE_DIR/epita/prepare.py > ~/install.log 2>&1"), timeout=300)
            machine.succeed(user("test -L ~/.config/kitty; test -L ~/Pictures; test -L ~/.zshrc; test -w ~/.config/kitty/kitty.conf"))
            machine.succeed(user("fc-match -f '%{family}' 'Material Symbols Rounded' | grep -q 'Material Symbols Rounded'"))
            machine.succeed(user("printf 'PERSISTENCE_TEST=oui\\n' >> ~/.config/nc/reglages.conf; python3 $NC_FLAKE_DIR/epita/prepare.py > ~/second-install.log 2>&1"), timeout=60)
            machine.succeed(user("grep -q PERSISTENCE_TEST=oui ~/.config/nc/reglages.conf"))
            # ZLE confirme le chargement des plugins et la disponibilité de l'invite.
            hook = 'autoload -Uz add-zle-hook-widget\n_nc_ready() { print $ZSH_VERSION > ~/terminal-ready; }\nadd-zle-hook-widget line-init _nc_ready\n'
            machine.succeed(user("printf %s " + shlex.quote(hook) + " > ~/.zshrc.perso"))
            machine.succeed("touch /home/testeur/ready")

        with subtest("services démarrés par le vrai hook Hyprland"):
            machine.wait_until_succeeds(user("hyprctl -i 0 -j monitors | jq -e 'length > 0'"), timeout=45)
            machine.wait_until_succeeds(user("systemctl --user is-active noctalia.service nc-ile.service hypridle.service nc-theme-sync.timer"), timeout=45)
            machine.wait_until_succeeds(user("noctalia msg status"), timeout=60)
            machine.wait_until_succeeds(user("qs -c nc-ile ipc show"), timeout=60)
            machine.succeed(user("zsh -ic '(( $+functions[_zsh_highlight] && $+functions[_zsh_autosuggest_start] && $+functions[p10k] ))'"))

        with subtest("Super Entrée utilise Zsh sans changer le shell du compte"):
            machine.send_key("meta_l-ret")
            machine.wait_for_file("/home/testeur/terminal-ready", timeout=120)
            machine.wait_until_succeeds(user("hyprctl -i 0 -j activewindow | jq -e '.class == \"kitty\"'"), timeout=60)
            machine.send_chars("print NC_INPUT_OK > ~/input-ok", delay=datetime.timedelta(milliseconds=150))
            # Redimensionner le terminal pendant la saisie, sans perdre le buffer.
            for width, height in [(900, 600), (700, 450), (1000, 650)]:
                lua = "hl.dispatch(hl.dsp.window.float({action='enable'})); hl.dispatch(hl.dsp.window.resize({x=%d,y=%d}))" % (width, height)
                machine.succeed(user("hyprctl -i 0 eval " + shlex.quote(lua)))
            machine.sleep(2)
            machine.send_key("ret")
            machine.wait_for_file("/home/testeur/input-ok", timeout=30)
            machine.succeed("grep -q NC_INPUT_OK /home/testeur/input-ok")
            errors = json.loads(machine.succeed(user("hyprctl -i 0 -j configerrors")))
            assert not [e for e in errors if e.strip()], errors
            machine.screenshot("terminal-epita")

        with subtest("les couleurs sur AFS sont répercutées dans Kitty"):
            machine.succeed(user("systemctl --user stop nc-theme-sync.path"))
            code = "import json,pathlib; p=pathlib.Path.home()/'.config/noctalia/colors.json'; c=json.loads(p.read_text()); c['mSurface']='#112233'; p.write_text(json.dumps(c))"
            machine.succeed(user("python3 -c " + shlex.quote(code)))
            machine.wait_until_succeeds(user("grep -q 'background #112233' ~/.config/kitty/themes/noctalia-dynamic.conf"), timeout=30)
            machine.screenshot("couleurs-epita")
    finally:
        print(machine.execute(user("for s in /run/user/1000/kitty-*; do kitty @ --to unix:$s get-text --extent=screen 2>/dev/null; done"))[1])
        print(machine.execute(user("systemctl --user status noctalia.service nc-ile.service nc-theme-sync.timer --no-pager; tail -n 100 ~/hyprland.log"))[1])
        print(machine.execute(user("hyprctl -i 0 configerrors; tail -n 100 /run/user/1000/hypr/*/hyprland.log"))[1])
        print(machine.execute(user("tail -n 50 ~/install.log"))[1])
        machine.screenshot("etat-final-epita")
        machine.execute("journalctl -b --no-pager > /tmp/epita-journal.log")
        machine.copy_from_machine("/tmp/epita-journal.log")
        for name in ["install.log", "second-install.log", "hyprland.log"]:
            machine.execute("cp /home/testeur/" + name + " /tmp/" + name + " 2>/dev/null || touch /tmp/" + name)
            machine.copy_from_machine("/tmp/" + name)
  '';
}
