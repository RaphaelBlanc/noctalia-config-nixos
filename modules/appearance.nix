{ config, lib, pkgs, noctaliaUpstream, ... }:
let
  cfg = config.programs.noctalia-config;
  grubTheme = pkgs.runCommand "nc-grub-theme" {} ''
    mkdir -p $out
    cp -r ${noctaliaUpstream}/system/grub-theme/nc/. $out/
    chmod u+w $out/theme.txt
    substituteInPlace $out/theme.txt --replace-fail '@BOOT_TITLE@' 'NixOS'
  '';
  sddmTheme = pkgs.sddm-astronaut.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      theme=$out/share/sddm/themes/sddm-astronaut-theme
      chmod -R u+w "$theme"
      cp ${noctaliaUpstream}/system/sddm/nc.conf "$theme/Themes/nc.conf"
      cp ${noctaliaUpstream}/system/sddm/nc.jpg "$theme/Backgrounds/nc.jpg"
      substituteInPlace "$theme/Themes/nc.conf" \
        --replace-fail '@LOCALE@' ${lib.escapeShellArg config.i18n.defaultLocale}
      sed -i 's|^ConfigFile=.*|ConfigFile=Themes/nc.conf|' "$theme/metadata.desktop"
      substituteInPlace "$theme/Main.qml" \
        --replace-warn 'Screen.ScreenWidth' 'Screen.width'
    '';
  });
in {
  options.programs.noctalia-config.appearance = {
    grub.enable = lib.mkEnableOption "le thème GRUB amont (GRUB doit déjà être configuré)";
    plymouth.enable = lib.mkEnableOption "Plymouth avec le thème BGRT NixOS";
    sddm.enable = lib.mkEnableOption "SDDM Wayland avec le thème nc amont";
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.appearance.grub.enable {
      assertions = [ { assertion = config.boot.loader.grub.enable;
        message = "Le thème nc nécessite une configuration GRUB existante."; } ];
      boot.loader.grub.theme = grubTheme;
    })
    (lib.mkIf cfg.appearance.plymouth.enable {
      boot.plymouth = { enable = true; theme = "bgrt"; themePackages = [ pkgs.nixos-bgrt-plymouth ]; };
      boot.kernelParams = [ "quiet" "splash" ];
    })
    (lib.mkIf cfg.appearance.sddm.enable {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
        theme = "sddm-astronaut-theme";
        extraPackages = with pkgs.kdePackages; [ qtsvg qtmultimedia qtvirtualkeyboard ];
      };
      environment.systemPackages = [ sddmTheme ];
    })
  ]);
}
