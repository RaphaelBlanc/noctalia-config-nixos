# Test intégral dans QEMU/KVM : aucun fichier de la session hôte n'est modifié.
{ noctaliaConfigModule, source }:
{ pkgs, ... }: {
  name = "noctalia-config-desktop";

  nodes.machine = { ... }: {
    imports = [ noctaliaConfigModule ];
    programs.noctalia-config.enable = true;
    programs.noctalia-config.helpers = { enable = true; users = [ "testeur" ]; };
    boot.kernelModules = [ "tun" "wireguard" ];
    networking.firewall.enable = false;
    users.users.testeur = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "video" "render" "networkmanager" ];
      password = "vm-only";
    };
    services.getty.autologinUser = "testeur";
    # Pas de synthèse vocale dans cette VM de test : évite toutes les voix MBROLA.
    # Le module destiné aux machines réelles conserve le choix de NixOS.
    services.speechd.enable = false;
    programs.bash.loginShellInit = ''
      if [ "$(tty)" = /dev/tty1 ] && [ "$USER" = testeur ]; then
        while [ ! -e "$HOME/.nc-vm-ready" ]; do sleep 0.2; done
        uwsm start -e -D Hyprland hyprland.desktop > "$HOME/hyprland-login.log" 2>&1
      fi
    '';
    environment.sessionVariables = {
      LIBGL_ALWAYS_SOFTWARE = "1";
      GALLIUM_DRIVER = "llvmpipe";
      AQ_NO_MODIFIERS = "1";
      QT_QUICK_BACKEND = "software";
    };
    environment.systemPackages = [ pkgs.mesa-demos pkgs.nftables ];
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
            "export PATH=$HOME/.local/bin:/run/wrappers/bin:/run/current-system/sw/bin:$PATH; "
            "export WAYLAND_DISPLAY=$(systemctl --user show-environment | sed -n 's/^WAYLAND_DISPLAY=//p'); " + command
        )

    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    try:
        with subtest("installation utilisateur complète"):
            machine.succeed(user("setsid -w nc-nixos-install --oui > ~/installation.log 2>&1"), timeout=240)
            machine.succeed("test -f /home/testeur/.config/hypr/hyprland.lua")
            machine.succeed("test -f /home/testeur/.config/nvim/init.lua")
            machine.succeed("grep -q /run/current-system/sw/bin/noctalia /home/testeur/.config/systemd/user/noctalia.service")
            machine.succeed(user("systemctl --user is-enabled noctalia.service nc-ile.service hypridle.service"))
            machine.succeed("touch /home/testeur/.nc-vm-ready")

        with subtest("session Hyprland et services du bureau"):
            machine.wait_until_succeeds(user("hyprctl -i 0 -j monitors | jq -e 'length > 0'"), timeout=120)
            machine.wait_until_succeeds(user("systemctl --user is-active noctalia.service nc-ile.service hypridle.service nc-profile-sync.service"), timeout=120)
            machine.wait_until_succeeds(user("noctalia msg status"), timeout=60)
            machine.wait_until_succeeds(user("qs -c nc-ile ipc show"), timeout=60)
            errors = [message for message in json.loads(machine.succeed(user("hyprctl -i 0 -j configerrors"))) if message.strip()]
            assert not errors, errors
            machine.wait_until_succeeds(user("journalctl --user -b -u noctalia.service --no-pager | grep -q 'texcache.*uploaded'"), timeout=60)
            machine.screenshot("bureau-noctalia")

        with subtest("terminal et configuration zsh"):
            machine.succeed(user("zsh -ic '(( $+functions[_zsh_highlight] && $+functions[_zsh_autosuggest_start] && $+functions[p10k] ))' > ~/zsh-validation.log 2>&1"))
            # precmd runs before the prompt is drawn. Wait for ZLE itself to
            # accept input, including on the slower shared CI runners.
            hook = 'autoload -Uz add-zle-hook-widget\n_nc_vm_ready() { : > "$HOME/zsh-ready"; }\nadd-zle-hook-widget line-init _nc_vm_ready\n'
            machine.succeed(user("printf %s " + shlex.quote(hook) + " > ~/.zshrc.perso"))
            terminal = "kitty --class nc-vm-test zsh"
            machine.succeed(user("hyprctl -i 0 eval " + shlex.quote("hl.exec_cmd(" + json.dumps(terminal) + ")")))
            machine.wait_for_file("/home/testeur/zsh-ready", timeout=120)
            machine.wait_until_succeeds(user("hyprctl -i 0 -j activewindow | jq -e '.class == \"nc-vm-test\"'"), timeout=60)
            # QEMU sendkey holds a key for 100 ms by default. Its key releases
            # must finish before the next key, especially around Shift.
            machine.send_chars("print NC_ZSH_OK > /home/testeur/terminal-ok\n", delay=datetime.timedelta(milliseconds=150))
            machine.wait_for_file("/home/testeur/terminal-ok", timeout=120)
            machine.succeed("grep -q NC_ZSH_OK /home/testeur/terminal-ok")
            machine.wait_until_succeeds(user("hyprctl -i 0 -j clients | jq -e 'any(.[]; .class == \"nc-vm-test\")'"))
            machine.screenshot("terminal-kitty")

        with subtest("assistants root déclaratifs et permissions limitées"):
            machine.succeed(user("sudo -n /run/current-system/sw/bin/nc-energie-root etat"))
            machine.succeed(user("sudo -n /run/current-system/sw/bin/nc-limite-charge etat"))
            machine.fail(user("sudo -n /run/current-system/sw/bin/nc-energie-root epp commande-invalide"))
            machine.fail(user("sudo -n /run/current-system/sw/bin/nc-vpn-root sudoers testeur"))
            machine.fail(user("sudo -n /run/current-system/sw/bin/bash -c true"))
            # Une vraie interface TUN et de vraies règles nft, uniquement dans la VM.
            machine.succeed("ip tuntap add dev nc-test mode tun")
            machine.succeed("ip link set nc-test up")
            machine.succeed("nft add table inet nc_test_preserve")
            machine.fail(user("sudo -n /run/current-system/sw/bin/nc-vpn-root activer lo 192.0.2.1@51820/udp"))
            machine.fail(user("sudo -n /run/current-system/sw/bin/nc-vpn-root activer nc-test adresse-invalide"))
            machine.fail("nft list table inet nc_vpn")
            machine.succeed(user("sudo -n /run/current-system/sw/bin/nc-vpn-root activer nc-test 192.0.2.1@51820/udp"))
            machine.succeed("nft list table inet nc_vpn")
            machine.succeed("nft list table inet nc_test_preserve")
            machine.succeed(user("sudo -n /run/current-system/sw/bin/nc-vpn-root desactiver"))
            machine.fail("nft list table inet nc_vpn")
            machine.succeed("nft list table inet nc_test_preserve")
    finally:
        machine.screenshot("etat-final")
        machine.execute("journalctl -b --no-pager > /tmp/journal-vm.log")
        machine.copy_from_machine("/tmp/journal-vm.log")
        machine.execute("test ! -f /home/testeur/installation.log || cp /home/testeur/installation.log /tmp/installation.log")
        machine.execute("test ! -f /home/testeur/hyprland-login.log || cp /home/testeur/hyprland-login.log /tmp/hyprland-login.log")
        machine.copy_from_machine("/tmp/installation.log")
        machine.execute("test -f /tmp/hyprland-login.log || touch /tmp/hyprland-login.log")
        machine.copy_from_machine("/tmp/hyprland-login.log")
        machine.execute("cp /home/testeur/zsh-validation.log /tmp/zsh-validation.log 2>/dev/null || touch /tmp/zsh-validation.log")
        machine.copy_from_machine("/tmp/zsh-validation.log")
  '';
}
