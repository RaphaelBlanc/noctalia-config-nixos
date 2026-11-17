{ pkgs, upstream }:
let
  inherit (pkgs) lib;
  helperPath = lib.makeBinPath (with pkgs; [
    bash coreutils findutils gnugrep gnused gawk util-linux iproute2 nftables
    systemd ethtool kmod pciutils
  ]) + ":/run/current-system/sw/bin";
  helpers = pkgs.runCommand "nc-root-helpers" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    mkdir -p $out/bin
    cp ${upstream}/system/nc-{energie-root,limite-charge,vpn-root} $out/bin/
    chmod +w $out/bin/*
    substituteInPlace $out/bin/nc-energie-root $out/bin/nc-limite-charge \
      --replace-fail 'PATH=/usr/sbin:/usr/bin:/sbin:/bin' 'PATH=${helperPath}'
    substituteInPlace $out/bin/nc-vpn-root \
      --replace-fail 'PATH = "/usr/sbin:/usr/bin:/sbin:/bin"' 'PATH = "${helperPath}"'
    substituteInPlace $out/bin/nc-energie-root $out/bin/nc-vpn-root \
      --replace-fail '/usr/local/bin/' '/run/current-system/sw/bin/'
    patchShebangs $out/bin
    chmod 755 $out/bin/*
  '';
  source = pkgs.runCommand "noctalia-config-nixos-source" {
    nativeBuildInputs = [ pkgs.patch pkgs.python3 ];
  } ''
    cp -r ${upstream} $out
    chmod -R u+w $out
    cd $out
    patch --batch --fuzz=0 -p1 < ${../patches/nixos-session.patch}
    python3 ${./adapt-source.py} $out
    substituteInPlace home/.config/systemd/user/noctalia.service \
      --replace-fail 'ExecStart=/usr/bin/noctalia' 'ExecStart=/usr/bin/env noctalia'
    cp ${../README.md} README-nixos.md
    cp ${../README.md} docs/nixos.md
    # Les changements de la configuration passent par le lock Nix, jamais par un git pull du Nix store.
    cat > home/.local/bin/nc-maj <<'UPDATE'
    #!/usr/bin/env bash
    [ "''${1:-}" != verifier ] || exit 0
    printf '%s\n' 'Bureau géré par NixOS.' \
      'Dans ta configuration NixOS : nix flake update noctalia-config, puis sudo nixos-rebuild switch --flake .#MACHINE.' \
      'Ensuite : nc-nixos-install. Consulte README-nixos.md pour les changements amont et le retour arrière.'
    UPDATE
    chmod 755 home/.local/bin/nc-maj
    # Contrats vérifiés à chaque mise à jour amont.
    ! grep -R '/usr/local/bin/nc-\(energie-root\|limite-charge\|vpn-root\)' home/.local/bin
    bash -n install.sh
  '';
  installer = pkgs.writeShellApplication {
    name = "nc-nixos-install";
    runtimeInputs = with pkgs; [ bash coreutils git gnugrep gnused findutils gawk diffutils python3 jq util-linux ];
    text = ''
      if [ "$(id -u)" = 0 ]; then echo "Lance nc-nixos-install sans sudo." >&2; exit 1; fi
      if ! grep -Eq '^ID="?nixos"?$' /etc/os-release; then
        echo "Cet adaptateur est destiné à NixOS." >&2; exit 1
      fi
      bash ${source}/install.sh "$@"
      mkdir -p "$HOME/.config/nc"
      printf '%s\n' ${source} > "$HOME/.config/nc/depot"
      printf '%s\n' ${lib.escapeShellArg (upstream.rev or "unknown")} > "$HOME/.config/nc/version-amont-nix"
    '';
  };
  zshCustom = pkgs.runCommand "nc-zsh-custom" {} ''
    mkdir -p $out/themes $out/plugins
    ln -s ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k $out/themes/powerlevel10k
    ln -s ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions $out/plugins/zsh-autosuggestions
    mkdir -p $out/plugins/zsh-syntax-highlighting
    ln -s ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
      $out/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
    ln -s ${pkgs.zsh-fzf-tab}/share/fzf-tab $out/plugins/fzf-tab
  '';
  epita-env = pkgs.buildEnv {
    name = "nc-epita-env";
    paths = with pkgs; [
      installer hyprland noctalia quickshell hypridle uwsm
      kitty nautilus sushi qt6Packages.qt6ct papirus-icon-theme
      cava swaybg imagemagick jq grim slurp swappy wl-clipboard wtype zenity
      brightnessctl libnotify python3 libqalculate playerctl fastfetch bluez glib
      git gh curl wget unzip zip xdg-utils fontconfig
      inotify-tools wf-recorder libva-utils tesseract pulseaudio
      xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
      sound-theme-freedesktop libsecret
      neovim ripgrep fd nodejs gcc gnumake tree-sitter gitui
      fzf zoxide eza bat delta lazygit yazi
      zsh oh-my-zsh
      nerd-fonts.caskaydia-cove noto-fonts adwaita-fonts material-symbols
    ];
    ignoreCollisions = true;
    passthru = { inherit zshCustom; ohMyZsh = "${pkgs.oh-my-zsh}/share/oh-my-zsh"; };
  };
in { inherit source installer helpers epita-env zshCustom; }
