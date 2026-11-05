{ config, lib, pkgs, noctaliaUpstream, ... }:
let
  cfg = config.programs.noctalia-config;
  native = import ../nix/packages.nix { inherit pkgs; upstream = noctaliaUpstream; };
  zshCustom = pkgs.runCommand "nc-zsh-custom" {} ''
    mkdir -p $out/themes $out/plugins
    ln -s ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k $out/themes/powerlevel10k
    ln -s ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions $out/plugins/zsh-autosuggestions
    # Le paquet Nix ne fournit pas le nom *.plugin.zsh attendu par oh-my-zsh.
    mkdir -p $out/plugins/zsh-syntax-highlighting
    ln -s ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
      $out/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
    ln -s ${pkgs.zsh-fzf-tab}/share/fzf-tab $out/plugins/fzf-tab
  '';
in {
  options.programs.noctalia-config = {
    enable = lib.mkEnableOption "le bureau noctalia-config (fichiers utilisateur via install.sh)";
    noctaliaPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.noctalia;
      description = "Paquet Noctalia v5 (par défaut celui de nixpkgs, précompilé dans le cache officiel).";
    };
    recommendedServices = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Activer NetworkManager, Bluetooth, UPower, PipeWire et power-profiles-daemon.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [ {
    assertions = [ {
      assertion = lib.versionAtLeast config.programs.hyprland.package.version "0.55";
      message = "noctalia-config utilise la configuration Lua : Hyprland >= 0.55 requis (nixos-unstable conseillé).";
    } ];

    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };
    programs.zsh.enable = true;
    programs.dconf.enable = true;
    security.polkit.enable = true;
    # Noctalia vérifie le mot de passe de l'utilisateur via PAM lors du déverrouillage.
    security.pam.services.noctalia = {};
    services.gnome.gnome-keyring.enable = lib.mkDefault true;
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };
    environment.sessionVariables = {
      ZSH = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
      ZSH_CUSTOM = "${zshCustom}";
    };
    fonts.packages = with pkgs; [
      nerd-fonts.caskaydia-cove noto-fonts adwaita-fonts material-symbols
    ];
    environment.systemPackages = with pkgs; [
      native.installer cfg.noctaliaPackage quickshell hypridle uwsm
      kitty nautilus sushi qt6Packages.qt6ct papirus-icon-theme
      cava swaybg imagemagick jq grim slurp swappy wl-clipboard wtype zenity
      brightnessctl libnotify python3 libqalculate playerctl fastfetch bluez glib
      git curl wget unzip zip xdg-utils fontconfig coreutils diffutils findutils
      gnused gnugrep gawk procps util-linux pciutils usbutils inotify-tools
      wf-recorder libva-utils (tesseract.override { enableLanguages = [ "eng" "fra" ]; })
      sound-theme-freedesktop libsecret
      networkmanager pipewire wireplumber
      neovim ripgrep fd nodejs gcc gnumake tree-sitter gitui
      fzf zoxide eza bat delta lazygit yazi
    ];
    # NixOS n'installe pas toujours une unité utilisateur avec le paquet hypridle.
    systemd.user.services.hypridle = {
      description = "Hypridle (noctalia-config)";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      # Les commandes du fichier hypridle.conf ont besoin du PATH importé par UWSM.
      environment.PATH = lib.mkForce null;
      serviceConfig = {
        ExecStart = "${pkgs.hypridle}/bin/hypridle";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  } (lib.mkIf cfg.recommendedServices {
    networking.networkmanager.enable = lib.mkDefault true;
    networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
    hardware.bluetooth.enable = lib.mkDefault true;
    services.upower.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    security.rtkit.enable = lib.mkDefault true;
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
      wireplumber.enable = lib.mkDefault true;
    };
  }) ]);
}
