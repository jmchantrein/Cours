# TODO

## À faire

### Cours Docker
- [ ] Rejouer les sorties marquées « à rejouer » avec `conteneurisation/rejouer.sh` sur un Debian 13 (docker.io 26.1.5, AppArmor), puis les recopier dans les diapos

### Cours Virtualisation
- [ ] Rejouer les sorties types (KVM, TP) avec `virtualisation/rejouer-tp.sh` sur une machine avec KVM, puis remplacer les sorties des diapos et les mentions « à rejouer » des notes

### Travaux pratiques
- [ ] Décider : arborescence `<cours>/cm`, `tp`, `artefacts` ; format des énoncés (Markdown + figures Typst en SVG, ou Typst) ; refonte de l'étape 3 ; sort de la partie Swarm et de l'étape 9
- [ ] Rapatrier dans `conteneurisation/tp/` les corrigés testés du dépôt `site` (`site/src/solutions/tp-docker-wordpress/`) et le harnais `site/scripts/test-solutions.sh` (deux chemins à adapter, nettoyage des volumes à borner), avec une CI dédiée
- [ ] Archiver la branche `corrections` par un tag puis la supprimer (rien n'y manque par rapport à `site`, hors commentaires en français et historique)
- [ ] TP conteneurisation, écarts de fond avec le cours : étape 3 (setuid, contredit « aucun binaire setuid », gosu ou setpriv) ; étape 5 (`--link` → réseau utilisateur et DNS) ; étape 4 (instruction `VOLUME` → volume nommé) ; Swarm et étape 9 (hors cadre du cours, Play with Docker fermé)
- [ ] TP conteneurisation, mises à jour mécaniques : `docker compose` et `compose.yaml` sans clé `version`, tags épinglés (`debian:13`, base de données maintenue), forme `docker container …`, `apt-get`, `WORKDIR`, liens docs.docker.com, vocabulaire du cours (service, persistance, publier, journal, entrypoint, couche)
- [ ] TP conteneurisation, erreurs factuelles : `docker volume prune` (anonymes seulement depuis Docker 23, lapsus « conteneur »), volumes anonymes supprimés seulement avec `--rm` ou `rm -v`, pilotes de stockage (aufs et devicemapper retirés, sans rapport avec les volumes), bash « passé en arrière-plan » (il lit une fin de fichier et sort), `GRANT ALL ON *.*` contre la consigne, `mysqldump` en cron (`-it`, `$(date)`), `docker stack deploy` sans nom de stack, `deploy` et `overlay` dans Compose
- [ ] TP conteneurisation : retirer les doublons avec les « À vous » des diapos (publier nginx, conteneurs qui surprennent) et y renvoyer
- [ ] Corrigés à la demande dans les énoncés : `<details>` en deux temps (indice, puis corrigé)
- [ ] Premier artefact interactif (cache de build) et publication GitHub Pages

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
