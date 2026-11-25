# TODO

## À faire

### Cours Docker
- [ ] Rejouer les sorties marquées « à rejouer » avec `conteneurisation/cm/rejouer.sh` sur un Debian 13 (docker.io 26.1.5, AppArmor), puis les recopier dans les diapos

### Cours Virtualisation
- [ ] Rejouer les sorties types (KVM, TP) avec `virtualisation/cm/rejouer-tp.sh` sur une machine avec KVM, puis remplacer les sorties des diapos et les mentions « à rejouer » des notes

### Cours Conteneurisation — Orchestration
- [ ] Rejouer sur Debian 13 les sorties Swarm des diapos « le fichier Compose devient une stack » et « passage à l’échelle, reprise sur panne » (prises sur Docker 29.10, un nœud), et tester la répartition de charge du routing mesh (`curl`, non rejouable sans IPVS)
- [ ] Vérifier les adresses des sources des diapos Orchestration (docs.docker.com, kubernetes.io : inaccessibles lors de la rédaction) et les faits marqués « à vérifier » dans les notes de l’orateur
- [ ] Essayer le manifeste Kubernetes de la diapo « pod, Deployment, Service » sur un cluster (kind, minikube ou k3s)

### Artefacts
- [ ] Rejouer `conteneurisation/artefacts/cache-de-build/verifier-buildkit.js` sur Debian 13 (docker.io 26.1.5) : le modèle n’a été confronté qu’à BuildKit de Docker Engine 29.10

### Travaux pratiques
- [ ] Vérifier dans Firefox et Chromium que les renvois du TP ouvrent le PDF à la bonne diapo (`#nameddest=`)
- [ ] Supprimer la branche `corrections` : son historique est rattaché à `main` par un commit de fusion sans changement de fichiers (`git show c83a3d5:wordpress_step_by_step/…` reste lisible)
- [ ] Vérifier les liens externes du TP WordPress (docs.docker.com, wordpress.org, iximiuz Labs : non testables depuis l’environnement de rédaction)
- [ ] Vérifier le site publié par GitHub Pages (accueil, TP, artefact, polices, renvois vers les diapos)

### Migration depuis le dépôt `site`
Périmètre décidé le 2026-11-25 : virtualisation (libvirt), delta conteneurisation, Ansible, outils d’administration
système en quatre cours (`shell/`, `edition-formats/`, `acces-distants/`, `git/`) ; pas de « page de cours » ;
Qt (licence à régler avec Vincent Barichard), ia-apprentissage, intro-ordinateur, intro-systeme et glossaire restent sur le site.
- [ ] Vague 3 — artefacts : chaîne de backing files qcow2, CMD × ENTRYPOINT, précédence et inventaire Ansible, idempotence, expansions Bash, graphe Git, typage YAML ↔ JSON
- [ ] Relecture par l’auteur des contenus dont la source du site est rédigée par IA (réseau Docker, erreurs à éviter, réseau et stockage libvirt, concepts Ansible, tmux, labo WireGuard)
- [ ] Ouvrir les liens des sources citées dans les diapos migrées (docs.ansible.com, git-scm.com, wireguard.com, docs.docker.com : inaccessibles lors de la rédaction)
- [ ] Faits à faire relire par l’auteur — libvirt : `qemu:///system` sans sudo par le groupe `libvirt`, VM du TP en BIOS (l’UEFI refuse l’instantané interne) ; Ansible : règle de précédence en 22 niveaux, idiome `creates:` ; shell : `sed -E` POSIX depuis 2024, corrections du support d’origine ; SSH : Ed25519 à la place de RSA 4096, changement de port requalifié en confort ; Docker : port publié sur 127.0.0.1 joignable du réseau local avant Docker 28 ; Git : exercice de conflit nouveau, dépôt nu local à la place de GitHub
- [ ] Relecture de fond de chaque cours migré contre les supports d’origine de l’auteur (diapos et TP : personne n’a encore suivi un énoncé de bout en bout comme un étudiant)
- [ ] Rejouer ce qui ne l’a pas été faute de moyens : conteneurisation (docker.io 26.1.5 d’un Debian 13), virtualisation (KVM réel, étapes 3, 4, 8 et 9 du TP libvirt), trois sorties WireGuard (module noyau absent : le labo tourne avec `wireguard-go`), le lien renvoyé par une forge après `git push`
- [ ] Vérifier en ligne trois faits WireGuard non vérifiés (wireguard.com inaccessible) : « environ 4 000 lignes », la liste des primitives cryptographiques, « audité »
- [ ] Faits à faire relire par l’auteur après le rejeu Debian 13 — édition et formats : `yq` 3.4.3 (message de `yq eval`, typage de `NO`, `yes`, `0644`), `-Y` ne garde pas les commentaires, `%YAML 1.1` sans effet avec ruamel sans `pure=True`, `dG` laisse cinq lignes, `vim-tiny` de priorité « important » ; accès distants : Entrée en mode copie de tmux 3.5a liée à `copy-pipe-and-cancel` ; Ansible : le labo garde ansible-core 2.19.4 par pip (Debian 13 fournit 2.19.11, mais un ansible-lint plus ancien)
- [ ] Terminal : essayer dans Firefox et Safari ; essayer le compagnon sur un macOS réel (binaire non signé, Gatekeeper) ; vérifier l’avertissement « accès au réseau local » de Chrome ; choisir une licence logicielle pour le compagnon (il suit CC BY-NC-SA par défaut) ; décider si `http://localhost:8000` reste une origine admise par défaut
- [ ] Terminal : les paquets `apk` de l’image Alpine ne sont pas épinglés (image non reproductible à l’identique, `paquets.txt` en garde la trace) ; ShellCheck n’existe pas pour Alpine x86 (étapes 6 à 8 du TP scripts par le compagnon)
- [ ] Vérifier la première compilation complète du site par la CI après fusion dans `main` (`compilation-cours.yml` ne tourne que sur `main` : construction de l’image de la VM, binaires du compagnon, sept cours, seize TP)
- [ ] Sur un Debian 13 réel (libvirt 11.3, AppArmor) : démarrer une VM dont le disque est déclaré `<disk type="volume">`, pour savoir si le refus AppArmor constaté sur Ubuntu 24.04 (libvirt 10.0) s’y produit aussi, puis ajuster le commentaire de `vm-exemple.xml` et la note de la diapo « Pools et volumes »
- [ ] Le runner GitHub dispose de `/dev/kvm` : décider si le harnais libvirt démarre aussi le domaine en `type="kvm"` (aujourd’hui il force TCG, le XML KVM n’est validé que par son schéma)
- [ ] Accès distants, à décider par l’auteur (relecture de fond du 2026-11-25) — points du support d’origine absents des diapos : « une paire de clés par environnement (ne fait pas consensus) », « clés plus longues, force brute impraticable », l’argument « performance » de WireGuard, la question sed sur le changement de port ; faits WireGuard : « audité » et le chiffre « environ 4 000 lignes » de 2017 restent sans source vérifiée (Linux 6.12 : 6 067 lignes dans `drivers/net/wireguard`, environ 4 650 hors commentaires)
- [ ] Ansible, à décider par l’auteur (relecture de fond du 2026-11-25) — le `.vimrc` (indentation de 2 espaces) et `mes_fonctions.bash` du TP d’origine ont disparu (le crochet contrôle encore des fichiers `.bash`, mais il n’en reste aucun) ; garder ansible-core 2.19.4 par pip ou passer au paquet Debian 13 (2.19.11) ; vérifier le gabarit nginx avec `listen [::]` sur un hôte qui a IPv6
- [ ] Git, à décider par l’auteur (relecture de fond du 2026-11-25) — volume : 51 diapos et deux TP pour les 3 h prévues à l’origine ; notions ajoutées sans équivalent dans le support d’origine (objets internes `cat-file` et `hash-object`, rebasage, `reflog`, trois modes de `reset`, branches de suivi, `push` refusé et `pull` divergent, `.gitignore`) ; exercices intercalés dans le cours au lieu d’être regroupés à la fin ; exercice de branches et de conflit ajouté ; exercice GitHub remplacé par un dépôt nu local

## Fait

### One-shots
- [x] 2026-11-19 — Renommer `typst/` en `typst_virtualisation/` et ajouter l'action GitHub qui compile `virtualisation.pdf` à la racine
- [x] 2026-11-19 — Mini TP « Votre première VM » : ajout de la question 6 (virtualisation imbriquée) et de son corrigé (3/3)
- [x] 2026-11-19 — Mini TP, question 3 : installation de Debian sur un disque qcow2 (prérequis des questions 5 et 6)
- [x] 2026-11-19 — Restructuration en monorepo : `commun/` (charte, polices), un dossier par cours, PDF `<cours>.pdf` à la racine, CI générique
- [x] 2026-11-19 — PDF déplacés dans leur dossier de cours (`<cours>/<cours>.pdf`), `.gitignore` supprimé
- [x] 2026-11-19 — Compilation locale dans `build/` (ignoré), CI déclenchée sur `main`
- [x] 2026-11-20 — Rendus adaptés compilés par la CI : deutéranopie, protanopie, tritanopie, achromatopsie, dyslexie (charte commune, cours inchangés ; polycopié abandonné)
- [x] 2026-11-20 — Charte par rôles pédagogiques (notion, pratique, retenir, précaution, avertissement, danger), pictogrammes, invité en violet, page Légende dans les variantes ; cours Virtualisation migré
- [x] 2026-11-20 — Pictogrammes : cerveau (à retenir), coureur en sueur (pratique), triangle « ! » pour les trois alertes (Tabler Icons, MIT)
- [x] 2026-11-20 — Feu tricolore de niveau sur les alertes ; rôle « réponse » (vert clair) pour les corrigés, distinct de la question (vert)
- [x] 2026-11-20 — Inversion : question (pratique) en vert clair, réponse en vert foncé
- [x] 2026-11-20 — Rôle « question » (vert clair) distinct de « pratique » (vert) ; réponse vert foncé ; feu tricolore réservé aux variantes
- [x] 2026-11-20 — AGENTS.md (consignes agents, renvoie à la charte) et CLAUDE.md (@AGENTS.md)
- [x] 2026-11-20 — Skill structurer-diapos-cours intégrée au dépôt (.claude/skills/), référencée dans AGENTS.md
- [x] 2026-11-20 — Relecture du cours Virtualisation selon structurer-diapos-cours : corrections, animation systématique, récapitulatif, sources, script rejouer-tp.sh
- [x] 2026-11-20 — Cours Docker adapté aux conventions : corriges() et illustration de couverture dans la charte, notes sans label de vérification, « diapositive », docker/README.md
- [x] 2026-11-21 — Cours Docker relu selon structurer-diapos-cours : ~480 écarts traités (textes ≥ 18 px, sigles, titres, sources, corrigés, cadres imbriqués, syntaxe, redites, annexes, récapitulatif en fin) ; docker/rejouer.sh
- [x] 2026-11-21 — Cours docker renommé conteneurisation ; variante « normal » renommée « projection », suffixe -projection sur le PDF
- [x] 2026-11-21 — Titre « Fondements de la conteneurisation », Avantages en bleu, coureur réservé aux questions, page de clôture, couches de la couverture en dégradé
- [x] 2026-11-23 — Audit du TP conteneurisation contre le cours et contre le dépôt `site` (énoncé, corrigés, harnais, artefacts) ; propositions d'organisation CM / TP / artefacts, de format et de corrigés à la demande
- [x] 2026-11-23 — Séparation CM / TP : `<cours>/cm/` (diapos, PDF, scripts de rejeu) et `<cours>/tp/<tp>/` ; `commun/charte.typ` extrait (rôles, palettes), commun aux diapos et aux TP
- [x] 2026-11-23 — Thème des TP en Typst vers HTML (`commun/theme-tp.typ`, `tp.css`, `tp.js`) : variantes choisies dans la page, indices et corrigés repliés, copie des seules commandes, schémas par palette, renvois vers les diapos ; page d’accueil `index.typ` ; CI étendue aux pages web
- [x] 2026-11-23 — Cours Conteneurisation : section Orchestration (8 diapos : limite de Compose, état désiré, Swarm, Kubernetes, lequel choisir) ; étiquettes sur les diapos citées par le TP
- [x] 2026-11-23 — TP « Conteneuriser WordPress » réécrit contre le cours : 9 étapes, sans setuid (root au démarrage seulement), réseau utilisateur à la place de `--link`, volumes nommés, Compose v2, passage à l’échelle avec Compose à la place de Swarm ; corrigés en fichiers réels sur `main`, harnais `tester.sh` et CI `test-corriges.yml`
- [x] 2026-11-23 — CI de test des corrigés : les neuf étapes du TP WordPress construites et vérifiées sur GitHub Actions (69 vérifications réussies)
- [x] 2026-11-23 — Premier artefact interactif, « Le cache de build » (`conteneurisation/artefacts/cache-de-build/`) : simulateur de la clé de chaque étape, cinq expériences avec réponses ; convention `<cours>/artefacts/<nom>/`, lié depuis l’étape 2 du TP et l’accueil
- [x] 2026-11-23 — README et page d’accueil : appel à signaler les erreurs par une issue et à proposer des corrections par pull request, propositions d’IA comprises
- [x] 2026-11-23 — Travail fusionné dans `main` ; historique de la branche `corrections` rattaché à `main`
- [x] 2026-11-23 — Publication du site par GitHub Pages depuis l’action de compilation (source « GitHub Actions »)
- [x] 2026-11-23 — Fichiers générés sortis du dépôt : PDF et `index.html` ignorés par git, compilés puis publiés par la CI sans commit (fin des PDF recommités à l’identique)
- [x] 2026-11-23 — Artefact « cache de build » tenu sur un écran de portable sans défilement (résultat du build sur chaque ligne du Dockerfile, expériences une à la fois) ; site : en-tête reprenant la couverture des diapos, cartes de cours à l’accueil, sommaire latéral qui suit la lecture, pied de page
- [x] 2026-11-23 — Sélecteur « Accessibilité » (pictogramme, options groupées par besoin) à la place de « Affichage » ; artefact « cache de build » : build qui se déroule dans le temps (attente dès la première étape sans cache, « passer l’attente », « sans attente »), durées colorées selon le gain, barres des derniers builds, cadre du cache clé par clé (réutilisée, créée, reconstruite, en réserve)
- [x] 2026-11-23 — Artefact « cache de build » : zones encadrées (cache mis en avant), barre de progression du build et remplissage de la ligne en cours, recettes jouables dans chaque expérience (étapes affichées, arrêt possible) ; page d’atelier à la hauteur de la fenêtre, texte qui grossit sur grand écran
- [x] 2026-11-23 — Artefact « cache de build » : lecteur de recette (étape précédente, lecture ou pause, étape suivante, quitter, rejouer) ; la pause fige le build en cours, le retour en arrière rétablit l’état mémorisé après chaque étape et annule une étape en cours
- [x] 2026-11-24 — Artefact « cache de build » : modèle recalé sur BuildKit (CMD, ENTRYPOINT, LABEL, EXPOSE hors des clés ; casse, espaces et commentaires sans effet ; FROM fixe ; instructions non simulées signalées), vérifié par `verifier-buildkit.js` (140 builds, aucun écart) ; recettes en carte distincte, pause après chaque étape avec explication calculée et « Continuer », option sans pause, reprise en main à la fin sans quitter ; la règle passe dans le bandeau du titre
- [x] 2026-11-24 — Artefact « cache de build » : la liste des étapes de la recette reste affichée pendant sa lecture (étapes faites cochées, étape expliquée surlignée, suivante repérée) ; panneau d’aide resserré sur les fenêtres basses
- [x] 2026-11-25 — Migration depuis `site`, vague 1 (diapos) : section « Administrer avec libvirt » et TP `virtualisation/tp/libvirt/` (harnais : 17 vérifications en lint, 54 en TCG) ; delta conteneurisation (réseau, journaux, audit, tableau CMD × ENTRYPOINT) ; cours nouveaux `ansible/`, `shell/`, `edition-formats/`, `acces-distants/`, `git/`, chacun avec son script de rejeu
- [x] 2026-11-25 — Migration depuis `site`, vague 2 (TP) : quinze séances avec corrigés en fichiers réels et harnais — shell (premiers-pas, fichiers, scripts, sed-awk), édition et formats (yaml-json, vim), Git (git-local, git-distant), accès distants (ssh, tmux, wireguard), Ansible (inventaire, playbooks, roles), en plus de libvirt
- [x] 2026-11-25 — Charte : composants communs `touche`, `tableau`, `fichier`, `machine`, `fleche`, `canevas` ; couleurs `distant` et `branche` dans chaque palette ; une illustration de couverture par cours (`tube`, `graphe`, `texte`, `tunnel`, `noeuds`)
- [x] 2026-11-25 — Terminal interactif des pages web (`commun/terminal/`) : VM Alpine dans le navigateur (v86, téléchargée à la demande, mise en cache, 34 Mo) et compagnon local en Go ; `page-web(terminal: …)` ; fichiers de départ des TP embarqués dans l’image ; les huit TP en mode `vm` rejoués dans la VM par les tests
- [x] 2026-11-25 — Accueil et README pour sept cours en trois groupes ; CI des corrigés en matrice (un harnais par tâche), paquets `apt` déclarés par TP (`paquets-apt.txt`), convention de proxy unique `TPTEST_CA`
- [x] 2026-11-25 — Sorties des diapos rejouées sur Debian 13 : shell (ShellCheck 0.10.0, Bats 1.11.1, cron), Git 2.47.3, édition et formats (vim 9.1.1230, yq 3.4.3, yamllint 1.37.1), accès distants (OpenSSH 10.0, tmux 3.5a), Ansible (Debian 13.8, Python 3.13) ; les scripts de rejeu se relancent seuls dans `debian:13-slim`
- [x] 2026-11-25 — CI des corrigés verte sur la branche : seize TP sur seize (ShellCheck ≥ 0.11, capture WireGuard filtrée, labo Ansible sans secret de build) ; TP libvirt : disque déclaré par fichier, parce que libvirt 10.0 écrit le profil AppArmor avant de traduire un disque `type="volume"` en chemin ; l’ISO sous `$HOME` demande une ACL pour `libvirt-qemu`
- [x] 2026-11-25 — Énoncés alignés sur les diapos rejouées : Git 2.47.3, justification de `indentkeys` du dojo Vim, messages réels de `ip link add` sans module WireGuard
