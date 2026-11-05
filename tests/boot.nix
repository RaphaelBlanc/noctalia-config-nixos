{ noctaliaConfigModule }:
{ ... }: {
  name = "noctalia-config-boot";
  nodes.machine = { ... }: {
    imports = [ noctaliaConfigModule ];
    programs.noctalia-config = {
      enable = true;
      appearance = {
        grub.enable = true;
        plymouth.enable = true;
        sddm.enable = true;
      };
    };
    users.users.testeur = { isNormalUser = true; uid = 1000; password = "vm-only"; };
    services.speechd.enable = false;
    boot.loader.grub = { enable = true; device = "/dev/vda"; };
    boot.loader.timeout = 1;
    environment.sessionVariables = { LIBGL_ALWAYS_SOFTWARE = "1"; QT_QUICK_BACKEND = "software"; };
    virtualisation = {
      useBootLoader = true;
      useEFIBoot = false;
      memorySize = 4096;
      cores = 4;
      diskSize = 8192;
      qemu.options = [ "-vga none -device virtio-vga" ];
    };
    system.stateVersion = "26.05";
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("display-manager.service")
    machine.succeed("test -f /boot/grub/grub.cfg")
    machine.succeed("grep -q theme /boot/grub/grub.cfg")
    machine.succeed("test -e /etc/plymouth/plymouthd.conf")
    machine.wait_until_succeeds("pgrep -u sddm -f sddm-greeter", timeout=120)
    machine.sleep(3)
    machine.screenshot("connexion-sddm")
    machine.execute("journalctl -b --no-pager > /tmp/journal-boot.log")
    machine.copy_from_machine("/tmp/journal-boot.log")
  '';
}
