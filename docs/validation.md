# Validation du 5 novembre 2026

Validation locale effectuée sous QEMU/KVM x86_64, avec les entrées verrouillées :

- noctalia-config : `94e593f4d37863549fac7642ca46d963ba39915d` ;
- nixpkgs : `0bb2eedc20e4739f29e8045034f2828ad7054f8f` ;
- NixOS 26.11, noyau 6.18.60, Hyprland 0.57.0, Noctalia 5.4.1,
  Quickshell 0.3.2.

## Résultats

- `nix flake check --no-build --all-systems` : réussite de l’évaluation
  x86_64-linux et aarch64-linux. Aucun build ARM ni démarrage ARM revendiqué.
- `nix flake check` : réussite des builds source/installateur et des vérifications
  du module et des règles sudo sur x86_64-linux.
- `nix build .#vm-test` : réussite de l’installation avec un utilisateur ordinaire,
  session Hyprland/UWSM, services et IPC Noctalia/Quickshell/hypridle, validation
  Lua, plugins Zsh et saisie réelle dans Kitty.
- Même VM : assistants énergie et batterie interrogés via les droits sudo
  limités ; commandes non autorisées refusées. Activation et désactivation du
  kill switch sur une interface TUN réelle de la VM, via nftables. Refus d’une
  interface non tunnel et d’un endpoint invalide ; une table nftables distincte
  est conservée après activation et désactivation.
- `nix build .#boot-test` : réussite du démarrage sur un disque BIOS/GRUB jetable,
  configuration du thème GRUB et de Plymouth, affichage SDDM Wayland avec le
  thème Astronaut/nc. Capture SDDM vérifiée visuellement. Le rendu de GRUB et
  l’animation Plymouth n’ont pas été inspectés visuellement.

Les captures du bureau, de Kitty et de SDDM et les journaux sont dans les sorties
`result-validation` et `result-validation-1` de la commande combinée décrite dans
le README. La CI est configurée pour les conserver comme artefacts lorsqu’elle
exécute ces tests ; cette validation locale ne prouve pas une exécution distante.

La première exécution GitHub a réussi l’installation et les contrôles du bureau,
puis expiré en attendant la commande saisie dans Kitty. Le test attend désormais
le widget de saisie ZLE et le focus de Kitty, et espace les touches de 150 ms
(au-delà des 100 ms de maintien de touche de QEMU). Le délai d’attente de cette
commande est limité à 120 s et une capture finale facilite le diagnostic.

## Limites

La VM utilise le rendu logiciel. Aucun PC physique Intel ou NVIDIA n’a été testé,
ni ses pilotes, sa batterie, sa veille, son audio, son Wi-Fi ou son Bluetooth.
La compatibilité sur les postes de l’école reste à vérifier avec leur propre
configuration matérielle et les droits d’administration nécessaires.

Des avertissements du bureau amont et des services externes restent possibles,
notamment les appels réseau impossibles dans la VM isolée et le budget CPU de
certains callbacks Noctalia lors du démarrage en rendu logiciel. Le portage ne
constitue pas une validation de tous les plugins et réglages du projet amont.
