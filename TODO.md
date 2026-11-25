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
- [ ] Vague 1 — diapos : delta virtualisation (libvirt, réseau, stockage, instantanés), delta conteneurisation (réseau, erreurs à éviter), `ansible/cm/`, `shell/cm/`, `edition-formats/cm/`, `acces-distants/cm/`, `git/cm/`
- [ ] Vague 2 — TP avec corrigés testés : `virtualisation/tp/libvirt/`, Ansible (trois séances), shell (dont premiers pas et fichiers, issus d’intro-linux), sed et awk, YAML/JSON, SSH, tmux, WireGuard, Git
- [ ] Vague 3 — artefacts : chaîne de backing files qcow2, CMD × ENTRYPOINT, précédence et inventaire Ansible, idempotence, expansions Bash, graphe Git, typage YAML ↔ JSON
- [ ] Terminal interactif des pages web (clic sur une commande → exécution dans un terminal), repris du principe du site
- [ ] Intégration : accueil `index.typ`, tableau du `README.md`, CI (paquets des harnais), relecture indépendante de chaque cours
- [ ] Relecture par l’auteur des contenus dont la source du site est rédigée par IA (réseau Docker, erreurs à éviter, réseau et stockage libvirt, concepts Ansible, tmux, labo WireGuard)

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
