# Charte commune des cours

- `charte.typ` : ce que tous les supports partagent — rôles pédagogiques, palettes des variantes, couleurs.
- `theme-cours.typ` : la charte appliquée aux diapos (Touying) : blocs, terminaux, schémas, animations.
  Import depuis un cours : `#import "../../commun/theme-cours.typ": *`
- `theme-tp.typ`, `tp.css`, `tp.js` : la charte appliquée aux pages web (énoncés de TP, accueil).
  Import depuis un TP : `#import "../../../commun/theme-tp.typ": *`
- `terminal/` : le terminal des pages web (voir « Pages web : terminal »).
- `fonts/` : IBM Plex Sans et Mono (SIL Open Font License 1.1, voir `fonts/OFL-IBM-Plex.txt`).

## Principe : le cours dit le rôle, la charte décide de l’apparence
Un cours n’écrit jamais de couleur : il déclare le **rôle pédagogique** d’un bloc, et la charte en tire
la couleur, le pictogramme et leur adaptation dans chaque variante.

| Rôle | Pictogramme | Couleur en projection | Usage |
|---|---|---|---|
| `notion` (défaut) | — | bleu | définir, expliquer |
| `pratique` | — | vert | exemple, démonstration, usage réel |
| `question` | coureur en sueur (l’effort des étudiants) | vert clair | exercice : ce qu’on demande de faire |
| `reponse` | — | vert foncé | corrigé : la réponse à une question |
| `retenir` | cerveau | bleu nuit | synthèse, point clé |
| `precaution` | triangle ! (+ feu du bas) | jaune | nuance, confusion fréquente, limite |
| `avertissement` | triangle ! (+ feu du milieu) | orange | erreur probable, mauvaise pratique |
| `danger` | triangle ! (+ feu du haut) | rouge | risque réel : sécurité, perte de données |

Les trois niveaux d’alerte suivent la gradation des normes de signalisation (ISO 3864, ANSI Z535) :
précaution, avertissement, danger ; les trois partagent le triangle « ! ». Dans les variantes, il est suivi d’un feu
tricolore dont le feu allumé (bas, milieu, haut) donne le niveau par sa position, donc même sans couleur. Le coureur ne marque que les questions : il signale une manipulation à faire. Les dessins du cerveau et du coureur viennent de Tabler Icons (MIT, `pictos/LICENSE-tabler-icons.txt`).

Dans les schémas : hôte et applications en **bleu**, invité (VM, OS invité) en **violet** (`c.invite`,
`c.invite-clair`). Dans les terminaux, `cadre(…, niveau: 0 | 1 | 2)` : hôte (trait plein), VM invitée (tirets),
VM imbriquée (pointillés).

## Écrire une diapo
- Une section (surtitre bleu) = un titre `=` ; une diapo = un titre `==`.
- Blocs colorés côte à côte, à hauteur égale :
  `#colonnes(bloc[Titre][- point], bloc(role: "pratique")[Titre][- point])`
- Note courte : `#note(role: "pratique")[...]` ; encadré à libellé : `#encadre(role: "precaution", libelle: [En vrai :])[...]`.
- Plusieurs questions et réponses sur une diapo : `#corriges(note: […], (1, [question], reponse[…]), …)`.
- Couverture : `#couverture(illustration: "vm" | "couches")[titre][sous-titre][auteur][date]` ; clôture, même design, en fin de cours : `#cloture(illustration: …)[Merci][Des questions ?][auteur][lien]`.
- Corrigé de TP : `#corrige(n, [question], uncover("2-", reponse(terminal[...])))` ; la question porte le vert
  clair du rôle `question`, la réponse une barre vert foncé qui apparaît avec elle.
- Machine lancée par la commande au-dessus, dans un terminal : `#cadre([VM (niveau 1)], niveau: 1)[...]`.
- Terminal : `#terminal[```...```]` ; une ligne `$ ` colore l’invite, une ligne `# ` grise le commentaire.
- Bandeau sombre (origine, éditeur) : `#bandeau[...]`.
- Source d’un fait, en bas de diapo : `#source[#link("https://…")[…]]`.

## Animer une diapo
Les apparitions suivent la skill `structurer-diapos-cours` : bloc par bloc, puis puce par puce.
- Cas courant : `#anime(rang(bloc[…][…], bloc[…][…]), rang(bloc(role: "retenir")[…][…]), bandeau[…], note: […], source-de: […])`.
  Un bloc apparaît avec sa première puce, chaque puce suivante au clic suivant ; un contenu quelconque compte pour un clic.
- Mise en page libre : `#slide(repeat: n, self => { let (uncover,) = utils.methods(self); … })`, avec
  `bloc-anime(b, debut, uncover)` pour un bloc, `lignes(uncover: uncover, …)` pour une ligne par clic.
- Dans `anime`, éléments à plusieurs clics : `lignes-anime(…)` (une ligne par clic), `plan-anime(…)`,
  `terminal-etapes([```…```], [```…```])` (un morceau de terminal par clic), et `pas(n, (uncover, debut) => …)`
  pour une mise en page libre.
- Notes de l’orateur d’une diapo animée : paramètre `note:` de `anime`, ou `utils.speaker-note(self: self)[…]`.
- Notes de l’orateur : `#speaker-note[...]`.
- Apparitions au clic : voir, dans `virtualisation/virtualisation.typ`, les diapos « Architecture simplifiée et bilan »,
  « La migration à chaud » et le corrigé du TP (style callback : `#slide(repeat: n, self => ...)` avec `uncover("2-", ...)`).
  Chaque étape devient une page du PDF.

Édition avec aperçu en direct : extension Tinymist (VS Code, VSCodium, Neovim…), avec la racine du dépôt comme racine du projet.

## Variantes de rendu
La charte lit `--input variante=<nom>` (projection, deuteranopie, protanopie, tritanopie, achromatopsie, dyslexie)
et adapte palette et espacements ; les cours n’ont rien à faire. Chaque variante commence par une page
« Légende », hors numérotation, qui relie ses couleurs à celles de la projection (« le bloc orange » = avertissement). Les réglages et leur justification sont en tête
de `charte.typ`. Une nouvelle palette s’ajoute dans `palettes` ; penser à l’ajouter aussi à la liste des
variantes de `.github/workflows/compilation-cours.yml`. Si une variante déborde, chercher d’abord une mise en page qui tienne ; le débordement n’est acceptable qu’en
dernier recours.

## Pages web : énoncés de TP
Un énoncé s’écrit en Typst et se compile en une page HTML autonome (`--features html --format html`).
La page embarque toutes les variantes : le lecteur choisit la sienne dans le bandeau, son choix est mémorisé
par son navigateur. Le nom du rôle et son pictogramme sont écrits dans chaque bloc.

- Page : `#show: page-web.with(titre: […], surtitre: […], sous-titre: […], auteur: […], date: […], liens: (([texte], "adresse"), …), illustration-couverture: "couches")`.
  L’en-tête reprend la couverture des diapos : fond nuit, surtitre, titre, illustration du cours (`"vm"`, `"couches"`,
  définies dans `charte.typ`). Le pied de page invite à signaler une erreur.
- Une étape = un titre `=` étiqueté (`= Étape 1 : … <etape-1>`) ; le sommaire en découle : en colonne à gauche
  sur un écran large, il marque l’étape en cours de lecture.
- Accueil : `#cartes(carte([titre], illustration: "vm")[texte #actions(bouton(principal: true, [texte], "adresse"), …)], …)`.
- Bloc : `#bloc(role: "question")[Consignes][- …]` ; remarque courte : `#note(role: "precaution")[…]`.
- Terminal : `#terminal[```console … ```]` ; une ligne `$ ` est une commande, une ligne `# ` un commentaire.
  Le bouton « Copier » ne copie que les commandes.
- À la demande : `#indice[…]`, `#indice(titre: […])[…]`, puis `#corrige[…]`. Ils sont repliés, et omis à l’impression.
- Fichier de corrigé : `#fichier("corrige/…/Dockerfile", read("corrige/…/Dockerfile"))` ; la page montre le
  fichier que `tester.sh` vérifie.
- Renvoi vers une diapo : poser une étiquette sur son titre dans le cours (`== Titre <ancre>`), puis
  `#diapo("../../cm/<cours>-projection.pdf", "ancre")[texte]`.
- Schéma : `#schema([légende], ch => …)` ; le dessin reçoit la charte d’une variante (`ch.c`, `ch.roles`) et
  s’écrit avec `boite(…)`, `case(…)` et les primitives de Typst. La page contient un dessin par palette.

## Pages web : artefacts
Un artefact est un petit logiciel interactif qui fait manipuler un concept : `<cours>/artefacts/<nom>/`.
- `<nom>.typ` : une page `page-web(atelier: true, …)`, compacte, qui place l’artefact et son aide côte à côte :
  `#artefact(read("<nom>.js"), style: read("<nom>.css"))[aide]`. L’aide énonce la règle (bloc `retenir`, renvoi
  `diapo(…)`) et propose des expériences : `#experiences(([question], [réponse], "recette"), …)`, montrées une
  à la fois. Le troisième élément, facultatif, nomme une recette que le script sait jouer, dans une carte à
  part. Par défaut la recette s’arrête après chaque étape, explique ce qui vient de se passer et attend
  « Continuer » ; une case l’enchaîne sans pause. « Revenir » rétablit l’état mémorisé après chaque étape.
  À la fin, le lecteur reprend la main sans rien fermer, et ses propres builds sont expliqués.
- Une explication se calcule à partir du résultat de la simulation ; elle ne s’écrit pas d’avance. Ce que le
  simulateur ne sait pas simuler, il le dit (« Limitation du simulateur : … ») au lieu de répondre.
- Un simulateur se vérifie contre l’outil réel : `cache-de-build/verifier-buildkit.js` rejoue des
  manipulations tirées au hasard dans l’artefact et dans un vrai `docker build`, et compare les résultats.
- Sur un écran d’ordinateur, la page d’atelier prend exactement la hauteur de la fenêtre : le texte grossit
  avec elle, et ce qui peut grandir défile dans son cadre. Rien n’est rogné à 1280 × 650 px utiles, toutes
  réponses ouvertes.
- `<nom>.js` : construit l’interface dans l’élément `#artefact`, sans bibliothèque externe.
- `<nom>.css` : n’emploie que les variables CSS de la charte (`--c-*`, `--<rôle>-entete`…), pour suivre la variante choisie.
- Un état se lit dans le texte (« CACHED », « DONE ») ; la couleur ne fait que le doubler.

## Pages web : terminal
Une page déclare son terminal : `page-web(…, terminal: ("compagnon",))` pour un TP Docker ou libvirt, qui ne
tourne pas dans une VM de navigateur ; `terminal: ("vm", "compagnon")` pour un TP shell (le premier mode est
proposé d’abord). Une page qui ne déclare rien reste telle quelle. Les sources des TP ne changent pas : `tp.js`
pose un bouton « Exécuter » après chaque commande `$ ` (suites `\` comprises) des blocs `terminal[…]`, actif
quand un terminal est ouvert ; un bouton « Terminal » du bandeau ouvre un volet en bas de la fenêtre, dont la page
réserve la hauteur.
- Mode `vm` : une VM Alpine Linux x86 dans l’onglet (v86), sans réseau ni installation. L’image se télécharge
  au clic sur « Démarrer la VM », avec sa progression, puis se range dans Cache Storage, sous une clé qui porte
  sa version (`cours-terminal-vm-<version>`) : une visite suivante ne télécharge rien.
- Mode `compagnon` : le vrai shell de l’étudiant, par l’exécutable `iadmin-terminal` (`terminal/compagnon/`, en Go),
  qui écoute sur `127.0.0.1` avec un jeton à usage unique, une liste d’origines et un seul client. La page
  [`terminal/compagnon.typ`](terminal/compagnon.typ) (publiée en `commun/terminal/`) explique son téléchargement.

Fichiers de `terminal/` :
- `terminal.js`, `terminal.css` : le volet, ajoutés par `theme-tp.typ` aux seules pages qui le déclarent ; le
  style n’emploie que les variables de la charte, et xterm.js reçoit ses couleurs de `--c-nuit`, `--c-texte-term`…
- `dependances.txt` : version, SHA-256 et adresse de chaque fichier tiers ; `preparer.sh [--vm]` les télécharge
  dans `vendor/` et, avec `--vm`, construit l’image (`construire-vm.sh`, Docker ; `vm/init`, `vm/profil.sh`) et son
  manifeste `vendor/vm/manifeste.json`.
- `compagnon/` : le code Go (`go.mod`, `go.sum`), `construire.sh` (exécutables statiques Linux et macOS, amd64 et
  arm64, et `SHA256SUMS`, dans `compagnon/dist/`), `tester.py` (protocole et refus).
- `LICENCES.md` : licences et sources des composants publiés.

`vendor/` et `compagnon/dist/` ne sont pas versionnés : la CI les construit et les publie avec le site.
Tester, depuis la racine du dépôt, après `preparer.sh --vm` et `compagnon/construire.sh` :

    node commun/terminal/tester-vm.mjs               # démarre la VM dans Node, vérifie ses outils
    python3 -I commun/terminal/compagnon/tester.py   # protocole, jeton, origine, un seul client
    node commun/terminal/tester-navigateur.js        # Chromium : clics, deux modes, cache, refus, captures

`tester-navigateur.js` compile les pages testées, dont une page d’essai du mode VM (`build/essai-terminal/`), et
les sert sur `localhost:8000`, origine que le compagnon admet pour les essais.

Limite connue : l’export HTML de Typst est expérimental. La CI fixe la version de Typst ; à chaque montée de
version, recompiler les pages et les relire dans un navigateur.
