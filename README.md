# noctalia-config-nixos

Adaptateur communautaire NixOS pour [noctalia-config de Théo](https://github.com/abcdef123456-wq/noctalia-config).
Ce dépôt suit l'amont par une entrée flake verrouillée. Il contient seulement le
module, les adaptations NixOS et les tests ; les configurations et images restent
dans le dépôt de leur auteur. Le projet amont ne fournit pas de support officiel NixOS.

## Installer

Il faut NixOS avec les droits nécessaires pour reconstruire le système. Sur une
machine administrée par ton école, fais intégrer le module par l'administrateur.
Conserve ta configuration matérielle, tes disques, ton bootloader et ton
`system.stateVersion`. Hyprland >= 0.55 et Noctalia v5 sont nécessaires : la
version nixpkgs verrouillée de ce dépôt fournit les versions utilisées en test.

Dans la flake de ton système :

```nix
inputs.noctalia-config.url = "github:RaphaelBlanc/noctalia-config-nixos";
# Facultatif, seulement si ton nixpkgs est assez récent :
# inputs.noctalia-config.inputs.nixpkgs.follows = "nixpkgs";
```

Ajoute ensuite à la liste `modules` de ton `nixosConfigurations.<machine>` :

```nix
inputs.noctalia-config.nixosModules.default
{
  programs.noctalia-config.enable = true;
  users.users.TON_UTILISATEUR.extraGroups = [ "networkmanager" ];
}
```

Le module utilise les paquets de la configuration NixOS qui l'importe. Ce système
doit donc utiliser un nixpkgs récent (nixos-unstable conseillé). L'entrée nixpkgs
de ce dépôt fixe les dépendances de ses tests et de `nix run`.

Reconstruis, puis lance l'installation de ta session **sans sudo** :

```bash
sudo nixos-rebuild switch --flake .#MACHINE
nc-nixos-install
```

Le programme vérifie les dépendances, sauvegarde les fichiers remplacés, adapte
les écrans et le clavier et active les services utilisateur. Les fichiers restent
modifiables par les réglages du bureau. Ne fais pas gérer les mêmes chemins en
parallèle par Home Manager. Pour revenir aux fichiers précédents :
`nc-nixos-install --restore`. `--files-only` copie seulement les fichiers.

Choisis **Hyprland (uwsm-managed)** sur ton écran de connexion. Le module n'en
active aucun par défaut. Pour zsh comme shell de connexion, ajoute explicitement
`users.users.TON_UTILISATEUR.shell = pkgs.zsh;` dans un module recevant `pkgs`.

## Machines Intel de l’école

L’exemple [`examples/ecole-intel.nix`](examples/ecole-intel.nix) s’ajoute aux
modules du système existant pour un PC avec graphique intégré Intel. Garde le
`hardware-configuration.nix` propre à chaque poste : ne copie pas les partitions
ou le bootloader d’un autre PC. Le pilote graphique est choisi par NixOS.

Sur le poste, `uname -m` permet de vérifier l’architecture et `sudo -l` les droits
du compte. L’accès à une seule commande via sudo ne garantit pas l’autorisation
de reconstruire NixOS. Si le compte ne peut pas le faire, l’administrateur devra
intégrer le module. Tu peux préparer ces fichiers avant d’avoir accès à la machine.

## Services et assistants système

NetworkManager/OpenVPN, Bluetooth, UPower, PipeWire et power-profiles-daemon sont
proposés. Pour conserver une configuration audio/énergie/réseau particulière
(TLP ou tuned, notamment), utilise
`programs.noctalia-config.recommendedServices = false;` et configure-les toi-même.

Les assistants matériels et le kill switch VPN sont **facultatifs** :

```nix
programs.noctalia-config.helpers = {
  enable = true;
  users = [ "TON_UTILISATEUR" ];
};
```

Les programmes amont `nc-energie-root`, `nc-limite-charge` et `nc-vpn-root` sont
installés dans le Nix store. Leurs interpréteurs, outils et chemins sont adaptés
à NixOS. Les règles sudo autorisent uniquement les sous-commandes prévues, pour
les comptes déclarés. Elles ne donnent pas accès à un shell root. La CI compare
ces règles aux listes produites par les assistants amont : une divergence fait
échouer la mise à jour.

Le kill switch contrôle une vraie interface TUN/WireGuard et ses endpoints avant
de créer sa table nftables `inet nc_vpn`. Il conserve les autres tables. Les
refus amont pour firewalld, ufw ou Mullvad actifs restent appliqués. Les réglages
matériels disponibles dépendent du processeur, du pilote et de la batterie ; le
module ne devine ni n'installe ton pilote NVIDIA.

## Démarrage et connexion

Ces options sont désactivées par défaut :

```nix
programs.noctalia-config.appearance = {
  grub.enable = true;     # seulement si GRUB est déjà configuré sur ce système
  plymouth.enable = true;
  sddm.enable = true;     # choisir un seul gestionnaire de connexion
};
```

Le thème GRUB utilise les images et polices de l'amont. Plymouth utilise le thème
BGRT NixOS (l'amont propose aussi BGRT). SDDM Wayland utilise le thème Astronaut
verrouillé dans nixpkgs, la configuration et l'image `nc` de l'amont. Le module
ne choisit aucun disque d'installation, aucun mode EFI/BIOS et n'active pas GRUB
à ta place. Si un autre gestionnaire de connexion est actif, configure son
remplacement dans ta configuration système avant d'activer SDDM.

## Suivre le dépôt de Théo

`flake.lock` fixe une révision exacte de l'entrée `upstream`, qui suit la branche
`main` officielle. Il n'y a ni copie de l'historique Git, ni duplication des
fonds d'écran ou des configurations dans ce dépôt. Le build applique un petit
patch d'adaptation dans le Nix store ; l'application sans approximation de ce
patch est vérifiée à chaque mise à jour. Les chemins des assistants et de leurs
clients sont adaptés à ce moment-là.

Pour mettre à jour cet adaptateur :

```bash
nix flake update upstream
nix flake check
nix build .#vm-test .#boot-test -L --cores 4 --max-jobs 2
```

La vérification hebdomadaire de CI essaie la dernière révision amont et conserve
le patch du lock dans ses artefacts. Elle ne fusionne pas automatiquement une
mise à jour et ne pousse rien sur le dépôt de Théo. Le mainteneur examine le
résultat et publie le nouveau lock.

Sur ta machine, mets à jour l'entrée de cet adaptateur dans la flake système,
reconstruis NixOS, puis relance `nc-nixos-install`. `nc-maj` affiche cette marche
à suivre ; son timer de vérification est silencieux. Le compteur de paquets de
l'île ne compte pas les générations NixOS. Les mises à jour et retours arrière
du système restent ceux de NixOS.

## Tests et limites

```bash
nix flake check --no-build --all-systems  # évaluation x86_64 et aarch64
nix flake check                         # builds et contrats de sécurité sur l'hôte
nix build .#vm-test -L                  # bureau et assistants, QEMU/KVM x86_64
nix build .#boot-test -L                # GRUB, Plymouth, greeter SDDM
```

Le test bureau utilise 4 Go de RAM, 4 vCPU et un disque virtuel de 8 Go. Il
installe les fichiers avec un compte ordinaire, vérifie la configuration Lua,
les services et leurs IPC, les plugins Zsh et une commande tapée dans Kitty.
Il vérifie aussi les autorisations sudo et les refus, puis active et désactive
le vrai kill switch sur un tunnel TUN de la VM avec de vraies règles nftables.
Le test de démarrage utilise un disque et un bootloader jetables ; il n'accède
pas aux disques du PC hôte. Les journaux et captures sont conservés dans les
résultats Nix.

La VM ne prouve pas le fonctionnement du matériel d'un PC : NVIDIA, charge de
batterie, consommation, Wi-Fi/Bluetooth et veille doivent être vérifiés sur le
poste concerné. Ses services externes sont inaccessibles et elle n'a ni carte
son ni Bluetooth ; les avertissements associés ne prouvent pas une panne réelle.
Hyprland 0.57 peut encore signaler `on_created_empty` dans la configuration
amont. Aucun support officiel de NixOS par Théo n'est annoncé ici.

## Origine et licence

Le bureau, les scripts et les thèmes viennent de Théo et des auteurs crédités
dans [son dépôt](https://github.com/abcdef123456-wq/noctalia-config). Les règles
et comportements des assistants root restent ceux de l'amont ; ce projet adapte
leur installation. La licence MIT est conservée pour le code ; les éléments
tiers de l'amont conservent leurs licences respectives.
