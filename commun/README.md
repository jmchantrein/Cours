# Charte commune des cours

- `charte.typ` : ce que tous les supports partagent — rôles pédagogiques, palettes des variantes, couleurs.
- `theme-cours.typ` : la charte appliquée aux diapos (Touying) : blocs, terminaux, schémas, animations.
  Import depuis un cours : `#import "../../commun/theme-cours.typ": *`
- `theme-tp.typ`, `tp.css`, `tp.js` : la charte appliquée aux pages web (énoncés de TP, pages de cours, accueil).
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
`c.invite-clair`), machine où l’on entre à distance (SSH) en **turquoise** (`c.distant`, `c.distant-clair`,
`c.distant-t`), commits d’une autre branche en **orange** (`c.branche`). Dans les terminaux,
`cadre(…, niveau: 0 | 1 | 2 | "distant")` : hôte (trait plein), VM invitée (tirets), VM imbriquée (pointillés),
session distante (trait mixte). Chaque couleur existe dans chaque palette ; elle se distingue de ses voisines dans
chaque variante (ΔE CIELAB simulé, Machado 2009 pour les dichromasies, clarté seule pour l’achromatopsie ; les
valeurs et les écarts sont en tête de `charte.typ`).

## Écrire une diapo
- Une section (surtitre bleu) = un titre `=` ; une diapo = un titre `==`.
- Blocs colorés côte à côte, à hauteur égale :
  `#colonnes(bloc[Titre][- point], bloc(role: "pratique")[Titre][- point])`
- Note courte : `#note(role: "pratique")[...]` ; encadré à libellé : `#encadre(role: "precaution", libelle: [En vrai :])[...]`.
- Plusieurs questions et réponses sur une diapo : `#corriges(note: […], (1, [question], reponse[…]), …)`.
- Couverture : `#couverture(illustration: "vm", surtitre: […])[titre][sous-titre][auteur][date]` (surtitre par défaut : « Cours ») ; clôture, même design et même
  illustration, en fin de cours : `#cloture(illustration: "vm")[Merci][Des questions ?][auteur][lien]`. Illustrations
  (dessinées dans `charte.typ`, une par cours) : `"vm"` (virtualisation : trois VM sur un hyperviseur), `"couches"`
  (conteneurisation : couches d’image), `"tube"` (shell : une invite, puis des lignes de texte filtrées par deux tubes `|`), `"graphe"` (git : main et
  une branche fusionnée), `"texte"` (édition et formats : fichier structuré et curseur), `"tunnel"` (accès distants :
  le poste, un tunnel chiffré, la machine distante), `"noeuds"` (ansible : un nœud de contrôle, trois nœuds gérés).
  Un cours nouveau ajoute sa illustration à `illustration(…)` de `charte.typ`, avec ses couleurs prises dans `c`.
- Corrigé de TP : `#corrige(n, [question], uncover("2-", reponse(terminal[...])))` ; la question porte le vert
  clair du rôle `question`, la réponse une barre vert foncé qui apparaît avec elle.
- Machine lancée par la commande au-dessus, dans un terminal : `#cadre([VM (niveau 1)], niveau: 1)[...]`.
- Terminal : `#terminal[```...```]` ; une ligne `$ ` colore l’invite, une ligne `# ` grise le commentaire. Un code
  en ligne (`` `ls` ``) posé dans un terminal prend la couleur du texte du terminal, non le bleu du texte courant.
- Bandeau sombre (origine, éditeur) : `#bandeau[...]`.
- Source d’un fait, en bas de diapo : `#source[#link("https://…")[…]]`.
- Touche du clavier, dans le texte : `#touche[Échap]`, `#touche[Ctrl+b]`.
- Tableau à en-tête, lignes alternées : `#tableau((auto, 1fr), ([Commande], [Effet]), ([`ls`], [liste]), …)` ; `taille:`
  fixe le texte, les réglages nommés (`inset`, `align`) passent à `table`. Les fonds sont translucides : le tableau se
  lit sur la diapo comme dans un bloc.
- Fichier affiché (un objet, à distinguer du terminal qui montre des commandes) : fond clair, nom en tête :
  `#fichier([config.yaml])[```yaml …```]` ; `nom: none` sans en-tête ; à côté d’un terminal, dans une `rangee`.
- Schéma sur un canevas aux coordonnées de la maquette (px) : `#canevas(512, { pose(x, y, …); fleche-pose(x1, y1, x2, y2) })`.
  `fleche-pose` dessine une flèche dans toute direction (`couleur:`, `ep:` épaisseur, `tirets: true`).
- Schéma en grille : `#machine(distant: false, role: [poste d’Ada])[client]` (le poste en bleu ; sans `distant: false`,
  une machine où l’on entre à distance, en turquoise) ; ce qui suit le nom (puces, fichiers…) se place dessous, au centre.
  `#fleche(haut: […], bas: […], vers: "gauche", couleur: …)` relie deux cellules d’une grille, libellée au-dessus et
  au-dessous.

## Dessiner une transformation
Une diapo montre une transformation (skill `structurer-diapos-cours`, « Schémas et mise en scène ») : un état de
départ, une action, un état d’arrivée ; chaque clic fait avancer l’action. Composants de `theme-cours.typ` :

- **Scène** : `#anime(scene(n, k => …))` occupe n clics ; le dessin est une fonction du clic k (1 à n, puis n + 1 :
  l’état final, sans plus rien mettre en valeur). Terminal et schéma qui avancent ensemble se placent dans la même
  scène : `scene(5, k => grid(columns: 2, terminal-annote(…, etape: k), schema-etats(…, etape: k)))`.
- **Arborescence** : `#arbre(racine, courant: "/home/ada/atelier", voir: (…), parcours: (…), ouverts: (…), caches: (…))`
  dessine un arbre de répertoires (un nœud : `"fichier"` ou `("rep", (enfants…))`, la racine `("/", (…))`), chaque
  niveau relié à son parent par un trait coudé. Il montre le chemin jusqu’au répertoire courant, ses frères et son
  contenu ; une ligne grise compte le reste (« + 18 autres »). Le répertoire courant est sur fond bleu (`ici: [ici]`
  ajoute un texte), ce qu’emploie la commande est encadré (`voir`), un chemin suivi est numéroté nœud par nœud
  (`parcours`), un nom `"- absent.txt"` est barré (n’existe pas), `etiquettes: ("/home/ada": raw("~"))` ajoute un texte.
- **Contexte** : `#anime(contexte: contexte(racine, courant: …, variables: (("p", "Ada"),)), …)` pose une colonne à
  gauche de la diapo, toujours à la même place, de la même largeur et de la même hauteur (`largeur-contexte`,
  `hauteur-contexte`) : le compte (`compte`, `machine` pour une session distante ou un conteneur), l’arbre (paramètres
  d’`arbre`), les variables. Quand une commande la change (`cd`, fichier créé), `contexte: k => contexte(…)` (k : le
  clic de la diapo) ; `corriges(contexte: …)` aussi. Le reste de la diapo dispose de 1 212 px de large au lieu de 1 664 :
  un schéma en px s’y redessine. Un titre sur deux lignes fait déborder la colonne : le garder sur une ligne.
  Exemples : `shell/cm/arbo.typ` (le module qui l’enseigne), `shell/cm/shell.typ` (`ctx(…)` y construit l’arbre).
- **Commande ou sortie annotée** : `#anime(commande-annotee(("$ wc -l f", ("9 f", 3)), annote("wc", legende: [la commande]), annote("-l", legende: [une option])))`.
  Une ligne paraît au clic donné (`("texte", clic)`, ou par morceaux `(("$ cut …", 1), (" | sort", 2))`) ; chaque
  `annote(…)` désigne un morceau par son texte (`"-l"`, `(ligne: 2, texte: ";", n: 1)`, `(ligne: 2, cols: (3, 7))`),
  l’encadre au clic où il paraît, puis le souligne, et le relie à sa légende. Les légendes se placent seules,
  d’après la colonne du morceau, sur des rangées où aucun trait ne coupe une légende ; `cote: "haut" | "bas" | "droite"`
  (à droite : les légendes trop proches sont décalées vers le bas). Une légende passée reste, grisée, si l’annotation
  en cours porte sur la même ligne (la suite décompose cette ligne), sinon elle s’efface ; `reste: true | false`
  l’impose. Au plus cinq légendes à l’écran : au-delà, les plus anciennes s’effacent — mieux, scinder la diapo.
  Sans `legende` : une marque seule (`garde: true` la laisse encadrée : la démonstration d’un corrigé).
  `fond: "fichier"` : sur fond clair, avec `nom:` en tête. Hors `anime` : `terminal-annote(…, etape: k)`.
- **Schéma à états** : `#schema-etats(etape: k, hauteur: 500, noeuds: (…), liens: (…), etats: ((:), (liens: (s1: (vers: "f.g"))), …))`.
  Des nœuds nommés, en px de la maquette (`x`, `y`, `l`, `h`), ou en cases (`grille: (x: 340, y: 130, ecart: 40)`,
  puis `col`, `lig`, `larg`, `haut`) : `"processus"` (prises 0, 1, 2 numérotées ; `attente: true` : pas encore lancé),
  `"terminal"`, `"fichier"` (`titre`, `pied`, `contenu` : des lignes ; `()` : vide), `"flux"` (ce qui circule dans un
  tube), `"boite"` (`attente: true` : commande non lancée), `"texte"` (une légende qui change avec l’état ;
  `role: "danger"` lui donne le fond et le pictogramme d’un rôle). `marque: (i, …)` encadre des lignes d’un contenu.
  Un lien va de `"nœud.prise"` à `"nœud.prise"` (prises du genre, `ports: (nom: ("g", 0.3))`, ou `g`, `d`, `h`, `b`) ;
  options `etiquette`, `donnee` (ce qui circule, sur fond de terminal), `tirets` (le flux 2), `motif: "dotted"` (voie non
  suivie), `fort`. Chaque état ne dit que ce qui change (`none` retire).
  `echelle: 1.25` agrandit tout le schéma (nœuds, textes, traits) sans changer ses coordonnées : pour occuper la hauteur
  de la diapo. Commande annotée : `taille:` (le terminal) et `taille-legende:` ; carte de progression : `taille:`.
- **Repère d’étape** : ce qui change au clic k porte une pastille, carré bleu à chiffre blanc (`pastille(n)`), distincte
  des prises rondes et blanches : au coin d’une boîte, dans l’en-tête d’un fichier, devant la légende, en face de la
  première ligne nouvelle d’un terminal, dont les lignes précédentes passent en gris ; un lien changé s’épaissit et
  laisse son ancien tracé en pointillé. `numero: k => …` règle la numérotation (défaut : l’état 1 est le départ, sans
  numéro ; `k => k` s’il est déjà une action). Le même numéro peut ouvrir une légende d’`annote` (`[#pastille(2) …]`).
- **Ligne réécrite par Bash** : `#anime(reecriture-anime(commande: "$ printf …", rangs: (r1, …, r6), notes: (…), sortie: (…)))`.
  Une rangée par étape de l’expansion (Mots, Accolades, Tilde $ $( ), Découpage, Chemins, Guillemets : les noms de
  l’artefact `shell/artefacts/expansions-bash/`) ; un mot `(origine, "texte", genre)` reste dans la colonne du mot tapé
  dont il vient ; genre `"x"` : produit par une expansion (fond teinté), `"q"` : protégé par des guillemets (souligné) ;
  `·` : une espace dans un mot, `∅` : un mot vide. À chaque clic, ce qui change est encadré et une seule note dit
  pourquoi ; au dernier clic, la sortie réelle prouve le résultat (à droite, ou `sortie-dessous: true`). `arguments("Mon", "dossier")` dessine, dans une
  légende, les arguments qu’une commande reçoit.
- **Touche du clavier** : `#rangee-touche(n, ("$ whoa",), ([Tab],), ("$ whoami ",), [légende])` dessine la ligne avant,
  la ou les touches, la ligne après, et la légende numérotée ; `ecran-ligne(lignes, curseur: (ligne, colonne))` est
  l’écran seul, curseur en pavé comme dans un terminal. `#ligne-curseur("$ echo …", curseur: 36, ancien: 47,
  retire: (36, 47), ajoute: none)` dessine une ligne en grand, le curseur en trait, son saut (flèche au-dessus de la
  ligne, ancienne place en tirets), le morceau coupé (laissé en place, barré) ou recollé (souligné). Exemple :
  `shell/cm/clavier.typ`.
- Les distinctions tiennent sans la couleur : épaisseur, motif du trait, cadre, numéro, étiquette.
- **Contraste des traits** : un trait se lit sur tout fond qu’il traverse, dans chaque variante, sans réglage à la main.
  Les liens de `schema-etats` et les flèches de la carte de progression passent sur un halo de la couleur du fond
  (`fleche-pose(…, halo: c.fond)`) : une flèche sombre qui entre dans un terminal ou en sort reste détachée du fond nuit.
  Un trait de légende d’`annote` est clair (`c.prompt`) tant qu’il est dans le terminal, de la couleur de la légende
  au-dehors ; les pastilles ont un liseré blanc. Un composant nouveau tire de même la couleur de ses traits de son fond.
- Exemples : `shell/cm/shell.typ`, des sections « Bash · Les bases » à « Bash · Guillemets et expansions ».

## Animer une diapo
Les apparitions suivent la skill `structurer-diapos-cours` : bloc par bloc, puis puce par puce.
- Cas courant : `#anime(rang(bloc[…][…], bloc[…][…]), rang(bloc(role: "retenir")[…][…]), bandeau[…], note: […], source-de: […])`.
  Un bloc apparaît avec sa première puce, chaque puce suivante au clic suivant ; un contenu quelconque compte pour un clic.
  Une énumération ou un énoncé, qui ne décomposent pas une explication, s’affichent d’un coup : `bloc(revele: "bloc")`.
- Mise en page libre : `#slide(repeat: n, self => { let (uncover,) = utils.methods(self); … })`, avec
  `bloc-anime(b, debut, uncover)` pour un bloc, `lignes(uncover: uncover, …)` pour une ligne par clic.
- Dans `anime`, éléments à plusieurs clics : `lignes-anime(…)` (une ligne par clic), `plan-anime(…)` (le plan, une partie par clic ; un sommaire s’affiche plutôt d’un coup : `#slide[#plan-cours(…)]`),
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
- L’étudiant tape : la consigne dit ce qu’il faut obtenir et comment le vérifier, sans montrer la commande. Les
  commandes vont dans des indices gradués (un qui oriente, puis `#indice(titre: [Dernier indice : les commandes…])`
  avec un `terminal[…]` de commandes seules) et au corrigé. Une commande d’une ligne repliée dans un indice ou un
  corrigé reçoit, à côté d’« Exécuter », un bouton « Écrire » qui la dépose à l’invite sans Entrée (VM et `host-shell-access` ;
  terminal fermé, il invite à le démarrer). `tester-vm.mjs` rejoue l’énoncé sans les indices (les corrigés
  comprises), puis, à la fin, les commandes d’indices absentes des corrigés. Exemple : `shell/tp/premiers-pas/`.
- Fichier de corrigé : `#fichier("corrige/…/Dockerfile", read("corrige/…/Dockerfile"))` ; la page montre le
  fichier que `tester.sh` vérifie.
- Renvoi vers une diapo : poser une étiquette sur son titre dans le cours (`== Titre <ancre>`), puis
  `#diapo("../../cm/<cours>-projection.pdf", "ancre")[texte]`.
- Schéma : `#schema([légende], ch => …)` ; le dessin reçoit la charte d’une variante (`ch.c`, `ch.roles`) et
  s’écrit avec `boite(…)`, `case(…)` et les primitives de Typst. La page contient un dessin par palette.

## Pages web : pages de cours
Une page de cours (`<cours>/pages/<module>/<module>.typ`) se suit à son rythme, les mains sur le terminal : une
notion, la commande qui la montre, un clic, le résultat dans le terminal à côté, une phrase qui dit quoi regarder,
puis la notion suivante. Ce n’est ni un TP (pas d’énoncé, pas de corrigé : la page montre, l’étudiant observe et
essaie ; les exercices longs restent au TP du module, vers lequel elle renvoie), ni un polycopié (ce qui se voit dans
le terminal ne se redit pas). Elle suit les règles de progression de `structurer-diapos-cours` : prérequis en
ouverture, pas de notion avant celles qui la composent, un fichier montré avant d’être manipulé. Un module peut avoir
ses diapos et sa page : la page reprend les exemples des diapos, dans le même ordre (les diapos font foi), et y
ajoute la pratique ; d’autres exemples vont au TP. Exemple : `shell/pages/arbo/`.

- Page : `#show: page-web.with(cours: true, terminal: ("vm", "host-shell-access"), depart: (…), contexte: (…), …)`. Sur un écran large
  (64 rem et plus), le texte défile à gauche et une colonne reste en vue à droite : le repère de contexte en haut,
  le terminal dessous, ouvert d’emblée ; terminal réduit, le repère prend la colonne. Sur un écran étroit, le repère
  se réduit à une ligne sous le bandeau (bouton « Arbre » pour le dessin) et le terminal redevient un volet en bas.
  En-tête compact, sommaire en boîte en tête du texte.
- Commandes : des blocs `terminal[…]` (sortie annoncée sous chaque commande), suivis de `#regardez[…]` : ce qu’il
  faut regarder dans le terminal ou dans le repère.
- Prédire : `#predire[question][#terminal[…]][explication]`, un bloc du rôle `question` ; la sortie annoncée et
  l’explication restent masquées jusqu’à ce que la commande soit exécutée (ou « Voir la sortie sans exécuter »).
- `#pastille(n)` : le carré bleu à chiffre blanc d’un pas, dans le texte comme dans le repère.
- `#touche[Tab]` : une touche, pour les gestes que l’étudiant tape lui-même (complétion, historique) : un clic
  n’envoie qu’une ligne, il ne montre pas la complétion.
- Geste au clavier : `#geste(tape: "who", touches: ("Tab", "Tab"), ligne: "who", ecran: "who     whoami  whois")[…]` :
  ce qu’on tape, les touches (ou un texte à taper), puis ce qu’on doit voir, calculé : la ligne avec le curseur en
  bloc (`point`, 0 au début), un écran, une sortie ; `voir` montre un écran sans le vérifier (recherche Ctrl+R).
  `ecrire: "…"` amorce une ligne longue : un bouton « Écrire » seul, qui la dépose à l’invite. `tester-vm.mjs` joue
  chaque geste touche par touche dans la VM et lit la ligne et le curseur dans Readline. Dans un `predire`, le
  résultat d’un geste reste masqué jusqu’à « Voir la sortie ». Exemple : `shell/pages/clavier/`.
- Le navigateur garde pour lui Ctrl+W, Ctrl+T, Ctrl+N : la page fait jouer Alt+Retour arrière à la place de Ctrl+W.
  Tant qu’un terminal tourne, quitter la page demande confirmation (`beforeunload`).
- Sans arborescence à montrer (module `intro`), la page ne déclare pas `contexte` : pas de repère, la colonne ne
  porte que le terminal, et s’efface quand on le réduit.
- **Repère de contexte** (`terminal/contexte.js`, `terminal/contexte.css`) : un arbre dessiné qui dit où l’on est,
  toujours au même endroit : la racine, le chemin jusqu’au répertoire courant (« ◀ vous êtes ici ») et jusqu’au
  répertoire personnel (`~`), le contenu du répertoire courant ; un répertoire replié nomme son contenu en petit, les
  noms cachés en italique gris. Une commande cliquée qui lit un chemin (`cd`, `ls`, `pwd`, `echo ~`) y est tracée :
  son départ (racine, répertoire courant, répertoire personnel, précédent), une pastille par composant, puis l’état
  qui suit (l’ancien répertoire porte « avant ») ; la légende de cette lecture se calcule d’après cet état.
  - En mode `vm`, le repère est **réel** : avant chaque invite, le Bash de la VM décrit son répertoire courant,
    `HOME`, `OLDPWD` et le contenu des répertoires voisins dans une séquence OSC invisible (`terminal/vm/contexte.bash`,
    sans lancer de processus, environ 0,2 s par invite) que `terminal.js` relaie (événement `terminal-contexte`).
  - Sinon (terminal fermé, VM qui démarre, `host-shell-access`), il est **déclaré** par la page : `contexte: (compte: "ada",
    depart: "/home/ada", personnel: "/home/ada", arbre: (…), creations: (…))`. `arbre` liste les chemins absolus connus
    (un répertoire finit par `/` ; `rep/.` le déclare vide, un répertoire sans entrée déclarée a un contenu inconnu) ;
    `creations` dit ce qu’une commande crée (`("bash preparer.sh", ("/home/ada/atelier/",))`). Le repère rejoue les
    `cd` de la page jusqu’au bloc qu’on lit, ou jusqu’à la dernière commande cliquée de ce bloc. `tester-vm.mjs`
    compare ce contexte déclaré au contexte réel après chaque commande : il dit vrai pour la page suivie dans l’ordre.
  - `host-shell-access` (le vrai shell de l’étudiant) ne décrit rien : le repère y reste déclaré, et le dit.

## Pages web : la page d’un cours
`<cours>/index.typ` (compilée en `<cours>/index.html`) présente le cours module par module : titre, numéro, ce qu’on
y apprend (`sait-faire`) et un lien par support présent (diaporama `cm/<module>.typ`, page de cours, TP et artefacts
que l’index nomme dans `existant`) ; un support prévu (`a-faire`) s’affiche « à venir ». Tout se lit dans
`progression.yaml` ; `construire-site.sh` passe la liste des fichiers présents (`--input existants=…`), pour ne
poser aucun lien mort. Dans une page, `module-de(index, id)` rend le numéro, le titre, le précédent et le suivant
d’un module ; `nom-module(index, id)` l’écrit. Exemple : `shell/index.typ`.

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
- `<nom>.js` : construit l’interface dans l’élément `#artefact`, sans bibliothèque externe. Il garde son simulateur,
  son interface et la déclaration de ses recettes ; le reste vient de `commun/artefact.js` (voir ci-dessous).
- `<nom>.css` : n’emploie que les variables CSS de la charte (`--c-*`, `--<rôle>-entete`…), pour suivre la variante choisie.
  Les sections, les boutons et les recettes sont déjà mis en forme par `commun/artefact.css`.
- Un état se lit dans le texte (« CACHED », « DONE ») ; la couleur ne fait que le doubler.

### Le moteur de recettes (`commun/artefact.js`)
`artefact(…)` embarque `artefact.css` et `artefact.js` avant le script de l’artefact, qui y prend `Artefact` :
`const { el, bouton, recettes } = Artefact;`. `el(balise, attributs, ...enfants)` crée un élément (`onclick` : un
écouteur ; `false` ou `null` : rien) ; `bouton(texte, action, attributs)` crée un bouton.
`recettes({…})` fait le reste : cartes des expériences, étapes, commandes du lecteur (continuer, pause au milieu
d’une étape, reprise, revenir, enchaînement sans pause, rejouer, reprise en main). L’artefact lui donne :
- `recettes` : `{ nom: [[titre, action], …] }`. `nom` est le troisième élément d’une expérience ; `titre` dit
  l’action (« Reconstruire. »), jamais son résultat ; `action` est une fonction `async` qui agit sur la simulation
  et rend le tableau de phrases qui expliquent ce qu’elle vient de faire, calculées à partir du résultat.
- `depart` (phrases affichées avant la première étape), `titreLibre` (titre de l’explication quand le lecteur a
  repris la main, « Votre build ») et `pause` (`() → ms`, le temps de lecture entre deux étapes qui s’enchaînent).
- `remettre()` : remet la simulation à son départ ; `capturer()` : son état complet, pour y revenir
  (`structuredClone`) ; `retablir(état)` : le rétablit, l’affiche et abandonne l’étape en cours d’exécution ;
  `afficher()` : redessine les commandes, qui se bloquent pendant une recette (`moteur.fige()`).

Il rend `moteur` : `fige()` (une recette n’est pas finie : le lecteur regarde), `libre(phrases)` (le lecteur a
modifié quelque chose à la fin d’une recette : ces phrases l’expliquent), `fermer()`, et `attendre(ms, suivi)`
(une attente que la pause d’une recette gèle ; `suivi(écoulé)` rend vrai pour l’interrompre). Une étape qui dure
dans le temps attend par `moteur.attendre`, jamais par `setTimeout` seul.

## Pages web : terminal
Une page déclare son terminal : `page-web(…, terminal: ("host-shell-access",))` pour un TP Docker ou libvirt, qui ne
tourne pas dans une VM de navigateur ; `terminal: ("vm", "host-shell-access")` pour un TP shell (le premier mode est
proposé d’abord). Une page qui ne déclare rien reste telle quelle. Les sources des TP ne changent pas : `tp.js`
pose un bouton « Exécuter » après chaque commande `$ ` (suites `\` comprises) des blocs `terminal[…]`, actif
quand un terminal est ouvert ; un bouton « Terminal » du bandeau ouvre un volet en bas de la fenêtre, dont la page
réserve la hauteur. Sur une page de cours, le terminal est dans la colonne de droite (voir « Pages web : pages de
cours »).
- Mode `vm` : une VM Alpine Linux x86 dans l’onglet (v86), sans réseau ni installation. L’image se télécharge
  au clic sur « Démarrer la VM », avec sa progression, puis se range dans Cache Storage, sous une clé qui porte
  sa version (`cours-terminal-vm-<version>`) : une visite suivante ne télécharge rien.
  Le shell est celui du compte ordinaire `ada` (uid 1000, groupes `ada` et `etudiants`, umask 002 : comme dans les
  corrigés Debian des TP), pas celui de root. L’image a Bash, coreutils, findutils, grep, sed, gawk, git, vim et
  vimtutor, nano, tmux, jq, tree, `procps-ng` (le `ps` complet), `bats`, et `man` (mandoc, avec les pages de
  coreutils, Bash, less, grep et tmux : 0,4 Mo compressés). Elle n’a ni `shellcheck` (introuvable pour Alpine x86),
  ni Python, `yq`, Docker, SSH : un TP qui en demande déclare `("host-shell-access",)`, ou dit à l’endroit voulu que
  l’étape demande `host-shell-access`. Ses fichiers sont en mémoire : la taille d’un dossier dans `ls -l` n’est pas celle d’un disque.
- **État de départ.** Une page (TP ou page de cours) qui déclare le mode `vm` déclare aussi l’état que ses
  commandes supposent : `page-web(depart: (script: "shell/tp/premiers-pas/preparer.sh", cree: "~/atelier", ici: "~"))`.
  `script` (chemin depuis la racine du dépôt) est un script versionné, dans le dossier d’une page, hors de `corrige/`,
  qui crée dossiers, fichiers et contenus ; `ici` est le répertoire d’arrivée ; `(ici: "~")` seul : rien à créer.
  `construire-vm.sh` embarque, de chaque TP et de chaque page de cours dont la source déclare `"vm"`, ses fichiers
  hors `corrige/`, `tester.sh`, `*.typ` et `index.html`, sous `/usr/share/cours/Cours-main/<chemin du dépôt>/`.
  La page passe `depart=` et `ici=` au noyau ; `vm/init` lance le script sous le compte `ada`, puis ouvre le shell
  dans `ici` : l’état est en place avant la première invite, sans rien demander à l’étudiant. Le bouton
  « Remettre à l’état de départ » redémarre la VM : son système, en mémoire, repart de l’image, et le script se
  relance. Quand le shell se termine (`exit`, Ctrl+D sur une ligne vide), la VM affiche « Session terminée ; nouvelle
  session. » et en ouvre un autre dans le répertoire personnel ; les fichiers restent. Les commandes qui installent l’état chez soi vont dans `terminal(host-shell-access: true)` : la VM ne les
  exécute pas (son « Exécuter » le dit) et `tester-vm.mjs` ne les rejoue pas. Sans réseau, le `wget` et le `curl`
  de la VM (`vm/telecharger`) servent encore ces fichiers aux adresses du site et de l’archive du dépôt.
- Mode `host-shell-access` : le vrai shell de l’étudiant, par l’exécutable `host-shell-access` (`terminal/host-shell-access/`, en Go),
  qui écoute sur `127.0.0.1` avec un jeton à usage unique, une liste d’origines et un seul client ; il est construit
  pour Linux seulement (amd64, arm64 ; WSL sous Windows). Rien n’y est installé d’office : le volet propose la
  commande qui installe l’état de départ de la page (`cd && curl -fsSLO … && bash …`, qui crée un dossier à part,
  `cree`), et le bouton « Installer l’état de départ » la lance après confirmation. La page
  [`terminal/host-shell-access/host-shell-access.typ`](terminal/host-shell-access/host-shell-access.typ) (publiée en `commun/terminal/`) explique son téléchargement.

Fichiers de `terminal/` :
- `terminal.js`, `terminal.css` : le volet, ajoutés par `theme-tp.typ` aux seules pages qui le déclarent ; le
  style n’emploie que les variables de la charte, et xterm.js reçoit ses couleurs de `--c-nuit`, `--c-texte-term`…
  `terminal.js` signale `terminal-commande` (une commande cliquée part), `terminal-session` et `terminal-contexte`.
- `contexte.js`, `contexte.css` : le repère de contexte des pages de cours ; `vm/contexte.bash` : sa description par
  la VM. Le modèle (lecture d’un chemin, `cd`, contexte déclaré) est entre `// <modele>` et `// </modele>` :
  `tester-vm.mjs` le reprend.
- `dependances.txt` : version, SHA-256 et adresse de chaque fichier tiers ; `preparer.sh [--vm]` les télécharge
  dans `vendor/` et, avec `--vm`, construit l’image (`construire-vm.sh`, Docker ; `vm/init`, `vm/profil.sh`) et son
  manifeste `vendor/vm/manifeste.json`.
- `host-shell-access/` : le code Go (`go.mod`, `go.sum`), `construire.sh` (exécutables statiques Linux, amd64 et
  arm64, et `SHA256SUMS`, dans `host-shell-access/dist/`), `tester.py` (protocole et refus).
- `LICENCES.md` : licences et sources des composants publiés.

`vendor/` et `host-shell-access/dist/` ne sont pas versionnés : la CI les construit et les publie avec le site.
`construire-site.sh` (à la racine de `commun/`) enchaîne `preparer.sh --vm`, `tester-vm.mjs`, `host-shell-access/construire.sh` et
`host-shell-access/tester.py`, puis compile les PDF et les pages web : c’est la construction de la CI. Sous `apercu/` (aperçu
d’une branche, voir `README.md`), la page vient du même site `https://jmchantrein.github.io` : `host-shell-access` l’admet,
et `racine` suffit pour retrouver `commun/terminal/vendor/`. `APERCU_BRANCHE` ajoute au bandeau des pages web
« Aperçu de la branche … » (entrée Typst `apercu`, lue par `page-web`).
Tester, depuis la racine du dépôt, après `preparer.sh --vm` et `host-shell-access/construire.sh` :

    node commun/terminal/tester-vm.mjs               # démarre la VM dans Node, vérifie ses outils, puis rejoue
                                                     # chaque TP et page de cours en mode vm, dans une VM neuve démarrée
                                                     # sur son état de départ (fichiers attendus, commandes de l’énoncé) ;
                                                     # une page de cours : chaque sortie, le repère déclaré contre le
                                                     # réel, et seule chaque section qui part de l’état de départ
    python3 -I commun/terminal/host-shell-access/tester.py   # protocole, jeton, origine, un seul client
    node commun/terminal/tester-navigateur.js        # Chromium : clics, deux modes, cache, refus, captures

`tester-navigateur.js` compile les pages testées, dont une page d’essai du mode VM (`build/essai-terminal/`), et
les sert sur `localhost:8000`, origine que `host-shell-access` admet pour les essais.

Limite connue : l’export HTML de Typst est expérimental. La CI fixe la version de Typst ; à chaque montée de
version, recompiler les pages et les relire dans un navigateur.
