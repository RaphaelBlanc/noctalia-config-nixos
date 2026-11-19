# Validation EPITA du 19 novembre 2026

Validation locale x86_64 sous QEMU/KVM, sans modification des configurations
de la session hôte.

- `nix flake check --no-build --all-systems` : évaluation x86_64 et aarch64.
- `nix flake check` : builds source/installateur, module, règles des assistants
  et vérifications EPITA sur x86_64.
- Vérifications EPITA : analyse ShellCheck, migration sans perte, récupération
  des réglages/images depuis un second home utilisant le même stockage,
  conservation d'un conflit dans les sauvegardes et copie modifiable d'une
  ancienne configuration liée à une source en lecture seule.
- Test dans un pseudo-terminal Zsh : rafale de SIGWINCH regroupée, accueil
  redessiné, invite restaurée et saisie en cours conservée.
- `nix build .#epita-test -L` : installation complète dans un compte utilisateur
  NixOS gardant Bash comme shell de connexion ; configurations et Pictures
  persistants, fichiers modifiables et second passage conservant les réglages.
- Même VM : démarrage depuis le hook Hyprland de Noctalia, Quickshell, hypridle
  et de la synchronisation des couleurs ; IPC des deux shells vérifié.
- Même VM : vrai raccourci Super + Entrée ouvrant Kitty avec Zsh ; plugins
  Oh My Zsh/Powerlevel10k disponibles ; commande saisie puis terminal
  redimensionné à trois tailles avant validation de la commande.
- Même VM : changement de `colors.json`, surveillance inotify arrêtée, couleur
  de fond du thème Kitty mise à jour par le timer.

Le résultat de `epita-test` contient `terminal-epita.png`, `couleurs-epita.png`,
`etat-final-epita.png` et les journaux d'installation et de session.

Le stockage persistant est simulé par un dossier partagé entre deux homes dans
les tests de migration et par un dossier ordinaire dans la VM. Aucun montage
OpenAFS réel ni PC physique EPITA n'a été testé. Les gestes de redimensionnement
à la souris, le rendu matériel, la latence AFS et les services configurés par
l'école restent à vérifier sur place. Les avertissements réseau/audio et de
rendu logiciel dans cette VM ne constituent pas une validation du matériel.
