{ config, lib, pkgs, noctaliaUpstream, ... }:
let
  cfg = config.programs.noctalia-config;
  p = import ../nix/packages.nix { inherit pkgs; upstream = noctaliaUpstream; };
  values = {
    epp = [ "performance" "balance_performance" "balance_power" "power" ];
    boost = [ "on" "off" ];
    freqmax = [ "100" "80" "60" ];
    platform = [ "low-power" "quiet" "cool" "balanced" "balanced-performance" "performance" ];
    nvidia-pm = [ "auto" "on" ];
    nvidia-pl = [ "0" "1" "2" "3" ];
    wifi-ps = [ "on" "off" ];
    usb-autosuspend = [ "on" "off" ];
    audio-ps = [ "on" "off" ];
    kbd = [ "0" "1" "2" "3" ];
  };
  energy = [ "etat" ] ++ lib.concatLists (lib.mapAttrsToList (k: vs: map (v: "${k} ${v}") vs) values);
  commands = lib.concatLists (lib.mapAttrsToList (name: args: map (arg: {
    command = "/run/current-system/sw/bin/${name} ${arg}";
    options = [ "NOPASSWD" ];
  }) args) {
    nc-energie-root = energy;
    nc-limite-charge = [ "etat" "state" "status" "on" "off" "0" "1" ];
    nc-vpn-root = [ "etat" "desactiver" "activer *" ];
  });
in {
  options.programs.noctalia-config.helpers = {
    enable = lib.mkEnableOption "les assistants matériels et le kill switch VPN amont";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Comptes autorisés aux seules sous-commandes contrôlées des assistants.";
    };
  };
  config = lib.mkIf (cfg.enable && cfg.helpers.enable) {
    assertions = [ {
      assertion = cfg.helpers.users != [] && builtins.all
        (u: builtins.match "[a-z_][a-z0-9_-]*" u != null && builtins.hasAttr u config.users.users)
        cfg.helpers.users;
      message = "helpers.users doit contenir des noms de comptes déclarés, en minuscules.";
    } ];
    environment.systemPackages = [ p.helpers ];
    security.sudo.enable = true;
    security.sudo.extraRules = [ { users = cfg.helpers.users; inherit commands; } ];
  };
}
