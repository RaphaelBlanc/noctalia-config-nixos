# Validation du 18 novembre 2026

Validation locale effectuée sous QEMU/KVM x86_64, avec les entrées verrouillées :

- noctalia-config : `11404ca78b73d8ca5fff37d55878bc94d146e3e7` ;
- nixpkgs : `0bb2eedc20e4739f29e8045034f2828ad7054f8f` ;
- NixOS 26.11, noyau 6.18.60, Hyprland 0.57.0, Noctalia 5.4.1,
  Quickshell 0.3.2.

L'installateur, `nc-paquets`, `nc-maj` et les clients des assistants sont ceux
de l'amont, sans correctif local. Le build fournit `VERSION` et
`~/.config/nc/plateforme.conf` ; le script de réécriture des chemins est retiré.
Les assistants root gardent les adaptations de leurs interpréteurs, de leur
PATH et des chemins des règles sudo. La liste des privilèges suit exactement
celle produite par la nouvelle version amont (Ethernet, RAPL, ventilateurs,
fréquence GPU et lecture de puissance compris).

L'installateur lance le code amont depuis une copie temporaire inscriptible
des sources : les modèles du Nix store sont en lecture seule et `install.sh`
conserve leurs modes. Cette copie évite donc d'installer des configurations
non modifiables. Après installation, le chemin enregistré pointe vers les
sources immuables et versionnées du store ; la copie temporaire est supprimée.
Les fichiers personnels conservés par l'amont ne sont pas rendus inscriptibles
par l'adaptateur.

## Résultats

- Tests amont ciblés (`test_plateforme_root`, `test_version_sans_git`,
  `test_dossiers_donnees`, `test_install_nixos`) : 56 tests réussis dans la
  source construite, avec des environnements temporaires.

- `nix flake check --no-build --all-systems` : réussite de l’évaluation
  x86_64-linux et aarch64-linux. Aucun build ARM ni démarrage ARM revendiqué.
- `nix flake check` : réussite des builds source/installateur et des vérifications
  du module et des règles sudo sur x86_64-linux.
- `nix build .#vm-test` : réussite de l’installation avec un utilisateur ordinaire,
  session Hyprland/UWSM, services et IPC Noctalia/Quickshell/hypridle, validation
  Lua, plugins Zsh et saisie réelle dans Kitty.
- Même VM : résolution des trois assistants root via `plateforme.conf`,
  depuis le script POSIX et les clients Python, avec les véritables fichiers
  appartenant à root dans le Nix store. Lecture de `VERSION` par `nc-diag`,
  refus de mise à jour Git par `nc-maj` (code 0), vérification silencieuse
  et recherche des données système via `XDG_DATA_DIRS`.
- Même VM : une seconde installation avec `--oui` conserve les fichiers
  `.zshrc` et `.p10k.zsh` personnalisés, ainsi qu’un lien symbolique Neovim
  et son contenu personnel (empreintes SHA-256 inchangées).
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

La première exécution GitHub du 5 novembre avait réussi l’installation et les contrôles du bureau,
puis expiré en attendant la commande saisie dans Kitty. Le test attend désormais
le widget de saisie ZLE et le focus de Kitty, et espace les touches de 150 ms
(au-delà des 100 ms de maintien de touche de QEMU). Le délai d’attente de cette
commande est limité à 120 s et une capture finale facilite le diagnostic.

La validation du 17 novembre a aussi révélé des lettres répétées pendant la
saisie virtuelle, avec le bureau en rendu logiciel à 5120×2160. Le scénario
fixe désormais l’écran virtuel à 1280×720 et désactive la répétition des touches
pour la saisie de la commande. Ces réglages concernent uniquement la VM.

## Limites

La VM utilise le rendu logiciel. Aucun PC physique Intel ou NVIDIA n’a été testé,
ni ses pilotes, sa batterie, sa veille, son audio, son Wi-Fi ou son Bluetooth.
La compatibilité sur les postes de l’école reste à vérifier avec leur propre
configuration matérielle et les droits d’administration nécessaires.

Des avertissements du bureau amont et des services externes restent possibles,
notamment les appels réseau impossibles dans la VM isolée et le budget CPU de
certains callbacks Noctalia lors du démarrage en rendu logiciel. Le portage ne
constitue pas une validation de tous les plugins et réglages du projet amont.
