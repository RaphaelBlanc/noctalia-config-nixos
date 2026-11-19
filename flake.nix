{
  description = "Adaptateur communautaire NixOS pour la configuration de Théo";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    upstream = {
      url = "github:abcdef123456-wq/noctalia-config/main";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, upstream }: let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    each = nixpkgs.lib.genAttrs systems;
    packagesFor = system: import ./nix/packages.nix {
      pkgs = nixpkgs.legacyPackages.${system};
      inherit upstream;
    };
  in {
    nixosModules.default = { ... }: {
      imports = [ ./modules/desktop.nix ./modules/helpers.nix ./modules/appearance.nix ];
      _module.args.noctaliaUpstream = upstream;
    };
    packages = each (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      p = packagesFor system;
    in {
      default = p.installer;
      inherit (p) source helpers epita-env zshCustom;
    } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
      epita-test = pkgs.testers.runNixOSTest (import ./tests/epita.nix {
        epitaEnv = p.epita-env;
        inherit (p) source zshCustom;
        epitaScripts = ./epita;
      });
      vm-test = pkgs.testers.runNixOSTest (import ./tests/desktop.nix {
        noctaliaConfigModule = self.nixosModules.default;
        source = p.source;
      });
      boot-test = pkgs.testers.runNixOSTest (import ./tests/boot.nix {
        noctaliaConfigModule = self.nixosModules.default;
      });
    });
    apps = each (system: {
      default = { type = "app"; program = "${self.packages.${system}.default}/bin/nc-nixos-install"; };
    });
    checks = each (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      machine = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ self.nixosModules.default ./examples/ecole-intel.nix ({ ... }: {
          programs.noctalia-config.enable = true;
          programs.noctalia-config.helpers = { enable = true; users = [ "testeur" ]; };
          users.users.testeur.isNormalUser = true;
          boot.loader.grub.enable = false;
          fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
          system.stateVersion = "26.05";
        }) ];
      };
      failures = builtins.filter (a: !a.assertion) machine.config.assertions;
    in {
      module = assert failures == []; pkgs.runCommand "nc-nixos-module-check" {
        names = map (p: p.name) machine.config.environment.systemPackages;
        sudoRules = builtins.toJSON machine.config.security.sudo.extraRules;
      } "touch $out";
      source = self.packages.${system}.source;
      epita-persistence = pkgs.runCommand "nc-epita-persistence-check" {
        nativeBuildInputs = [ pkgs.python3 pkgs.shellcheck pkgs.zsh ];
      } ''
        cd ${self}
        shellcheck -x epita/nc-start epita/nc-zsh epita/nc-session epita/env.sh
        python3 ${self}/tests/epita-persistence.py
        python3 ${self}/tests/epita-terminal.py ${self.packages.${system}.source}/home/.config/nc/greeting.zsh
        touch $out
      '';
      installer = self.packages.${system}.default;
      helper-policy = pkgs.runCommand "nc-helper-policy-check" {
        nativeBuildInputs = [ pkgs.python3 ];
      } ''
        python3 ${./tests/helpers-policy.py} ${self.packages.${system}.helpers} \
          ${pkgs.writeText "sudo-rules.json" (builtins.toJSON machine.config.security.sudo.extraRules)}
        touch $out
      '';
    });
  };
}
