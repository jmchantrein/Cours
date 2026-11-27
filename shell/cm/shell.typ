// Cours « Fondements de l’administration système GNU/Linux » (anciennement « Shell : Bash, sed et awk ») — Typst + Touying.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts shell/cm/shell.typ build/shell/shell.pdf
// Une diapo = un titre `==` ; une section (surtitre bleu) = un titre `=`.
// Structure : règles de .claude/skills/structurer-diapos-cours ; apparence : charte de commun/.
// Sorties : rejouées dans un conteneur debian:13-slim (bash 5.2.37, GNU sed 4.9, mawk 1.3.4, ShellCheck 0.10.0, Bats 1.11.1) par shell/cm/rejouer.sh ;
// les fichiers montrés sur les diapos sont ceux de shell/cm/exemples/, lus tels quels.

#import "../../commun/theme-cours.typ": *

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Fondements de l’administration système GNU/Linux],
)

// Un fichier d’exemple, affiché tel qu’il est dans exemples/ (celui que rejouer.sh exécute).
#let fichier-ex(nom, taille: px(18), hauteur: auto) = fichier(nom, taille: taille, hauteur: hauteur,
  raw(read("exemples/" + nom).trim(at: end), block: true, lang: none))
// Version des outils, rappelée dans les notes de l’orateur.
#let versions = [Sortie réelle : conteneur debian:13-slim (Debian 13.8), bash 5.2.37, locale C.UTF-8 (messages en anglais), rejouée par shell/cm/rejouer.sh.]

#couverture(illustration: "tube", surtitre: "Cours · le shell Bash, sed et awk")[Fondements][de l’administration système #box[GNU/Linux]][Jean-Mathieu Chantrein][25 novembre 2026]
#speaker-note[Cours tiré des parties Bash, sed et awk du cours « Outils de l’administration système » (sources/outils\_admin\_sys/partie\_1) et des scripts d’exploration « subtilités de Bash ».]

// ======================================================================
= Sommaire

== Plan du cours

#slide[#plan-cours(
  ([Bash : les bases], [Lire une commande et `ls -l`, flux et tubes, variables, tests, boucles]),
  ([Bash : guillemets et expansions], [Ce que Bash fait de la ligne avant de l’exécuter]),
  ([Bash : des scripts robustes], [Exécuter, recevoir des arguments, cron, `set -euo pipefail`, ShellCheck, Bats, portée de `local`]),
  ([sed et awk], [Le cycle de sed, le modèle d’awk, sur un même fichier de données]),
  ([Annexe, puis pour rappel], [Mémo des guillemets, pour aller plus loin ; l’essentiel du cours]),
)
  #speaker-note[Un exercice fait en séance dans chaque partie. Les TP et les artefacts reprennent les diapositives étiquetées (ordre des expansions, redirections, cycle de sed, modèle d’awk).]
]

// ======================================================================
= Bash · Les bases

== Bash, sed, awk : à quoi ils servent

// Un élément d’une scène qui paraît au clic d (avant : caché, sa place gardée).
#let des(k, d, x) = if k >= d { x } else { hide(x) }
// Contexte : la colonne de gauche (voir contexte dans commun/theme-cours.typ), autour de ~/atelier (31 fichiers
// d’exemple, copiés de shell/cm/exemples/) ou d’un répertoire voisin. ctx(chemin, contenu, voir, absent, autres,
// variables) dessine l’arbre depuis ~ : les répertoires du chemin, le contenu montré du répertoire courant (un nom
// qui finit par / est un répertoire), ce qui manque (barré) et une ligne grise pour les autres.
#let ctx(chemin: "/home/ada/atelier", contenu: (), voir: (), absent: (), autres: 0, variables: ()) = {
  let segs = chemin.split("/").filter(x => x != "").slice(2)  // après /home/ada
  let entree(x) = if x.ends-with("/") { (x.slice(0, -1), ()) } else { x }
  let noeud = (segs.last(), contenu.map(entree) + absent.map(x => "- " + x)
    + if autres > 0 { ("+ " + str(autres) + if autres > 1 { " autres" } else { " autre" },) } else { () })
  for (i, sg) in segs.slice(0, -1).enumerate().rev() {
    // un répertoire au-dessus du courant : atelier y garde ses 31 fichiers, comptés
    noeud = (sg, (noeud, ..if sg == "atelier" { ("+ 31 autres",) } else { () }))
  }
  let ada = (noeud, ..if segs.first() != "atelier" { (("atelier", ()),) } else { () })
  let plein(x) = if x.starts-with("$") { x } else { chemin + "/" + x.trim("/", at: end) }
  contexte(("/", (("home", (("ada", ada),)),)), courant: chemin, depuis: "/home/ada", voir: voir.map(plein),
    variables: variables, etiquettes: ("/home/ada": raw("~")))
}
#let atelier(contenu: ("pionnieres.csv",), total: 31, ..args) = ctx(chemin: "/home/ada/atelier",
  contenu: contenu, autres: total - contenu.len(), ..args)
#let _conf = read("exemples/services.conf").trim(at: end).split("\n")
#let _conf-no = _conf.map(l => l.replace("autostart = yes", "autostart = no"))
#anime(
  scene(3, k => schema-etats(hauteur: 500, etape: k, taille: px(21),
    noeuds: (
      term: (x: 0, y: 0, l: 840, h: 240, genre: "terminal", titre: "Terminal", contenu: ()),
      conf: (x: 900, y: 0, l: 764, h: 500, genre: "fichier", titre: "services.conf", contenu: _conf, taille: px(20)),
      txt: (x: 0, y: 280, l: 840, genre: "texte", taille: px(27), contenu: [Sur un serveur, sans interface graphique, la configuration est du texte : on la lit et on la modifie avec des commandes.]),
    ),
    etats: (
      (:),
      (noeuds: (
        term: (contenu: ("$ sed -i 's/autostart = yes/autostart = no/' services.conf",)),
        conf: (contenu: _conf-no, marque: (4, 9)),
        txt: (contenu: [*sed* remplace du texte dans le fichier, sans l’ouvrir dans un éditeur : les deux `yes` deviennent `no`.]),
      )),
      (noeuds: (
        term: (contenu: ("$ sed -i 's/autostart = yes/autostart = no/' services.conf",
          "$ awk '$1 == \"port\" { print $3 }' services.conf", "8080", "5432", "0")),
        conf: (marque: (2, 7, 12)),
        txt: (contenu: [*awk* découpe chaque ligne en champs : sur les lignes dont le 1#super[er] champ est `port`, il affiche le 3#super[e].]),
      )),
    ),
  )),
  note(role: "retenir", taille: px(24))[*Bash* lit et lance ces commandes, les enchaîne par des tubes et les range dans des scripts. Objectifs : composer de petits outils, comprendre ce que Bash fait de la ligne, écrire des scripts robustes (ShellCheck, Bats), transformer du texte avec sed et awk.],
  source-de: link("https://www.gnu.org/software/bash/manual/bash.html")[GNU, Bash Reference Manual],
  note: [#versions Un clic par outil, sur le même fichier, montré avant et après. Les sorties sont réelles (session « À quoi servent sed et awk » de rejouer.sh) ; sed et awk sont détaillés dans la dernière partie. Bash (Bourne Again SHell, GNU) : le shell interactif par défaut de Debian et d’Ubuntu ; sed (stream editor) ; awk, un langage pour les fichiers en colonnes, comme les exports CSV (comma-separated values). On s’en sert pour automatiser les tâches répétitives (sauvegardes, comptes, installations) et traiter configurations, journaux et exports, souvent sur un serveur distant. Sur Debian, /bin/sh est dash (un shell POSIX plus léger, pour les scripts système) ; le shell de connexion des utilisateurs est bash. Sous macOS, le shell par défaut est zsh depuis Catalina (2019) : les scripts de ce cours commencent par \#!/bin/bash et s’exécutent avec bash.],
)

== Le fil rouge : pionnieres.csv <fil-rouge>

#let _l = read("exemples/pionnieres.csv").trim(at: end).split("\n")
#anime(
  contexte: atelier(voir: ("pionnieres.csv",)),
  commande-annotee(taille: px(21),
    ("$ ls pionnieres.csv", "pionnieres.csv", ("$ cat pionnieres.csv", 2), .._l.map(x => (x, 2))),
    annote((ligne: 1, texte: "pionnieres.csv"), cote: "droite", clic: 1, legende: [`ls` le trouve : le fichier existe]),
    annote((ligne: 3, texte: _l.at(0)), cote: "droite", clic: 3, reste: true, legende: [la première ligne, l’en-tête, nomme les colonnes]),
    annote((ligne: 11, texte: ";"), clic: 4, legende: [`;` sépare les colonnes]),
    annote((ligne: 11, texte: "1982"), clic: 5, legende: [colonne 2 : `annee`]),
    annote((ligne: 11, texte: "cryptographie"), clic: 6, legende: [colonne 3 : `domaine`]),
  ),
  note: [#versions D’abord l’existence du fichier (ls), puis son contenu (cat), puis sa structure : un clic par élément. La colonne de gauche dit où l’on est : le répertoire de travail \~/atelier, qui contient les 31 fichiers d’exemple du cours (ls | wc -l) ; les TP le fournissent. Le fichier vient du dojo sed et awk du site (écrit pour lui, sans droits tiers) : 9 lignes, l’en-tête et 8 pionnières. « materiel » et « reseau » sont écrits sans accent exprès : l’exercice sed les corrige. Les lignes ne sont pas triées par année (Goldwasser après Perlman), exprès aussi : le tri sert dans l’exercice des tubes. Les colonnes n’ont pas de largeur fixe : seul le ; les sépare.],
)

== Décoder une ligne de ls -l <ls-l>

#let _ls = (
  "-rw-r--r-- 1 ada ada        474 Nov 25 09:53 pionnieres.csv",
  "-rwxr-x--- 1 ada etudiants  174 Nov 25 09:53 sauvegarde.sh",
  "drwxr-xr-x 2 ada ada       4096 Nov 25 10:01 scripts",
)
#let demo(..args) = ctx(chemin: "/home/ada/demo", contenu: ("pionnieres.csv", "sauvegarde.sh", "scripts/"), ..args)
#anime(
  contexte: demo(voir: ("sauvegarde.sh",)),
  scene(7, k => stack(spacing: px(20),
    terminal-annote(etape: k, taille: px(21), ("$ ls -l", "total 12", .._ls),
      annote((ligne: 3, texte: _ls.at(1)), clic: 2, garde: true)),
    des(k, 2, terminal-annote(etape: k, taille: px(31), (_ls.at(1),),
      annote((0, 1), cote: "haut", clic: 3, legende: [type : `-` fichier ordinaire, `d` répertoire]),
      annote("rwxr-x---", clic: 4, legende: [les droits : trois triplets (diapositive suivante)]),
      annote(" 1 ", clic: 5, legende: [nombre de liens]),
      annote("174", cote: "haut", clic: 6, legende: [taille en octets]),
      annote("Nov 25 09:53", "sauvegarde.sh", cote: "haut", clic: 7, legende: [dernière modification, puis le nom]),
    )),
  )),
  source-de: link("https://www.gnu.org/software/coreutils/manual/html_node/What-information-is-listed.html")[GNU coreutils, What information is listed],
  note: [#versions La ligne de sauvegarde.sh est agrandie dessous, puis décodée un champ par clic ; propriétaire et groupe sont à la diapositive suivante, avec les droits qui les concernent. Le répertoire \~/demo est préparé pour l’exemple (session « Décoder ls -l » de rejouer.sh) ; le groupe etudiants est créé pour lui (groupadd, puis chgrp). Dans un terminal en français, la date s’écrit « nov. 25 09:55 ». Pour un lien symbolique, le type est l. Le nombre de liens d’un répertoire compte ses sous-répertoires plus deux (lui-même et « . »).],
)

== Les droits : trois triplets, pour trois classes

#anime(
  contexte: demo(voir: ("sauvegarde.sh",)),
  commande-annotee(taille: px(31), (_ls.at(1),),
    annote("rwx", clic: 2, reste: true, legende: [#pastille(1) lire (`r`), écrire (`w`), exécuter (`x`)]),
    annote("ada", cote: "haut", clic: 2, reste: true, legende: [#pastille(1) le propriétaire]),
    annote("r-x", clic: 3, reste: true, legende: [#pastille(2) lire, exécuter ; `-` : droit absent]),
    annote("etudiants", cote: "haut", clic: 3, reste: true, legende: [#pastille(2) les membres du groupe]),
    annote("---", clic: 4, reste: true, legende: [#pastille(3) tous les autres : aucun droit]),
  ),
  note: [#versions Un triplet par clic, avec la classe d’utilisateurs qu’il concerne : le même numéro relie le triplet (sous la ligne) et la classe (au-dessus). Pour un utilisateur donné, un seul triplet compte : celui du propriétaire s’il l’est, sinon celui du groupe s’il en est membre, sinon celui des autres. Sur un répertoire, x donne le droit de le traverser, w celui d’y créer ou d’y supprimer des noms.],
)

== À vous : décoder ls -l <exercice-ls-l>

#anime(
  contexte: demo(),
  rang(bloc(role: "question", revele: "bloc")[À vous][
    + Sur la ligne de `scripts` : qui peut y *entrer* (`cd`), qui peut y *créer* un fichier ?
    + Un membre du groupe etudiants peut-il *modifier* `sauvegarde.sh` ? *L’exécuter* ?
    + Un autre utilisateur peut-il *lire* `pionnieres.csv` ?
    + Quels droits donne `chmod 640 pionnieres.csv` ? (r = 4, w = 2, x = 1)
  ]),
  rang(bloc(role: "pratique", taille: px(24))[La sortie de ls -l][
    #terminal(titre: none, taille: px(22), raw(_ls.join("\n"), block: true))
  ]),
  note: [À faire en direct, une question par clic. Laisser chercher avant de passer au corrigé. Sur un répertoire, x donne le droit de le traverser (y entrer, atteindre ses fichiers), w celui d’y créer ou d’y supprimer des noms, à condition d’avoir aussi x.],
)

== Décoder ls -l : corrigé

// Une ligne de ls -l, ses triplets utiles encadrés : la démonstration d’une réponse.
#let preuve(lignes, ..morceaux, texte) = stack(spacing: px(8),
  terminal-annote(taille: px(20), lignes, ..morceaux.pos().map(m => annote(m, garde: true))),
  text(size: px(24), texte))
#corriges(contexte: demo(), note: [La question reste affichée ; un clic par réponse, avec la ligne qui la démontre, triplets en cause encadrés. Octal : chaque chiffre est la somme des droits d’une classe. #versions],
  (1, [Sur `scripts` : qui peut y entrer, qui peut y créer un fichier ?],
    reponse(preuve((_ls.at(2),), "rwx", (ligne: 0, texte: "r-x", n: 1), (ligne: 0, texte: "r-x", n: 2))[
      Tout le monde y entre (`x` dans les trois triplets) ; seule ada y crée des fichiers (`w` pour le propriétaire seulement).])),
  (2, [Un membre d’etudiants peut-il modifier `sauvegarde.sh` ? L’exécuter ?],
    reponse(preuve((_ls.at(1),), "r-x", "etudiants")[
      Groupe `r-x` : pas de modification (`w` absent), mais l’exécution est permise.])),
  (3, [Un autre utilisateur peut-il lire `pionnieres.csv` ?],
    reponse(preuve((_ls.at(0),), (ligne: 0, texte: "r--", n: 2))[Oui : les autres ont `r--`.])),
  (4, [Quels droits donne `chmod 640 pionnieres.csv` ?],
    reponse(preuve(("$ chmod 640 pionnieres.csv", "$ ls -l pionnieres.csv", "-rw-r----- 1 ada ada 474 Nov 25 09:53 pionnieres.csv"),
        (ligne: 2, cols: (1, 4)), (ligne: 2, cols: (4, 7)), (ligne: 2, cols: (7, 10)))[
      6 = 4 + 2 : `rw-` ; 4 : `r--` ; 0 : `---`.])),
)

// ----------------------------------------------------------------------
= Bash · Flux et tubes

== Trois flux par processus <flux-standards>

// Les schémas de cette section : un processus et ses trois prises, le clavier, le terminal ; 2 en tirets.
#let clavier = (x: 0, y: 200, l: 210, h: 110, titre: [Clavier])
#let erreur-ls = "ls: cannot access 'absent.txt': No such file or directory"
#anime(
  scene(3, k => schema-etats(hauteur: 560, etape: k, taille: px(24),
    noeuds: (
      ls: (x: 340, y: 130, l: 260, h: 250, genre: "processus", titre: "ls", sous: [un processus]),
      txt: (x: 0, y: 430, l: 1664, genre: "texte", taille: px(28), contenu: [Chaque processus naît avec trois flux numérotés : *0*, l’entrée standard (_stdin_) : ce qu’il lit ; *1*, la sortie standard (_stdout_) : ses résultats ; *2*, l’erreur standard (_stderr_) : ses messages d’erreur.]),
    ),
    etats: (
      (:),
      (noeuds: (
        clavier: clavier,
        ecran: (x: 920, y: 140, l: 744, h: 230, genre: "terminal", titre: "Terminal", taille: px(20), contenu: ()),
        txt: (contenu: [Au lancement, le shell branche 0 sur le clavier, 1 et 2 sur l’écran du terminal.]),
      ), liens: (
        e0: (de: "clavier", vers: "ls.0"),
        s1: (de: "ls.1", vers: "ecran.g", etiquette: [1 : sortie], pos: 0.45),
        s2: (de: "ls.2", vers: "ecran.g", etiquette: [2 : erreur], pos: 0.45, tirets: true),
      )),
      (noeuds: (
        ecran: (contenu: ("$ ls pionnieres.csv absent.txt", erreur-ls, "pionnieres.csv")),
        txt: (contenu: [ls écrit le nom trouvé sur 1, le message d’erreur sur 2 : à l’écran, rien ne distingue les deux lignes.]),
      ), liens: (
        s1: (etiquette: none, donnee: raw("pionnieres.csv"), pos-donnee: 0.45),
        s2: (etiquette: none, donnee: [message d’erreur], pos-donnee: 0.45),
      )),
    ),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Redirections.html")[Bash Reference Manual, Redirections],
  note: [#versions Un clic : le processus seul ; les branchements par défaut ; l’exécution, avec sur chaque fil ce qu’il porte. ls écrit d’abord ses erreurs (les noms introuvables), puis la liste. Un descripteur de fichier est le numéro sous lequel un processus désigne un fichier ouvert ; 0, 1 et 2 sont ouverts dès sa naissance, hérités du shell qui l’a lancé. Le flux 2 est dessiné en tirets dans tout le cours. ls ne lit pas son entrée standard : elle reste branchée, inutilisée.],
)

== Rediriger 1 ou 2 vers un fichier : > et 2> <redirections>

// Fichier au-dessus du terminal pour 1, au-dessous pour 2 : les fils ne se croisent pas.
#let ls-base = (x: 170, y: 160, l: 200, h: 240, genre: "processus", titre: "ls")
#let fichier-haut = (x: 540, y: 0, l: 672, h: 100, genre: "fichier", taille: px(18))
#let _cmd1 = "$ ls pionnieres.csv absent.txt > sortie.txt"
#anime(
  contexte: k => atelier(contenu: ("pionnieres.csv", ..if k >= 2 { ("sortie.txt",) }, ..if k >= 5 { ("erreurs.txt",) }),
    total: 31 + (if k >= 2 { 1 } else { 0 }) + (if k >= 5 { 1 } else { 0 }),
    voir: if k >= 5 { ("erreurs.txt",) } else if k >= 2 { ("sortie.txt",) } else { () }, absent: ("absent.txt",)),
  scene(5, k => schema-etats(hauteur: 590, etape: k, taille: px(24),
    noeuds: (
      clavier: (..clavier, y: 225, l: 120), ls: ls-base,
      ecran: (x: 540, y: 125, l: 672, h: 330, genre: "terminal", titre: "Terminal", taille: px(18), contenu: ()),
      txt: (x: 0, y: 470, l: 400, genre: "texte", taille: px(26), contenu: [Au départ, 1 et 2 vont à l’écran.]),
    ),
    liens: (
      e0: (de: "clavier", vers: "ls.0"),
      s1: (de: "ls.1", vers: "ecran.g"),
      s2: (de: "ls.2", vers: "ecran.g", tirets: true),
    ),
    etats: (
      (:),
      (noeuds: (
        ecran: (contenu: (_cmd1,)),
        sortie: (..fichier-haut, titre: "sortie.txt", contenu: ()),
        txt: (contenu: [Avant de lancer ls, Bash branche 1 sur `sortie.txt` : il le crée, ou le vide s’il existe.]),
      ), liens: (s1: (vers: "sortie.g", etiquette: raw("> sortie.txt"))),
      ),
      (noeuds: (
        ecran: (contenu: (_cmd1, erreur-ls)),
        sortie: (contenu: ("pionnieres.csv",)),
        txt: (contenu: [ls s’exécute : le nom part dans le fichier, l’erreur reste à l’écran.]),
      )),
      (noeuds: (
        ecran: (contenu: (_cmd1, erreur-ls, "$ cat sortie.txt", "pionnieres.csv")),
        txt: (contenu: [`cat` affiche le fichier : il contient la sortie de ls.]),
      )),
      (noeuds: (
        ecran: (contenu: (_cmd1, erreur-ls, "$ cat sortie.txt", "pionnieres.csv",
          "$ ls pionnieres.csv absent.txt 2> erreurs.txt", "pionnieres.csv")),
        erreurs: (x: 540, y: 480, l: 672, h: 100, genre: "fichier", taille: px(18), titre: "erreurs.txt", contenu: (erreur-ls,)),
        txt: (contenu: [`2> erreurs.txt` : c’est 2, cette fois, qui part dans un fichier ; 1 reste à l’écran.]),
      ), liens: (
        s1: (vers: "ecran.g", etiquette: none),
        s2: (vers: "erreurs.g", etiquette: raw("2> erreurs.txt"), pos: 0.55),
      )),
    ),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Redirections.html")[Bash Reference Manual, Redirections],
  note: [#versions Un clic par étape, numérotée sur le schéma et devant sa légende : Bash branche, puis ls s’exécute ; cat montre le fichier ; puis 2>, branché et exécuté d’un même clic. La colonne de gauche montre sortie.txt, puis erreurs.txt, apparaître dans le répertoire. L’ancien branchement reste en pointillé au clic où il change. Une redirection s’écrit n’importe où dans la commande, mais par convention à la fin. > est l’abréviation de 1>. Si sortie.txt existait, son contenu serait perdu (diapositives suivantes).],
)

== Ajouter ou lire : >> et <

#anime(
  contexte: k => atelier(contenu: ("pionnieres.csv", "sortie.txt", "sauvegarde.sh"), total: 32,
    voir: if k <= 3 { ("sortie.txt",) } else { ("pionnieres.csv",) }),
  scene(5, k => schema-etats(hauteur: 590, etape: k, taille: px(24),
    noeuds: (
      clavier: (..clavier, y: 125, l: 120), ls: (..ls-base, y: 60),
      sortie: (..fichier-haut, h: 150, titre: "sortie.txt", contenu: ("pionnieres.csv",)),
      ecran: (x: 540, y: 180, l: 672, h: 230, genre: "terminal", titre: "Terminal", taille: px(19),
        contenu: ("$ ls pionnieres.csv > sortie.txt",)),
      txt: (x: 540, y: 440, l: 672, genre: "texte", taille: px(26), contenu: [Un premier `ls … > sortie.txt` y a écrit un nom.]),
    ),
    liens: (
      e0: (de: "clavier", vers: "ls.0"),
      s1: (de: "ls.1", vers: "sortie.g", etiquette: raw("> sortie.txt")),
      s2: (de: "ls.2", vers: "ecran.g", tirets: true),
    ),
    etats: (
      (:),
      (noeuds: (
        ecran: (contenu: ("$ ls sauvegarde.sh >> sortie.txt", "$ cat sortie.txt", "pionnieres.csv", "sauvegarde.sh")),
        sortie: (contenu: ("pionnieres.csv", "sauvegarde.sh")),
        txt: (contenu: [`>>` ajoute à la fin du fichier : l’ancien contenu reste.]),
      ), liens: (s1: (etiquette: raw(">> sortie.txt")))),
      (noeuds: (
        ecran: (contenu: ("$ ls sauvegarde.sh > sortie.txt", "$ cat sortie.txt", "sauvegarde.sh")),
        sortie: (contenu: ("sauvegarde.sh",)),
        txt: (contenu: [`>` vide le fichier, puis écrit : l’ancien contenu est perdu.]),
      ), liens: (s1: (etiquette: raw("> sortie.txt")))),
      (noeuds: (
        ls: (titre: "wc"),
        ecran: (contenu: ("$ wc -l pionnieres.csv", "9 pionnieres.csv")),
        sortie: none,
        csv: (x: 0, y: 420, l: 470, h: 120, genre: "fichier", titre: "pionnieres.csv", pied: [9 lignes], taille: px(19),
          contenu: ("nom;annee;domaine;contribution", "# …"), ports: (arg: ("h", 0.8), entree: ("h", 0.3))),
        txt: (contenu: [Avec un argument, `wc` ouvre lui-même le fichier : il en connaît le nom, et l’affiche.]),
      ), liens: (
        s1: (vers: "ecran.g", etiquette: none),
        arg: (de: "csv.arg", vers: "ls.b", etiquette: [argument], motif: "dash-dotted"),
      )),
      (noeuds: (
        ecran: (contenu: ("$ wc -l pionnieres.csv", "9 pionnieres.csv", "$ wc -l < pionnieres.csv", "9")),
        txt: (contenu: [`< pionnieres.csv` : Bash branche 0 sur le fichier ; `wc` lit son entrée standard, sans en connaître le nom.]),
      ), liens: (
        e0: (de: "csv.entree", etiquette: raw("< pionnieres.csv"), pos: 0.45),
        arg: none,
      )),
    ),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Redirections.html")[Bash Reference Manual, Redirections],
  note: [#versions Le fichier change à chaque clic : ajout (>>), écrasement (>), puis l’entrée standard rebranchée (<). Le premier ls … > sortie.txt est joué juste avant (shell/cm/rejouer.sh, session « Ajouter, écraser, lire »). Le fichier pionnieres.csv est montré par son en-tête seulement : son contenu complet est sur la diapositive du fil rouge.],
)

== L’ordre des redirections compte <ordre-redirections>

// Un scénario : la commande, dont chaque redirection est pointée à son clic, et son effet sur les flux de ls.
#let scenario(k, d, commande, annotations, etats) = grid(columns: (1fr, px(1010)), column-gutter: px(24), align: horizon,
  terminal-annote(etape: k - d + 1, taille: px(20), (commande,), ..annotations),
  schema-etats(hauteur: 255, etape: k - d + 1, taille: px(22),
    noeuds: (
      ls: (x: 0, y: 30, l: 200, h: 195, genre: "processus", titre: "ls"),
      ecran: (x: 340, y: 145, l: 670, h: 110, genre: "terminal", titre: "Écran", taille: px(18), contenu: ()),
    ),
    liens: (
      s1: (de: "ls.1", vers: "ecran.g"),
      s2: (de: "ls.2", vers: "ecran.g", tirets: true),
    ),
    etats: etats))
// le fichier au-dessus de l’écran : 1 (prise du haut) monte vers lui, 2 descend vers l’écran, sans croisement
#let fichier-sortie = (x: 340, y: 0, l: 670, h: 110, genre: "fichier", titre: "sortie.txt", taille: px(18), contenu: ())
#anime(
  scene(9, k => stack(spacing: px(12),
    scenario(k, 1, "$ ls pionnieres.csv absent.txt > sortie.txt 2>&1", (
      annote("> sortie.txt", clic: 2, cote: "haut", legende: [#pastille(1) 1 → `sortie.txt`]),
      annote("2>&1", clic: 3, legende: [#pastille(2) 2 → où va 1 *maintenant* : `sortie.txt`]),
      annote("ls", clic: 4, cote: "haut", legende: [#pastille(3) ls s’exécute]),
      ), ((:),
       (noeuds: (sortie: fichier-sortie), liens: (s1: (vers: "sortie.g"))),
       (liens: (s2: (vers: "sortie.g"))),
       (noeuds: (sortie: (contenu: (erreur-ls, "pionnieres.csv")), ecran: (contenu: ("# (rien)",))))),
    ),
    des(k, 5, line(length: 100%, stroke: px(2) + c.filet)),
    des(k, 5, scenario(k, 5, "$ ls pionnieres.csv absent.txt 2>&1 > sortie.txt", (
      annote("2>&1", clic: 2, cote: "haut", legende: [#pastille(1) 2 → où va 1 *maintenant* : l’écran ; rien ne bouge]),
      annote("> sortie.txt", clic: 3, legende: [#pastille(2) 1 → `sortie.txt` ; 2 reste à l’écran]),
      ), ((:),
       (liens: (s2: (vers: "ecran.g"))),
       (noeuds: (sortie: fichier-sortie), liens: (s1: (vers: "sortie.g"))),
       (noeuds: (sortie: (contenu: ("pionnieres.csv",)), ecran: (contenu: (erreur-ls,))))),
    )),
    des(k, 9, note(role: "retenir", taille: px(24))[Bash applique les redirections de gauche à droite, avant de lancer la commande ; `2>&1` copie la destination de 1 *à cet instant*. Pour tout envoyer dans un fichier : `commande > fichier 2>&1`, dans cet ordre.]),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Redirections.html")[Bash Reference Manual, Redirections],
  note: [#versions Quatre clics par commande : l’état de départ, chaque redirection dans l’ordre où Bash la lit, puis l’exécution (étape 3, la même pour la seconde commande) ; ce que montrent l’écran et sortie.txt est la sortie réelle (cat sortie.txt après chaque commande). Le manuel de Bash donne exactement cet exemple (section REDIRECTION, « Note that the order of redirections is significant »). 2>&1 se lit « le descripteur 2 devient une copie du descripteur 1 », pas « 2 va vers 1 pour toujours ».],
)

== > vide le fichier avant de lancer la commande <troncature>

#let _tri = (
  "Booth Kathleen;1947;langages;premier langage d'assemblage",
  "Conway Lynn;1978;materiel;révolution VLSI",
  "Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste",
  "Hamilton Margaret;1969;logiciel;logiciel embarqué d'Apollo 11",
  "Hopper Grace;1952;langages;premier compilateur A-0",
  "Johnson Katherine;1962;calcul;trajectoires de Friendship 7",
  "Lovelace Ada;1843;programmation;premier programme publié",
  "Perlman Radia;1985;reseau;protocole spanning tree",
  "nom;annee;domaine;contribution",
)
#anime(
  scene(4, k => schema-etats(hauteur: 600, etape: k, taille: px(24),
    noeuds: (
      term: (x: 0, y: 0, l: 470, h: 390, genre: "terminal", titre: "Terminal", taille: px(19),
        contenu: ("$ cp pionnieres.csv copie.csv", "$ wc -c copie.csv", "474 copie.csv")),
      copie: (x: 900, y: 0, l: 764, h: 390, genre: "fichier", titre: "copie.csv", pied: [474 octets], contenu: _l,
        taille: px(19), ports: (ecrit: ("g", 0.3), lu: ("g", 0.85))),
      txt: (x: 0, y: 440, l: 1664, genre: "texte", taille: px(28), contenu: [`copie.csv` : une copie du fil rouge, 474 octets.]),
    ),
    etats: (
      (:),
      (noeuds: (
        term: (contenu: ("$ cp pionnieres.csv copie.csv", "$ wc -c copie.csv", "474 copie.csv", "$ sort copie.csv > copie.csv")),
        sort: (x: 500, y: 70, l: 230, h: 210, genre: "processus", titre: "sort", sous: [pas lancé], attente: true),
        copie: (contenu: (), pied: [0 octet]),
        txt: (contenu: [Bash prépare `> copie.csv` : il ouvre le fichier en écriture, ce qui le *vide*, avant que sort démarre.]),
      ), liens: (s1: (de: "sort.1", vers: "copie.ecrit", etiquette: raw("> copie.csv")))),
      (noeuds: (
        term: (contenu: ("$ cp pionnieres.csv copie.csv", "$ wc -c copie.csv", "474 copie.csv", "$ sort copie.csv > copie.csv",
          "$ wc -c copie.csv", "0 copie.csv")),
        sort: (attente: false, sous: [lit du vide]),
        txt: (role: "danger", taille: px(26), contenu: [sort lit un fichier déjà vide et n’écrit rien : les données sont perdues. Ne jamais rediriger vers le fichier qu’on lit.]),
      ), liens: (lit: (de: "copie.lu", vers: "sort.b", etiquette: [lit son argument], motif: "dash-dotted"))),
      (noeuds: (
        term: (contenu: ("$ cp pionnieres.csv copie.csv", "$ sort -o copie.csv copie.csv", "$ wc -c copie.csv", "474 copie.csv")),
        sort: (sous: [lit tout, écrit]),
        copie: (contenu: _tri, pied: [474 octets, triés]),
        txt: (role: none, taille: px(28), contenu: [`sort -o copie.csv` : sort lit toute son entrée, puis écrit lui-même le fichier ; il est trié.]),
      ), liens: (
        s1: (de: "sort.d", vers: "copie.ecrit", etiquette: raw("-o copie.csv")),
        lit: (fort: false),
      )),
    ),
  )),
  source-de: link("https://www.gnu.org/software/coreutils/manual/html_node/sort-invocation.html")[GNU coreutils, sort invocation],
  note: [#versions Sur une copie, pour ne pas perdre le fil rouge. Un clic : la copie ; Bash prépare la redirection (sort n’a pas démarré) ; sort s’exécute ; la bonne manière. GNU sort lit toute son entrée avant d’écrire : -o peut désigner le fichier d’entrée (documenté dans le manuel de coreutils). Pour les autres commandes : écrire dans un fichier temporaire, puis mv. set -o noclobber fait refuser > sur un fichier existant (>| force). En locale C.UTF-8, les majuscules passent avant les minuscules : l’en-tête « nom;… » finit en dernier.],
)

== Le tube branche une sortie sur une entrée <tubes>

#let _f3 = ("domaine", "programmation", "langages", "langages", "calcul", "logiciel", "materiel", "reseau", "cryptographie")
#let _f3-tri = ("calcul", "cryptographie", "domaine", "langages", "langages", "logiciel", "materiel", "programmation", "reseau")
#let _f3-uniq = ("1 calcul", "1 cryptographie", "1 domaine", "2 langages", "1 logiciel", "1 materiel", "1 programmation", "1 reseau").map(x => "      " + x)
#let _f3-fin = ("2 langages", "1 reseau", "1 programmation", "1 materiel", "1 logiciel", "1 domaine", "1 cryptographie", "1 calcul").map(x => "      " + x)
#let _tube = (x, titre) => (x: x + 40, y: 66, l: 210, h: 84, genre: "processus", titre: titre, taille-titre: px(30),
  ports: ("0": ("g", 0.5), "1": ("d", 0.5), arg: ("h", 0.3)))
#let _flux = (x, contenu, genre: "flux") => (x: x, y: 180, l: 300, h: 275, genre: genre, contenu: contenu, taille: px(20))
#let _barre = text(size: px(34), weight: 700, raw("|"))
#anime(
  scene(6, k => stack(spacing: px(18),
    terminal-annote(etape: k, taille: px(26),
      ((("$ cut -d';' -f3 pionnieres.csv", 1), (" | sort", 3), (" | uniq -c", 4), (" | sort -rn", 5)),),
      annote("-d';' -f3", clic: 2, cote: "haut", legende: [la colonne 3 ; les colonnes sont séparées par `;`]),
      annote("| sort", clic: 3), annote("| uniq -c", clic: 4), annote("| sort -rn", clic: 5),
    ),
    schema-etats(hauteur: 500, etape: k, taille: px(24), numero: k => none,
      noeuds: (
        csv: (x: 0, y: 0, l: 230, h: 42, genre: "fichier", titre: "pionnieres.csv", contenu: none),
        cut: _tube(340, "cut"), d1: _flux(340, _f3),
        txt: (x: 690, y: 200, l: 970, genre: "texte", taille: px(28), contenu: [cut écrit sur sa sortie standard la colonne 3 de chaque ligne, en-tête compris.]),
      ),
      liens: (arg: (de: "csv.d", vers: "cut.arg", motif: "dash-dotted", etiquette: [argument], pos: 0.4), o1: (de: "cut.b", vers: "d1.h")),
      etats: (
        (:),
        (:),
        (noeuds: (srt: _tube(680, "sort"), d2: _flux(680, _f3-tri),
          txt: (x: 1030, l: 630, contenu: [`|` : la sortie standard de cut devient l’entrée standard de sort.])),
         liens: (t1: (de: "cut.1", vers: "srt.0", etiquette: _barre), o2: (de: "srt.b", vers: "d2.h"))),
        (noeuds: (unq: _tube(1020, "uniq -c"), d3: _flux(1020, _f3-uniq),
          txt: (x: 1370, l: 290, contenu: [uniq -c fusionne les lignes identiques *qui se suivent* et les compte : d’où le tri.])),
         liens: (t2: (de: "srt.1", vers: "unq.0", etiquette: _barre), o3: (de: "unq.b", vers: "d3.h"))),
        (noeuds: (rn: _tube(1360, "sort -rn"), d4: _flux(1360, _f3-fin, genre: "terminal"), txt: none),
         liens: (t3: (de: "unq.1", vers: "rn.0", etiquette: _barre), o4: (de: "rn.b", vers: "d4.h"))),
        (noeuds: (d4: (marque: (5,)), rq: (x: 680, y: 465, l: 984, genre: "texte", taille: px(25),
          contenu: [La ligne encadrée, `1 domaine`, vient de l’en-tête : à retirer (exercice).]))),
      ),
    ),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Pipelines.html")[Bash Reference Manual, Pipelines],
  note: [#versions Une commande par clic ; sous chacune, ce qui sort réellement d’elle (rejoué étape par étape : cut, puis cut | sort, puis | uniq -c, puis | sort -rn). Les cadres en tirets sont ce qui circule dans les tubes, pas des fichiers : aucun fichier temporaire. Le dernier, sur fond de terminal, est ce qui s’affiche. sort -rn : numérique, ordre décroissant ; les lignes de même compte sortent en ordre alphabétique inverse (-r). Tube puis redirection de la dernière commande : ls -l | grep csv > resultats.txt écrit dans resultats.txt la ligne de pionnieres.csv. Exemple d’origine du cours : cat fichier.txt | sort | uniq | wc -l ; sort fichier.txt suffit, sans cat.],
)

== Code de retour : && et || <codes-retour>

#let _voie = (x, y, titre) => (x: x, y: y, l: 240, h: 90, titre: titre)
#anime(
  scene(5, k => schema-etats(hauteur: 530, etape: k, taille: px(26), numero: k => k,
    noeuds: (
      term: (x: 0, y: 0, l: 1664, h: 200, genre: "terminal", titre: "Terminal", taille: px(25),
        contenu: ("$ ls absent.txt", erreur-ls, "$ echo $?", "2")),
      cmd: (x: 0, y: 320, l: 560, h: 110, titre: raw("ls absent.txt"), sous: [ne trouve pas le fichier]),
      code: (x: 640, y: 320, l: 230, h: 110, titre: [`$?` = 2], taille-titre: px(32)),
      ok: _voie(970, 235, [0 : succès]),
      ko: _voie(970, 415, [autre : échec]),
    ),
    liens: (
      c1: (de: "cmd", vers: "code"),
      v-ok: (de: "code", vers: "ok", motif: "dotted", fort: false),
      v-ko: (de: "code", vers: "ko", fort: true),
    ),
    etats: (
      (noeuds: (term: (:), cmd: (:), code: (:))),
      (noeuds: (
        term: (contenu: ("$ grep -q Hopper pionnieres.csv", "$ echo $?", "0")),
        cmd: (titre: raw("grep -q Hopper pionnieres.csv"), sous: [trouve Hopper]), code: (titre: [`$?` = 0]),
       ), liens: (v-ok: (motif: none, fort: true), v-ko: (motif: "dotted", fort: false))),
      (noeuds: (
        term: (contenu: ("$ grep -q Hopper pionnieres.csv && echo \"trouvée\"", "trouvée")),
        suite: (x: 1360, y: 235, l: 304, h: 90, titre: raw("echo \"trouvée\""), sous: [lancée]),
       ), liens: (et: (de: "ok", vers: "suite", etiquette: text(size: px(30), raw("&&"))))),
      (noeuds: (
        term: (contenu: ("$ grep -q Turing pionnieres.csv || echo \"absent du fichier\"", "absent du fichier")),
        cmd: (titre: raw("grep -q Turing pionnieres.csv"), sous: [ne trouve pas Turing]), code: (titre: [`$?` = 1]),
        suite: (y: 415, titre: raw("echo \"absent …\""), sous: [lancée]),
       ), liens: (v-ok: (motif: "dotted", fort: false), v-ko: (motif: none, fort: true), et: none,
         ou: (de: "ko", vers: "suite", etiquette: text(size: px(30), raw("||"))))),
      (noeuds: (
        term: (contenu: ("$ grep -q Hopper pionnieres.csv || echo \"absent du fichier\"", "# (rien : echo n’est pas lancé)")),
        cmd: (titre: raw("grep -q Hopper pionnieres.csv"), sous: [trouve Hopper]), code: (titre: [`$?` = 0]),
        suite: (sous: [pas lancée], attente: true),
       ), liens: (v-ok: (motif: none, fort: true), v-ko: (motif: "dotted", fort: false), ou: (motif: "dotted", fort: false))),
    ),
  )),
  encadre(role: "avertissement", libelle: [Ne pas confondre :])[`cmd1 | cmd2` *branche* deux flux ; `cmd1 || cmd2` enchaîne selon le *code de retour*.],
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Lists.html")[Bash Reference Manual, Lists of Commands],
  note: [#versions Un clic par commande, numérotée : la voie suivie est en trait plein, l’autre en pointillé. `a && b` : b seulement si a réussit (code 0) ; `a || b` : b seulement si a échoue. ls renvoie 2 pour une erreur sérieuse (fichier introuvable), 1 pour une erreur mineure ; chaque commande documente ses codes (man ls, section Exit status). grep -q : silencieux, seul le code compte (0 trouvé, 1 non trouvé). Le commentaire « (rien : echo n’est pas lancé) » n’est pas une sortie : la commande n’affiche rien.],
)

== À vous : deux pipelines sur pionnieres.csv <exercice-tubes>

#anime(
  contexte: atelier(voir: ("pionnieres.csv",)),
  rang(bloc(role: "question", revele: "bloc")[À vous][
    + En un seul pipeline : le *nombre de domaines distincts* (colonne 3), sans compter l’en-tête
    + En un seul pipeline : les *trois lignes les plus récentes* (année la plus grande)
  ]),
  rang(bloc(role: "pratique", taille: px(25))[Aide][
    #tableau((auto, 1fr), inset: (x: px(10), y: px(6)),
      ([Commande], [Effet]),
      [`tail -n +2`], [à partir de la ligne 2],
      [`head -n 3`], [les 3 premières lignes],
      [`sort -u`], [trie et dédoublonne],
      [`wc -l`], [compte les lignes],
      [`sort -t';' -k2 -rn`], [trie sur la colonne 2, numériquement, en ordre inverse],
    )
  ]),
  note: [À faire en direct. Laisser chercher avant de passer au corrigé.],
)

== Deux pipelines : corrigé

#corriges(contexte: atelier(voir: ("pionnieres.csv",)), note: [#versions La réponse 1 montre d’abord la liste qu’elle compte. Le module « Bash : les bases » du site annonçait 6 domaines distincts : la commande en donne 7 sur ce fichier. -k2 trie à partir de la colonne 2 ; -n compare 1985 et 1982 comme des nombres.],
  (1, [Le nombre de domaines distincts, sans l’en-tête],
    reponse(terminal(titre: none, taille: px(18))[```
      $ cut -d';' -f3 pionnieres.csv | tail -n +2 | sort -u
      calcul
      cryptographie
      langages
      logiciel
      materiel
      programmation
      reseau
      $ cut -d';' -f3 pionnieres.csv | tail -n +2 | sort -u | wc -l
      7
      ```])),
  (2, [Les trois lignes les plus récentes],
    reponse(terminal-annote(taille: px(18), largeur-legende: px(420),
      ("$ tail -n +2 pionnieres.csv | sort -t';' -k2 -rn | head -n 3",
       "Perlman Radia;1985;reseau;protocole spanning tree",
       "Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste",
       "Conway Lynn;1978;materiel;révolution VLSI"),
      annote("tail -n +2", cote: "haut", legende: [sans l’en-tête]),
      annote("-t';' -k2", cote: "haut", legende: [séparateur `;`, clé : colonne 2]),
      annote("-rn", cote: "haut", legende: [nombres, décroissant]),
    ))),
)

// ----------------------------------------------------------------------
= Bash · Variables, tests, boucles

== Variables : affecter sans espace, lire avec \$ <variables>

#let _path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
#anime(
  contexte: k => ctx(chemin: "/home/ada/atelier",
    variables: (("nom", "Ada"), ..if k >= 4 { (("HOME", "/home/ada"), ("USER", "ada")) }, ..if k >= 5 { (("PATH", "/usr/local/sbin:…"),) }),
    voir: if k <= 2 { ("$nom",) } else if k == 4 { ("$HOME", "$USER") } else if k == 5 { ("$PATH",) } else { () }),
  commande-annotee(taille: px(21),
    ("$ nom='Ada'", ("$ echo \"Bonjour $nom\"", 2), ("Bonjour Ada", 2), ("$ nom = Ada", 3),
      ("bash: nom: command not found", 3), ("$ echo \"$HOME $USER\"", 4), ("/home/ada ada", 4),
      ("$ echo \"$PATH\"", 5), (_path, 5)),
    annote("nom='Ada'", cote: "droite", clic: 1, legende: [affecter : aucune espace autour de `=`]),
    annote("Bonjour Ada", cote: "droite", clic: 2, legende: [`$nom` est remplacé par la valeur de `nom`]),
    annote("nom = Ada", cote: "droite", clic: 3, legende: [avec des espaces, trois mots : Bash cherche une commande `nom`]),
    annote((ligne: 6, texte: "/home/ada ada"), cote: "droite", clic: 4, legende: [`HOME`, `USER` : définies dès l’ouverture de session]),
    annote(_path, cote: "droite", clic: 5, legende: [`PATH` : les répertoires où Bash cherche les commandes]),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html")[Bash Reference Manual, Shell Parameters],
  note: [#versions Une commande par clic ; la colonne de gauche montre les variables définies. Les noms en majuscules sont l’usage pour les variables d’environnement (HOME, PATH) ; pour ses propres variables, les minuscules évitent d’en écraser une par accident. "\$nom" lit la valeur sans la découper (partie suivante). Exemple d’origine : nom="Charlie" ; echo "Bonjour \$nom".],
)

== if et test : [ est une commande <tests>

#let _tests = read("exemples/exemple_tests.bash").trim(at: end).split("\n")
#anime(
  contexte: atelier(contenu: ("exemple_tests.bash", "pionnieres.csv"), voir: ("exemple_tests.bash",)),
  scene(5, k => stack(spacing: px(16),
    terminal-annote(etape: k, taille: px(23), fond: "fichier", nom: "exemple_tests.bash", _tests,
      annote(_tests.at(1), cote: "droite", clic: 2, legende: [`[` est une commande (`test`) : elle reçoit `-d`, `/backup` et `]` ; `if` regarde son code de retour]),
    ),
    des(k, 3, terminal-annote(etape: k, taille: px(23),
      (("$ bash exemple_tests.bash", 3), ("Le répertoire /backup n’existe pas", 3), ("$ type [", 4), ("[ is a shell builtin", 4),
        ("$ [-f pionnieres.csv]", 5), ("bash: [-f: command not found", 5)),
      annote("Le répertoire /backup n’existe pas", cote: "droite", clic: 3, legende: [code non nul : la branche `else`]),
      annote("[ is a shell builtin", cote: "droite", clic: 4, legende: [une commande interne de Bash]),
      annote("bash: [-f: command not found", cote: "droite", clic: 5, legende: [sans espace, `[-f` est un seul mot : aucune commande de ce nom]),
    )),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html")[Bash Reference Manual, Conditional Expressions],
  note: [#versions Le script d’abord, puis son exécution. Script d’origine du cours (code/exemple\_tests.bash), apostrophe typographique ajoutée. [ et test sont la même commande interne ; le ] final est son dernier argument obligatoire. if teste le code de retour de la commande qui suit : n’importe quelle commande convient (if grep -q …). Des espaces autour de [, ] et de chaque opérateur : ce sont des arguments.],
)

== Les opérateurs de test

#let _ops(titre, ..lignes) = tableau((auto, 1fr), inset: (x: px(10), y: px(7)), taille: px(24), ([#titre], []), ..lignes)
#anime(
  contexte: atelier(voir: ("pionnieres.csv",), variables: (("annee", "1843"),)),
  grid(columns: (1fr, 1fr, 1fr), column-gutter: px(28),
    _ops([Fichiers], [`-e f`], [existe], [`-f f`], [fichier ordinaire], [`-d f`], [répertoire], [`-r`, `-w`, `-x`], [lisible, modifiable, exécutable], [`-s f`], [non vide]),
    _ops([Chaînes], [`-z "$s"`], [vide], [`-n "$s"`], [non vide], [`"$a" = "$b"`], [égales], [`"$a" != "$b"`], [différentes]),
    _ops([Nombres], [`-eq`, `-ne`], [égal, différent], [`-lt`, `-le`], [inférieur (ou égal)], [`-gt`, `-ge`], [supérieur (ou égal)]),
  ),
  terminal-annote(taille: px(20),
    ("$ [ \"$annee\" -lt 1900 ] && echo \"XIXe siècle\"", "XIXe siècle",
     "$ [ \"$annee\" -lt 1900 -a -f pionnieres.csv ] && echo \"les deux\"", "les deux"),
    annote("-a", cote: "droite", legende: none),
    annote((ligne: 3, texte: "les deux"), cote: "droite", legende: [`-a` (et), `-o` (ou) : retirés de POSIX.1-2024 ; préférer `&&` entre deux tests, ou `[[ … ]]`]),
  ),
  source-de: link("https://pubs.opengroup.org/onlinepubs/9799919799/utilities/test.html")[POSIX, test],
  note: [#versions Un aide-mémoire, puis la combinaison de deux tests. Tous viennent du cours d’origine. -a et -o étaient obsolescents dans POSIX.1-2018 (ambigus selon le nombre d’arguments) et ont été retirés de POSIX.1-2024 (Issue 8, défaut 1330) ; Bash les accepte encore, comme le montre l’exemple. POSIX : la norme des shells Unix.],
)

== [[ … ]] : le test propre à Bash

#anime(
  contexte: atelier(voir: ("pionnieres.csv",), variables: (("annee", "1843"), ("vide", ""))),
  commande-annotee(taille: px(19),
    ("$ [[ $annee -lt 1900 && -f pionnieres.csv ]] && echo \"les deux\"", "les deux",
     ("$ [[ $annee =~ ^[0-9]+$ ]] && echo \"un nombre\"", 3), ("un nombre", 3),
     ("$ vide=", 4), ("$ [[ $vide = Ada ]] || echo \"faux, sans erreur\"", 4), ("faux, sans erreur", 4),
     ("$ [ $vide = Ada ] || echo \"faux\"", 5), ("bash: [: =: unary operator expected", 5), ("faux", 5)),
    annote((ligne: 0, texte: "&&", n: 1), cote: "haut", clic: 2, legende: [`&&` s’écrit dans les doubles crochets]),
    annote((ligne: 3, texte: "un nombre"), cote: "droite", clic: 3, legende: [`=~` : correspond à l’expression régulière `^[0-9]+$` (que des chiffres)]),
    annote((ligne: 6, texte: "faux, sans erreur"), cote: "droite", clic: 4, reste: true, legende: [`[[` : la variable vide reste un argument vide]),
    annote("bash: [: =: unary operator expected", cote: "droite", clic: 5, legende: [`[` : la variable vide disparaît, `=` n’a plus rien à gauche]),
  ),
  note(role: "precaution", taille: px(22))[`[[ … ]]` est propre à Bash (et à zsh, ksh) : un script en `#!/bin/sh` doit s’en passer.],
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html")[Bash Reference Manual, Conditional Constructs],
  note: [#versions Dans [[ … ]], Bash ne découpe pas les variables en mots et ne développe pas les motifs de fichiers : [[ \$vide = Ada ]] marche même si vide est vide. =\~ compare à une expression régulière étendue (POSIX ERE) ; sans guillemets à droite, sinon la chaîne est prise littéralement. [[ … ]] n’existe pas dans sh (dash) : réservé aux scripts \#!/bin/bash.],
)

== Boucles : for, un tour par mot <boucles>

#anime(
  contexte: k => atelier(contenu: ("pionnieres.csv", "services.conf"),
    voir: if k == 2 { ("pionnieres.csv", "services.conf") } else if k == 3 { ("pionnieres.csv", "$fichier") } else if k == 4 { ("services.conf", "$fichier") } else { () },
    variables: if k == 3 { (("fichier", "pionnieres.csv"),) } else if k >= 4 { (("fichier", "services.conf"),) } else { () }),
  commande-annotee(taille: px(19),
    ("$ for fichier in *.csv *.conf; do echo \"Fichier : $fichier\"; done", ("Fichier : pionnieres.csv", 3),
      ("Fichier : services.conf", 4), ("$ echo {1..5}", 5), ("1 2 3 4 5", 5)),
    annote("*.csv *.conf", cote: "haut", clic: 2, legende: [la liste : Bash la remplace d’abord par les noms qui correspondent]),
    annote("Fichier : pionnieres.csv", cote: "droite", clic: 3, legende: [tour 1 : `fichier` vaut `pionnieres.csv`]),
    annote("Fichier : services.conf", cote: "droite", clic: 4, legende: [tour 2 : `services.conf` ; la liste est épuisée]),
    annote("1 2 3 4 5", cote: "droite", clic: 5, legende: [`{1..5}` : une suite de mots, sans lire le disque]),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Looping-Constructs.html")[Bash Reference Manual, Looping Constructs],
  note: [#versions Syntaxe : for var in liste; do … done. La colonne montre la variable de boucle à chaque tour. {1..5} : l’expansion des accolades produit la suite, sans rien lire sur le disque ; for i in {1..5} fait cinq tours.],
)

== Boucles : while, tant que le test réussit

#anime(
  contexte: k => ctx(chemin: "/home/ada/atelier", voir: ("$compteur",),
    variables: (("compteur", str(calc.min(calc.max(k, 1), 4))),)),
  commande-annotee(taille: px(24),
    ("$ compteur=1", "$ while [ \"$compteur\" -le 3 ]; do", "    echo \"Itération $compteur\"",
      "    compteur=$((compteur + 1))", "done", ("Itération 1", 2), ("Itération 2", 3), ("Itération 3", 4),
      ("$ echo $((7 * 6)) $((7 / 2)) $((7 % 2))", 6), ("42 3 1", 6)),
    annote("Itération 1", cote: "droite", clic: 2, legende: [1 ≤ 3 : le corps s’exécute ; `compteur` passe à 2]),
    annote("Itération 2", cote: "droite", clic: 3, legende: [2 ≤ 3 : encore ; `compteur` passe à 3]),
    annote("Itération 3", cote: "droite", clic: 4, legende: [3 ≤ 3 : encore ; `compteur` passe à 4]),
    annote((ligne: 4, texte: "done"), cote: "droite", clic: 5, legende: [4 ≤ 3 est faux : la boucle s’arrête]),
    annote("42 3 1", cote: "droite", clic: 6, legende: [`$(( … ))` : calcul entier ; `/` tronque, `%` donne le reste]),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html")[Bash Reference Manual, Shell Arithmetic],
  note: [#versions Syntaxe : while condition; do … done. La boucle est celle du cours d’origine, avec la variable entre guillemets. La colonne montre compteur après chaque tour. \$(( … )) : l’arithmétique entière du shell (7 / 2 vaut 3, % est le reste).],
)

== for sur \$(ls) : un nom à espace se coupe en deux <for-ls>

#anime(
  contexte: k => ctx(chemin: "/home/ada/atelier/rapports", contenu: ("mon rapport.txt", "notes.txt"),
    voir: if k >= 2 { ("mon rapport.txt",) } else { () }),
  commande-annotee(taille: px(24),
    ("$ touch \"mon rapport.txt\" notes.txt", ("$ for f in $(ls *.txt); do echo \"[$f]\"; done", 2), ("[mon]", 2),
      ("[rapport.txt]", 2), ("[notes.txt]", 2), ("$ for f in *.txt; do echo \"[$f]\"; done", 4), ("[mon rapport.txt]", 4),
      ("[notes.txt]", 4)),
    annote("[mon]", cote: "droite", clic: 3, reste: true, legende: [un nom, deux tours : la sortie de ls est recoupée aux espaces]),
    annote("[mon rapport.txt]", cote: "droite", clic: 4, legende: [le motif `*.txt` : un mot par fichier, espaces compris]),
  ),
  encadre(role: "avertissement", libelle: [Mauvaise pratique :])[`for f in $(ls …)` ; écrire `for f in *.txt`. La partie suivante dit pourquoi : découpage (étape 4), puis chemins (étape 5).],
  source-de: link("https://www.shellcheck.net/wiki/SC2045")[ShellCheck, SC2045],
  note: [#versions Exemple d’origine du cours : for fichier in \$(ls). La sortie de ls est découpée en mots sur les espaces, d’où « mon » et « rapport.txt ». Le motif \*.txt est développé après le découpage : chaque nom reste un seul mot. ShellCheck signale la première forme (SC2045).],
)

// ======================================================================
= Bash · Guillemets et expansions

== Voir les arguments reçus : `printf '[%s]\n'`

#anime(

  commande-annotee(taille: px(34),
    ("$ printf '[%s]\\n' un deux \"trois quatre\"", ("[un]", 4), ("[deux]", 4), ("[trois quatre]", 4)),
    annote("'[%s]\\n'", cote: "haut", clic: 2, reste: true, legende: [le format : `%s` reçoit un argument, entre crochets, puis `\n`]),
    annote("un deux \"trois quatre\"", cote: "haut", clic: 3, reste: true, legende: [trois arguments ; les guillemets gardent les deux derniers mots ensemble]),
    annote("[trois quatre]", cote: "droite", clic: 4, legende: [le format resservi à chaque argument : une ligne par argument reçu]),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-printf")[Bash Reference Manual, printf],
  note: [#versions printf réutilise son format pour chaque argument : une ligne entre crochets par argument reçu, ce qui rend visibles les espaces et les mots. C’est l’instrument de mesure de cette partie : echo, lui, recolle ses arguments avec une espace et cache leurs frontières.],
)

== Avant d’exécuter, Bash réécrit la ligne <ordre-expansions>

#let labo(contenu: ("ada.txt", "grace.txt", "hedy.txt"), ..args) = ctx(chemin: "/home/ada/atelier/labo", contenu: contenu, ..args)
#let _p = (("p", "Ada Lovelace"),)
#anime(
  contexte: k => labo(variables: _p, voir: if k == 3 { ("$p",) } else if k == 5 { ("ada.txt", "grace.txt", "hedy.txt") } else { () }),
  reecriture-anime(
    commande: "$ printf '[%s]\\n' {a,b} $p \"$p\" *.txt '$p'",
    rangs: (
      ((0, "{a,b}"), (1, "$p"), (2, "\"$p\"", "q"), (3, "*.txt"), (4, "'$p'", "q")),
      ((0, "a", "x"), (0, "b", "x"), (1, "$p"), (2, "\"$p\"", "q"), (3, "*.txt"), (4, "'$p'", "q")),
      ((0, "a", "x"), (0, "b", "x"), (1, "Ada·Lovelace", "x"), (2, "\"Ada·Lovelace\"", "xq"), (3, "*.txt"), (4, "'$p'", "q")),
      ((0, "a", "x"), (0, "b", "x"), (1, "Ada", "x"), (1, "Lovelace", "x"), (2, "\"Ada·Lovelace\"", "xq"), (3, "*.txt"), (4, "'$p'", "q")),
      ((0, "a", "x"), (0, "b", "x"), (1, "Ada", "x"), (1, "Lovelace", "x"), (2, "\"Ada·Lovelace\"", "xq"),
        (3, "ada.txt", "x"), (3, "grace.txt", "x"), (3, "hedy.txt", "x"), (4, "'$p'", "q")),
      ((0, "a", "x"), (0, "b", "x"), (1, "Ada", "x"), (1, "Lovelace", "x"), (2, "Ada·Lovelace", "x"),
        (3, "ada.txt", "x"), (3, "grace.txt", "x"), (3, "hedy.txt", "x"), (4, "$p")),
    ),
    notes: (
      [Bash coupe la ligne en mots, aux espaces hors guillemets ; chaque mot garde sa colonne.],
      [`{a,b}` devient deux mots.],
      [`$p` et `"$p"` prennent la valeur de `p` (de même `~`, `$( )`, `$(( ))`) ; entre `'…'`, rien.],
      [Hors guillemets, la valeur est recoupée aux espaces : `$p` donne deux mots, `"$p"` un seul.],
      [Hors guillemets, `*.txt` devient les noms des fichiers qui correspondent.],
      [Les guillemets sont retirés : printf reçoit neuf arguments après le format.],
    ),
    note-fin: [La preuve : une ligne par argument reçu. *À retenir :* seules les étapes 2, 4 et 5 multiplient les mots ; les guillemets doubles empêchent 4 et 5, les simples toutes.],
    sortie-dessous: true, taille: px(21),
    sortie: ("[a]", "[b]", "[Ada]", "[Lovelace]", "[Ada Lovelace]", "[ada.txt]", "[grace.txt]", "[hedy.txt]", "[$p]"),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html")[Bash Reference Manual, Shell Expansions],
  note: [#versions Un clic par étape ; les noms des étapes sont ceux de l’artefact « Avant d’exécuter, Bash réécrit la ligne ». Fond teinté : produit par une expansion ; souligné : protégé par des guillemets ; « · » : une espace dans un mot. Ordre donné par man bash (bash 5.2), section EXPANSION : « brace expansion ; tilde expansion, parameter and variable expansion, arithmetic expansion, and command substitution (done in a left-to-right fashion) ; word splitting ; and pathname expansion ». La substitution de processus \<( … ) se fait en même temps que l’étape 3, et la suppression des guillemets vient en dernier. Le découpage (étape 4) ne porte que sur les résultats de \$, \$( ) et \$(( )) hors guillemets, pas sur ceux de \~. Seules les accolades, le découpage et les chemins peuvent multiplier les mots (sauf "\$\@", qui donne un mot par argument).],
)

== Les guillemets décident des expansions <guillemets>

#anime(
  reecriture-anime(
    commande: "$ printf '[%s]\\n' $p \"$p\" '$p' *.txt \"*.txt\" '*.txt'",
    rangs: (
      ((0, "$p"), (1, "\"$p\"", "q"), (2, "'$p'", "q"), (3, "*.txt"), (4, "\"*.txt\"", "q"), (5, "'*.txt'", "q")),
      ((0, "$p"), (1, "\"$p\"", "q"), (2, "'$p'", "q"), (3, "*.txt"), (4, "\"*.txt\"", "q"), (5, "'*.txt'", "q")),
      ((0, "Ada·Lovelace", "x"), (1, "\"Ada·Lovelace\"", "xq"), (2, "'$p'", "q"), (3, "*.txt"), (4, "\"*.txt\"", "q"), (5, "'*.txt'", "q")),
      ((0, "Ada", "x"), (0, "Lovelace", "x"), (1, "\"Ada·Lovelace\"", "xq"), (2, "'$p'", "q"), (3, "*.txt"), (4, "\"*.txt\"", "q"), (5, "'*.txt'", "q")),
      ((0, "Ada", "x"), (0, "Lovelace", "x"), (1, "\"Ada·Lovelace\"", "xq"), (2, "'$p'", "q"),
        (3, "ada.txt", "x"), (3, "grace.txt", "x"), (3, "hedy.txt", "x"), (4, "\"*.txt\"", "q"), (5, "'*.txt'", "q")),
      ((0, "Ada", "x"), (0, "Lovelace", "x"), (1, "Ada·Lovelace", "x"), (2, "$p"),
        (3, "ada.txt", "x"), (3, "grace.txt", "x"), (3, "hedy.txt", "x"), (4, "*.txt"), (5, "*.txt")),
    ),
    notes: (
      [Trois écritures de `$p`, trois de `*.txt` : sans guillemets, doubles, simples.],
      [Pas d’accolades : rien ne change.],
      [`$p` et `"$p"` prennent la valeur ; `'$p'` ne bouge pas : entre simples, rien n’est développé.],
      [Seul `$p`, sans guillemets, est recoupé : deux mots.],
      [Seul `*.txt`, sans guillemets, devient des noms de fichiers.],
      [Les guillemets partent : `"$p"` reste un mot, `'$p'` et `'*.txt'` restent du texte.],
    ),
    note-fin: [La preuve : neuf arguments après le format.],
    sortie: ("[Ada]", "[Lovelace]", "[Ada Lovelace]", "[$p]", "[ada.txt]", "[grace.txt]", "[hedy.txt]", "[*.txt]", "[*.txt]"),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Quoting.html")[Bash Reference Manual, Quoting],
  note: [#versions Doubles : les valeurs sont insérées, mais restent un seul mot ; simples : rien n’est développé, chaque caractère est littéral. Le répertoire labo ne contient que ada.txt, grace.txt et hedy.txt.],
)

== Les guillemets, expansion par expansion

#let oui = text(weight: 700)[oui]
#let non = text(fill: c.gris)[non]
#let _lignes-tab = (
  ([Tilde `~`], oui, non, non),
  ([Accolades `{a,b}`], oui, non, non),
  ([Variables `$p`], oui, oui, non),
  ([Commande `$(…)`, calcul `$((…))`], oui, oui, non),
  ([Découpage en mots], oui, non, non),
  ([Chemins `*.txt`], oui, non, non),
)
#let _preuves = (
  ("$ printf '[%s]\\n' ~ \"~\" '~'", "[/home/ada]", "[~]", "[~]"),
  ("$ printf '[%s]\\n' {a,b} \"{a,b}\" '{a,b}'", "[a]", "[b]", "[{a,b}]", "[{a,b}]"),
  ("$ printf '[%s]\\n' $p \"$p\" '$p'", "[Ada]", "[Lovelace]", "[Ada Lovelace]", "[$p]"),
  ("$ printf '[%s]\\n' $(echo un deux) \"$(echo un deux)\" '$(echo un deux)'", "[un]", "[deux]", "[un deux]", "[$(echo un deux)]",
   "$ printf '[%s]\\n' $((6*7)) \"$((6*7))\" '$((6*7))'", "[42]", "[42]", "[$((6*7))]"),
  ("$ printf '[%s]\\n' $(echo un deux) \"$(echo un deux)\" '$(echo un deux)'", "[un]", "[deux]", "[un deux]", "[$(echo un deux)]"),
  ("$ printf '[%s]\\n' *.txt \"*.txt\" '*.txt'", "[ada.txt]", "[grace.txt]", "[*.txt]", "[*.txt]"),
)
#anime(
  scene(6, k => grid(columns: (1fr, px(820)), column-gutter: px(28),
    table(columns: (1.9fr, 0.7fr, 0.7fr, 0.7fr), stroke: none, inset: (x: px(10), y: px(12)), align: (left + horizon, center + horizon, center + horizon, center + horizon),
      fill: (x, y) => if y == 0 { c.bleu.transparentize(82%) } else if y == calc.min(k, 6) and k <= 6 { c.appli },
      table.header(..([Expansion], [sans], [`"…"`], [`'…'`]).map(t => text(size: px(27), weight: 600, t))),
      .._lignes-tab.enumerate().map(((i, l)) => l.map(x => {
        let cell = text(size: px(27), x)
        if i + 1 <= k { if i + 1 == calc.min(k, 6) and k <= 6 { box(stroke: (bottom: px(3) + c.encre), cell) } else { cell } } else { hide(cell) }
      })).flatten(),
    ),
    terminal(titre: none, taille: px(17), raw(_preuves.at(calc.min(k, 6) - 1).join("\n"), block: true)),
  )),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Quoting.html")[Bash Reference Manual, Quoting],
  note: [#versions Une ligne du tableau par clic, avec à droite la commande qui l’établit : la même écriture sans guillemets, entre doubles, entre simples. Le découpage se lit sur la preuve des commandes : `$(echo un deux)` donne deux arguments sans guillemets, un seul entre doubles. Le répertoire labo de cette session ne contient que ada.txt et grace.txt. Entre guillemets doubles, l’antislash garde un sens devant \$, \`, ", \\ et le saut de ligne ; entre simples, rien n’a de sens : on ne peut pas y écrire une apostrophe. Le tilde n’est développé qu’en début de mot, hors guillemets.],
)

== Découpage, chemins : la ligne qui a l’air juste

#anime(
  contexte: k => labo(contenu: if k >= 4 { ("ada.txt", "grace.txt", "hedy.txt") } else { () },
    variables: (("hommage", "Grace     Hopper"), ..if k >= 4 { (("motif", "*.txt"),) }),
    voir: if k <= 3 { ("$hommage",) } else { ("$motif", "ada.txt", "grace.txt", "hedy.txt") }),
  commande-annotee(taille: px(24),
    ("$ hommage=\"Grace     Hopper\"", ("$ echo $hommage", 2), ("Grace Hopper", 2), ("$ echo \"$hommage\"", 3),
      ("Grace     Hopper", 3), ("$ touch ada.txt grace.txt hedy.txt", 4), ("$ motif=\"*.txt\"", 4), ("$ echo $motif", 4),
      ("ada.txt grace.txt hedy.txt", 4), ("$ echo \"$motif\"", 5), ("*.txt", 5)),
    annote("Grace Hopper", cote: "droite", clic: 2, reste: true, legende: [echo reçoit #arguments("Grace", "Hopper") et les recolle avec une espace]),
    annote((ligne: 4, texte: "Grace     Hopper"), cote: "droite", clic: 3, legende: [echo reçoit #arguments("Grace     Hopper") : intact]),
    annote((ligne: 8, texte: "ada.txt grace.txt hedy.txt"), cote: "droite", clic: 4, reste: true, legende: [la valeur `*.txt` passe par l’étape 5, Chemins]),
    annote((ligne: 10, texte: "*.txt"), cote: "droite", clic: 5, legende: [entre guillemets : le texte, tel quel]),
  ),
  encadre(role: "avertissement", libelle: [Conséquence :])[`rm $motif` ne supprime pas ce qu’on lit : le résultat dépend des fichiers du répertoire courant.],
  note: [#versions echo recolle ses arguments avec une seule espace : les cinq espaces disparaissent entre l’étape 4 et l’affichage. Exemples de l’article « Guillemets, expansions et sous-shells » du site, rejoués.],
)

== Deux erreurs classiques sans guillemets

#anime(
  contexte: k => ctx(chemin: if k == 3 { "/home/ada/atelier/Mon dossier important" } else { "/home/ada/atelier" },
    contenu: if k == 3 { () } else { ("Mon dossier important/",) }, autres: if k == 3 { 0 } else { 31 },
    variables: (("dossier", "Mon dossier important"), ..if k >= 4 { (("nom", ""),) }),
    voir: if k <= 3 { ("$dossier", "Mon dossier important/") } else { ("$nom",) }),
  commande-annotee(taille: px(18),
    ("$ dossier=\"Mon dossier important\"", "$ mkdir \"$dossier\"", ("$ cd $dossier", 2), ("bash: cd: too many arguments", 2),
      ("$ cd \"$dossier\" && pwd", 3), ("/home/ada/atelier/Mon dossier important", 3), ("$ nom=", 4),
      ("$ [ $nom = \"Etudiant\" ] && echo \"Bonjour, $nom\"", 4), ("bash: [: =: unary operator expected", 4),
      ("$ [ \"$nom\" = \"Etudiant\" ] || echo \"test exécuté, réponse : non\"", 5), ("test exécuté, réponse : non", 5)),
    annote("bash: cd: too many arguments", cote: "droite", clic: 2, reste: true, legende: [cd reçoit #arguments("Mon", "dossier", "important")]),
    annote("/home/ada/atelier/Mon dossier important", cote: "droite", clic: 3, reste: true, legende: [cd reçoit #arguments("Mon dossier important")]),
    annote("bash: [: =: unary operator expected", cote: "droite", clic: 4, reste: true, legende: [`[` reçoit #arguments("=", "Etudiant", "]")]),
    annote((ligne: 10, texte: "test exécuté, réponse : non"), cote: "droite", clic: 5, reste: true, legende: [`[` reçoit #arguments("", "=", "Etudiant", "]")]),
  ),
  source-de: link("https://mywiki.wooledge.org/BashPitfalls")[Greg’s Wiki, BashPitfalls],
  note: [#versions Exemples du cours d’origine (diapositive « Exemples d’erreurs sans guillemets »). La colonne suit le cd réussi, puis revient au répertoire de départ pour la seconde erreur (une autre session du relevé). Sans guillemets, la variable vide disparaît à l’étape 4 : [ reçoit = Etudiant ], et l’opérateur = n’a pas d’opérande à gauche ; avec guillemets, l’argument vide (∅) reste.],
)

== Simples, doubles, et la troisième écriture `$'…'`

#anime(
  contexte: atelier(voir: ("pionnieres.csv",), variables: _p),
  commande-annotee(taille: px(23),
    ("$ p=\"Ada Lovelace\"", ("$ echo \"$p\" '$p' \"'$p'\" '\"$p\"'", 2), ("Ada Lovelace $p 'Ada Lovelace' \"$p\"", 2),
      ("$ echo \"\\$p vaut $p, prix : 100$\"", 3), ("$p vaut Ada Lovelace, prix : 100$", 3),
      ("$ echo 'a\\tb' \"a\\tb\"", 4), ("a\\tb a\\tb", 4), ("$ echo $'a\\tb'", 5), ("a\tb", 5),
      ("$ echo $'aujourd\\'hui'", 6), ("aujourd'hui", 6),
      ("$ echo \"$(echo *.csv)\" '$(echo *.csv)'", 7), ("pionnieres.csv $(echo *.csv)", 7)),
    annote("Ada Lovelace $p 'Ada Lovelace' \"$p\"", cote: "droite", clic: 2, legende: [doubles : la valeur ; simples : le texte ; l’une dans l’autre : un caractère ordinaire]),
    annote("$p vaut Ada Lovelace, prix : 100$", cote: "droite", clic: 3, legende: [`\$` : un dollar littéral ; un `$` sans nom reste tel quel]),
    annote((ligne: 6, texte: "a\\tb a\\tb"), cote: "droite", clic: 4, legende: [`\t` : sans effet entre `'…'` comme entre `"…"`]),
    annote((ligne: 8, cols: (0, 9)), cote: "droite", clic: 5, legende: [`$'…'` interprète `\t` (tabulation), `\n`]),
    annote("aujourd'hui", cote: "droite", clic: 6, legende: [et `\'` : la seule écriture où une apostrophe s’échappe]),
    annote("pionnieres.csv $(echo *.csv)", cote: "droite", clic: 7, legende: [`$( )` est exécutée entre doubles, pas entre simples]),
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html")[Bash Reference Manual, ANSI-C Quoting],
  note: [#versions Une écriture par clic. Entre doubles, \\\$ donne un \$ littéral ; un \$ qui n’est suivi d’aucun nom reste un \$. echo n’interprète pas \\t (sauf echo -e) ; \$'…' (citation ANSI-C) interprète \\n, \\t, \\'. En shell interactif, ! déclenche l’expansion de l’historique, même entre doubles ; jamais entre simples ni dans un script.],
)

== Les accolades délimitent le nom de la variable <accolades>

#anime(
  contexte: k => ctx(chemin: "/home/ada/atelier",
    variables: (("fichier", "rapport"), ("ext", "txt"), ..if k >= 4 { (("chemin", "/usr/local/bin"),) }),
    voir: if k == 3 { ("$fichier", "$ext") } else if k == 5 { ("$chemin",) } else { () }),
  commande-annotee(taille: px(24),
    ("$ fichier=\"rapport\"", "$ ext=\"txt\"", ("$ echo \"$fichierext\"", 2), ("", 2), ("$ echo \"${fichier}.${ext}\"", 3),
      ("rapport.txt", 3), ("$ chemin=\"/usr/local/bin\"", 4), ("$ echo \"$chemin_backup\"", 4), ("", 4),
      ("$ echo \"${chemin}_backup\"", 5), ("/usr/local/bin_backup", 5)),
    annote("$fichierext\"", cote: "droite", clic: 2, legende: [Bash lit la variable `fichierext`, qui n’existe pas : rien]),
    annote("${fichier}.${ext}\"", cote: "droite", clic: 3, legende: [`${…}` : le nom s’arrête à l’accolade]),
    annote("$chemin_backup\"", cote: "droite", clic: 4, legende: [`_` fait partie d’un nom : la variable `chemin_backup`, vide]),
    annote("${chemin}_backup\"", cote: "droite", clic: 5, legende: [`${chemin}`, puis le texte `_backup`]),
  ),
  note(role: "retenir", taille: px(23))[Écrire `"${variable}"` : guillemets doubles toujours, accolades dès qu’un caractère suit. Retirer les guillemets seulement pour *vouloir* le découpage, et le dire en commentaire.],
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html")[Bash Reference Manual, Shell Parameter Expansion],
  note: [#versions Exemples du cours d’origine (diapositive « Exemples d’erreurs sans accolades »). Un nom de variable s’arrête au premier caractère qui n’est ni lettre, ni chiffre, ni \_ : \$fichier.txt marcherait, \$fichierext et \$chemin\_backup non. À ne pas confondre avec {a,b}, l’expansion des accolades. ShellCheck : SC2086 pour les guillemets manquants.],
)

== À vous : combien de mots ? <exercice-expansions>

#anime(
  contexte: labo(variables: _p),
  rang(bloc(role: "question", revele: "bloc")[À vous : prévoyez la sortie de chaque ligne][
    + `printf '[%s]\n' $p`
    + `printf '[%s]\n' "$p"`
    + `printf '[%s]\n' '$p'`
    + `printf '[%s]\n' *.txt "*.txt"`
    + `printf '[%s]\n' "$(echo *.txt)"`
    + `printf '[%s]\n' {ada,hedy}.txt`
  ]),
  rang(bloc(role: "pratique", taille: px(25))[Point de départ][
    #terminal(titre: none, taille: px(21))[```
      $ touch ada.txt grace.txt hedy.txt
      $ p="Ada Lovelace"
      ```]
  ]),
  note: [À faire en direct : chacun écrit sa prévision, puis on exécute. Le répertoire ne contient que les trois fichiers créés par touch (colonne de gauche). L’artefact « Avant d’exécuter, Bash réécrit la ligne » permet de vérifier chaque étape.],
)

== Combien de mots : corrigé (1/2)

#let _rep(t, ..lignes) = stack(spacing: px(8), terminal(titre: none, taille: px(20), raw(lignes.pos().join("\n"), block: true)),
  text(size: px(23), t))
#corriges(contexte: labo(variables: _p), note: [#versions Chaque réponse nomme l’étape qui décide, avec le nom que lui donne l’artefact.],
  (1, [`printf '[%s]\n' $p`],
    reponse(_rep([Étape 4, Découpage : hors guillemets, la valeur est recoupée en deux mots.], "$ printf '[%s]\\n' $p", "[Ada]", "[Lovelace]"))),
  (2, [`printf '[%s]\n' "$p"`],
    reponse(_rep([Entre guillemets doubles, pas d’étape 4 : un seul mot.], "$ printf '[%s]\\n' \"$p\"", "[Ada Lovelace]"))),
  (3, [`printf '[%s]\n' '$p'`],
    reponse(_rep([Entre guillemets simples, rien n’est développé : le texte `$p`.], "$ printf '[%s]\\n' '$p'", "[$p]"))),
)

== Combien de mots : corrigé (2/2)

#corriges(contexte: labo(variables: _p), note: [#versions Question 5 : la substitution produit « ada.txt grace.txt hedy.txt » (echo recolle), et les guillemets en font un seul mot. Question 6 : les accolades ne regardent pas le disque, contrairement à \*.txt.],
  (4, [`printf '[%s]\n' *.txt "*.txt"`],
    reponse(_rep([Étape 5, Chemins : `*.txt` hors guillemets devient trois noms ; entre guillemets, le texte.],
      "$ printf '[%s]\\n' *.txt \"*.txt\"", "[ada.txt]", "[grace.txt]", "[hedy.txt]", "[*.txt]"))),
  (5, [`printf '[%s]\n' "$(echo *.txt)"`],
    reponse(_rep([Étape 3 : la commande donne une ligne ; entre guillemets, pas d’étape 4 : un seul mot.],
      "$ printf '[%s]\\n' \"$(echo *.txt)\"", "[ada.txt grace.txt hedy.txt]"))),
  (6, [`printf '[%s]\n' {ada,hedy}.txt`],
    reponse(_rep([Étape 2, Accolades : deux mots, sans regarder le disque.], "$ printf '[%s]\\n' {ada,hedy}.txt", "[ada.txt]", "[hedy.txt]"))),
)

// ======================================================================
= Bash · Des scripts robustes

== Un script : shebang, droit x, ./ <script-executable>

#let _note = [#versions Script d’origine du cours (« Écriture d’un script Bash »), avec exit 0 à la place de return 0 (diapositive suivante). ./ est nécessaire parce que le répertoire courant n’est pas dans PATH. Sans le droit x, bash bonjour.sh lance quand même le script : c’est alors bash qu’on exécute, et le shebang est ignoré.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.2)[Le fichier, puis son exécution][
      #fichier-ex("bonjour.sh")
      #terminal(titre: none, taille: px(19))[```
        $ ./bonjour.sh
        bash: ./bonjour.sh: Permission denied
        $ chmod u+x bonjour.sh
        $ ./bonjour.sh
        Script lancé
        Itération 1
        Itération 2
        Itération 3
        $ echo $?
        0
        ```]
    ],
    bloc[Un script Bash][
      - Un fichier texte de commandes
      - 1#super[re] ligne, le *shebang* `#!/bin/bash` : l’interpréteur à lancer
      - `chmod u+x` : le droit d’exécution pour le propriétaire
      - `./bonjour.sh` : le chemin, car `.` n’est pas dans `PATH`
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Scripts.html")[Bash Reference Manual, Shell Scripts],
  note: _note,
)

== exit, pas return : le code de retour d’un script <exit>

#let _note = [#versions Le support d’origine finissait son exemple par return 0 ; le module du site l’a corrigé. return ne vaut que dans une fonction ou un fichier chargé par source. Codes : 0 succès, 1 à 125 échecs au choix du script ; 126 (non exécutable), 127 (introuvable) et 128 + n (tué par le signal n) sont réservés par le shell.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Le piège, rejoué][
      #fichier-ex("retour.sh")
      #terminal(titre: none, taille: px(19))[```
        $ ./retour.sh
        Script lancé
        ./retour.sh: line 4: return: can only `return' from a function or sourced script
        $ echo $?
        2
        ```]
    ],
    bloc(role: "avertissement")[exit N][
      - `return` hors d’une fonction : erreur
      - Un script se termine par `exit N`
      - `0` : succès ; un code par cas d’échec, documenté
      - `&&`, `||`, cron et l’intégration continue (CI) lisent ce code
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html")[Bash Reference Manual, Exit Status],
  note: _note,
)

== Recevoir des arguments : `$1`, `$#` <arguments>

#let _note = [#versions exemple\_argument.bash reprend le script d’origine, plus \$\# (ajouté). bash -x montre la même chose au débogage (plus loin).]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Le script, puis son exécution][
      #fichier-ex("exemple_argument.bash")
      #terminal(titre: none, taille: px(19))[```
        $ ./exemple_argument.bash arg1 arg2
        L’argument zéro est : ./exemple_argument.bash
        Le premier argument est : arg1
        Le deuxième argument est : arg2
        Nombre d’arguments : 2
        ```]
    ],
    bloc[Paramètres positionnels][
      - `$0` : le script, tel qu’il a été appelé
      - `$1`, `$2`… : les arguments ; `${10}` au-delà de 9
      - `$#` : leur nombre
      - Un argument absent : chaîne vide
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Positional-Parameters.html")[Bash Reference Manual, Positional Parameters],
  note: _note,
)

== Tous les arguments : `"$@"` <arguments-tous>

#let _note = [#versions "\$\*" (entre guillemets) colle tous les arguments en un seul mot ; \$\* et \$\@ sans guillemets les redécoupent. ShellCheck : SC2048. La ligne shellcheck disable dit à ShellCheck que le découpage est voulu ici.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.5)[Le script, puis son exécution][
      #fichier-ex("tous_les_arguments.bash", taille: px(17))
      #terminal(titre: none, taille: px(18))[```
        $ ./tous_les_arguments.bash "Grace Hopper" Ada
        [Grace Hopper]
        [Ada]
        ---
        [Grace]
        [Hopper]
        [Ada]
        ```]
    ],
    bloc(role: "retenir")[À retenir][
      - `"$@"` : un mot par argument reçu, espaces compris
      - `$*` sans guillemets : les arguments sont redécoupés
      - Transmettre ses arguments : `main "$@"`
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Special-Parameters.html")[Bash Reference Manual, Special Parameters],
  note: _note,
)

== Saisie interactive ou arguments <saisie-ou-arguments>

#let _note = [#versions Script d’origine (exemple\_saisie.bash). read -r : l’antislash est gardé tel quel (sans -r, il échappe le caractère suivant). <<< (chaîne ici, here string) envoie le mot sur l’entrée standard : c’est ainsi qu’on teste un script interactif (Bats, plus loin).]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[Mode interactif : read][
      #fichier-ex("exemple_saisie.bash")
      #terminal(titre: none, taille: px(19))[```
        # <<< : la réponse arrive sur l’entrée standard
        $ ./exemple_saisie.bash <<< "Ada"
        Entrez votre nom :
        Bonjour, Ada !
        ```]
    ],
    bloc[Deux modes][
      - Interactif : `read -r nom` attend une saisie ; pour l’installation, la configuration initiale
      - Non interactif : arguments, variables d’environnement, fichier de configuration
    ],
  ),
  rang(bloc(role: "avertissement")[Inconvénient, d’après le cours d’origine][
    Un script qui attend une saisie ne peut pas tourner sous cron ou at, ni dans un déploiement automatisé.
  ]),
  note: _note,
)

== Exemple : sauvegarder un répertoire <sauvegarder-dossier>

#let _note = [#versions Script d’origine (« Script pour sauvegarder des fichiers »), avec deux changements : le répertoire arrive en argument (l’original écrivait /chemin/vers/dossier), et les variables sont entre guillemets. date +%Y%m%d donne 20261125 le 25 novembre 2026 : le nom trie bien par ordre chronologique. tar -c crée, -z compresse (gzip), -f nomme l’archive ; -t liste son contenu.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.4)[Le script, puis son exécution][
      #fichier-ex("sauvegarde.sh")
      #terminal(titre: none, taille: px(19))[```
        $ ./sauvegarde.sh donnees
        $ ls sauvegarde_*
        sauvegarde_20261125.tar.gz
        $ tar -tzf sauvegarde_*.tar.gz
        donnees/
        donnees/pionnieres.csv
        ```]
    ],
    bloc[Ce qu’il fait][
      - `$(date +%Y%m%d)` : la date, insérée dans le nom
      - `tar -czf` : archive compressée
      - Reste à le lancer chaque jour : cron
    ],
  ),
  source-de: link("https://www.gnu.org/software/tar/manual/tar.html")[GNU tar, manuel],
  note: _note,
)

== Digression : planifier avec cron <cron>

#let _note = [Formats d’après crontab(5) de Debian 13 (paquet cron). Le cours d’origine donnait le format système (avec login) comme format unique ; recopié dans crontab -e, le champ en trop devient le début de la commande. cron fournit un environnement minimal : SHELL=/bin/sh, HOME et LOGNAME tirés de /etc/passwd, PATH réduit (/usr/bin:/bin) ; le répertoire courant est HOME. Quand jour du mois et jour de la semaine sont tous deux restreints, la tâche tourne si l’un OU l’autre correspond. Rejoué avec le service cron de Debian 13 (session « cron » de shell/cm/rejouer.sh) : la tâche voit SHELL=/bin/sh, PATH=/usr/bin:/bin, HOME et LOGNAME d’ada, et démarre dans HOME ; une ligne de crontab -e qui commence par un login échoue (« /bin/sh: 1: ada: not found ») ; avec jour du mois et jour de la semaine tous deux restreints, la tâche tourne dès que l’un des deux correspond ; avec le seul jour du mois, elle ne tourne pas un autre jour. Aucune sortie de cron n’est affichée sur la diapositive.]
#anime(
  rang(
    bloc(taille: px(25))[Le service cron][
      - Lance des commandes à heures fixes : sauvegardes, rapports, nettoyage
      - Table par utilisateur : `crontab -e` (éditer), `crontab -l` (lister)
      - Table système : `/etc/crontab`, `/etc/cron.d/`
    ],
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Une ligne de crontab][
      #terminal(titre: none, taille: px(19))[```
        # min heure jour mois jour_semaine commande
        0 2 * * 1 /home/ada/bin/sauvegarde.sh /home/ada/donnees
        # /etc/crontab : un champ de plus, l’utilisateur
        0 2 * * 1 ada /home/ada/bin/sauvegarde.sh /home/ada/donnees
        ```]
      - Chaque lundi (1 ; 0 = dimanche) à 2 h 00
      - Minutes 0–59, heures 0–23, jour 1–31, mois 1–12
    ],
  ),
  rang(bloc(role: "precaution", taille: px(25))[Pièges][
    - `crontab -e` n’a *pas* de champ utilisateur : ne pas y recopier une ligne de `/etc/crontab`
    - Environnement minimal : chemins absolus, pas de `read`
    - Jour du mois *et* jour de la semaine restreints : la tâche tourne si l’un *ou* l’autre correspond
  ]),
  source-de: link("https://manpages.debian.org/trixie/cron/crontab.5.en.html")[crontab(5), Debian 13],
  note: _note,
)

== set -e : s’arrêter à la première erreur <set-euo-pipefail>

#let _note = [#versions Sans set -e, l’échec du cd ne change rien à la suite : le script continue dans le répertoire courant, avec le code 0 à la fin. Avec un vrai rm -f ./\*.tmp, il supprimerait les fichiers du mauvais répertoire. Autre parade, explicite : cd /tmp/chantier || exit 1. Seule l’option -e sert ici ; -u et pipefail, que la formule set -euo pipefail ajoute, viennent à la diapositive suivante.]
#anime(
  rang(
    bloc(role: "pratique")[Sans set -e][
      #fichier-ex("nettoyage.sh", taille: px(17))
      #terminal(titre: none, taille: px(17))[```
        $ ./nettoyage.sh
        ./nettoyage.sh: line 2: cd: /tmp/chantier: No such file or directory
        Je supprimerais les .tmp de : /home/ada/atelier
        $ echo $?
        0
        ```]
    ],
    bloc(role: "pratique")[Avec set -e][
      #fichier-ex("nettoyage-e.sh", taille: px(17))
      #terminal(titre: none, taille: px(17))[```
        $ ./nettoyage-e.sh
        ./nettoyage-e.sh: line 3: cd: /tmp/chantier: No such file or directory
        $ echo $?
        1
        ```]
    ],
  ),
  rang(bloc(role: "danger", taille: px(25))[Risque réel][
    Sans `set -e`, un `cd` qui échoue laisse le script continuer ailleurs : un `rm` y supprimerait les mauvais fichiers.
  ]),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html")[Bash Reference Manual, The Set Builtin],
  note: _note,
)

== set -u et pipefail

#let _note = [#versions set -u : une variable non définie devient une erreur (ici une faute de frappe : fichier\_journa). Le code d’un pipeline est celui de sa dernière commande ; avec pipefail, celui de la dernière commande en échec. Les trois options viennent du cours d’origine (« Bonnes pratiques pour déboguer »).]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[set -u][
      #fichier-ex("faute-de-frappe.sh", taille: px(18))
      #terminal(titre: none, taille: px(18))[```
        $ ./faute-de-frappe.sh
        ./faute-de-frappe.sh: line 4: fichier_journa: unbound variable
        $ echo $?
        1
        ```]
    ],
    bloc(role: "pratique")[set -o pipefail][
      #terminal(titre: none, taille: px(18))[```
        $ false | true
        $ echo $?
        0
        $ set -o pipefail
        $ false | true
        $ echo $?
        1
        ```]
    ],
  ),
  rang(bloc(role: "retenir", taille: px(25))[`set -euo pipefail` en tête de script][
    - `-e` : arrêt à la première commande en échec
    - `-u` : variable non définie = erreur
    - `-o pipefail` : un pipeline échoue si l’un de ses maillons échoue
  ]),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html")[Bash Reference Manual, The Set Builtin],
  note: _note,
)

== Les limites de set -e <limites-set-e>

#let _note = [#versions Le manuel de Bash liste les exceptions : commande testée par if, while ou until, membre d’une liste && ou || (sauf la dernière), commande précédée de !. Une fonction appelée dans un if perd aussi set -e pour tout son corps. D’où les avis partagés sur set -e (BashFAQ/105) : il aide, mais ne dispense pas de tester les commandes qui comptent.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.4)[Démonstration][
      #terminal(titre: none, taille: px(20))[```
        $ bash -c 'set -e; false && true; echo "toujours là"'
        toujours là
        $ bash -c 'set -e; if false; then :; fi; echo "toujours là"'
        toujours là
        $ bash -c 'set -e; false; echo "jamais affiché"'
        $ echo $?
        1
        ```]
    ],
    bloc(role: "precaution")[Nuance][
      - Un échec testé (`if`, `&&`, `||`) n’arrête pas le script
      - `set -e` complète les tests, ne les remplace pas
    ],
  ),
  source-de: [#link("https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html")[Bash Reference Manual, The Set Builtin] · #link("https://mywiki.wooledge.org/BashFAQ/105")[BashFAQ/105]],
  note: _note,
)

== Déboguer : bash -x <bash-x>

#let _note = [#versions Les lignes + sont écrites sur l’erreur standard, après expansion : on y lit la valeur réelle des arguments. set -x et set +x activent et coupent la trace dans une partie du script. Le cours d’origine conseille aussi des echo aux points critiques.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.5)[Démonstration][
      #terminal(titre: none, taille: px(19))[```
        $ bash -x ./exemple_argument.bash "Grace Hopper"
        + echo 'L’argument zéro est : ./exemple_argument.bash'
        L’argument zéro est : ./exemple_argument.bash
        + echo 'Le premier argument est : Grace Hopper'
        Le premier argument est : Grace Hopper
        + echo 'Le deuxième argument est : '
        Le deuxième argument est : 
        + echo 'Nombre d’arguments : 1'
        Nombre d’arguments : 1
        ```]
    ],
    bloc[Trace][
      - `+` : chaque commande, *après* expansion
      - On voit `$2` vide
      - `set -x` … `set +x` : tracer une partie seulement
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html")[Bash Reference Manual, The Set Builtin],
  note: _note,
)

== ShellCheck relit le script avant l’exécution <shellcheck>

#let _note = [#versions ShellCheck 0.10.0, paquet de Debian 13. Niveaux : error, warning, info, style. Chaque code (SC2045…) a sa page d’explication sur shellcheck.net. Intégrable à Vim, VS Code, aux crochets Git et à la CI : les corrigés des TP le passent.]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.75, taille: px(24))[Un script à relire][
      #fichier-ex("a-relire.sh", taille: px(17))
      - `sudo apt install shellcheck`
      - Erreurs, guillemets manquants, mauvaises pratiques
    ],
    bloc(role: "pratique", poids: 1.25)[Le rapport][
      #terminal(titre: none, taille: px(15))[```
        $ shellcheck a-relire.sh

        In a-relire.sh line 3:
        for fichier in $(ls $dossier); do
                       ^------------^ SC2045 (error): Iterating over ls output is fragile. Use globs.
                            ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

        Did you mean:
        for fichier in $(ls "$dossier"); do


        In a-relire.sh line 4:
            if [ $fichier = "rapport.txt" ]; then
                 ^------^ SC2086 (info): Double quote to prevent globbing and word splitting.

        Did you mean:
            if [ "$fichier" = "rapport.txt" ]; then

        For more information:
          https://www.shellcheck.net/wiki/SC2045 -- Iterating over ls output is fragi...
          https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing ...
        ```]
    ],
  ),
  source-de: link("https://www.shellcheck.net/wiki/")[shellcheck.net, wiki des règles],
  note: _note,
)

== Fonctions et main() <fonctions-main>

#let _note = [#versions Script d’origine (exemple\_main\_function.bash), appel final main "\$\@" (l’original appelait main sans arguments). Une fonction reçoit ses propres \$1, \$2 ; return N y fixe son code de retour. local est détaillé (et nuancé) dans la partie suivante.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[Le script][
      #fichier-ex("exemple_main_function.bash", taille: px(17))
    ],
    bloc(taille: px(25))[Pourquoi main()][
      #terminal(titre: none, taille: px(17))[```
        $ ./exemple_main_function.bash
        Bienvenue dans ce script Bash !
        La somme de 5 et 10 est 15
        ```]
      - Lisibilité : le déroulé se lit en un endroit
      - Une fonction par tâche, réutilisable
      - Arguments centralisés : `main "$@"`
      - `local` : variables propres à la fonction (presque, partie suivante)
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html")[Bash Reference Manual, Shell Functions],
  note: _note,
)

== source n’est pas ./ <source>

#let _note = [#versions Le cours d’origine présentait ./fichier comme équivalent de source : c’est faux, ./ exécute le fichier dans un nouveau processus, dont les définitions disparaissent avec lui. . fichier (point, espace) est la forme POSIX de source. Intérêt : partager fonctions et configuration entre scripts (DRY, Don’t Repeat Yourself).]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.2)[Démonstration][
      #fichier-ex("bibliotheque.sh", taille: px(18))
      #terminal(titre: none, taille: px(18))[```
        # nouveau processus : la fonction meurt avec lui
        $ ./bibliotheque.sh
        $ saluer Ada
        bash: saluer: command not found
        # source : exécuté dans le shell courant
        $ source bibliotheque.sh
        $ saluer Ada
        Bonjour, Ada !
        ```]
    ],
    bloc(role: "avertissement")[Correction du support d’origine][
      - `source fichier` ou `. fichier` : dans le shell *courant*
      - `./fichier` : dans un *nouveau* processus
      - Pour partager des fonctions : `source`
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html")[Bash Reference Manual, Bourne Shell Builtins],
  note: _note,
)

== Digression : qu’est-ce qu’un test unitaire ?

#anime(
  rang(
    bloc[Test unitaire][
      - Vérifie automatiquement une petite partie du code, isolée
      - Rapide : rejoué à chaque modification, en intégration continue
      - Sans dépendance externe (base de données, serveur)
      - But : détecter tôt ce qu’une modification a cassé
    ],
    bloc(role: "pratique")[Pour Bash][
      - *Bats* (_Bash Automated Testing System_) : écrit en Bash ; paquet `bats`
      - *shunit2* : inspiré de JUnit, pour tous les shells POSIX
    ],
  ),
  source-de: link("https://bats-core.readthedocs.io/")[bats-core, documentation],
  note: [Contenu du cours d’origine (« Digression : qu’est-ce qu’un test unitaire ? » et « Frameworks de tests unitaires pour Bash »). Le projet maintenu est bats-core (l’ancien sstephenson/bats est abandonné).],
)

== Tester un script avec Bats <bats>

#let _note = [#versions Bats 1.11.1, paquet de Debian 13. Dans un terminal, bats affiche ce format (rejouer.sh le demande par --formatter pretty, puis reconstitue l’écran) ; dans un tube ou en CI, il écrit le format TAP (1..2, ok 1 …). run lance la commande et range son code dans \$status et sa sortie dans \$output. L’exemple d’origine (run ls) ne teste que ls : celui-ci teste le script de l’exercice.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.5)[Deux tests de liste\_fichiers.bash][
      #fichier-ex("liste_fichiers.bats", taille: px(16))
      #terminal(titre: none, taille: px(18))[```
        $ bats liste_fichiers.bats
        liste_fichiers.bats
         ✓ liste les fichiers d’un répertoire
         ✓ code 1 si le répertoire n’existe pas

        2 tests, 0 failures
        ```]
    ],
    bloc(taille: px(25))[Lire le test][
      - `@test "nom" { … }` : un cas
      - `run` : capture `$status` et `$output`
      - `<<<` : la réponse « au clavier »
      - `[ … ]` : les vérifications
    ],
  ),
  source-de: link("https://bats-core.readthedocs.io/en/stable/writing-tests.html")[bats-core, Writing tests],
  note: _note,
)

== À vous : deux scripts <exercice-scripts>

#anime(
  rang(bloc(role: "question", taille: px(26))[À vous][
    + `liste_fichiers.bash` : demande un répertoire, affiche « Fichier : … » pour chacun de ses fichiers ; code 1 si le répertoire n’existe pas
    + `copie_fichiers.bash` : demande une source et une destination, crée la destination si besoin, copie, confirme ; un code par erreur (1 source absente, 2 création impossible, 3 copie impossible)
    + Passez les deux scripts à ShellCheck
  ]),
  rang(bloc(role: "pratique", taille: px(25))[Prérequis][
    - Paquets `shellcheck` et `bats` ; un répertoire `donnees/` avec quelques fichiers
    - Messages d’erreur sur l’erreur standard : `echo "…" >&2`
  ]),
  note: [Exercices du cours d’origine. À faire en direct ; laisser chercher avant de passer au corrigé. Les tests Bats du premier script sont sur la diapositive précédente.],
)

== Deux scripts : corrigé (1/2)

#slide(repeat: 2, self => {
  let (uncover,) = utils.methods(self)
  question(1, [`liste_fichiers.bash` : demande un répertoire, affiche « Fichier : … » pour chacun de ses fichiers ; code 1 si le répertoire n’existe pas])
  v(px(12))
  uncover("2-", reponse(rangee(poids: (1.1, 1),
    h => fichier-ex("liste_fichiers.bash", taille: px(16), hauteur: h),
    h => terminal(titre: none, taille: px(16), hauteur: h)[```
      $ ./liste_fichiers.bash <<< donnees
      Entrez le chemin du répertoire :
      Fichier : donnees/pionnieres.csv
      Fichier : donnees/services.conf
      $ echo $?
      0
      $ ./liste_fichiers.bash <<< /nulle/part
      Entrez le chemin du répertoire :
      Le répertoire /nulle/part n’existe pas.
      $ echo $?
      1
      ```])))
  utils.speaker-note(self: self)[#versions Corrigé d’origine (code/liste\_fichiers.bash). "\$repertoire"/\* : le motif est développé hors guillemets, le nom du répertoire reste protégé. Le message d’erreur part sur l’erreur standard (>&2). ShellCheck ne signale rien.]
})

== Deux scripts : corrigé (2/2)

#slide(repeat: 2, self => {
  let (uncover,) = utils.methods(self)
  question(2, [`copie_fichiers.bash` : source et destination demandées, création de la destination, copie, confirmation ; codes 1, 2, 3])
  v(px(12))
  uncover("2-", reponse(rangee(poids: (1.7, 1),
    h => fichier-ex("copie_fichiers.bash", taille: px(14), hauteur: h),
    h => terminal(titre: none, taille: px(15), hauteur: h)[```
      $ printf '%s\n' donnees copie > reponses.txt
      $ ./copie_fichiers.bash < reponses.txt
      Entrez le répertoire source :
      Entrez le répertoire destination :
      Le répertoire destination n’existe pas. Création de copie.
      Les fichiers ont été copiés de donnees vers copie.
      $ echo $?
      0
      $ ls copie
      pionnieres.csv
      services.conf
      ```])))
  utils.speaker-note(self: self)[#versions Corrigé d’origine (code/copie\_fichiers\_1.bash et \_2.bash, réunis). Motif commande || \{ echo "…" >&2; exit N; \} : l’échec est traité là où il survient, avec un code propre à chaque cas. Les deux réponses arrivent par un fichier sur l’entrée standard. ShellCheck ne signale rien.]
})

// ======================================================================
= Bash · Portée de local

== local ne protège que vers le haut <portee-local>

#let _note = [#versions Script tiré des explorations de l’auteur (sources/subtilites\_bash) et de l’article « local n’est pas ce que vous croyez » du site. Portée lexicale (C, Python, JavaScript) : la visibilité se lit dans le texte du programme. Portée dynamique (Bash) : une variable locale vit tant que la fonction qui l’a déclarée est sur la pile d’appels, et toutes les fonctions appelées pendant ce temps la voient. Le préfixe \_\_\_ des noms de fonctions est une convention de l’auteur.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.25)[Démonstration][
      #fichier-ex("portee-locale.bash", taille: px(17))
      #terminal(titre: none, taille: px(17))[```
        $ ./portee-locale.bash
          ___visiteuse voit : « déclarée dans main »
        de retour dans main : « modifiée par ___visiteuse »
        ```]
    ],
    bloc(taille: px(25))[Portée dynamique][
      - `___visiteuse` ne reçoit rien, ne déclare rien…
      - … et lit *et modifie* la locale de `main`
      - `local` : la variable disparaît au retour de la fonction (rien ne fuit vers le haut)
      - Mais toutes les fonctions *appelées* la partagent
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html")[Bash Reference Manual, Shell Functions],
  note: _note,
)

== local -r : la constante descend, l’affectation avorte

#let _note = [#versions Comportement observé avec bash 5.2.37 (script non interactif, mode non POSIX) : l’affectation à une variable en lecture seule abandonne toute la commande de premier niveau en cours, ici l’appel de main, puis le script reprend à la commande suivante avec le code 1. En mode POSIX (bash --posix, ou sh), le script entier s’arrêterait. Le script d’origine de l’auteur commente la ligne fautive pour cette raison.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[Le script][
      #fichier-ex("portee-readonly.bash", taille: px(16))
    ],
    bloc(taille: px(24))[Ce qui se passe][
      #terminal(titre: none, taille: px(15))[```
        $ ./portee-readonly.bash
          je vois : « gravée dans main »
        ./portee-readonly.bash: line 6: _constante: readonly variable
        suite du script, code de retour de main : 1
        ```]
      - `local -r` : la fonction appelée voit la constante, sans pouvoir la modifier
      - L’affectation refusée n’est pas un simple échec : le reste de la fonction *et* de `main` est sauté
      - Le script reprend après l’appel de `main`, avec le code 1
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html")[Bash Reference Manual, Bash Builtins (local, declare -r)],
  note: _note,
)

== Sous-shell : une copie de tout <sous-shell>

#let _note = [#versions Les numéros de processus changent à chaque exécution. \$\$ donne le PID du shell principal, hérité tel quel par les sous-shells (POSIX) ; BASHPID donne celui du processus courant. On dit parfois que les variables sont « exportées implicitement » vers le sous-shell : c’est un abus de langage, le sous-shell est une copie (fork, la duplication du processus) du shell, export ou pas.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.15)[Le script][
      #fichier-ex("portee-sous-shell.bash", taille: px(15))
    ],
    bloc(taille: px(24))[Sous-shell][
      #terminal(titre: none, taille: px(15))[```
        $ ./portee-sous-shell.bash
        main : $$=1835, BASHPID=1835
        — appel direct :
          BASHPID=1835 : je vois « déclarée dans main »
        main relit : « modifiée par ___visiteuse »
        — appel en sous-shell :
          BASHPID=1836 : je vois « déclarée dans main »
        main relit : « déclarée dans main »
        ```]
      - `( … )` : un nouveau processus, copie du shell (_fork_ : la duplication d’un processus) qui garde tout (locales, constantes)
      - Les modifications restent dans la copie
      - `$$` : numéro de processus (PID) du shell principal ; `BASHPID` : celui du processus courant ; différents dans un sous-shell
      - Aussi : chaque `$( … )` et chaque maillon d’un tube
    ],
  ),
  source-de: link("https://www.gnu.org/software/bash/manual/html_node/Command-Execution-Environment.html")[Bash Reference Manual, Command Execution Environment],
  note: _note,
)

== Nouveau processus : seul l’environnement passe

#let _note = [#versions export transmet des chaînes dans l’environnement, sans attribut : la constante arrive modifiable. export -f transmet le texte de la fonction pour qu’un bash -c la retrouve : c’est le montage classique avec nohup pour détacher un traitement long (script d’origine utilisation\_de\_export\_avec\_nohup.bash). La règle à retenir est la conclusion du script d’exploration de l’auteur.]
#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  let b-script = bloc(role: "pratique")[Le script][#fichier-ex("export-processus.bash", taille: px(15))]
  let b-proc = bloc(taille: px(23))[Nouveau processus][
    #terminal(titre: none, taille: px(15))[```
      $ ./export-processus.bash
        nouveau processus : je vois « en lecture seule ici »
        readonly perdu : « modifiée sans protestation »
      main relit : « en lecture seule ici »
      ```]
    - `bash -c`, `nohup`, un autre script : n’hérite que de l’*environnement*
    - `export` : la valeur passe, l’attribut `readonly` non
    - Le processus parent garde sa copie intacte
  ]
  let b-ret = bloc(role: "retenir", taille: px(23))[À retenir][
    Bonne pratique : qu’une fonction ne touche que ses arguments et ses locales ; pour toucher celles d’une autre, la déclarer *dans* celle-ci (fonction imbriquée).
  ]
  grid(columns: (1fr, 1fr), column-gutter: px(32),
    bloc-anime(b-script, 1, uncover),
    stack(spacing: px(20), bloc-anime(b-proc, 1, uncover), bloc-anime(b-ret, 5, uncover)),
  )
  source[#link("https://www.gnu.org/software/bash/manual/html_node/Environment.html")[Bash Reference Manual, Environment]]
  utils.speaker-note(self: self, _note)
})

== À vous : que va afficher devinette.bash ? <exercice-local>

#anime(
  rang(
    bloc(role: "question", poids: 1.1)[À vous][
      + Écrivez, sans l’exécuter, les cinq lignes affichées par `./devinette.bash`
      + Quelle ligne change si l’on retire `local` devant `total` ?
    ],
    bloc(role: "pratique")[Le script][
      #fichier-ex("devinette.bash", taille: px(18))
    ],
  ),
  note: [À faire en direct : chacun écrit sa prévision, puis on exécute. Indice : total n’est déclarée que dans main.],
)

== devinette.bash : corrigé

#corriges(note: [#versions Question 1 : compter lit et modifie la locale total de main (portée dynamique) : 11, puis 12 ; dans le sous-shell, 13, perdu au retour. message est locale à compter : vide dans main. total est locale à main : vide au niveau du script. Question 2 : sans local, total devient globale et la dernière ligne affiche total=12 (rejoué avec une copie du script modifiée).],
  (1, [Les cinq lignes affichées par `./devinette.bash`],
    reponse(terminal(titre: none, taille: px(20))[```
      $ ./devinette.bash
      appel n° 11
      appel n° 12
      appel n° 13
      main : total=12, message=vide
      script : total=vide
      ```])),
  (2, [Quelle ligne change sans `local` devant `total` ?],
    reponse[La dernière : `total` devient globale, le script affiche `total=12`]),
)

// ======================================================================
= sed

== sed : un éditeur de flux

#let _note = [#versions GNU sed 4.9. Contenu de la diapositive d’origine « Introduction à sed ». Sur macOS et les BSD, sed est une autre implémentation : les commandes de base sont les mêmes, certaines options diffèrent (-i, plus loin).]
#anime(
  rang(
    bloc[Qu’est-ce que sed ?][
      - Un éditeur de flux (_stream editor_) *non interactif* : il transforme le texte qui le traverse
      - Rechercher, remplacer, insérer, supprimer des lignes
      - Avec des expressions régulières
      - Ligne à ligne : un million de lignes se traitent comme dix
    ],
    bloc(role: "pratique")[Syntaxe][
      #terminal(titre: none, taille: px(22))[```
        $ sed 'script' fichier
        $ commande | sed 'script'
        ```]
      - Le résultat va sur la sortie standard
      - Le fichier n’est *pas* modifié
    ],
  ),
  source-de: link("https://www.gnu.org/software/sed/manual/sed.html")[GNU sed, manuel],
  note: _note,
)

== Le cycle de sed : une ligne à la fois <cycle-sed>

#let _note = [#versions D’après le manuel de GNU sed, section « How sed works » : sed garde deux tampons, l’espace de motif (pattern space), actif, et l’espace de réserve (hold space), hors du cadre de ce cours. sed '' : script vide, chaque ligne est réaffichée telle quelle. -n supprime l’affichage automatique ; p affiche l’espace de motif à la demande : sans -n, chaque ligne sort deux fois.]
#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1.15fr, 1fr), column-gutter: px(40),
    lignes(largeur: px(90), taille-cle: px(36), taille: px(25), uncover: uncover,
      ([1], [Lire une ligne de l’entrée, retirer son saut de ligne, la placer dans l’*espace de motif* (_pattern space_)]),
      ([2], [Appliquer chaque commande du script dont l’*adresse* correspond (sans adresse : toutes les lignes)]),
      ([3], [Fin du script : afficher l’espace de motif, sauf avec `-n`]),
      ([4], [Vider l’espace de motif, passer à la ligne suivante : retour en 1]),
    ),
    stack(spacing: px(16),
      uncover("5-", terminal(titre: none, taille: px(19))[```
        $ sed '' lignes.txt
        Ligne 1 : Première ligne.
        Ligne 2 : Deuxième ligne.
        Ligne 3 : Troisième ligne.
        $ sed -n '2p' lignes.txt
        Ligne 2 : Deuxième ligne.
        ```]),
      uncover("6-", terminal(titre: none, taille: px(19))[```
        # sans -n : affichée par p, puis en 3
        $ sed 'p' lignes.txt
        Ligne 1 : Première ligne.
        Ligne 1 : Première ligne.
        Ligne 2 : Deuxième ligne.
        Ligne 2 : Deuxième ligne.
        Ligne 3 : Troisième ligne.
        Ligne 3 : Troisième ligne.
        ```]),
    ),
  )
  source[#link("https://www.gnu.org/software/sed/manual/sed.html#Execution-Cycle")[GNU sed, How sed works]]
  utils.speaker-note(self: self, _note)
})

== Substituer : s/motif/remplacement/drapeaux <sed-substitution>

#let _note = [#versions Exemple d’origine (fichier.txt, ici turing.txt), avec l’orthographe Alan Turing. Drapeaux : g toutes les occurrences, un nombre n la n-ième seulement, i (GNU) sans tenir compte de la casse. Le séparateur est le caractère qui suit s : / par convention, mais , : | ou \# conviennent, ce qui évite d’échapper chaque / d’un chemin (cours d’origine, « Choix du séparateur »).]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.4)[Démonstration][
      #terminal(titre: none, taille: px(19))[```
        $ sed 's/Alan Turing/Ada Lovelace/g' turing.txt
        Bonjour Ada Lovelace.
        Ada Lovelace aime coder en Bash.
        # le fichier n’a pas changé
        $ cat turing.txt
        Bonjour Alan Turing.
        Alan Turing aime coder en Bash.
        $ echo "Alan Turing et Alan Kay" | sed 's/Alan/Ada/'
        Ada Turing et Alan Kay
        $ echo "Alan Turing et Alan Kay" | sed 's/Alan/Ada/g'
        Ada Turing et Ada Kay
        # un autre séparateur pour les chemins
        $ echo "/usr/local/bin" | sed 's/\/usr\/local/\/opt/'
        /opt/bin
        $ echo "/usr/local/bin" | sed 's,/usr/local,/opt,'
        /opt/bin
        ```]
    ],
    bloc(taille: px(25))[`s/motif/rempl/drapeaux`][
      - Sans drapeau : la *première* occurrence de chaque ligne
      - `g` (_global_) : toutes
      - Séparateur libre : `s,…,…,`
    ],
  ),
  source-de: link("https://www.gnu.org/software/sed/manual/sed.html#The-_0022s_0022-Command")[GNU sed, The s Command],
  note: _note,
)

== Supprimer et insérer : d, i, a <sed-commandes>

#let _note = [#versions Exemples d’origine (commandes d et i), sur un même fichier de trois lignes. La forme d’une ligne 2i texte est une extension GNU ; la forme POSIX écrit i\\ puis le texte sur la ligne suivante. d supprime l’espace de motif et passe à la ligne suivante, sans l’afficher.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.35)[Démonstration][
      #terminal(titre: none, taille: px(20))[```
        $ sed '2d' lignes.txt
        Ligne 1 : Première ligne.
        Ligne 3 : Troisième ligne.
        $ sed '2i Nouveau texte ajouté avant la ligne 2' lignes.txt
        Ligne 1 : Première ligne.
        Nouveau texte ajouté avant la ligne 2
        Ligne 2 : Deuxième ligne.
        Ligne 3 : Troisième ligne.
        $ sed '1a Texte ajouté après la ligne 1' lignes.txt
        Ligne 1 : Première ligne.
        Texte ajouté après la ligne 1
        Ligne 2 : Deuxième ligne.
        Ligne 3 : Troisième ligne.
        ```]
    ],
    bloc[Commandes][
      - `d` (_delete_) : supprimer la ligne
      - `i` (_insert_) : insérer *avant*
      - `a` (_append_) : ajouter *après*
      - Le nombre devant : l’adresse, ici un numéro de ligne
      - `2i texte` sur une seule ligne : extension de GNU sed (POSIX : `i\` puis le texte à la ligne suivante)
    ],
  ),
  source-de: link("https://www.gnu.org/software/sed/manual/sed.html#Other-Commands")[GNU sed, Other Commands],
  note: _note,
)

== Adresser : numéro, plage, motif <sed-adresses>

#let _note = [#versions L’adresse se place devant la commande ; une plage s’écrit début,fin ; \$ désigne la dernière ligne. /langages/ : les lignes qui contiennent langages (expression régulière). Le cours d’origine citait l’« édition de texte sur des plages de lignes » parmi les capacités non abordées.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.6)[Démonstration][
      #terminal(titre: none, taille: px(18))[```
        # sans la ligne 1 (l’en-tête)
        $ sed '1d' pionnieres.csv | head -n 2
        Lovelace Ada;1843;programmation;premier programme publié
        Booth Kathleen;1947;langages;premier langage d'assemblage
        # sans les lignes qui contiennent « langages »
        $ sed '/langages/d' pionnieres.csv
        nom;annee;domaine;contribution
        Lovelace Ada;1843;programmation;premier programme publié
        Johnson Katherine;1962;calcul;trajectoires de Friendship 7
        Hamilton Margaret;1969;logiciel;logiciel embarqué d'Apollo 11
        Conway Lynn;1978;materiel;révolution VLSI
        Perlman Radia;1985;reseau;protocole spanning tree
        Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste
        # seulement les lignes 2 à 3
        $ sed -n '2,3p' pionnieres.csv
        Lovelace Ada;1843;programmation;premier programme publié
        Booth Kathleen;1947;langages;premier langage d'assemblage
        ```]
    ],
    bloc(taille: px(25))[Adresses][
      - `2` : la ligne 2
      - `2,3` : une plage
      - `$` : la dernière ligne
      - `/motif/` : les lignes qui contiennent le motif
      - `-n` et `p` : n’afficher que ce qu’on demande
    ],
  ),
  source-de: link("https://www.gnu.org/software/sed/manual/sed.html#Addresses-overview")[GNU sed, Addresses],
  note: _note,
)

== -i : modifier le fichier, avec une copie de secours <sed-in-place>

#let _note = [#versions -i (in-place) écrit dans un fichier temporaire puis remplace l’original. -i.bak garde l’original sous services.conf.bak. Le sed de macOS et des BSD exige un argument : sed -i '' 's/…/…/' f ; la forme GNU sed -i 's/…/…/' f y prend le script pour un suffixe. Le cours d’origine recommandait déjà de tester sans -i d’abord.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Démonstration][
      #terminal(titre: none, taille: px(19))[```
        $ sed -i.bak 's/autostart = yes/autostart = no/' services.conf
        $ grep autostart services.conf
        autostart = no
        autostart = no
        autostart = no
        $ echo services.conf*
        services.conf services.conf.bak
        $ diff services.conf.bak services.conf
        5c5
        < autostart = yes
        ---
        > autostart = no
        10c10
        < autostart = yes
        ---
        > autostart = no
        ```]
    ],
    bloc(role: "avertissement")[Avec des gants][
      - `-i` modifie le *fichier*, sans retour arrière
      - Tester la commande sans `-i` d’abord
      - `-i.bak` : copie de l’original
      - macOS, BSD : `sed -i '' …`
    ],
  ),
  source-de: [#link("https://www.gnu.org/software/sed/manual/sed.html#Command_002dLine-Options")[GNU sed, Command-Line Options] · #link("https://man.freebsd.org/cgi/man.cgi?sed")[sed(1), FreeBSD]],
  note: _note,
)

== Expressions régulières : basiques ou étendues <sed-regex>

#let _note = [#versions Exemple d’origine (identifiants à trois chiffres). Sans -E, sed lit des expressions régulières basiques (BRE, POSIX) : \{3\} y est littéral, il faut \\\{3\\\}, de même \\( \\) et \\+ (GNU). Avec -E, étendues (ERE) : \{3\}, ( ), +, ? sans antislash. -E est POSIX depuis 2024 ; -r en est l’ancien synonyme GNU.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.2)[Démonstration][
      #terminal(titre: none, taille: px(20))[```
        $ sed -E 's/[0-9]{3}/###/g' identifiants.txt
        Identifiant : ###
        Identifiant : ###
        Identifiant : ###
        $ sed 's/[0-9]\{3\}/###/g' identifiants.txt
        Identifiant : ###
        Identifiant : ###
        Identifiant : ###
        $ sed 's/[0-9]{3}/###/g' identifiants.txt
        Identifiant : 123
        Identifiant : 456
        Identifiant : 789
        ```]
    ],
    bloc(taille: px(25))[Deux syntaxes][
      - `[0-9]` : un chiffre ; `{3}` : trois fois
      - Sans `-E` (basiques) : `\{3\}`, `\( \)`
      - `-E` (étendues) : `{3}`, `( )`, `+`, `?`
      - Sans `-E`, `{3}` est pris au pied de la lettre
    ],
  ),
  source-de: link("https://www.gnu.org/software/sed/manual/sed.html#BRE-vs-ERE")[GNU sed, BRE vs ERE],
  note: _note,
)

== Groupes de capture : réutiliser ce qu’on a trouvé <sed-captures>

#let _note = [#versions Exemple d’origine (autrices.txt, « encore 1 000 000 de lignes comme celles-ci ») en syntaxe basique, puis sur le fil rouge en syntaxe étendue. .\* est gourmand : le premier groupe prend le plus long possible, jusqu’à la dernière espace (un prénom composé passerait dans le nom). [^;]+ : un ou plusieurs caractères autres que ; ; [^ ;]+ : ni espace ni ;. & désigne toute la correspondance.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.7)[Démonstration][
      #terminal(titre: none, taille: px(18))[```
        $ cat autrices.txt
        Nom : Tuaillon Victoire
        Nom : Despentes Virginie
        Nom : Bagieu Pénélope
        $ sed 's/Nom : \(.*\) \(.*\)/Prénom : \2, Nom : \1/g' autrices.txt
        Prénom : Victoire, Nom : Tuaillon
        Prénom : Virginie, Nom : Despentes
        Prénom : Pénélope, Nom : Bagieu
        # en étendues : parenthèses sans antislash
        $ sed -E 's/^([^ ;]+) ([^;]+);/\2 \1;/' pionnieres.csv | head -n 3
        nom;annee;domaine;contribution
        Ada Lovelace;1843;programmation;premier programme publié
        Kathleen Booth;1947;langages;premier langage d'assemblage
        ```]
    ],
    bloc(taille: px(25))[Capturer][
      - `\( … \)` (ou `( … )` avec `-E`) : un groupe
      - `\1`, `\2` : le texte capturé, dans le remplacement
      - Réordonner des champs sur des millions de lignes
    ],
  ),
  source-de: link("https://www.gnu.org/software/sed/manual/sed.html#Back_002dreferences-and-Subexpressions")[GNU sed, Back-references and Subexpressions],
  note: _note,
)

== À vous : sed sur les données <exercice-sed>

#anime(
  rang(bloc(role: "question", taille: px(26))[À vous, avec sed seulement][
    + Corrigez `materiel` en `matériel` et `reseau` en `réseau` dans `pionnieres.csv` (sortie standard)
    + Comptez les lignes de `pionnieres.csv` sans son en-tête
    + Sur une *copie* de `services.conf`, remplacez `port = 0` par `port = disabled`, dans le fichier
    + Une ligne `#PasswordAuthentication yes` d’une copie de `sshd_config` doit devenir `PasswordAuthentication no` : capturez le nom de la directive plutôt que de le réécrire
  ]),
  note: [Exercices 1 à 3 inspirés du dojo du site ; 4 : cas d’administration réel (durcir SSH). Le cours d’origine renvoyait au tutoriel tiers softsam/sed-awk-tutoriel, sans licence : non repris ici, cité en annexe.],
)

== sed : corrigé (1/2)

#corriges(note: [#versions Question 1 : deux commandes séparées par ; dans un même script ; chacune s’applique à chaque ligne. Question 2 : 1d retire l’en-tête, wc -l compte. Pour garder les en-têtes accentués intacts, on aurait aussi pu écrire s/materiel;/matériel;/.],
  (1, [Corrigez `materiel` et `reseau` (sortie standard)],
    reponse(terminal(titre: none, taille: px(19))[```
      $ sed 's/materiel/matériel/; s/reseau/réseau/' pionnieres.csv | tail -n 3
      Conway Lynn;1978;matériel;révolution VLSI
      Perlman Radia;1985;réseau;protocole spanning tree
      Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste
      ```])),
  (2, [Comptez les lignes sans l’en-tête],
    reponse(terminal(titre: none, taille: px(19))[```
      $ sed '1d' pionnieres.csv | wc -l
      8
      ```])),
)

== sed : corrigé (2/2)

#corriges(note: [#versions Question 3 : ^ et \$ ancrent le motif en début et fin de ligne, pour ne pas toucher un port = 0123 éventuel. Question 4 : \#? rend le dièse facultatif (ligne commentée ou non) ; la capture évite une faute de frappe dans le remplacement. Pour le vrai fichier : -i, sudo, et une session SSH de secours ouverte, sous peine de s’enfermer dehors (cours Accès distants).],
  (3, [Sur une copie de `services.conf` : `port = 0` → `port = disabled`, dans le fichier],
    reponse(terminal(titre: none, taille: px(19))[```
      $ cp services.conf services.copie
      $ sed -i 's/^port = 0$/port = disabled/' services.copie
      $ grep -n port services.copie
      3:port = 8080
      8:port = 5432
      13:port = disabled
      ```])),
  (4, [`#PasswordAuthentication yes` → `PasswordAuthentication no`, en capturant le nom],
    reponse(terminal(titre: none, taille: px(19))[```
      $ cat sshd_config.copie
      #PasswordAuthentication yes
      $ sed -E 's,^#?(PasswordAuthentication) .*,\1 no,' sshd_config.copie
      PasswordAuthentication no
      ```])),
)

// ======================================================================
= awk

== awk : un langage pour les colonnes

#let _note = [#versions awk vient de ses trois auteurs, Aho, Weinberger et Kernighan (Bell Labs, 1977). Sous Debian, la commande awk est mawk 1.3.4 par défaut ; gawk (GNU awk) s’installe à part (paquet gawk). Les programmes de ce cours s’en tiennent à l’awk de POSIX : ils marchent avec les deux, sauf l’ordre de for (… in …), signalé plus loin.]
#anime(
  rang(
    bloc[Qu’est-ce qu’awk ?][
      - Un *langage de programmation* orienté texte
      - Pour les fichiers structurés en colonnes : CSV, journaux, sorties de commandes
      - Filtrer, extraire, calculer, agréger
      - Conditions, boucles, expressions régulières
    ],
    bloc(role: "pratique")[Syntaxe][
      #terminal(titre: none, taille: px(22))[```
        $ awk 'motif { action }' fichier
        ```]
      - Sous Debian : `awk` est *mawk* ; *gawk* en option
    ],
  ),
  source-de: link("https://pubs.opengroup.org/onlinepubs/9799919799/utilities/awk.html")[POSIX, awk],
  note: _note,
)

== awk : enregistrements, champs, motif → action <modele-awk>

#let _note = [#versions D’après la spécification POSIX d’awk : l’entrée est découpée en enregistrements (séparateur RS, le saut de ligne par défaut), chaque enregistrement en champs (séparateur FS : par défaut, des suites d’espaces ou de tabulations ; -F le change). Pour chaque enregistrement, chaque paire motif \{ action \} est essayée dans l’ordre. Concaténation : deux expressions côte à côte, sans opérateur.]
#slide(repeat: 7, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1.1fr, 1fr), column-gutter: px(40),
    lignes(largeur: px(200), taille-cle: px(30), taille: px(25), uncover: uncover,
      ([Enregistrement], [Une ligne (séparateur `RS`) ; `$0` : la ligne entière ; `NR` : son numéro]),
      ([Champs], [`$1`, `$2`… découpés par `FS` (espaces par défaut, `-F';'`) ; `NF` : leur nombre]),
      ([Motif → action], [Pour chaque ligne : si le motif est vrai, l’action s’exécute]),
      ([Par défaut], [Sans motif : toutes les lignes ; sans action : `print $0`]),
      ([BEGIN, END], [Actions avant la première ligne, après la dernière]),
    ),
    stack(spacing: px(16),
      uncover("6-", terminal(titre: none, taille: px(19))[```
        $ cat personnes.txt
        Alice 25 F
        Bob 30 M
        Chris 22 NB
        $ awk '{ print NR ": " $0 " (" NF " champs)" }' personnes.txt
        1: Alice 25 F (3 champs)
        2: Bob 30 M (3 champs)
        3: Chris 22 NB (3 champs)
        ```]),
      uncover("7-", encadre(role: "retenir", libelle: [À retenir :])[awk lit ligne à ligne, découpe en champs, et applique chaque paire `motif { action }`.]),
    ),
  )
  source[#link("https://pubs.opengroup.org/onlinepubs/9799919799/utilities/awk.html")[POSIX, awk] · #link("https://www.gnu.org/software/gawk/manual/gawk.html#Getting-Started")[GNU awk, Getting Started]]
  utils.speaker-note(self: self, _note)
})

== Les champs : \$1, \$2… et le séparateur -F <awk-champs>

#let _note = [#versions Premier exemple : celui du cours d’origine (« enlever les informations concernant le genre »). La virgule de print insère le séparateur de sortie OFS, une espace par défaut. NR > 1 saute l’en-tête du CSV.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Démonstration][
      #terminal(titre: none, taille: px(20))[```
        $ awk '{ print $1, $2 }' personnes.txt
        Alice 25
        Bob 30
        Chris 22
        # -F';' : le séparateur du CSV ; NR > 1 : sans l’en-tête
        $ awk -F';' 'NR > 1 { print $1, $2 }' pionnieres.csv | head -n 3
        Lovelace Ada 1843
        Booth Kathleen 1947
        Hopper Grace 1952
        ```]
    ],
    bloc[Extraire des colonnes][
      - `print $1, $2` : deux champs, séparés par `OFS`
      - `-F';'` : le séparateur d’entrée
      - `NR > 1` : un motif, l’action ne vaut que pour les lignes 2 et suivantes
    ],
  ),
  source-de: link("https://www.gnu.org/software/gawk/manual/gawk.html#Fields")[GNU awk, Examining Fields],
  note: _note,
)

== Comparer : nombre ou chaîne ? <awk-comparaison>

#let _note = [#versions Même résultat avec gawk 5.2.1. Le filtre d’origine \$2 < "30" compare des chaînes (ordre du dictionnaire) : "100" < "30" parce que « 1 » vient avant « 3 ». Il donnait le bon résultat par chance sur les données d’origine. Règle POSIX : un champ qui ressemble à un nombre est comparé numériquement à une constante numérique, lexicalement dès que l’autre côté est une chaîne (une constante entre guillemets).]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.25)[L’exemple d’origine, puis un cas qui le casse][
      #terminal(titre: none, taille: px(20))[```
        $ awk '$2 < "30" { print $1, $2 }' personnes.txt
        Alice 25
        Chris 22
        $ echo "Dan 100 M" >> personnes.txt
        $ awk '$2 < "30" { print $1, $2 }' personnes.txt
        Alice 25
        Chris 22
        Dan 100
        $ awk '$2 < 30 { print $1, $2 }' personnes.txt
        Alice 25
        Chris 22
        ```]
    ],
    bloc(role: "avertissement")[Le piège][
      - `"30"` entre guillemets : comparaison de *chaînes*
      - `"100" < "30"` : vrai, caractère par caractère
      - `30` sans guillemets : comparaison de *nombres*
    ],
  ),
  source-de: link("https://www.gnu.org/software/gawk/manual/gawk.html#Variable-Typing")[GNU awk, Variable Typing and Comparison],
  note: _note,
)

== Calculer, puis résumer avec END <awk-begin-end>

#let _note = [#versions Exemples d’origine (« Calculs avec awk », « Regrouper et sommer »). Une variable awk non initialisée vaut 0 (ou la chaîne vide) : somme += \$2 n’a pas besoin de déclaration. La virgule de print insère OFS : "Total : ", somme donne deux espaces, la sortie d’origine (« Total : 45 ») en montrait une.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.5)[Démonstration][
      #terminal(titre: none, taille: px(18))[```
        $ cat produits.txt
        Produit1 10 2
        Produit2 15 4
        Produit3 20 1
        $ awk '{ print $1, $2 * $3 }' produits.txt
        Produit1 20
        Produit2 60
        Produit3 20
        # la virgule ajoute une espace : deux en tout
        $ awk '{ somme += $2 } END { print "Total : ", somme }' produits.txt
        Total :  45
        $ awk '{ somme += $2 } END { print "Total :", somme }' produits.txt
        Total : 45
        $ awk -F';' 'BEGIN { print "Avant la première ligne" } END { print NR " lignes lues" }' pionnieres.csv
        Avant la première ligne
        9 lignes lues
        ```]
    ],
    bloc(taille: px(25))[Calculs][
      - Opérateurs `+ - * / %`
      - `somme += $2` : accumuler, ligne après ligne
      - `END { … }` : après la dernière ligne
      - `BEGIN { … }` : avant la première
    ],
  ),
  source-de: link("https://www.gnu.org/software/gawk/manual/gawk.html#BEGIN_002fEND")[GNU awk, The BEGIN and END Special Patterns],
  note: _note,
)

== Tableaux associatifs : compter par domaine <awk-tableaux>

#let _note = [#versions mawk 1.3.4. gawk 5.2.1 sort le même tableau dans un autre ordre (calcul, cryptographie, materiel, langages, logiciel, programmation, reseau). POSIX ne fixe pas l’ordre de for (clé in tableau) : on trie après (| sort). Le cours d’origine citait les tableaux associatifs parmi les capacités non abordées.]
#anime(
  rang(
    bloc(role: "pratique", poids: 2)[Démonstration][
      #terminal(titre: none, taille: px(17))[```
        $ awk -F';' 'NR > 1 { n[$3]++ } END { for (d in n) print d, n[d] }' pionnieres.csv
        logiciel 1
        materiel 1
        cryptographie 1
        calcul 1
        reseau 1
        programmation 1
        langages 2
        $ awk -F';' 'NR > 1 { n[$3]++ } END { for (d in n) print d, n[d] }' pionnieres.csv | sort
        calcul 1
        cryptographie 1
        langages 2
        logiciel 1
        materiel 1
        programmation 1
        reseau 1
        ```]
    ],
    bloc(taille: px(25))[Tableau associatif][
      - Indexé par une *chaîne* : `n["langages"]`
      - `n[$3]++` : un compteur par domaine
      - `for (d in n)` : parcourir les clés
      - Ordre non garanti (mawk et gawk diffèrent) : trier la sortie
    ],
  ),
  source-de: link("https://www.gnu.org/software/gawk/manual/gawk.html#Scanning-an-Array")[GNU awk, Scanning All Elements of an Array],
  note: _note,
)

== Filtrer par expression régulière : `~` <awk-regex>

#let _note = [#versions Exemple d’origine (adresses électroniques), dont le motif /\@example.fr/ marche, mais où le point désigne n’importe quel caractère : il accepterait \@exampleXfr. \\. désigne un point littéral, \$ la fin du champ. !\~ est la négation. Sans précision, /motif/ seul s’applique à \$0.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Démonstration][
      #terminal(titre: none, taille: px(20))[```
        $ awk '$0 ~ /@example.fr/ { print $0 }' emails.txt
        chris@example.fr Chris
        $ awk '$1 ~ /@example\.fr$/ { print $2 }' emails.txt
        Chris
        $ awk -F';' '$4 ~ /premier/ { print $1 }' pionnieres.csv
        Lovelace Ada
        Booth Kathleen
        Hopper Grace
        ```]
    ],
    bloc(taille: px(25))[Motif `~`][
      - `champ ~ /regex/` : le champ correspond
      - `!~` : ne correspond pas
      - `.` : n’importe quel caractère ; `\.` : un point
      - `$` : fin du texte testé
    ],
  ),
  source-de: link("https://www.gnu.org/software/gawk/manual/gawk.html#Regexp-Usage")[GNU awk, How to Use Regular Expressions],
  note: _note,
)

== À vous : awk sur les données <exercice-awk>

#anime(
  rang(bloc(role: "question", taille: px(26))[À vous, avec awk seulement, sur pionnieres.csv][
    + Nom et année des contributions *antérieures à 1970*
    + La contribution la plus récente : nom et année
    + Nom et domaine, séparés par une tabulation (`OFS`)
    + Combien de contributions contiennent « premier » ?
  ]),
  rang(bloc(role: "pratique", taille: px(24))[Aide][
    - `-v OFS='\t'` : donner une valeur à une variable avant la lecture
    - `if (condition) { … }` dans une action
  ]),
  note: [Exercices inspirés du dojo du site. À faire en direct ; laisser chercher avant de passer au corrigé.],
)

== awk : corrigé (1/2)

#corriges(note: [#versions Question 1 : 1970 sans guillemets, comparaison numérique ; 1969 inclus, 1978 exclu. Question 2 : max vaut 0 au départ (variable non initialisée), toute année le dépasse.],
  (1, [Nom et année des contributions antérieures à 1970],
    reponse(terminal(titre: none, taille: px(18))[```
      $ awk -F';' 'NR > 1 && $2 < 1970 { print $1, $2 }' pionnieres.csv
      Lovelace Ada 1843
      Booth Kathleen 1947
      Hopper Grace 1952
      Johnson Katherine 1962
      Hamilton Margaret 1969
      ```])),
  (2, [La contribution la plus récente : nom et année],
    reponse(terminal(titre: none, taille: px(18))[```
      $ awk -F';' 'NR > 1 { if ($2 > max) { max = $2; nom = $1 } } END { print nom, max }' pionnieres.csv
      Perlman Radia 1985
      ```])),
)

== awk : corrigé (2/2)

#corriges(note: [#versions Question 3 : la tabulation sépare les champs de sortie (affichée ici comme un saut de colonne). Question 4 : n++ ne s’exécute que pour les lignes dont le 4e champ contient « premier ».],
  (3, [Nom et domaine, séparés par une tabulation],
    reponse(terminal(titre: none, taille: px(18))[```
      $ awk -F';' -v OFS='\t' 'NR > 1 { print $1, $3 }' pionnieres.csv | head -n 3
      Lovelace Ada	programmation
      Booth Kathleen	langages
      Hopper Grace	langages
      ```])),
  (4, [Combien de contributions contiennent « premier » ?],
    reponse(terminal(titre: none, taille: px(18))[```
      $ awk -F';' '$4 ~ /premier/ { n++ } END { print n }' pionnieres.csv
      3
      ```])),
)

// ======================================================================
= Annexe

== Mémo : guillemets et expansions <memo-guillemets>

#let _note = [#versions Chaque ligne rejouée par shell/cm/rejouer.sh (session « Mémo »), dans un répertoire qui ne contient que ada.txt, grace.txt et hedy.txt. Exemples originaux de l’article du site ; le tableau classique qui circule vient de Stack Overflow, sous une licence (CC BY-SA) incompatible avec celle de ce cours : il n’est pas repris.]
#anime(
  rang(bloc(taille: px(22))[`p="Ada Lovelace"`, le répertoire contient ada.txt, grace.txt, hedy.txt][
    #tableau((1fr, 1.25fr, 2fr), inset: (x: px(10), y: px(5)),
      ([Écrit], [Arguments reçus], [Pourquoi]),
      [`"${p}"`], [`Ada Lovelace`], [variable développée, un seul mot],
      [`'${p}'`], [`${p}`], [rien n’est développé entre simples],
      [`"'${p}'"`], [`'Ada Lovelace'`], [des simples dans des doubles : ordinaires],
      [`'"${p}"'`], [`"${p}"`], [des doubles dans des simples : ordinaires],
      [`${p}`], [`Ada` · `Lovelace`], [hors guillemets : découpage en mots],
      [`*.txt`], [`ada.txt` · `grace.txt` · `hedy.txt`], [chemins, hors guillemets],
      [`"*.txt"`], [`*.txt`], [pas de chemins entre guillemets],
      [`"\${p}"`, `"100$"`], [`${p}`, `100$`], [`\$` échappe ; un `$` sans nom reste `$`],
      [`'\n'`, `"\n"`], [`\n`], [`\n` n’est interprété ni entre simples ni entre doubles],
      [`$'\n\t'`, `$'\''`], [saut de ligne, tabulation ; `'`], [citation ANSI-C],
      [`"$(echo hi)"`, `'$(echo hi)'`], [`hi`, `$(echo hi)`], [commande exécutée entre doubles seulement],
    )
  ]),
  note: _note,
)

== Pour s’entraîner et aller plus loin

#anime(
  rang(
    bloc(role: "pratique", taille: px(25))[S’entraîner][
      - #link("https://github.com/phyver/GameShell")[GameShell] : un jeu d’aventure qui se joue au shell (exercice du cours d’origine)
      - #link("https://github.com/softsam/sed-awk-tutoriel")[softsam/sed-awk-tutoriel] : tutoriel et exercices sed et awk (dépôt tiers, sans licence : à consulter chez lui)
      - #link("https://explainshell.com/")[explainshell.com] : décortiquer une ligne de commande
    ],
    bloc(taille: px(25))[Références][
      - `man bash`, `man sed`, `man awk` ; #link("https://www.gnu.org/software/bash/manual/")[Bash Reference Manual]
      - #link("https://linuxcommand.org/lc3_learning_the_shell.php")[linuxcommand.org] : apprendre le shell
      - #link("https://mywiki.wooledge.org/BashPitfalls")[BashPitfalls] : les pièges commentés
    ],
  ),
  rang(bloc(role: "precaution", taille: px(25))[Hors du cadre de ce cours][
    - sed : espace de réserve (_hold space_), traitement sur plusieurs lignes, commandes externes
    - awk : fonctions définies par l’utilisateur, plusieurs fichiers, scripts autonomes (`#!/usr/bin/awk -f`), `printf`
  ]),
  note: [Ressources du cours d’origine (« Ressources supplémentaires ») et capacités qu’il citait comme non abordées (« Conclusion » de sed et d’awk). Le module du site renvoyait à un fork du tutoriel softsam ; ce cours renvoie au dépôt amont, sans en reprendre le contenu.],
)

// ======================================================================
= Pour rappel · liste non exhaustive

== Bash : l’essentiel

#anime(
  rang(bloc(role: "retenir", taille: px(25))[Les bases, les guillemets][
    - Trois flux : stdin (0), stdout (1), stderr (2) ; `>` écrase, `>>` ajoute, `> f 2>&1` dans cet ordre
    - `|` branche une sortie sur une entrée ; `&&` et `||` suivent le code de retour (`$?`)
    - Avant d’exécuter, Bash développe : accolades, puis `~` `$` `$(…)` `$((…))`, puis découpage, puis chemins
    - `"${variable}"` : un seul mot, ni découpage ni chemins ; `'…'` : rien n’est développé
  ]),
  rang(bloc(role: "retenir", taille: px(25))[Les scripts][
    - Shebang, `chmod u+x`, `exit N` ; arguments `"$@"` plutôt que `read` pour l’automatisable
    - `set -euo pipefail`, `bash -x`, ShellCheck, Bats ; `main "$@"`, `source` ≠ `./`
    - `local` : portée dynamique ; sous-shell = copie ; nouveau processus = environnement seul
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

== sed et awk : l’essentiel

#anime(
  rang(
    bloc(role: "retenir", taille: px(25))[sed][
      - Une ligne à la fois dans l’espace de motif ; affichée en fin de cycle, sauf `-n`
      - `s/motif/rempl/g`, `d`, `i`, `a` ; adresses : numéro, plage, `/motif/`
      - `-E` : expressions étendues ; `\1` : groupe capturé
      - `-i.bak` après avoir testé sans `-i`
    ],
    bloc(role: "retenir", taille: px(25))[awk][
      - Enregistrements, champs `$1…$NF`, `-F` ; `motif { action }`
      - `BEGIN`, `END` ; tableaux associatifs, à trier
      - `$2 < 1970` : nombre ; `$2 < "1970"` : chaîne
    ],
  ),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

#cloture(illustration: "tube")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
