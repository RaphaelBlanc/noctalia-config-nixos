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
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    cp -r ${upstream} $out
    chmod -R u+w $out
    cd $out
    cp ${../README.md} README-nixos.md
    cp ${../README.md} docs/nixos.md
    # Contrats amont pour une source sans .git et des assistants dans le profil Nix.
    printf '%s %s\n' ${lib.escapeShellArg upstream.rev} \
      "$(date -u -d @${toString upstream.lastModified} +%F)" > VERSION
    mkdir -p home/.config/nc
    printf '%s\n' 'NC_ROOT_BIN=/run/current-system/sw/bin' > home/.config/nc/plateforme.conf
    # Les clients restent identiques à l'amont ; seuls les assistants root ont
    # leurs interpréteurs, leur PATH et les chemins des règles sudo adaptés.
    cmp install.sh ${upstream}/install.sh
    cmp home/.local/bin/nc-maj ${upstream}/home/.local/bin/nc-maj
    cmp home/.local/bin/nc-paquets ${upstream}/home/.local/bin/nc-paquets
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
      # install.sh conserve les modes des modèles. Le store est en lecture seule :
      # une copie temporaire permet d'installer des configurations modifiables,
      # sans changer les fichiers personnels que l'amont décide de conserver.
      install_source=$(mktemp -d)
      trap 'rm -rf -- "$install_source"' EXIT
      cp -R ${source}/. "$install_source/"
      chmod -R u+w "$install_source"
      bash "$install_source/install.sh" "$@"
      mkdir -p "$HOME/.config/nc"
      printf '%s\n' ${source} > "$HOME/.config/nc/depot"
      printf '%s\n' ${lib.escapeShellArg (upstream.rev or "unknown")} > "$HOME/.config/nc/version-amont-nix"
    '';
  };
in { inherit source installer helpers; }
