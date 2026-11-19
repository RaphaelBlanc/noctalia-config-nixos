# Noctalia sur les postes EPITA

Ce guide utilise les scripts `epita/` de `RaphaelBlanc/noctalia-config-nixos`.
Le correctif est sur la branche `fix/epita-session-afs` tant que sa PR vers
`epita` n'est pas fusionnée. Toutes les commandes se lancent sans sudo.

1. **Préparer le dépôt.** Le poste doit être sous NixOS, avec Git, Nix,
   un AFS accessible en écriture et une connexion réseau.

   Pour une première installation :

   ```bash
   mkdir -p "$HOME/afs/.confs"
   git clone --branch fix/epita-session-afs --single-branch \
     https://github.com/RaphaelBlanc/noctalia-config-nixos.git \
     "$HOME/afs/.confs/noctalia-config-nixos"
   ```

   Si le dépôt existe déjà sur la branche `epita`, enregistre d'abord tes
   modifications éventuelles, puis récupère le correctif :

   ```bash
   cd "$HOME/afs/.confs/noctalia-config-nixos"
   git status
   git fetch origin
   git switch fix/epita-session-afs
   git pull --ff-only
   ```

2. **Installer ou réparer la session.** Ferme la session Noctalia si elle tourne
   déjà, puis lance depuis ta session habituelle :

   ```bash
   cd "$HOME/afs/.confs/noctalia-config-nixos"
   ./epita/nc-start --check
   ```

   Ce premier passage construit ou récupère les paquets, migre les données
   existantes vers AFS, applique l'installateur utilisateur et prépare les
   services. Il peut prendre plusieurs minutes et les images occupent de
   l'espace sur ton quota AFS. `--check` prépare réellement les fichiers ;
   il ne lance pas Hyprland.

   Les configurations fournies par noctalia-config, les scripts `nc-*`, les
   thèmes et plugins, `.zshrc`, `.p10k.zsh`, `.zshrc.perso`, `.face`, `Pictures`,
   la clé du presse-papiers et les sauvegardes de l'installateur sont stockés sous :

   ```text
   ~/afs/.confs/noctalia-config/home/
   ```

   Les chemins habituels (`~/.config/kitty`, `~/.config/hypr`, `~/Pictures`, etc.)
   deviennent des liens vers ces données. Les configurations d'applications
   étrangères à noctalia-config ne sont pas déplacées. En cas de conflit avec
   des réglages AFS déjà présents, AFS est prioritaire et les fichiers locaux
   sont conservés dans `~/afs/.confs/noctalia-config/migration-backups/`.
   Les réglages personnels reconnus par l'installateur amont restent conservés.

   Les paquets Nix, les caches, la base du presse-papiers et les sockets restent
   propres au poste. Les
   liens vers les paquets sont dans `$XDG_RUNTIME_DIR/nc-epita` (ou dans un
   répertoire temporaire privé au compte si cette variable est absente).

3. **Démarrer le bureau.** Enregistre ton travail, ferme ta session habituelle,
   appuie sur **Ctrl + Alt + F3**, puis connecte-toi avec ton compte EPITA :

   ```bash
   "$HOME/afs/bin/nc-start"
   ```

   Hyprland lance maintenant les services après création de ses sockets
   Wayland. Tu n'as plus à importer les variables ou à lancer Noctalia à la
   main. **Super + Entrée** ouvre Kitty avec le Zsh de la configuration :
   Oh My Zsh, Powerlevel10k, accueil et couleurs Noctalia. Le shell de connexion
   du compte EPITA reste inchangé. Un réglage `shell` dans ton fichier personnel
   Kitty garde toutefois la priorité.

   La synchronisation des couleurs est lancée avec la session ; un contrôle
   toutes les cinq secondes complète la surveillance des fichiers, car AFS
   ne transmet pas toujours les événements de modification entre postes.

4. **Sur un autre poste ou après une mise à jour.** Reprends simplement
   `./epita/nc-start --check`, puis connecte-toi au TTY et lance `nc-start`.
   Les données AFS sont réutilisées et les liens locaux sont recréés.
   Pour actualiser le dépôt :

   ```bash
   cd "$HOME/afs/.confs/noctalia-config-nixos"
   git pull --ff-only
   ./epita/nc-start --check
   ```

   Le lanceur réévalue les paquets et réinstalle les modèles si la source a
   changé. Pour forcer cette réinstallation après une ancienne installation
   partielle, utilise `./epita/nc-start --reinstall`.

5. **Vérifier et diagnostiquer.** Dans la session Hyprland :

   ```bash
   readlink -f "$HOME/.config/kitty"
   readlink -f "$HOME/Pictures"
   systemctl --user status noctalia.service nc-ile.service nc-theme-sync.timer --no-pager
   hyprctl configerrors
   hyprctl monitors
   nc-diag
   ```

   Les deux premiers chemins doivent arriver dans AFS. Pour les erreurs :

   ```bash
   journalctl --user -b -u noctalia.service -u nc-ile.service \
     -u nc-theme-sync.service --no-pager -n 100
   ```

   L'accueil Zsh regroupe les changements de taille et restaure l'invite après
   redessin. Le comportement exact du déplacement et du redimensionnement à
   la souris dépend aussi de Hyprland, du pilote et de l'écran ; si un problème
   persiste, précise le geste, l'application et le résultat de `hyprctl monitors`.

   Pour quitter la session : **Super + Maj + M**. Les scripts `profile` et
   `xsession` sont facultatifs et ne sont pas installés automatiquement.

Les tests en VM utilisent un dossier qui simule la persistance d'AFS ; ils
ne remplacent pas un essai sur le montage AFS et le matériel d'un poste EPITA.
Les fonctions système telles que PAM, le partage d'écran et les réglages
matériels dépendent aussi de la configuration fournie par l'école.
