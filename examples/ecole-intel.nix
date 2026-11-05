# À ajouter aux modules de la flake NixOS existante, avec
# inputs.noctalia-config.nixosModules.default.
{ ... }:
{
  programs.noctalia-config.enable = true;
  hardware.graphics.enable = true;

  # Remplacer le nom avant de décommenter, si nécessaire :
  # users.users.moncompte.extraGroups = [ "networkmanager" ];
  # users.users.moncompte.shell = pkgs.zsh; # ajouter pkgs aux arguments du module

  # Garder le hardware-configuration.nix généré sur CE PC : disques, EFI,
  # microcode Intel et modules du noyau diffèrent selon les postes.
  # Aucun pilote NVIDIA ni réglage i915/xe imposé : NixOS choisit le pilote.
  # Les assistants root et les thèmes de démarrage restent facultatifs.
}
