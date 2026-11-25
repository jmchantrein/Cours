# TODO

## À faire

### Cours Docker
- [ ] Rejouer les sorties marquées « à rejouer » avec `conteneurisation/cm/rejouer.sh` sur un Debian 13 (docker.io 26.1.5, AppArmor), puis les recopier dans les diapos

### Cours Virtualisation
- [ ] Rejouer les sorties types (KVM, TP) avec `virtualisation/cm/rejouer-tp.sh` sur une machine avec KVM, puis remplacer les sorties des diapos et les mentions « à rejouer » des notes
- [ ] Rejouer `virtualisation/tp/incus/tester.sh --up` sur une Debian 13 réelle (Incus 6.0.4) : la CI tourne sur Ubuntu 26.04, avec l’Incus 6.0.5 d’Ubuntu, et lance le harnais avec `--nesting`. À regarder d’abord : le conteneur témoin de l’étape 4 reçoit-il une adresse IPv4 sans `--nesting` ? Sinon, le contournement est `security.nesting=true`, et l’énoncé devra le dire dans ses prérequis. La mémoire à chaud y sera refusée (6.0.4) là où la CI (6.0.5) l’accepte : le harnais attend l’un ou l’autre selon la version
- [ ] Rejouer en direct les commandes des diapos Incus, écrites d’après les sources d’Incus 6.0.4 et non exécutées
- [ ] À la fusion de la branche qui ajoute la section libvirt et le TP `virtualisation/tp/libvirt/` : cette branche fusionne d’abord dans `main` ; ensuite, fusionner `main` ici, résoudre les conflits dans `virtualisation.typ`, `test-corriges.yml`, `index.typ` et `README.md`, adopter la convention de CI de `main` pour les prérequis du harnais Incus (`paquets-apt.txt` à la place des directives `ci-prerequis` de l’en-tête de `tester.sh`), puis appuyer la diapo `trois-etages` et les questions de comparaison du TP Incus sur le TP libvirt
- [ ] Après cette fusion, déplacer la diapo « VM et conteneurs : deux façons d’isoler » (étiquette `vm-et-conteneurs`) avant la section Incus, et ajouter LXC et Incus à sa colonne des conteneurs, pour que « conteneur système », cgroups et espaces de noms soient définis avant leur premier emploi

### Cours Conteneurisation — Orchestration
- [ ] Rejouer sur Debian 13 les sorties Swarm des diapos « le fichier Compose devient une stack » et « passage à l’échelle, reprise sur panne » (prises sur Docker 29.10, un nœud), et tester la répartition de charge du routing mesh (`curl`, non rejouable sans IPVS)
- [ ] Vérifier les adresses des sources des diapos Orchestration (docs.docker.com, kubernetes.io : inaccessibles lors de la rédaction) et les faits marqués « à vérifier » dans les notes de l’orateur
- [ ] Essayer le manifeste Kubernetes de la diapo « pod, Deployment, Service » sur un cluster (kind, minikube ou k3s)

### Docker Sandboxes (cours Conteneurisation et Virtualisation)
- [ ] Rejouer les commandes `sbx` de la diapo « Docker Sandboxes » du cours Conteneurisation sur un Ubuntu 24.04 avec KVM et un compte Docker (`sbx` 0.54.1 lors de la rédaction), puis recopier les sorties
- [ ] Relire la diapo à chaque évolution de `sbx` (version 0.x, une version par semaine) : commandes, prérequis, liste des concurrents

### Artefacts
- [ ] Rejouer `conteneurisation/artefacts/cache-de-build/verifier-buildkit.js` sur Debian 13 (docker.io 26.1.5) : le modèle n’a été confronté qu’à BuildKit de Docker Engine 29.10
- [ ] Rejouer `virtualisation/artefacts/heritage-des-profils/verifier-incus.js` sur Debian 13 (Incus 6.0.4)

### Travaux pratiques
- [ ] Vérifier dans Firefox et Chromium que les renvois du TP ouvrent le PDF à la bonne diapo (`#nameddest=`)
- [ ] Supprimer la branche `corrections` : son historique est rattaché à `main` par un commit de fusion sans changement de fichiers (`git show c83a3d5:wordpress_step_by_step/…` reste lisible)
- [ ] Vérifier les liens externes du TP WordPress (docs.docker.com, wordpress.org, iximiuz Labs : non testables depuis l’environnement de rédaction)
- [ ] Vérifier le site publié par GitHub Pages (accueil, TP, artefact, polices, renvois vers les diapos)

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
- [x] 2026-11-25 — Docker Sandboxes dans les deux cours : Virtualisation, une diapo « Docker Sandboxes : une microVM par agent IA » (architecture, concurrents par technique d’isolation) et une puce au récapitulatif ; Conteneurisation, deux diapos en fin de « Utilisation avancée · Sécurité » (le besoin et l’annonce, puis la mise en place avec `sbx`) ; faits lus dans le dépôt source de la doc Docker (`docker/docs`, 25/11/2026)
- [x] 2026-11-25 — Incus dans le cours de virtualisation : section dans les diapos, TP « Découvrir Incus » (`virtualisation/tp/incus/`, sept étapes des machines virtuelles aux conteneurs système, Docker dans une VM en facultatif, corrigés joués en CI par `tester.sh --up` sur Ubuntu 26.04 et Incus 6.0.5, 82 vérifications), artefact « L’héritage des profils » confronté à Incus 6.0.5 par `verifier-incus.js` (60 manipulations, aucun écart) ; un seul TP sous virtualisation (ADR 0001), TP WordPress inchangé hormis une mention facultative ; boutons à l’accueil, README
