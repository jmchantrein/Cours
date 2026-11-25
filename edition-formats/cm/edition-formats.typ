// Cours « Éditer et structurer du texte » (Vim, Markdown, YAML et JSON) — Typst + Touying.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts edition-formats/cm/edition-formats.typ build/edition-formats/edition-formats.pdf
// Une diapo = un titre `==` ; une section (surtitre bleu) = un titre `=`.
// Structure : règles de .claude/skills/structurer-diapos-cours ; apparence : charte de commun/.
// Sorties des terminaux : edition-formats/cm/rejouer.sh les rejoue et relève les versions.

#import "../../commun/theme-cours.typ": *

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Éditer et structurer du texte],
)

// ---------- Composant propre à ce cours ----------
// Rendu d’un document Markdown, tel qu’un visualiseur l’afficherait.
#let rendu(titre: [Rendu], hauteur: auto, corps) = block(width: 100%, height: hauteur,
  fill: c.fond, stroke: px(2) + c.filet, radius: px(12), clip: true, stack(
    if titre != none { block(width: 100%, fill: c.filet, inset: (x: px(18), y: px(6)),
      text(size: px(20), weight: 600, fill: c.ardoise, titre)) },
    block(width: 100%, inset: (x: px(18), y: px(12)), { set text(size: px(22)); set par(spacing: px(14)); corps }),
  ))

#couverture(illustration: "texte")[Éditer et structurer du texte][Vim, Markdown, YAML et JSON : l’administrateur travaille en texte brut][Jean-Mathieu Chantrein][25 novembre 2026]
#speaker-note[Le cours réunit trois outils qui ont un point commun : le texte brut. Un serveur se configure par des fichiers texte (Vim les édite), se documente par des fichiers texte (Markdown), et se décrit par des données en texte (YAML, JSON).]

// ======================================================================
= Sommaire

== Plan du cours

#anime(plan-anime(
  ([Vim : éditer sans interface graphique], [Les modes, la grammaire opérateur + mouvement, rechercher et remplacer, `~/.vimrc`]),
  ([Markdown : documenter en texte brut], [La syntaxe et son rendu, les extensions, convertir avec pandoc]),
  ([YAML et JSON : structurer des données], [Une même structure, le typage implicite et ses pièges, valider, interroger avec jq et yq]),
), note: [Trois parties, un exercice fait en séance à la fin de chacune. Fil rouge : le fichier config.yaml d’une application, édité avec Vim (partie 1), documenté par un README en Markdown (partie 2), lu, converti et validé (partie 3).])

// ======================================================================
= Introduction

== Un serveur s’administre en texte brut <texte-brut>

#anime(
  rang(
    bloc(taille: px(25))[Sur un serveur, tout est texte][
      - *Configuration* : des fichiers texte sous `/etc` (`/etc/ssh/sshd_config`, `/etc/fstab`…)
      - *Documentation* : un `README.md` à côté du code et des scripts
      - *Données* : YAML pour ce qu’un humain écrit (Compose, Ansible, Kubernetes), JSON pour ce que les programmes échangent (interfaces de programmation ou API web, `ip -json`)
      - Les mêmes outils pour tout : un éditeur, `grep`, `diff`, Git
    ],
    bloc(role: "pratique", poids: 0.9, taille: px(24))[Fil rouge : MonApplication sur le serveur web01][
      #fichier([/srv/monapp/config.yaml])[```
      ---
      application:
        nom: MonApplication
        version: 1.2.3
        environnements:
          production:
            url: https://prod.example.org
          developpement:
            url: http://dev.example.org
      ```]
      - On l’*édite* avec Vim, on la *documente* en Markdown, on la *lit et la valide* comme donnée YAML et JSON
    ],
  ),
  note: [Le fil rouge reprend le config.yaml du cours d’origine (yaml_et_json), avec des domaines réservés à la documentation (example.org, RFC 2606) à la place des domaines fictifs d’origine. ip -json (ip -j) : sortie JSON d’iproute2, citée ici comme exemple sans sortie.],
)

// ======================================================================
= Vim · éditer sans interface graphique

== Sur le serveur, l’éditeur vit dans le terminal

#anime(
  rang(
    bloc(taille: px(25))[Pourquoi Vim][
      - La plupart des serveurs n’ont pas d’interface graphique : on les administre à distance, par SSH (_Secure Shell_), dans un terminal
      - `vi` fait partie de la norme POSIX (_Portable Operating System Interface_) : on le trouve sur presque tous les Unix ; Vim (_Vi IMproved_) en est la version moderne
      - Léger, rapide même à travers une connexion lente, et tout au clavier
    ],
    bloc(role: "pratique", poids: 1.05)[Éditer la configuration de web01][
      #terminal(titre: none, taille: px(21))[
        ```
        # sur le poste : ouvrir une session sur web01
        $ ssh admin@web01
        ```
        #cadre([web01 (session SSH)], niveau: "distant")[
          ```
          # sur web01 : ouvrir le fichier dans Vim
          $ vim /srv/monapp/config.yaml
          ```
        ]
      ]
    ],
  ),
  rang(bloc(role: "precaution", taille: px(24))[Limites][
    - Courbe d’apprentissage abrupte : les premières heures sont lentes
    - Pas toujours là : l’image `debian:13` d’un conteneur n’a ni `vi`, ni `nano`, ni `vim` ; installez le paquet `vim` pour la version complète
  ]),
  source-de: [#link("https://pubs.opengroup.org/onlinepubs/9699919799/utilities/vi.html")[POSIX, vi] · #link("https://www.vim.org/")[vim.org]],
  note: [Vi : Bill Joy, 1976 ; Vim : Bram Moolenaar, 1991, maintenu par la communauté depuis 2023. Le cadre en trait mixte est la session ouverte sur web01 par la commande ssh au-dessus (l’accès distant est le sujet du cours Accès distants). Le conteneur sans éditeur : docker container run --rm debian:13 sh -c "command -v vi nano vim || echo aucun éditeur" répond « aucun éditeur » (rejouer.sh). Sur Debian, la commande vi est souvent fournie par vim-tiny, version réduite (ni coloration, ni vimtutor) : à vérifier sur une installation Debian 13 minimale ; sur Ubuntu 24.04, vim-tiny est de priorité « important », vim « optional ». Nano est l’éditeur par défaut (commande editor) de Debian et d’Ubuntu.],
)

== Les modes de Vim et leurs transitions <vim-modes>

#let noeud(x, y, l, h, nom, detail, sombre: false) = pose(x, y, block(width: px(l), height: px(h),
  fill: if sombre { c.nuit } else { c.appli }, stroke: px(3) + c.bleu, radius: px(14),
  align(center + horizon, stack(spacing: px(10),
    text(size: px(32), weight: 600, fill: if sombre { c.fond } else { c.encre }, nom),
    text(size: px(22), fill: if sombre { c.texte-term } else { c.ardoise }, detail)))))
#let etiquette(x, y, l, corps, cote: center) = pose(x, y, block(width: px(l), align(cote, text(size: px(26), corps))))

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  canevas(512, {
    uncover("1-", noeud(622, 180, 420, 140, [Normal], [naviguer, supprimer, copier], sombre: true))
    uncover("2-", {
      noeud(0, 180, 380, 140, [Insertion], [écrire du texte])
      fleche-pose(622, 222, 380, 222)
      etiquette(380, 172, 242, [#touche[i] #touche[a] #touche[o]])
      fleche-pose(380, 280, 622, 280)
      etiquette(380, 290, 242, [#touche[Échap]])
    })
    uncover("3-", {
      noeud(1284, 180, 380, 140, [Ligne de commande], [`:w`, `:q`, `:s`, `/motif`])
      fleche-pose(1042, 222, 1284, 222)
      etiquette(1042, 172, 242, [#touche[:] #touche[/]])
      fleche-pose(1284, 280, 1042, 280)
      etiquette(1042, 290, 242, [#touche[Entrée] #touche[Échap]])
    })
    uncover("4-", {
      noeud(622, 400, 420, 120, [Visuel], [sélectionner, puis agir])
      fleche-pose(780, 320, 780, 400)
      etiquette(330, 340, 430, [#touche[v] #touche[V] #touche[Ctrl+v]], cote: right)
      fleche-pose(884, 400, 884, 320)
      etiquette(904, 340, 300, [#touche[Échap]], cote: left)
    })
    uncover("5-", {
      noeud(622, 0, 420, 100, [Remplacement], [écrire par-dessus])
      fleche-pose(780, 180, 780, 100)
      etiquette(330, 120, 430, [#touche[R]], cote: right)
      fleche-pose(884, 100, 884, 180)
      etiquette(904, 120, 300, [#touche[Échap]], cote: left)
    })
  })
  v(px(20))
  uncover("6-", encadre(role: "retenir", libelle: [Perdu ?], taille: px(26))[#touche[Échap] ramène au mode normal. Une touche agit selon le mode : `dd` écrit « dd » en insertion, supprime la ligne en mode normal.])
  source[#link("https://vimhelp.org/intro.txt.html#vim-modes")[Vim, `:help vim-modes`]]
  utils.speaker-note(self: self)[Un mode par clic, avec les touches qui y mènent et celle qui en revient. Vim démarre en mode normal. i insère avant le curseur, a après, o ouvre une ligne en dessous. : ouvre la ligne de commande (commandes Ex), / une recherche ; Entrée exécute, Échap abandonne. v sélectionne par caractères, V par lignes, Ctrl+v par colonnes (bloc). R est une variante du mode insertion : chaque caractère tapé remplace celui du dessous. Le manuel (:help vim-modes) compte sept modes de base (normal, visuel, sélection, insertion, ligne de commande, Ex, terminal) et sept variantes, dont le remplacement ; sélection, Ex et terminal sortent du cadre du cours. Le manuel conseille Échap deux fois si l’on ne sait plus où l’on est. Vim affiche le mode en bas de l’écran (-- INSERTION --, -- VISUEL --) quand l’option showmode est active (par défaut).]
})

== Survivre : écrire, enregistrer, quitter <vim-survivre>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[Créer un fichier, de bout en bout][
      #terminal(titre: none, taille: px(22))[
        ```
        $ vim bonjour.txt
        # dans Vim : i, Hello World !, Échap, :wq, Entrée
        $ cat bonjour.txt
        Hello World !
        ```
      ]
      + #touche[i] : passer en insertion, puis taper le texte
      + #touche[Échap] : revenir en mode normal
      + #touche[:]`wq` #touche[Entrée] : enregistrer (_write_) et quitter (_quit_)
    ],
    bloc[La ligne de commande][
      - `:w` : enregistrer, sans quitter
      - `:q` : quitter ; refusé si le fichier a changé depuis le dernier enregistrement
      - `:wq` : enregistrer et quitter
      - `:q!` : quitter *sans* enregistrer : les modifications sont perdues
      - `u` : annuler (_undo_) ; #touche[Ctrl+r] : rétablir
    ],
  ),
  rang(bloc(role: "precaution", taille: px(24))[`:q` sur un fichier modifié][
    - Vim répond : `E37: Modifications non enregistrées (ajoutez ! pour passer outre)`. Il protège le travail : `:w` pour garder, `:q!` pour jeter
  ]),
  source-de: link("https://vimhelp.org/editing.txt.html#write-quit")[Vim, `:help write-quit`],
  note: [La séquence de touches a été jouée dans Vim (vim -s, sans configuration) : le fichier contient « Hello World ! ». Message E37 en français (LANG=fr\_FR.UTF-8), Vim 9.1.0016 (Ubuntu 24.04, faute d’accès aux miroirs Debian ici) : à rejouer sur Debian 13 avec rejouer.sh. ZZ (mode normal) équivaut à :x, qui n’enregistre que si le fichier a changé.],
)

== Se déplacer en mode normal <vim-deplacer>

#anime(
  rang(
    bloc(taille: px(25))[Dans la ligne et d’une ligne à l’autre][
      - #touche[h] #touche[j] #touche[k] #touche[l] : gauche, bas, haut, droite (les flèches marchent aussi)
      - #touche[w] #touche[b] #touche[e] : mot suivant, mot précédent, fin du mot
      - #touche[0] #touche[^] #touche[\$] : début de ligne, premier caractère non blanc, fin de ligne
      - #touche[gg] #touche[G] : première, dernière ligne ; `12G` : ligne 12
    ],
    bloc(taille: px(25))[Par le contenu][
      - `/motif` #touche[Entrée] : chercher vers le bas ; `?motif` : vers le haut
      - #touche[n] #touche[N] : occurrence suivante, précédente
      - #touche[%] : la parenthèse, le crochet ou l’accolade qui correspond
      - #touche[f]`x` : jusqu’au prochain « x » de la ligne
    ],
  ),
  rang(bloc(role: "precaution", taille: px(24))[Mot (`w`) ou MOT (`W`)][
    - Un _mot_ s’arrête à la ponctuation : dans `1.2.3`, `w` voit cinq mots. Un _MOT_ (#touche[W] #touche[B] #touche[E]) ne s’arrête qu’aux espaces
  ]),
  source-de: link("https://vimhelp.org/motion.txt.html")[Vim, `:help motion.txt`],
  note: [hjkl : la rangée du milieu du clavier, sous les doigts (motion.txt : « Think of j as an arrow pointing downwards »). Chacune de ces touches est un mouvement : c’est elle qui donnera sa portée à un opérateur, diapositive suivante. La différence mot / MOT est démontrée sur config.yaml deux diapositives plus loin.],
)

== Opérateur + mouvement : la grammaire de Vim <vim-grammaire>

#anime(
  rang(bloc(role: "retenir", taille: px(30))[La règle][
    - [compteur] *opérateur* [compteur] *mouvement* : l’opérateur agit sur le texte que le mouvement parcourt
  ]),
  rang(
    bloc(taille: px(25))[Opérateurs][
      - #touche[d] supprimer (_delete_) · #touche[y] copier (_yank_)
      - #touche[c] changer : supprimer, puis passer en insertion
      - #touche[>] #touche[<] décaler à droite, à gauche
    ],
    bloc(taille: px(25))[Mouvements][
      - Tous ceux de la diapositive précédente : `w`, `W`, `$`, `0`, `j`, `G`, `gg`, `/motif`…
      - Après un opérateur, Vim attend le mouvement (mode « opérateur en attente »)
    ],
    bloc(role: "pratique", taille: px(25))[Combinaisons][
      - `dw` supprime jusqu’au mot suivant ; `d$` jusqu’à la fin de ligne
      - Opérateur doublé = la ligne : `dd`, `yy`, `cc` ; `3dd` : trois lignes
      - `2d3w` : six mots ; #touche[.] répète la dernière modification
    ],
  ),
  source-de: link("https://vimhelp.org/motion.txt.html#operator")[Vim, `:help operator`],
  note: [Un clic pour la règle, puis bloc par bloc et ligne par ligne. Apprendre Vim, c’est apprendre cette petite grammaire, pas une liste de raccourcis : n opérateurs et m mouvements donnent n × m commandes. motion.txt, section operator : « When doubling the operator it operates on a line » et « 2d3w deletes six words » (les compteurs se multiplient). p colle (_put_) après le curseur, P avant. Autres opérateurs : gU (majuscules), = (réindenter), gq (formater). Le mode « opérateur en attente » (_Operator-pending_) est une des variantes listées par :help vim-modes.],
)

== La grammaire à l’œuvre sur config.yaml <vim-grammaire-config>

#let essai(t, e, r) = (text(font: mono, size: px(25), t), text(size: px(25), e), text(font: mono, size: px(24), r))
#anime(
  pas(7, (u, d) => {
    let ls = (
      essai([`/1.2.3` #touche[Entrée] `cW2.0.0` #touche[Échap]], [change le MOT sous le curseur], [  version: 2.0.0]),
      essai([`/1.2.3` #touche[Entrée] `cw2.0.0` #touche[Échap]], [`w` s’arrête au point : seul « 1 » change], [  version: 2.0.0.2.3]),
      essai([`/nom` #touche[Entrée] `yyp`], [copie la ligne, la colle en dessous], [  nom: MonApplication (deux fois)]),
      essai([`/environ` #touche[Entrée] `d2j`], [supprime cette ligne et les deux suivantes], [environnements et production disparaissent]),
      essai([`/production` #touche[Entrée] `dG`], [supprime jusqu’à la fin du fichier], [il reste les quatre premières lignes]),
      essai([`/version` #touche[Entrée] `dd` `.`], [supprime une ligne, puis répète], [version et environnements disparaissent]),
      essai([`jdd` `u` #touche[Ctrl+r]], [supprime, annule, rétablit], [la ligne application: est supprimée]),
    )
    grid(columns: (px(560), px(560), 1fr), align: horizon,
      inset: (x, y) => (y: px(11), left: if x > 0 { px(24) } else { 0pt }),
      stroke: (x, y) => if y < ls.len() { (bottom: px(1) + c.filet) },
      ..([Touches], [Effet], [Résultat]).map(t => text(size: px(22), weight: 600, fill: c.bleu, t)),
      ..ls.enumerate().map(((i, l)) => l.map(x => u(str(d + i) + "-", x))).flatten())
  }),
  note: [Chaque ligne part du config.yaml d’origine (avec la ligne --- en tête), le curseur en début de fichier. Toutes les séquences ont été jouées dans Vim sans configuration (vim -u NONE -s fichier-de-touches) et les résultats relevés dans le fichier (rejouer.sh, Vim 9.1.0016 ; à rejouer sur Debian 13). Après /1.2.3, le curseur est sur le « 1 » ; c’est un mot de Vim, distinct du « . » qui suit. Note : dans /1.2.3, le point est un métacaractère de l’expression régulière (n’importe quel caractère) : il trouve aussi « 1x2y3 ».],
)

== Rechercher et remplacer : `:s` <vim-substituer>

#anime(
  rang(
    bloc(taille: px(25))[La commande][
      - `:`[plage]`s/motif/remplacement/`[drapeaux]
      - Plage : rien = la ligne du curseur ; `%` = tout le fichier ; `8,9` = lignes 8 à 9
      - Drapeaux : `g` = toutes les occurrences de chaque ligne, sinon la première seulement ; `c` = demander confirmation
      - Même syntaxe que `sed` (cours _Shell_)
    ],
    bloc(role: "pratique", poids: 1.05, taille: px(24))[Sur config.yaml][
      #terminal(titre: none, taille: px(20))[
        ```
        # sans g : la première occurrence de chaque ligne
        :%s/o/0/
        applicati0n:
          n0m: MonApplication
        # avec g : toutes les occurrences
        :%s/o/0/g
        applicati0n:
          n0m: M0nApplicati0n
        # changer de domaine partout
        :%s/example.org/example.net/g
              url: https://prod.example.net
              url: http://dev.example.net
        ```
      ]
    ],
  ),
  rang(bloc(role: "precaution", taille: px(24))[Le motif est une expression régulière][
    - Le `.` y vaut n’importe quel caractère : `example.org` trouve aussi « exampleXorg ». Pour un point littéral : `example\.org`
  ]),
  source-de: link("https://vimhelp.org/change.txt.html#:substitute")[Vim, `:help :substitute`],
  note: [Les lignes qui suivent chaque commande sont le début du fichier obtenu (relevé après :wq ; Vim 9.1.0016, à rejouer sur Debian 13). Ce terminal montre la ligne de commande de Vim (« : »), pas celle du shell. Avec le drapeau c, Vim demande pour chaque occurrence : y (oui), n (non), a (toutes), q (quitter). & répète la dernière substitution sur la ligne courante.],
)

== Les modes visuels : commenter un bloc <vim-visuel>

#anime(
  rang(
    bloc(taille: px(25))[Sélectionner, puis agir][
      - #touche[v] par caractères · #touche[V] par lignes · #touche[Ctrl+v] par colonnes (bloc)
      - On étend la sélection avec les mouvements (`j`, `$`, `G`…)
      - Puis un opérateur : `y`, `d`, `c`, `>`
      - En bloc : #touche[I] insère le même texte au début de chaque ligne
    ],
    bloc(role: "pratique", poids: 1.15, taille: px(24))[Mettre l’environnement de développement en commentaire][
      Touches : `/developpement` #touche[Entrée] #touche[Ctrl+v] #touche[j] #touche[I] `# ` #touche[Échap]
      #fichier([config.yaml, après], taille: px(20))[```
      ---
      application:
        nom: MonApplication
        version: 1.2.3
        environnements:
          production:
            url: https://prod.example.org
          # developpement:
          #   url: http://dev.example.org
      ```]
    ],
  ),
  source-de: link("https://vimhelp.org/visual.txt.html#v_b_I")[Vim, `:help v_b_I`],
  note: [Le geste d’administrateur par excellence : commenter plusieurs lignes d’un coup, puis les décommenter (Ctrl+v, sélection des deux colonnes « \# », d). Le texte tapé après I n’apparaît que sur la première ligne pendant la frappe ; il est recopié sur toutes les lignes du bloc à l’appui sur Échap. Le fichier « après » est le résultat réel de la séquence (vim -s). Le \# étant inséré dans la colonne du curseur, l’indentation est conservée : le fichier reste un YAML valide, et yq n’y lit plus que l’environnement de production (partie 3).],
)

== Configurer Vim : `~/.vimrc` <vimrc>

#anime(
  rang(
    bloc(poids: 1.1, taille: px(24))[Le fichier de configuration][
      #fichier([~/.vimrc])[```
      " les commentaires commencent par un guillemet
      set number
      set autoindent
      set tabstop=4
      syntax on
      filetype plugin indent on
      ```]
      - Lu à chaque démarrage de Vim : numéros de ligne, indentation automatique, tabulation de 4 colonnes, coloration syntaxique
    ],
    bloc(role: "pratique", taille: px(24))[Vérifier une option][
      #terminal(titre: none, taille: px(21))[
        ```
        # dans Vim, sur config.yaml
        :set tabstop? shiftwidth? expandtab?
          tabstop=4  shiftwidth=2  expandtab
        ```
      ]
      - `filetype plugin indent on` charge les réglages du type de fichier : pour un YAML, indentation de 2 et espaces à la place des tabulations (`expandtab`)
      - Le YAML interdit les tabulations (partie 3)
    ],
  ),
  source-de: link("https://vimhelp.org/starting.txt.html#vimrc")[Vim, `:help vimrc`],
  note: [Sortie réelle de :set sur config.yaml avec ce .vimrc (Vim 9.1.0016, à rejouer sur Debian 13). Les réglages YAML viennent du greffon de type de fichier livré avec Vim (ftplugin/yaml.vim : expandtab, shiftwidth=2, softtabstop=2). Le cours d’origine donne tabstop=2 sur la diapositive et 4 dans l’exercice : la diapositive suit l’exercice. Sans ~/.vimrc, Vim charge defaults.vim, qui active déjà la coloration et les types de fichier ; dès qu’un ~/.vimrc existe, defaults.vim n’est plus chargé, d’où les deux dernières lignes.],
)

== À vous : votre `~/.vimrc` <vim-exercice>

#anime(
  rang(bloc(role: "question")[À vous][
    + Avec Vim, créez `~/.vimrc` contenant deux lignes : `set number` et `set tabstop=4`
    + Enregistrez et quittez
    + Rouvrez le fichier : que voyez-vous de nouveau ?
    + Remplacez le 4 par un 2 avec la touche #touche[r], sans passer en mode insertion, puis enregistrez et quittez
    + Comment vérifier, dans Vim, la valeur de `tabstop` ?
  ]),
  note: [Exercice du cours d’origine, fait en séance. Une question par clic ; laisser chercher avant le corrigé. Rappel : r remplace un seul caractère, R entre en mode remplacement.],
)

== À vous : corrigé

#corriges(note: [Séquences jouées dans Vim (vim -s) : le fichier obtenu contient bien set number puis set tabstop=4, puis set tabstop=2 après la seconde séquence (rejouer.sh, Vim 9.1.0016 ; à rejouer sur Debian 13). Question 3 : la configuration est lue au démarrage, d’où les numéros de ligne dès la réouverture. Question 5 : :set tabstop? affiche la valeur ; :set tabstop (sans ?) ne marcherait pas pour une option numérique.],
  ("1-2", [Créez `~/.vimrc` (`set number`, `set tabstop=4`), enregistrez et quittez],
    reponse(terminal(titre: none, taille: px(20))[```
    $ vim ~/.vimrc
    # i, set number, Entrée, set tabstop=4, Échap, :wq, Entrée
    $ cat ~/.vimrc
    set number
    set tabstop=4
    ```])),
  (3, [Rouvrez le fichier : que voyez-vous de nouveau ?],
    reponse[Les numéros de ligne : `~/.vimrc` est lu au démarrage, `set number` s’applique déjà.]),
  (4, [Remplacez le 4 par un 2 avec #touche[r]],
    reponse(terminal(titre: none, taille: px(20))[```
    $ vim ~/.vimrc
    # /4, Entrée : le curseur est sur le 4 ; r2 ; :wq, Entrée
    $ cat ~/.vimrc
    set number
    set tabstop=2
    ```])),
  (5, [Vérifier la valeur de `tabstop` dans Vim],
    reponse[`:set tabstop?` affiche `tabstop=2`.]),
)

== S’entraîner, chaque jour <vim-entrainer>

#anime(
  rang(
    bloc(role: "pratique", taille: px(26))[Le tutoriel intégré][
      - `vimtutor` (en français : `vimtutor fr`) : une demi-heure, dans Vim, sur un fichier qu’on modifie en suivant ses consignes
      - Le refaire jusqu’à ce qu’aucune étape ne ralentisse, puis se servir de Vim tous les jours
    ],
    bloc(taille: px(26))[Pour aller plus loin][
      - `:help`, et `:help` suivi d’une commande : `:help dd`
      - #link("https://www.openvim.com")[openvim.com] (simulateur), #link("https://vim-adventures.com")[vim-adventures.com] (jeu)
      - Beaucoup d’éditeurs graphiques ont un « mode Vim »
    ],
  ),
  rang(bloc(role: "retenir", taille: px(26))[À retenir][
    - Des modes : #touche[Échap] ramène au mode normal. Une grammaire : opérateur + mouvement. `:wq` enregistre et quitte, `:q!` jette
  ]),
  note: [vimtutor est fourni avec la version complète de Vim (tutoriels de /usr/share/vim/vim91/tutor, dont tutor.fr). Le cours d’origine conclut : « Ne pas basculer dans le côté obscur et ne pas se servir d’emacs ;-) ». Une fois les bases acquises, les greffons (plugins) étendent Vim ; Neovim en est un dérivé moderne.],
)

// ======================================================================
= Markdown · documenter en texte brut

== Markdown : un README lisible brut et rendu

#anime(
  rang(
    bloc(taille: px(25))[Un langage de balisage léger][
      - _Baliser_ un texte : y ajouter des marques qui décrivent sa structure. En HTML (_HyperText Markup Language_) : `<h1>Titre</h1>` ; en Markdown : `# Titre`
      - Léger : les marques restent lisibles dans le fichier brut, avec `cat` sur le serveur
      - Créé par John Gruber (2004) ; normalisé par CommonMark ; GitHub et GitLab y ajoutent des extensions (GFM, _GitHub Flavored Markdown_)
    ],
    bloc(role: "pratique", taille: px(25))[Pourquoi pour un administrateur][
      - Le `README.md` d’un dépôt : rendu par GitHub ou GitLab, lu tel quel dans un terminal
      - Du texte brut : se versionne avec Git, se cherche avec `grep`, s’édite avec Vim
      - Se convertit en HTML, PDF, ODT… avec pandoc
    ],
  ),
  rang(bloc(role: "precaution", taille: px(24))[Le rendu dépend du destinataire][
    - Markdown fixe la *structure*, pas l’apparence : GitHub, pandoc et un forum rendent le même fichier un peu différemment
  ]),
  source-de: [#link("https://daringfireball.net/projects/markdown/")[J. Gruber, Markdown] · #link("https://spec.commonmark.org/0.31.2/")[CommonMark 0.31.2] · #link("https://github.github.com/gfm/")[GFM]],
  note: [Fil rouge : MonApplication a un README.md, à côté de config.yaml. Le cours d’origine renvoie au dépôt de l’auteur « Présentation du langage Markdown (rédigé en Markdown) » ; les deux diapositives suivantes en reprennent la syntaxe, source à gauche, rendu à droite. CommonMark lève les ambiguïtés de la description d’origine de Gruber ; GFM est CommonMark plus des extensions (tableaux, cases à cocher, texte barré, liens automatiques).],
)

== Titres, paragraphes, emphase, listes <markdown-syntaxe>

#anime(
  rang(
    bloc(role: "pratique", taille: px(24))[Source : README.md][
      #fichier(none, taille: px(20))[```
      # MonApplication

      Une application web, déployée sur **web01**.
      Ce *README* explique comment l’installer.

      ## Installation

      1. Cloner le dépôt
      2. Lancer l’installation
         - sur Debian 13
         - avec les droits root
      ```]
    ],
    bloc(taille: px(24))[Rendu][
      #rendu(titre: none)[
        #text(size: px(38), weight: 600)[MonApplication]

        Une application web, déployée sur *web01*. Ce _README_ explique comment l’installer.

        #text(size: px(30), weight: 600)[Installation]

        #enum[Cloner le dépôt][Lancer l’installation #list[sur Debian 13][avec les droits root]]
      ]
    ],
  ),
  rang(bloc(taille: px(22))[Les règles][
    - `#` à `######` : titres de niveau 1 à 6, sans sauter de niveau ; `**gras**`, `*italique*`
    - Une ligne vide sépare deux paragraphes ; un simple retour à la ligne ne les sépare pas
    - `-`, `*` ou `+` : puces ; `1.` : numéros ; une sous-liste s’indente sous le texte de l’élément
  ]),
  source-de: link("https://spec.commonmark.org/0.31.2/")[CommonMark 0.31.2],
  note: [Le rendu de droite reproduit celui de pandoc -f gfm -t html sur ce fichier (pandoc 3.1.11.1) : « web01. » et « Ce README » sont réunis dans un seul paragraphe \<p>, la sous-liste est imbriquée dans le deuxième élément. Dans l’origine, \_\_gras\_\_ et \_italique\_ (soulignés) valent \*\*gras\*\* et \*italique\* ; \*\*\*gras italique\*\*\* combine les deux. Un seul titre de niveau 1 par document : les sommaires et les ancres des titres en sont déduits.],
)

== Liens, images, citations, code

#anime(
  rang(
    bloc(role: "pratique", taille: px(24))[Source : README.md (suite)][
      #fichier([README.md], taille: px(21))[````
      [Documentation de Debian](https://www.debian.org/doc/)

      ![Schéma de l’architecture](schema.png)

      > Ne modifiez pas la production un vendredi.

      Le fichier `config.yaml` décrit l’application :

      ```yaml
      version: 1.2.3
      ```
      ````]
    ],
    bloc(taille: px(24))[Rendu][
      #rendu(titre: none)[
        #text(fill: c.bleu)[#underline[Documentation de Debian]]
        #v(px(4))
        #block(width: 100%, height: px(56), stroke: (paint: c.gris, thickness: px(2), dash: "dashed"), radius: px(8),
          align(center + horizon, text(size: px(20), fill: c.gris)[image schema.png ; si elle manque : « Schéma de l’architecture »]))
        #block(stroke: (left: px(5) + c.filet), inset: (left: px(14), y: px(4)))[Ne modifiez pas la production un vendredi.]
        Le fichier `config.yaml` décrit l’application :
        #block(width: 100%, fill: c.espace, radius: px(8), inset: px(10), raw("version: 1.2.3"))
      ]
    ],
  ),
  rang(bloc(role: "avertissement", taille: px(23))[Le texte alternatif d’une image n’est pas facultatif][
    - Le texte entre crochets est lu par les lecteurs d’écran et affiché si l’image manque : décrivez ce que l’image montre
  ]),
  source-de: link("https://spec.commonmark.org/0.31.2/#images")[CommonMark 0.31.2, Images],
  note: [Lien : [texte](adresse) ; image : la même chose précédée de « ! » ; citation : « > » ; code en ligne entre accents graves, bloc de code entre trois accents graves, avec le langage pour la coloration (ici yaml). Le fichier schema.png n’existe pas : le rendu montre ce que fait un navigateur quand l’image manque. pandoc en tire \<a href=…>, \<img src="schema.png" alt="Schéma de l’architecture" />, \<blockquote> et \<pre class="sourceCode yaml"> (sortie relevée, pandoc 3.1.11.1).],
)

== Les tableaux : une extension de Markdown

#anime(
  rang(
    bloc(role: "pratique", poids: 0.7, taille: px(24))[Un tableau GFM][
      #fichier([tableau.md])[```
      | Option | Effet |
      |:-------|:------|
      | `-l` | format long |
      ```]
      - La ligne de tirets sépare l’en-tête ; les `:` règlent l’alignement (`:--` gauche, `:-:` centre, `--:` droite)
    ],
    bloc(role: "pratique", poids: 1.5)[Deux lectures du même fichier][
      #terminal(titre: none, taille: px(18))[
        ```
        # CommonMark seul : pas de tableau, un paragraphe
        $ pandoc -f commonmark -t html tableau.md
        <p>| Option | Effet | |:-------|:------| | <code>-l</code> | format long
        |</p>
        # GFM (GitHub, GitLab) : un vrai tableau
        $ pandoc -f gfm -t html tableau.md
        <table>
        <thead>
        <tr class="header">
        <th style="text-align: left;">Option</th>
        # … 9 lignes : la 2e colonne, puis la ligne du corps
        </table>
        ```
      ]
    ],
  ),
  rang(bloc(role: "retenir", taille: px(24))[À retenir][
    - Tableaux, cases à cocher, texte barré : des extensions. Vérifiez ce que comprend le destinataire avant de vous en servir
  ]),
  source-de: [#link("https://github.github.com/gfm/#tables-extension-")[GFM, Tables (extension)] · #link("https://pandoc.org/MANUAL.html#tables")[pandoc, Tables]],
  note: [Sorties réelles de pandoc 3.1.11.1 (binaire officiel, dans un conteneur Debian 13 ; à rejouer avec le paquet pandoc de Debian 13). Le deuxième résultat est tronqué : la ligne « \# … » remplace l’en-tête Effet et la ligne du corps (\<tbody>…\</tbody>). Le format par défaut de pandoc (-f markdown, « Pandoc’s Markdown ») comprend aussi les tableaux. Le cours d’origine (dépôt Markdown) montre qu’on n’est pas obligé d’aligner les barres verticales : seule la ligne de tirets compte.],
)

== Un source, plusieurs formats : pandoc

#anime(
  rang(
    bloc(role: "pratique", poids: 1.7)[Convertir doc.md][
      #terminal(titre: none, taille: px(18))[
        ```
        $ sudo apt install pandoc
        # vers HTML, sur la sortie standard
        $ pandoc -f gfm -t html doc.md | head -3
        <h1 id="documentation-de-la-commande-ls">Documentation de la commande
        <code>ls</code></h1>
        <p><code>ls</code> liste le contenu d’un répertoire : ses fichiers et
        # page HTML complète (-s, standalone), dans un fichier (-o)
        $ pandoc -f gfm -s --metadata title="ls" doc.md -o doc.html
        # le format de sortie se déduit de l’extension : .odt, .docx, .pdf
        $ pandoc doc.md -o doc.pdf
        pdflatex not found. Please select a different --pdf-engine or install pdflatex
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la commande][
      - `-f` (_from_) : format d’entrée ; `-t` (_to_) : format de sortie
      - `-s` : document autonome, avec en-tête ; une page HTML exige un titre (`--metadata title=…`)
      - Le PDF passe par LaTeX : prérequis `texlive-latex-base` et `texlive-latex-recommended`
    ],
  ),
  source-de: link("https://pandoc.org/MANUAL.html")[pandoc, manuel],
  note: [doc.md est le fichier de l’exercice suivant (corrigé). Sorties réelles, pandoc 3.1.11.1 dans un conteneur Debian 13 (binaire officiel : les miroirs Debian n’étaient pas joignables ; à rejouer avec le paquet pandoc de Debian 13, rejouer.sh). Sans --metadata title, pandoc -s avertit « This document format requires a nonempty \<title> element » et prend le nom du fichier. L’erreur PDF est voulue : elle montre le prérequis ; les paquets texlive sont ceux du cours d’origine. pandoc -o doc.odt et -o doc.docx marchent sans LaTeX.],
)

== À vous : documenter une commande <markdown-exercice>

#anime(
  rang(bloc(role: "question")[À vous][
    + Avec Vim, créez un fichier `doc.md`
    + Ajoutez un titre de niveau 1 : « Documentation de la commande `ls` »
    + Ajoutez un paragraphe qui explique à quoi sert la commande
    + Insérez un bloc de code qui montre comment utiliser `ls`
    + Ajoutez une liste à puces des options les plus courantes de `ls`
    + Convertissez `doc.md` en HTML avec pandoc
  ]),
  note: [Exercice du cours d’origine (le premier des trois), fait en séance ; la conversion pandoc vient du troisième. Une question par clic. Le README.md d’un projet fictif (deuxième exercice d’origine) et les conversions en ODT et PDF peuvent aller en TP.],
)

== À vous : corrigé

#slide(repeat: 3, self => {
  let (uncover,) = utils.methods(self)
  corrige(1, [Créez `doc.md` : titre, paragraphe, bloc de code, liste des options courantes],
    uncover("2-", reponse(fichier([doc.md], taille: px(20))[````
    # Documentation de la commande `ls`

    `ls` liste le contenu d’un répertoire : ses fichiers et ses sous-répertoires.

    ```bash
    ls -lh /etc/ssh
    ```

    Options courantes :

    - `-l` : format long (droits, propriétaire, taille, date)
    - `-a` : affiche aussi les fichiers cachés (nom commençant par `.`)
    - `-h` : tailles lisibles (Kio, Mio), avec `-l`
    - `-t` : trie par date de modification
    ````])))
  v(px(8)); filet-corrige; v(px(8))
  corrige(6, [Convertissez `doc.md` en HTML avec pandoc],
    uncover("3-", reponse(terminal(titre: none, taille: px(20))[```
    $ pandoc -f gfm -s --metadata title="ls" doc.md -o doc.html
    $ ls doc.html
    doc.html
    ```])))
  utils.speaker-note(self: self)[Fichier converti réellement (pandoc 3.1.11.1) : h1, paragraphe, bloc de code bash, liste de quatre éléments. Une ligne vide avant la liste est nécessaire après « Options courantes : » pour un rendu propre partout. On ouvre doc.html dans un navigateur pour voir le rendu.]
})

// ======================================================================
= YAML et JSON · structurer des données

== Une même personne, quatre formats

#anime(
  rang(
    bloc(role: "pratique", taille: px(22))[CSV (_comma-separated values_) : à plat][
      #fichier([personne.csv], taille: px(17))[```
      nom,age,rue,ville,hobby1,hobby2,hobby3
      John Doe,30,123 Main St,Paris,lecture,course,voyage
      ```]
      - Pas de hiérarchie : rien ne dit qu’une adresse contient une rue et une ville ; trois loisirs, ni plus ni moins
    ],
    bloc(role: "pratique", poids: 0.8, taille: px(22))[XML (_eXtensible Markup Language_) : verbeux][
      #fichier([personne.xml], taille: px(17))[```
      <personne>
        <nom>John Doe</nom>
        <age>30</age>
        <adresse>
          <rue>123 Main St</rue>
          <ville>Paris</ville>
        </adresse>
        <hobbies>
          <hobby>lecture</hobby> …
      ```]
    ],
  ),
  rang(
    bloc(role: "pratique", taille: px(22))[JSON : hiérarchique, strict][
      #fichier([personne.json], taille: px(17))[```
      {"personne": {"nom": "John Doe", "age": 30,
        "adresse": {"rue": "123 Main St", "ville": "Paris"},
        "hobbies": ["lecture", "course", "voyage"]}}
      ```]
    ],
    bloc(role: "pratique", poids: 0.8, taille: px(22))[YAML : la hiérarchie par l’indentation][
      #fichier([personne.yaml], taille: px(17))[```
      personne:
        nom: John Doe
        age: 30
        adresse: {rue: 123 Main St, ville: Paris}
        hobbies: [lecture, course, voyage]
      ```]
    ],
  ),
  note: [Exemple du cours d’origine (README yaml_et_json). Le XML est abrégé (« … » : les deux autres loisirs et les balises fermantes). Le JSON est ici compacté, le YAML mélange style bloc (indentation) et style flux (accolades, crochets) : les deux styles sont du YAML. Le cours d’origine affirme qu’un YAML ne peut pas tenir sur une ligne : c’est vrai du style bloc, pas du style flux ; echo "{personne: {nom: John Doe, age: 30, hobbies: [lecture, course]}}" | yq -c . rend l’objet JSON attendu.],
)

== JSON : une syntaxe stricte, six types <json-syntaxe>

#anime(
  rang(
    bloc(taille: px(25))[JSON, _JavaScript Object Notation_][
      - Un format de données, issu de la notation des objets de JavaScript ; normes RFC 8259 (IETF, _Request for Comments_) et ECMA-404
      - *Objet* `{"clé": valeur, …}` · *tableau* `[valeur, …]`
      - *Chaîne* `"…"` (guillemets doubles seulement) · *nombre* `30`, `3.14` · `true`, `false` · `null`
      - Ni commentaire, ni virgule finale ; l’indentation ne compte pas
    ],
    bloc(role: "pratique", poids: 1.05, taille: px(24))[jq refuse un commentaire][
      #terminal(titre: none, taille: px(20))[
        ```
        $ echo '{"a": 1} # commentaire' | jq .
        jq: parse error: Invalid numeric literal at line 1, column 11
        {
          "a": 1
        }
        ```
      ]
      - jq (_JSON query_) lit des valeurs JSON à la suite : il affiche la première, puis bute sur `#`, qui n’est pas du JSON (code de retour 5)
    ],
  ),
  rang(bloc(role: "retenir", taille: px(24))[Usage][
    - Le format des échanges entre programmes : API web, journaux structurés, sorties `--json` ou `-j` des commandes (`ip -j addr`, `lsblk -J`)
  ]),
  source-de: [#link("https://www.rfc-editor.org/rfc/rfc8259")[RFC 8259] · #link("https://jqlang.org/manual/")[jq, manuel]],
  note: [jq 1.7.1 (binaire officiel, conteneur Debian 13 ; à rejouer avec le paquet jq de Debian 13). Ordre des sorties : jq écrit l’erreur sur la sortie d’erreur, l’objet sur la sortie standard ; le terminal les mêle dans l’ordre de leur arrivée. RFC 8259 (2017) : « The names within an object SHOULD be unique » ; le doublon est traité deux diapositives plus loin. Le cours d’origine classe JSON parmi les formats de données et YAML parmi les langages ; la comparaison reste pertinente, car les deux servent aux mêmes usages (configuration, sérialisation, transfert).],
)

== YAML : la hiérarchie par l’indentation <yaml-syntaxe>

#anime(
  rang(
    bloc(role: "pratique", poids: 0.95, taille: px(24))[config.yaml, annoté][
      #fichier([config.yaml, élargi], taille: px(20))[```
      ---                      # début de document
      # un commentaire
      application:             # clé: valeur (mapping)
        nom: MonApplication    # 2 espaces = un niveau
        version: 1.2.3
        environnements:
          production:
            url: https://prod.example.org
      paquets:                 # séquence (liste)
        - nginx
        - python3
      ports: [80, 443]         # style flux, comme JSON
      ```]
    ],
    bloc(taille: px(24))[Les règles][
      - YAML, _YAML Ain’t Markup Language_ : écrit pour être lu et modifié par un humain
      - *Mapping* : `clé: valeur`, avec une espace après les deux-points
      - *Séquence* : un `- ` par élément
      - *Scalaire* : une valeur simple (chaîne, nombre, booléen, null)
      - L’indentation porte la hiérarchie : des *espaces*, jamais de tabulation
      - `#` : commentaire ; `---` : début d’un document (plusieurs par fichier possibles)
    ],
  ),
  source-de: link("https://yaml.org/spec/1.2.2/")[YAML 1.2.2, spécification],
  note: [À l’origine, YAML signifiait _Yet Another Markup Language_ ; l’acronyme est devenu récursif (_YAML Ain’t Markup Language_) : YAML vise les qualités d’un langage de balisage sans en être un (cours d’origine). Ce fichier élargit config.yaml de deux clés (paquets, ports) pour montrer séquence et style flux. yamllint attend --- en tête (règle document-start, avertissement). Versions de la spécification : 1.1 (2005), 1.2 (2009), révision 1.2.2 (2021).],
)

== YAML et JSON : une même structure <yaml-json-correspondance>

#anime(
  pas(1, (u, d) => u(str(d) + "-", tableau((1fr, 1fr, 1.25fr), taille: px(23),
    ([YAML], [JSON], [Remarque]),
    ([mapping `clé: valeur`], [objet `{"clé": valeur}`], [une clé YAML peut être autre chose qu’une chaîne ; en JSON, toujours une chaîne]),
    ([séquence `- élément`], [tableau `[élément]`], [identiques en style flux : `[a, b]`]),
    ([scalaire nu : `30`, `true`, `null`, `web01`], [nombre, booléen, null, chaîne], [le type d’un scalaire nu se déduit de sa forme : diapositive suivante]),
    ([scalaire entre guillemets : `"1984"`], [chaîne `"1984"`], [les guillemets imposent la chaîne]),
    ([`# commentaire`], [—], [perdu à la conversion]),
    ([ancre `&a`, alias `*a`], [—], [résolus : le bloc est recopié]),
    ([plusieurs documents (`---`)], [plusieurs valeurs JSON], [une par document]),
  ))),
  rang(bloc(role: "retenir", taille: px(25))[Le modèle commun][
    - Un arbre : des *mappings* (objets) et des *séquences* (tableaux), terminés par des *scalaires*. Convertir, c’est réécrire le même arbre dans l’autre syntaxe
  ]),
  source-de: link("https://yaml.org/spec/1.2.2/#chapter-3-processes-and-models")[YAML 1.2.2, chap. 3 (modèle de représentation)],
  note: [Le tableau apparaît d’un bloc, puis la synthèse. La spécification décrit trois sortes de nœuds : mapping, séquence, scalaire. Une clé YAML non chaîne (par exemple 80: http) devient une chaîne en JSON ("80"). Les commentaires et les ancres appartiennent à la présentation du fichier, pas aux données : un convertisseur les abandonne ou les résout.],
)

== Convertir et comparer : python3, yq, jq <yaml-convertir>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.75)[YAML vers JSON, puis contrôle][
      #terminal(titre: none, taille: px(18))[
        ```
        # avec Python et son module yaml (paquet python3-yaml)
        $ python3 -c 'import sys, json, yaml
        > json.dump(yaml.safe_load(sys.stdin), sys.stdout, indent=2)' < config.yaml
        {
          "application": {
            "nom": "MonApplication",
            "version": "1.2.3",
        # …
        # avec yq : sans option, il écrit du JSON
        $ yq . config.yaml > config.json
        $ jq -r '.application.nom' config.json
        MonApplication
        # même arbre ? (-S trie les clés)
        $ jq -S . config.json > a.json
        $ yq -S . config.yaml > b.json
        $ cmp a.json b.json && echo identiques
        identiques
        ```
      ]
    ],
    bloc(taille: px(24))[Lire les commandes][
      - `yaml.safe_load` : lit le YAML sans exécuter de code
      - Un *analyseur* (_parser_) lit le texte et en construit l’arbre : ici PyYAML
      - yq (_YAML query_) : `.` rend le document entier ; `-r` (_raw_) : chaîne sans guillemets
      - Prérequis : paquets `python3-yaml`, `yq`, `jq`
      - `cmp` : se tait et réussit si les deux fichiers sont identiques
    ],
  ),
  source-de: [#link("https://pyyaml.org/wiki/PyYAMLDocumentation")[PyYAML] · #link("https://github.com/kislyuk/yq")[yq (Python)] · #link("https://jqlang.org/manual/")[jq]],
  note: [Sorties réelles dans un conteneur Debian 13 : Python 3.13, PyYAML 6.0.4, yq 4.4.5 (version Python), jq 1.7.1, installés depuis PyPI et les binaires officiels faute d’accès aux miroirs Debian : à rejouer avec les paquets Debian 13 (python3-yaml, yq, jq). La sortie Python est tronquée (« \# … ») : elle est identique à celle de yq. Le yq employé ici est celui qu’installe sudo apt install yq : diapositive « Deux outils nommés yq ». yaml.load sans Loader sûr peut construire des objets Python arbitraires : toujours safe\_load pour un fichier reçu.],
)

== JSON est-il du YAML ?

#anime(
  rang(
    bloc(taille: px(24))[La réponse de la spécification][
      - YAML 1.2 a été révisé pour que JSON en soit un sous-ensemble : un document JSON est un document YAML 1.2
      - Pas en YAML 1.1 : PyYAML, qui suit la 1.1, refuse la tabulation, permise en JSON
      - Les clés en double : JSON les déconseille, YAML les interdit
    ],
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Deux analyseurs, deux réponses][
      #terminal(titre: none, taille: px(18))[
        ```
        $ printf '{\t"a": 1}\n' > tabulation.json
        # PyYAML (YAML 1.1)
        $ python3 -c 'import sys, yaml
        > print(yaml.safe_load(sys.stdin))' < tabulation.json
        # …
        found character '\t' that cannot start any token
        # ruamel.yaml (YAML 1.2), paquet python3-ruamel.yaml
        $ python3 -c 'from ruamel.yaml import YAML; import sys
        > print(YAML(typ="safe").load(sys.stdin))' < tabulation.json
        {'a': 1}
        # une clé en double : jq garde la dernière
        $ printf '{"a": 1, "a": 2}\n' > doublon.json
        $ jq -c . doublon.json
        {"a":2}
        ```
      ]
    ],
  ),
  rang(bloc(role: "retenir", taille: px(24))[En pratique][
    - Du JSON se colle dans un fichier YAML. L’inverse est faux : commentaires et ancres n’ont pas d’équivalent JSON
  ]),
  source-de: [#link("https://yaml.org/spec/1.2.2/#12-yaml-history")[YAML 1.2.2, § 1.2] · #link("https://www.rfc-editor.org/rfc/rfc8259#section-4")[RFC 8259, § 4]],
  note: [ruamel.yaml 0.19.1 refuse ce fichier (DuplicateKeyError) ; PyYAML garde la dernière valeur sans rien dire. La trace de PyYAML est abrégée (« \# … ») : elle se termine par yaml.scanner.ScannerError, while scanning for the next token. Sorties réelles, conteneur Debian 13, PyYAML 6.0.4 et ruamel.yaml 0.19.1 (PyPI ; à rejouer avec python3-yaml et python3-ruamel.yaml de Debian 13). Le cours d’origine renvoie à l’article JSON::XS « JSON and YAML » sur les cas limites ; le site disait « pas tout à fait » sans préciser : la réponse dépend de la version de YAML que suit l’analyseur.],
)

== Le typage implicite des scalaires <yaml-typage>

#anime(
  rang(bloc(role: "retenir", taille: px(26))[La règle][
    - Un scalaire *nu* (sans guillemets) prend le type dont il a la forme, selon le *schéma* de la version que suit l’analyseur. Entre guillemets : une chaîne. Avec une étiquette (`!!str`, `!!int`) : le type imposé
  ]),
  pas(1, (u, d) => u(str(d) + "-", tableau((1fr, 1.6fr, 1.4fr), taille: px(22),
    ([Type], [YAML 1.1 (PyYAML)], [YAML 1.2, schéma de base (ruamel.yaml)]),
    ([booléen], [`true`, `false`, `yes`, `no`, `on`, `off` (et leurs capitales)], [`true`, `false`, `True`, `FALSE`… seulement]),
    ([null], [`null`, `~`, valeur vide], [`null`, `~`, valeur vide]),
    ([entier], [`42`, `0644` (octal), `0x1F`, `22:22` (base 60)], [`42`, `0o644` (octal), `0x1F`]),
    ([flottant], [`3.14`, `1.10` (= 1.1), `.inf`], [`3.14`, `1.10` (= 1.1), `.inf`]),
    ([date], [`2024-01-15`], [pas dans le schéma : ruamel.yaml et PyYAML en font une date]),
    ([chaîne], [tout le reste : `web01`, `1.2.3`, `"1984"`], [tout le reste, dont `yes`, `NO`, `22:22`]),
  ))),
  source-de: [#link("https://yaml.org/type/bool.html")[YAML 1.1, types] · #link("https://yaml.org/spec/1.2.2/#1023-core-schema")[YAML 1.2.2, § 10.2.3 Core Schema]],
  note: [Le tableau résume les relevés des deux diapositives suivantes. La spécification 1.1 inclut aussi y, Y, n, N parmi les booléens ; PyYAML ne les applique pas (y reste une chaîne, relevé). Le schéma de base 1.2 n’a pas de type date ; ruamel.yaml (typ safe, 1.2 par défaut) en reconnaît pourtant, comme PyYAML ; yq (Go) l’étiquette !!timestamp mais l’écrit en chaîne. Une directive %YAML 1.1 en tête de document fait lire ruamel.yaml en 1.1 ; PyYAML ignore %YAML 1.2 et reste en 1.1 (relevé). JSON a les mêmes types, sans date.],
)

== Le problème de la Norvège : `NO` vaut `false` <yaml-norvege>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.7)[Le même fichier, deux analyseurs][
      #fichier([norvege.yaml], taille: px(20))[```
      ---
      pays: [FR, NO, SE]
      actif: yes
      ```]
      #terminal(titre: none, taille: px(18))[
        ```
        # PyYAML : YAML 1.1
        $ python3 -c 'import sys, yaml
        > print(yaml.safe_load(sys.stdin))' < norvege.yaml
        {'pays': ['FR', False, 'SE'], 'actif': True}
        # ruamel.yaml : YAML 1.2
        $ python3 -c 'from ruamel.yaml import YAML; import sys
        > print(YAML(typ="safe").load(sys.stdin))' < norvege.yaml
        {'pays': ['FR', 'NO', 'SE'], 'actif': 'yes'}
        $ yamllint norvege.yaml
        norvege.yaml
          2:12      warning  truthy value should be one of [false, true]  (truthy)
          3:8       warning  truthy value should be one of [false, true]  (truthy)
        ```
      ]
    ],
    bloc(role: "avertissement", taille: px(24))[Écrire sans ambiguïté][
      - Le code pays de la Norvège devient le booléen `false` en YAML 1.1
      - Booléens : `true` et `false`, toujours
      - Une chaîne qui ressemble à autre chose : entre guillemets, `"NO"`
      - yamllint le signale (règle _truthy_)
    ],
  ),
  source-de: [#link("https://yaml.org/type/bool.html")[YAML 1.1, bool] · #link("https://yamllint.readthedocs.io/en/stable/rules.html#module-yamllint.rules.truthy")[yamllint, truthy]],
  note: [Sorties réelles, conteneur Debian 13 : PyYAML 6.0.4, ruamel.yaml 0.19.1, yamllint 1.38.0 (PyPI ; à rejouer avec les paquets Debian 13). yamllint s’appuie lui-même sur PyYAML. Ansible lit ses fichiers avec PyYAML : un yes y est un booléen (documentation Ansible, YAML Syntax) — à vérifier sur la version d’ansible-core du cours Ansible. Le yq de Debian (version Python) ne suit ni l’un ni l’autre exactement : yq 4.4.5 lit NO et yes comme des chaînes.],
)

== Autres pièges : octal, base 60, versions, dates <yaml-pieges>

#anime(
  rang(
    bloc(role: "pratique", poids: 0.75, taille: px(24))[typage.yaml][
      #fichier([typage.yaml], taille: px(21))[```
      ---
      mode: 0644
      mode_12: 0o644
      duree: 22:22
      version: 1.10
      date: 2024-01-15
      titre: 1984
      titre_chaine: "1984"
      ```]
    ],
    bloc(role: "pratique", poids: 1.25, taille: px(24))[Valeurs lues][
      #tableau((1fr, 1.1fr, 1.1fr, 1fr), taille: px(21),
        ([Clé], [PyYAML (1.1)], [ruamel.yaml (1.2)], [yq Go (1.2)]),
        ([`mode`], [`420`], [`644`], [`644`]),
        ([`mode_12`], [`'0o644'`], [`420`], [`420`]),
        ([`duree`], [`1342`], [`'22:22'`], [`"22:22"`]),
        ([`version`], [`1.1`], [`1.1`], [`1.1`]),
        ([`date`], [date Python], [date Python], [`"2024-01-15"`]),
        ([`titre`], [`1984`], [`1984`], [`1984`]),
        ([`titre_chaine`], [`'1984'`], [`'1984'`], [`"1984"`]),
      )
    ],
  ),
  rang(bloc(role: "avertissement", taille: px(23))[Les conséquences][
    - Des droits `0644` lus en décimal ; un `22:22` (port de Compose) lu en base 60 ; une version `1.10` devenue `1.1` ; une date que `json.dumps` refuse (`TypeError: Object of type date is not JSON serializable`). Guillemets !
  ]),
  source-de: [#link("https://yaml.org/type/int.html")[YAML 1.1, int] · #link("https://yaml.org/spec/1.2.2/#1023-core-schema")[YAML 1.2.2, Core Schema] · #link("https://docs.docker.com/reference/compose-file/services/#ports")[Compose, ports]],
  note: [Relevés réels, conteneur Debian 13 : PyYAML 6.0.4 (yaml.safe\_load), ruamel.yaml 0.19.1 (YAML(typ="safe"), 1.2 par défaut), yq Go v4.44.3 (yq -o=json) ; à rejouer avec rejouer.sh. 0644 en 1.1 : octal, soit 420 ; en 1.2, l’octal s’écrit 0o644, et 0644 est un entier décimal. 22:22 en 1.1 : 22 × 60 + 22 = 1342 (entier sexagésimal) ; la documentation de Compose recommande de mettre les ports entre guillemets pour cette raison. 1.10 est un flottant dans les deux versions : une version s’écrit entre guillemets. La date : PyYAML rend un datetime.date, que le module json ne sait pas écrire. 1984 sans guillemets : un entier, d’où les guillemets du titre dans l’exercice.],
)

== Chaînes sur plusieurs lignes : `|` garde, `>` replie

#anime(
  rang(
    bloc(role: "pratique", poids: 0.8, taille: px(24))[multi.yaml][
      #fichier([multi.yaml], taille: px(21))[```
      ---
      litteral: |
        ligne 1
        ligne 2
      replie: >
        ligne 1
        ligne 2
      sans_fin: |-
        ligne 1
        ligne 2
      ```]
    ],
    bloc(role: "pratique", poids: 1.2, taille: px(24))[Ce qu’en lit un analyseur][
      #terminal(titre: none, taille: px(19))[
        ```
        $ python3 -c 'import sys, json, yaml
        > print(json.dumps(yaml.safe_load(sys.stdin), indent=1))' < multi.yaml
        {
         "litteral": "ligne 1\nligne 2\n",
         "replie": "ligne 1 ligne 2\n",
         "sans_fin": "ligne 1\nligne 2"
        }
        ```
      ]
      - `|` (littéral) : les retours à la ligne sont gardés
      - `>` (replié) : ils deviennent des espaces
      - `-` après `|` ou `>` : sans retour à la ligne final ; `+` : on les garde tous
      - JSON n’a qu’une écriture : `\n` dans la chaîne
    ],
  ),
  rang(bloc(role: "precaution", taille: px(23))[Vaut pour les deux versions][
    - Les styles `|` et `>` sont les mêmes en YAML 1.1 et 1.2 ; l’indentation du bloc fixe ce qui appartient à la chaîne. Usage typique : un script dans un fichier de configuration
  ]),
  source-de: link("https://yaml.org/spec/1.2.2/#81-block-scalar-styles")[YAML 1.2.2, § 8.1 Block Scalar Styles],
  note: [Sortie réelle, PyYAML 6.0.4 (conteneur Debian 13). ruamel.yaml donne les mêmes chaînes. Le réglage de fin (_chomping_) : « clip » par défaut (un seul retour à la ligne final), « strip » avec -, « keep » avec +.],
)

== Ancres, alias et clé de fusion <yaml-ancres>

#anime(
  rang(
    bloc(role: "pratique", poids: 0.8, taille: px(24))[ancres.yaml][
      #fichier([ancres.yaml], taille: px(21))[```
      ---
      defaut: &defaut
        couleur: bleu
        taille: M
      objet1:
        <<: *defaut
        taille: L
      objet2: *defaut
      ```]
    ],
    bloc(role: "pratique", poids: 1.2, taille: px(24))[Résolu à la lecture][
      #terminal(titre: none, taille: px(19))[
        ```
        # objet1, puis objet2, une ligne chacun
        $ yq -c '.objet1, .objet2' ancres.yaml
        {"couleur":"bleu","taille":"L"}
        {"couleur":"bleu","taille":"M"}
        ```
      ]
      - `&defaut` : l’*ancre* nomme un nœud ; `*defaut` : l’*alias* le réutilise tel quel
      - `<<:` : la *clé de fusion* recopie les clés du nœud, puis les clés écrites à côté les surchargent (`taille: L`)
    ],
  ),
  rang(bloc(role: "precaution", taille: px(23))[La clé de fusion n’est pas dans YAML 1.2][
    - `<<` est un type du dépôt de YAML 1.1, absent de la spécification 1.2 ; PyYAML, ruamel.yaml et yq l’appliquent tout de même. Ancres et alias, eux, font partie des deux versions
  ]),
  source-de: [#link("https://yaml.org/type/merge.html")[YAML 1.1, Merge Key] · #link("https://yaml.org/spec/1.2.2/#71-alias-nodes")[YAML 1.2.2, § 7.1 Alias Nodes]],
  note: [Exemple du cours d’origine (par défaut, objet1, objet2), clé « par défaut » renommée defaut (une clé sans espace). Sortie réelle, yq 4.4.5 (Python) ; yq -c . ancres.yaml affiche aussi defaut, sur une seule ligne trop longue pour la diapositive. PyYAML 6.0.4, ruamel.yaml 0.19.1 et yq Go v4.44.3 (explode) donnent le même arbre. En JSON, il n’y a plus d’ancre : objet2 est une copie.],
)

== Valider avant d’appliquer : yamllint <yamllint>

#anime(
  rang(
    bloc(role: "pratique", poids: 0.75, taille: px(22))[Deux fichiers fautifs][
      #fichier([tabulation.yaml (`cat -T`)], taille: px(18))[```
      titre: 1984
      auteur: George Orwell
      mots_cles:
        - dystopie
      ^I- politique
      ```]
      #v(px(4))
      #fichier([indentation.yaml], taille: px(18))[```
      ---
      application:
        nom: MonApplication
         version: 1.2.3
      ```]
    ],
    bloc(role: "pratique", poids: 2)[Trois verdicts][
      #terminal(titre: none, taille: px(17))[
        ```
        $ sudo apt install yamllint
        # rien à signaler : code de retour 0
        $ yamllint config.yaml ancres.yaml
        # ^I : une tabulation au début de la ligne 5
        $ yamllint tabulation.yaml
        tabulation.yaml
          1:1       warning  missing document start "---"  (document-start)
          5:1       error    syntax error: found character '\t' that cannot start any token (syntax)
        # une espace de trop devant version
        $ yamllint indentation.yaml
        indentation.yaml
          4:11      error    syntax error: mapping values are not allowed here (syntax)
        ```
      ]
    ],
  ),
  encadre(role: "notion", libelle: [Lire le verdict :], taille: px(22))[`ligne:colonne`, niveau, message, (règle). `error` : ce n’est pas du YAML, code de retour 1 ; `warning` : du YAML, mais une règle de style ou de prudence n’est pas suivie. Avant de pousser une configuration sur un serveur : yamllint, puis l’outil lui-même.],
  source-de: link("https://yamllint.readthedocs.io/en/stable/")[yamllint, documentation],
  note: [Sorties réelles, yamllint 1.38.0 (PyPI, conteneur Debian 13 ; à rejouer avec le paquet yamllint de Debian 13). tabulation.yaml : la ligne 5 commence par une tabulation. indentation.yaml : « version » est indenté de trois espaces sous « nom » (deux) : l’analyseur y voit la suite de la valeur MonApplication, puis bute sur les deux-points. La configuration de yamllint se règle par un fichier .yamllint (règles activées, niveaux).],
)

== Interroger et modifier : jq et yq <yq-jq>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.35)[Sur config.yaml][
      #terminal(titre: none, taille: px(19))[
        ```
        # un filtre jq navigue de clé en clé
        $ yq -r '.application.environnements.production.url' config.yaml
        https://prod.example.org
        # modifier le fichier : -i (en place) exige -y (sortie YAML)
        $ yq -i '.application.version = "1.2.4"' config.yaml
        yq: -i/--in-place can only be used with -y/-Y/-t/-T/-x
        $ yq -yi '.application.version = "1.2.4"' config.yaml
        $ grep version config.yaml
          version: 1.2.4
        # la version mise en commentaire avec Vim (partie 1)
        $ yq -c .application.environnements commente.yaml
        {"production":{"url":"https://prod.example.org"}}
        ```
      ]
    ],
    bloc(taille: px(24))[Le principe][
      - yq lit le YAML, le convertit en JSON et le passe à jq : les filtres sont ceux de jq
      - Sans `-i`, seule la sortie change, pas le fichier (comme `sed`)
      - `.[0]` : le premier élément d’un tableau (on compte à partir de 0) ; `keys` : les clés d’un objet ; `select(…)` : un filtre
    ],
  ),
  source-de: [#link("https://github.com/kislyuk/yq")[yq (Python)] · #link("https://jqlang.org/manual/")[jq, manuel]],
  note: [Sorties réelles, yq 4.4.5 (Python) et jq 1.7.1, conteneur Debian 13 ; la dernière commande porte sur le config.yaml dont l’environnement de développement a été mis en commentaire avec Ctrl+v (diapositive « Les modes visuels »). Le site affirmait que -i sans -y réécrit le fichier en JSON : yq 4.4.5 (et yq 3.1.0 d’Ubuntu 24.04) refusent, avec le message ci-dessus ; à rejouer avec le yq de Debian 13. -yi réécrit le fichier : les commentaires et la mise en forme d’origine sont perdus (-Y les garde en partie).],
)

== Deux outils nommés yq <deux-yq>

#anime(
  rang(
    bloc(taille: px(24))[yq en Python (kislyuk)][
      - Celui de `sudo apt install yq` (Debian, Ubuntu)
      - Une surcouche de jq : il lui passe le JSON
      - Sortie JSON par défaut ; `-y` pour du YAML
      - `-i` exige `-y`
    ],
    bloc(taille: px(24))[yq en Go (mikefarah)][
      - Un autre programme, au même nom, installé par snap, brew ou téléchargement
      - Sa propre syntaxe, proche de celle de jq
      - Sortie YAML par défaut ; `-o=json` pour du JSON
      - `-i` réécrit le fichier en YAML
    ],
    bloc(role: "pratique", poids: 1.2, taille: px(23))[Lequel est installé ?][
      #terminal(titre: none, taille: px(19))[
        ```
        $ yq --version
        yq 4.4.5
        jq-1.7.1
        # le yq Go, ici sous le nom yq-go
        $ yq-go --version
        yq (https://github.com/mikefarah/yq/) version v4.44.3
        ```
      ]
    ],
  ),
  rang(bloc(role: "avertissement", taille: px(23))[Une commande copiée d’un tutoriel peut viser l’autre yq][
    - `yq eval '.a' f.yaml` (Go) échoue avec le yq Python : `jq: error: eval/0 is not defined`. Vérifiez d’abord `yq --version`
  ]),
  source-de: [#link("https://github.com/kislyuk/yq")[github.com/kislyuk/yq] · #link("https://mikefarah.gitbook.io/yq/")[mikefarah.gitbook.io/yq]],
  note: [Les deux yq ont été installés côte à côte dans le conteneur Debian 13 (le Go sous le nom yq-go). Sorties réelles. Le yq Python affiche sa version et celle de jq ; le paquet yq de Debian et d’Ubuntu est la version Python (Ubuntu 24.04 : 3.1.0, qui s’annonce « yq 0.0.0 ») : version du paquet Debian 13 à relever. Les deux lisent les scalaires différemment de PyYAML (diapositive « Autres pièges ») : on ne présume pas du typage, on le vérifie.],
)

== Vers l’infrastructure as code

#anime(
  rang(
    bloc(role: "pratique", poids: 0.9, taille: px(24))[Décrire une action en YAML][
      #fichier([commande.yaml], taille: px(21))[```
      ---
      command:
        - bash
        - -c
        - |
          echo hello world
      ```]
      #terminal(titre: none, taille: px(20))[
        ```
        $ yq -c . commande.yaml
        {"command":["bash","-c","echo hello world\n"]}
        ```
      ]
    ],
    bloc(taille: px(25))[D’où viennent Compose, Ansible, Kubernetes][
      - Chacun pourrait inventer son format pour décrire ce qu’un serveur doit exécuter
      - Des outils ont normalisé ce format : on décrit en YAML l’état voulu, l’outil l’applique
      - Compose (cours _Conteneurisation_), Ansible (cours à venir) : du YAML, lu avec les règles de cette partie
    ],
  ),
  note: [Exemple du cours d’origine, corrigé : l’original est un YAML invalide (le contenu du bloc | n’était pas indenté sous le tiret, et l’option était écrite c au lieu de -c). Sortie réelle, yq 4.4.5. L’infrastructure as code (IaC) : décrire l’infrastructure dans des fichiers versionnés, plutôt que de la configurer à la main.],
)

== À vous : un livre en YAML, puis en JSON <yaml-exercice>

#anime(
  rang(
    bloc(role: "pratique", poids: 0.8, taille: px(24))[Données][
      - Titre : « 1984 »
      - Auteur : George Orwell
      - Année de publication : 1949
      - Genre : Dystopie
      - Mots-clés : dystopie, politique, science-fiction
    ],
    bloc(role: "question", taille: px(25))[À vous][
      + Écrivez `livre.yaml` : titre, auteur, année de publication, genre et liste de mots-clés
      + Validez-le avec `yamllint`
      + Convertissez-le en `livre.json` avec `yq`
      + Quel est le type du titre dans `livre.json` ? Et sans guillemets dans le YAML ?
    ],
  ),
  note(role: "pratique")[Prérequis : `sudo apt install yamllint yq` (commande du cours d’origine).],
  note: [Exercices 1 et 3 du cours d’origine, pour un seul livre ; la question 4 fait le lien avec le typage implicite. Les exercices 2, 4 et 5 (trois livres, ancres et alias, requêtes yq) relèvent du TP.],
)

== À vous : corrigé (1/2)

#slide(repeat: 3, self => {
  let (uncover,) = utils.methods(self)
  corrige(1, [Écrivez `livre.yaml`],
    uncover("2-", reponse(fichier([livre.yaml], taille: px(21))[```
    ---
    titre: "1984"
    auteur: George Orwell
    annee_publication: 1949
    genre: Dystopie
    mots_cles:
      - dystopie
      - politique
      - science-fiction
    ```])))
  v(px(8)); filet-corrige; v(px(8))
  corrige(2, [Validez-le avec `yamllint`],
    uncover("3-", reponse(terminal(titre: none, taille: px(20))[```
    # aucune ligne : aucune remarque
    $ yamllint livre.yaml
    $ echo $?
    0
    ```])))
  utils.speaker-note(self: self)[Corrigé du site (fichier réel), relu : yamllint 1.38.0 n’affiche rien et rend 0. Les clés sans accent ni espace (annee\_publication, mots\_cles) évitent les guillemets et les surprises d’encodage ; le cours d’origine déconseille les espaces dans les clés.]
})

== À vous : corrigé (2/2)

#slide(repeat: 3, self => {
  let (uncover,) = utils.methods(self)
  corrige(3, [Convertissez-le en `livre.json` avec `yq`],
    uncover("2-", reponse(terminal(titre: none, taille: px(20))[```
    $ yq . livre.yaml > livre.json
    $ cat livre.json
    {
      "titre": "1984",
      "auteur": "George Orwell",
      "annee_publication": 1949,
      "genre": "Dystopie",
      "mots_cles": [
        "dystopie",
        "politique",
        "science-fiction"
      ]
    }
    ```])))
  v(px(8)); filet-corrige; v(px(8))
  corrige(4, [Quel est le type du titre ? Et sans guillemets ?],
    uncover("3-", reponse(terminal(titre: none, taille: px(20))[```
    $ yq -c '[.titre, .annee_publication] | map(type)' livre.yaml
    ["string","number"]
    # sans guillemets : un nombre
    $ printf 'titre: 1984\n' | yq -c '.titre | type'
    "number"
    ```])))
  utils.speaker-note(self: self)[Sorties réelles, yq 4.4.5 (Python) et jq 1.7.1, conteneur Debian 13. type est une fonction de jq. Le titre « 1984 » sans guillemets serait l’entier 1984 : le piège du typage implicite, identique en YAML 1.1 et 1.2.]
})

// ======================================================================
= Pour rappel

== Pour rappel · liste non exhaustive

#anime(
  rang(bloc(role: "retenir", taille: px(26))[L’essentiel du cours][
    - Un serveur se configure, se documente et se décrit en texte brut
    - Vim : des modes (#touche[Échap] ramène au mode normal) et une grammaire, opérateur + mouvement ; `:%s/motif/remplacement/g` ; `:wq`, `:q!`
    - Markdown : des marques lisibles brutes ; CommonMark pour le cœur, GFM pour les tableaux ; pandoc convertit
    - YAML et JSON : le même arbre (mappings, séquences, scalaires) ; JSON est du YAML 1.2, pas du YAML 1.1
    - Un scalaire nu est typé selon la version : `NO`, `0644`, `22:22`, `1.10` se mettent entre guillemets ; `true` et `false` seulement
    - Valider avec yamllint ; interroger avec jq et yq, en vérifiant quel yq est installé
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

#cloture(illustration: "texte")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
