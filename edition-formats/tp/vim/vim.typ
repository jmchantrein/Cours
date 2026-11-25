// TP « Dojo Vim » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     edition-formats/tp/vim/vim.typ build/edition-formats/vim.html
// Chaque kata : dojo/<kata>/depart.* et attendu.*, affichés tels quels ; son corrigé, corrige/<kata>.touches,
// est la suite de touches que tester.sh rejoue dans Vim et compare à l’attendu.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/edition-formats-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du dojo ou du corrigé, affiché tel quel.
#let f(chemin, lang: auto) = fichier(chemin, read(chemin), lang: lang)
// Les commandes d’un kata : copier le départ, l’éditer, comparer à l’attendu.
#let lancer(kata, ext) = terminal(raw(lang: "console", block: true,
  "$ cd ~/dojo/" + kata + "\n$ cp depart." + ext + " kata." + ext + "\n$ vim kata." + ext
  + "\n$ diff -u attendu." + ext + " kata." + ext + " && echo réussi"))

#show: page-web.with(
  titre: [Dojo Vim],
  surtitre: [Éditer et structurer du texte · travaux pratiques],
  sous-titre: [Six katas : un fichier de départ, le résultat attendu, et le moins de touches possible pour passer de l’un à l’autre],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("vm", "compagnon"),
  liens: (
    ([Diapos du cours], pdf),
    ([Fichiers du dojo], "https://github.com/jmchantrein/Cours/tree/main/edition-formats/tp/vim/dojo"),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/edition-formats/tp/vim/corrige"),
    ([Aide de Vim], "https://vimhelp.org/"),
  ),
)

= Avant de commencer <avant>

Un dojo est une salle d’entraînement, un kata un exercice qu’on répète jusqu’à ce que le geste devienne
automatique. Chaque kata donne un fichier de départ et le résultat attendu : vous transformez une copie du
départ dans Vim, puis `diff` vous dit si vous avez réussi. Les katas reprennent les exercices du cours : les
modes (#d("vim-modes")[Les modes de Vim et leurs transitions]), la grammaire opérateur + mouvement
(#d("vim-grammaire")[la grammaire de Vim]), `:s` et les modes visuels.

#bloc(role: "pratique")[Prérequis][
  - Le Vim complet, pas une version réduite : `sudo apt install vim`. Sur Debian, la commande `vi` peut être
    fournie par `vim-tiny`, une version réduite, sans `vimtutor` ; dans une image Alpine, `vi` est celui de
    BusyBox, réduit lui aussi.
  - Les fichiers du dojo, dans `~/dojo` : la commande ci-dessous les extrait de l’archive du dépôt des cours.
]

#terminal[```console
$ cd
$ curl -fsSL https://github.com/jmchantrein/Cours/archive/refs/heads/main.tar.gz | tar -xz --strip-components=4 Cours-main/edition-formats/tp/vim/dojo
$ ls dojo
1-survivre  2-vimrc  3-copier  4-remplacer  5-commenter  6-corriger
```]

#note(role: "precaution")[Le terminal de cette page, quand il tourne dans une VM du navigateur, n’a pas de réseau :
son `curl` livre pourtant ces fichiers, que l’image de la VM embarque. Si `curl` échoue ailleurs, travaillez dans
votre propre terminal, ou téléchargez les fichiers un à un depuis le lien « Fichiers du dojo ».]

#bloc[La méthode, pour chaque kata][
  + Copiez le fichier de départ, ouvrez la copie dans Vim, transformez-la, enregistrez et quittez (`:wq`).
  + Comparez-la au résultat attendu : `diff -u` n’affiche rien et `echo réussi` s’exécute si les deux fichiers
    sont identiques. Sinon, les lignes `-` sont celles de l’attendu, les lignes `+` les vôtres.
  + Raté ? Recopiez le départ et recommencez : un kata se refait jusqu’à ce qu’il ne demande plus de réfléchir.
]

#bloc(role: "pratique")[Compter ses touches][
  `vim -W touches kata.txt` enregistre tout ce que vous tapez dans le fichier `touches`, et `wc -c < touches` en
  compte les octets : c’est votre score, à faire baisser d’une tentative à l’autre. `vim -s touches` rejoue
  l’enregistrement sur un autre fichier.
]

#bloc[Indices et corrigés][
  Chaque kata propose des indices, puis un corrigé, repliés. Un corrigé est la suite de touches, dans un fichier
  réel : une ligne qui commence par `"` y est un commentaire ; les fins de ligne ne comptent pas ; `<Esc>` est la
  touche Échap, `<CR>` la touche Entrée, `<C-v>` la combinaison Ctrl+v. Chaque corrigé est rejoué
  automatiquement dans le Vim de Debian 13 (9.1), sans configuration, avec la configuration par défaut et avec le
  `~/.vimrc` du cours, et son résultat comparé à l’attendu par `diff`. Il existe d’autres solutions, souvent plus
  courtes : seul compte le résultat.
]

= Kata 1 : survivre <kata-1>

#bloc(role: "question")[Consignes][
  - Le départ est un fichier vide. Écrivez-y `Hello World !`, enregistrez et quittez.
  - Refaites le kata jusqu’à ce que la boucle insertion, Échap, `:wq` soit un réflexe.
]

#lancer("1-survivre", "txt")

#f("dojo/1-survivre/attendu.txt")

#indice(titre: [Indice : la boucle de survie])[
  Vim démarre en mode normal : une touche y est une commande, pas un caractère. #d("vim-survivre")[Survivre :
  écrire, enregistrer, quitter] donne la boucle complète.
]

#corrige[
  #f("corrige/1-survivre.touches", lang: "text")
  Si Vim répond `E37` à `:q`, c’est que le fichier a changé depuis le dernier enregistrement : `:wq` enregistre
  et quitte, `:q!` quitte en jetant les modifications.
]

= Kata 2 : remplacer un caractère <kata-2>

#bloc(role: "question")[Consignes][
  - Le départ est le `~/.vimrc` de l’exercice du cours. Remplacez le 4 par un 2 *avec la touche `r`*, sans
    passer en mode insertion.
  - Ajoutez à la fin la ligne `syntax on`.
]

#lancer("2-vimrc", "vimrc")

#f("dojo/2-vimrc/depart.vimrc")
#f("dojo/2-vimrc/attendu.vimrc")

#indice(titre: [Indice : poser le curseur])[
  Une recherche place le curseur sur ce qu’elle trouve : `/4` puis Entrée. `r` remplace le seul caractère sous
  le curseur, et l’on reste en mode normal. `o` ouvre une ligne sous le curseur et passe en insertion.
]

#corrige[
  #f("corrige/2-vimrc.touches", lang: "text")
  C’est l’exercice fait en séance : #d("vim-exercice")[À vous : votre `~/.vimrc`]. Ici, le fichier n’est pas
  votre vraie configuration : `kata.vimrc` n’est lu par Vim que si vous le lui demandez (`vim -u kata.vimrc`).
]

= Kata 3 : naviguer, copier des lignes <kata-3>

#bloc(role: "question")[Consignes][
  - Ajoutez un serveur `web02` : copiez les trois lignes de `web01` à la fin du fichier, puis changez `web01` en
    `web02` dans la copie.
  - Revenez au début du fichier et ajoutez, sous `---`, la ligne de commentaire
    `# configuration de MonApplication sur web01 et web02`.
  - Servez-vous de `gg`, `G` et `/`, et d’une sélection en mode visuel ligne : pas de flèches.
]

#lancer("3-copier", "yaml")

#f("dojo/3-copier/depart.yaml")
#f("dojo/3-copier/attendu.yaml")

#indice(titre: [Indice : sélectionner, copier, coller])[
  `V` sélectionne la ligne du curseur, `j` étend la sélection d’une ligne, `y` copie ; `p` colle sous le
  curseur ce qui a été copié par lignes. `gg` et `G` mènent à la première et à la dernière ligne :
  #d("vim-deplacer")[Se déplacer en mode normal].
]
#indice(titre: [Indice : changer un mot])[
  `cw` supprime jusqu’à la fin du mot et passe en insertion : #d("vim-grammaire-config")[La grammaire à l’œuvre
  sur config.yaml]. Pour atteindre le mot, `fw` saute au prochain « w » de la ligne. `3yy`, à la place de `V2jy`,
  copie aussi trois lignes.
]

#corrige[
  #f("corrige/3-copier.touches", lang: "text")
  Après `p`, le curseur est sur la première ligne collée : c’est là que `fw` cherche le « w » de `web01`. Avec
  le `~/.vimrc` du cours, Vim indente selon le type du fichier ; le commentaire ajouté sous `---` reste en
  colonne 1, le résultat ne change pas.
]

= Kata 4 : rechercher et remplacer partout <kata-4>

#bloc(role: "question")[Consignes][
  - Le domaine de l’application change : remplacez `example.org` par `example.net` partout, en une commande.
  - Le dépôt d’une autre organisation, `example-org.fr`, ne doit pas changer.
]

#lancer("4-remplacer", "yaml")

#f("dojo/4-remplacer/depart.yaml")
#f("dojo/4-remplacer/attendu.yaml")

#indice(titre: [Indice : la commande])[
  `:%s/motif/remplacement/g` : `%` pour tout le fichier, `g` pour toutes les occurrences de chaque ligne :
  #d("vim-substituer")[Rechercher et remplacer : `:s`]. Regardez la ligne `miroirs` : combien d’occurrences y
  a-t-il ?
]
#indice(titre: [Indice : le piège])[
  Le motif est une expression régulière, où `.` vaut n’importe quel caractère, le tiret compris.
]

#corrige[
  #f("corrige/4-remplacer.touches", lang: "text")
  Sans `g`, la deuxième adresse de la ligne `miroirs` reste en `example.org`. Sans `\.`, le motif `example.org`
  trouve aussi `example-org` : le dépôt de l’autre organisation devient `example.net.fr`. `diff` montre l’une et
  l’autre erreur.
]

= Kata 5 : commenter, décommenter en colonne <kata-5>

#bloc(role: "question")[Consignes][
  - Rétablissez l’environnement `developpement`, mis en commentaire : retirez les deux colonnes `# ` de ses deux
    lignes, d’un seul geste.
  - Mettez en commentaire tout le bloc `serveurs`, ses quatre lignes, en ajoutant `# ` en tête de chacune, d’un
    seul geste.
]

#lancer("5-commenter", "yaml")

#f("dojo/5-commenter/depart.yaml")
#f("dojo/5-commenter/attendu.yaml")

#indice(titre: [Indice : le mode visuel bloc])[
  Ctrl+v sélectionne un rectangle : des colonnes, sur plusieurs lignes. `d` le supprime ; `I` insère du texte
  devant, sur chaque ligne, quand on revient au mode normal par Échap :
  #d("vim-visuel")[Les modes visuels : commenter un bloc].
]

#indice(titre: [Indice : le « \# » saute en retrait])[
  Avec certaines versions de Vim (9.1.0016, celle d’Ubuntu 24.04), le greffon d’indentation YAML replace la ligne en
  retrait dès qu’on tape `#` en début de ligne : les quatre lignes du bloc se retrouvent décalées. Annulez (`u`) et
  interdisez-lui ce réflexe avec `:set indentkeys-=0#` avant de commenter. Le Vim de Debian 13 (9.1.1230) ne le fait pas.
]

#corrige[
  #f("corrige/5-commenter.touches", lang: "text")
  Pendant la frappe, `# ` n’apparaît que sur la première ligne du bloc ; Échap le recopie sur les trois autres.
  La ligne `:set indentkeys-=0#` n’est utile qu’avec le Vim d’Ubuntu 24.04 (9.1.0016) ; sur Debian 13 (9.1.1230), `0#` n’est plus dans `indentkeys` : elle ne change rien, et le corrigé réussit des deux côtés.
  Le fichier reste un YAML valide : yq n’y lit plus de clé `serveurs`.
]

= Kata 6 : corriger un texte <kata-6>

#bloc(role: "question")[Consignes][
  - Corrigez le texte, à la manière des leçons de `vimtutor` : un mot en double, un `a` qui doit être un `à`,
    une ligne en trop, deux caractères en trop, une fin de phrase qui manque, un mot à changer.
  - Le moins possible en mode insertion : `x`, `dw`, `dd`, `r`, `A`, `cw`.
]

#lancer("6-corriger", "txt")

#f("dojo/6-corriger/depart.txt")
#f("dojo/6-corriger/attendu.txt")

#indice(titre: [Indice : les commandes])[
  `x` supprime le caractère sous le curseur, `dw` jusqu’au début du mot suivant, `dd` la ligne ; `r` remplace un
  caractère, `A` ajoute en fin de ligne, `cw` change un mot. `u` annule la dernière modification.
]

#corrige[
  #f("corrige/6-corriger.touches", lang: "text")
  `dw` sur le premier « des » emporte aussi l’espace qui le suit : il reste un seul « des ». `rà` remplace un
  caractère par un caractère accentué, dans un fichier en UTF-8.
]

= Pour aller plus loin : vimtutor <vimtutor>

#bloc(role: "question")[Consignes][
  - Lancez `vimtutor` (en français : `vimtutor fr`) et faites le tutoriel en entier, une demi-heure environ.
  - Refaites-le chaque jour jusqu’à ce qu’aucune étape ne vous ralentisse ; refaites aussi les katas, en
    comptant vos touches.
  - Puis servez-vous de Vim tous les jours : #d("vim-entrainer")[S’entraîner, chaque jour].
]

#terminal[```console
$ vimtutor fr
```]

#note(role: "pratique")[`vimtutor` n’a pas de corrigé : c’est un fichier que l’on modifie en suivant ses propres
consignes, et chaque leçon dit ce que l’on doit voir. Il est fourni avec le paquet `vim`, pas avec `vim-tiny`.]
