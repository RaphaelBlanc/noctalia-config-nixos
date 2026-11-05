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
in { inherit source installer helpers; }
