// Module `arbo` du cours « Fondements de l’administration système GNU/Linux » : « Se repérer dans l’arborescence » — Typst + Touying, un diaporama par module.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts shell/cm/arbo.typ build/shell/arbo.pdf
//   (une variante : --input variante=dyslexie ; le site publie shell/cm/arbo-<variante>.pdf)
// Contenu : les notions du module `arbo` de shell/progression.yaml, et rien de ce qui appartient aux suivants.
// Il tient pour acquis les modules `intro` (terminal, shell, invite, commande, option, argument) et `clavier`.
// Numéros de module : lus dans l’index (partage/carte.typ : numero, module-ref), jamais écrits ici.
// Fil rouge : l’arborescence que crée shell/tp/premiers-pas/preparer.sh sous ~/atelier (compte ada), celle de la VM du
// terminal et de la page de cours du même module ; arbre dans partage/atelier.typ.
// Sorties : rejouées par shell/cm/rejouer-arbo.sh dans un conteneur debian:13-slim (bash 5.2.37, coreutils 9.7),
// sous le compte ordinaire ada, ls comme dans un terminal de 80 colonnes.

#import "../../commun/theme-cours.typ": *
#import "partage/carte.typ": carte-progression, module, numero, module-ref, surtitre-module, pied-module
#import "partage/atelier.typ": racine-tp

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: pied-module("arbo"),
)

#let versions = [Sortie réelle : conteneur debian:13-slim, bash 5.2.37, GNU coreutils 9.7, compte ada, \~/atelier préparé par preparer.sh ; rejouée par shell/cm/rejouer-arbo.sh.]
// Chemins du fil rouge.
#let maison = "/home/ada"
#let at = "/home/ada/atelier"
// La colonne de contexte sur l’arborescence du TP ; ~ étiqueté dès qu’il a été défini.
#let ici(courant, tilde: true, ..args) = contexte(racine-tp, courant: courant,
  etiquettes: if tilde { ((maison): raw("~")) } else { (:) }, ..args)
#let des(k, d, x) = if k >= d { x } else { hide(x) }
// Une commande et sa sortie dans un cadre à elle, qui paraît au clic d : ses légendes au-dessus ou au-dessous ne
// croisent aucune autre ligne.
#let cmd(k, d, lignes, taille: px(28), ..ann) = des(k, d, terminal-annote(etape: k, taille: taille, lignes, ..ann))

#couverture(illustration: "tube", surtitre: surtitre-module("arbo"))[Se repérer dans l’arborescence][Où suis-je, que contient ce répertoire, comment aller ailleurs][Jean-Mathieu Chantrein][27 novembre 2026]
#speaker-note[Trente minutes. Module #numero("arbo") de l’index shell/progression.yaml ; il tient pour acquis les modules #numero("intro") (terminal, shell, invite, commande, option, argument) et #numero("clavier") (le clavier du shell). Les commandes sont celles de la page de cours du module et du TP « Premiers pas dans le shell » (étapes 2 et 4), sur l’arborescence de preparer.sh.]

// ======================================================================
= Ouverture

== Où en est-on dans le cours

#slide[
  #carte-progression(ici: "arbo")
  #speaker-note[La carte est calculée à partir de l’index (shell/progression.yaml) : chaque module tient pour acquis ceux d’où partent ses flèches, et ceux-là seulement. On est au module #numero("arbo") ; les modules #numero("intro") et #numero("clavier") sont acquis.]
]

== Ce qu’on tient pour acquis

#let _q = module.at("arbo").ouverture.first()
#anime(
  rang(bloc(role: "question", revele: "bloc", taille: px(30))[Question à la salle][#eval(_q.question, mode: "markup")]),
  commande-annotee(taille: px(48), ("$ ls -a notes",),
    annote("ls", cote: "haut", clic: 2, reste: true, legende: [la commande]),
    annote("-a", clic: 3, reste: true, legende: [une option]),
    annote("notes", cote: "haut", clic: 4, reste: true, legende: [un argument]),
  ),
  note(role: "retenir", taille: px(26))[Une hésitation ? C’est le #module-ref(_q.renvoi) : à revoir avant la suite.],
  note: [La question vient de l’index (champ ouverture du module). Laisser répondre la salle avant de dévoiler, un mot par clic. Ce que fait -a, et ce qu’est notes, c’est l’objet de ce module.],
)

// ======================================================================
= L’arborescence

== Des répertoires dans des répertoires

#let _racine = "bin   dev  home  lib64\tmnt  proc  run\t srv  tmp  var"
#let _racine2 = "boot  etc  lib\t media\topt  root  sbin  sys  usr"
#anime(
  contexte: k => ici(none, tilde: false, voir: if k == 2 { ("/home",) } else if k == 3 { ("/tmp",) } else { () },
    parcours: if k >= 2 { ("/home", "/home/ada") } else { () }),
  commande-annotee(taille: px(30), ("$ ls /", _racine, _racine2),
    annote((ligne: 0, texte: "/"), cote: "haut", clic: 1, legende: [`/` : la racine, d’où part toute l’arborescence]),
    annote("home", clic: 2, legende: [`home` : un répertoire par compte, dont `ada`]),
    annote("tmp", clic: 3, legende: [`tmp` : les fichiers temporaires]),
  ),
  note(role: "retenir", taille: px(26))[Un *répertoire* contient des fichiers et d’autres répertoires ; tous partent de la racine `/`. La colonne de gauche dessine cet arbre.],
  source-de: link("https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html")[Filesystem Hierarchy Standard 3.0],
  note: [#versions La racine est celle du conteneur du relevé : sur un poste Debian, on y trouve en plus lost+found, et parfois d’autres répertoires. Les noms en colonnes sont ceux de ls dans un terminal ; la colonne de gauche n’en montre que deux, la ligne grise compte les autres. Le rôle de chaque répertoire de la racine est fixé par le FHS (Filesystem Hierarchy Standard) : hors du cadre de ce module, sauf home et tmp.],
)

== Le répertoire courant : pwd

#anime(
  contexte: k => ici(maison, tilde: k >= 3, ici: if k >= 2 { [vous êtes ici] }),
  commande-annotee(taille: px(36), ("$ pwd", "/home/ada"),
    annote("/home/ada", cote: "droite", clic: 2, legende: [le répertoire courant : là où agissent les commandes]),
    annote((ligne: 1, texte: "/"), clic: 3, reste: true, legende: [ce chemin part de la racine]),
  ),
  note(role: "notion", taille: px(26))[À l’ouverture d’un terminal, le shell part du *répertoire personnel* du compte : `/home/ada` pour ada. On l’abrège `~` : dans la colonne, l’étiquette `~`.],
  note(role: "pratique", taille: px(26))[La colonne de gauche dit, sur chaque diapo du cours : le compte, l’arbre autour du répertoire courant (sur fond bleu), ce que la commande emploie (encadré).],
  note: [#versions pwd : print working directory. Le répertoire courant appartient au shell : chaque terminal a le sien. La colonne de gauche est le repère de tout le cours : à partir du module suivant, elle reste là sans qu’on la commente.],
)

== Ce que contient un répertoire : ls, ls -a

#anime(
  contexte: k => ici(maison, voir: if k >= 2 { (at,) } else { () }, ouverts: if k >= 2 { (at,) } else { () },
    caches: if k >= 3 { (at,) } else { () }),
  scene(3, k => stack(spacing: px(10),
    cmd(k, 1, ("$ ls", "atelier"), annote((ligne: 1, texte: "atelier"), clic: 1, legende: [`ls` seul : le contenu du répertoire courant])),
    cmd(k, 2, ("$ ls atelier", "journaux  notes  pionnieres.csv  projets  vieux"),
      annote((ligne: 0, texte: "atelier"), cote: "haut", clic: 2, legende: [un répertoire en argument : son contenu])),
    cmd(k, 3, ("$ ls -a atelier", ".  ..  .reglages  journaux  notes  pionnieres.csv  projets  vieux"), taille: px(26),
      annote(".reglages", clic: 3, legende: [`-a` (_all_) : aussi les noms cachés, qui commencent par un point])),
  )),
  note: [#versions ls (list) ne change pas de répertoire : il montre. Un fichier caché n’a rien de secret : son nom commence par un point, et ls le tait par défaut (des réglages, le plus souvent). Les deux premiers noms de ls -a, . et .., sont l’objet d’une diapositive plus loin. ls -l (le détail de chaque fichier) appartient au module « Droits ».],
)

== Changer de répertoire courant : cd

#anime(
  contexte: k => ici(if k <= 1 { maison } else if k == 2 { at } else { at + "/notes" }, ici: [ici]),
  commande-annotee(taille: px(28),
    ("$ pwd", "/home/ada", ("$ cd atelier", 2), ("$ pwd", 2), ("/home/ada/atelier", 2), ("$ cd notes", 3), ("$ pwd", 3),
      ("/home/ada/atelier/notes", 3), ("$ ls", 4), ("a-faire.txt  idees.txt\tlisezmoi.txt", 4)),
    annote((ligne: 1, texte: "/home/ada"), cote: "droite", clic: 1, legende: [départ : le répertoire personnel, `~`]),
    annote((ligne: 2, texte: "atelier"), cote: "droite", clic: 2, legende: [`cd` n’affiche rien : le répertoire courant change]),
    annote("/home/ada/atelier/notes", cote: "droite", clic: 3, legende: [un cran plus bas, dans `notes`]),
    annote((ligne: 9, texte: "lisezmoi.txt"), cote: "droite", clic: 4, legende: [`ls` : le contenu de `notes`]),
  ),
  note: [#versions cd : change directory. Un clic par commande : le repère bleu de la colonne suit le répertoire courant, à partir de \~, montré par pwd. cd sans erreur n’affiche rien ; pwd le confirme.],
)

== Un chemin relatif part du répertoire courant

#anime(
  contexte: k => ici(if k >= 5 { at + "/projets/site" } else { at + "/notes" }, ici: [ici],
    parcours: if k >= 5 { () } else { (at, at + "/projets", at + "/projets/site").slice(0, calc.max(0, k - 1)) }),
  scene(5, k => stack(spacing: px(10),
    cmd(k, 1, ("$ cd atelier/notes",), taille: px(34)),
    cmd(k, 2, ("$ cd ../projets/site",), taille: px(40),
      annote("..", cote: "haut", clic: 2, reste: true, legende: [#pastille(1) `..` : on remonte d’un cran, dans `atelier`]),
      annote("projets", clic: 3, reste: true, legende: [#pastille(2) on descend dans `projets`]),
      annote("site", cote: "haut", clic: 4, reste: true, legende: [#pastille(3) puis dans `site`])),
    cmd(k, 5, ("$ pwd", "/home/ada/atelier/projets/site"), taille: px(34),
      annote((ligne: 1, texte: "/home/ada/atelier/projets/site"), cote: "droite", clic: 5, legende: [arrivé : `pwd` le confirme])),
  )),
  note(role: "retenir", taille: px(25))[Un chemin *relatif* ne commence pas par `/` : il se lit depuis le répertoire courant, une branche par nom, séparés par `/`.],
  note: [#versions Un composant par clic, numéroté comme sur la colonne. Le premier cd (atelier/notes) est déjà un chemin relatif, lu depuis \~. .. est expliqué deux diapositives plus loin ; il suffit ici de savoir qu’il remonte d’un cran.],
)

== Un chemin absolu part de la racine

#anime(
  contexte: k => ici(if k >= 4 { at + "/projets/site" } else { at + "/notes" }, ici: [ici],
    parcours: if k == 2 { ("/",) } else if k == 3 { ("/", "/home", maison, at, at + "/projets", at + "/projets/site") } else { () }),
  scene(4, k => stack(spacing: px(10),
    cmd(k, 1, ("$ cd /home/ada/atelier/notes",), taille: px(32)),
    cmd(k, 2, ("$ cd /home/ada/atelier/projets/site",), taille: px(32),
      annote((ligne: 0, cols: (5, 6)), cote: "haut", clic: 2, reste: true, legende: [#pastille(1) un `/` en tête : on part de la racine]),
      annote((ligne: 0, cols: (6, 35)), clic: 3, reste: true, legende: [#pastille(2) à #pastille(6) puis de branche en branche jusqu’à `site`])),
    cmd(k, 4, ("$ pwd", "/home/ada/atelier/projets/site"), taille: px(32),
      annote((ligne: 1, texte: "/home/ada/atelier/projets/site"), cote: "droite", clic: 4, legende: [le même répertoire, d’où qu’on parte])),
  )),
  note(role: "retenir", taille: px(25))[Un chemin *absolu* commence par `/` : il désigne le même endroit quel que soit le répertoire courant. `pwd` en affiche un.],
  note: [#versions Le point de départ est notes, comme à la diapositive précédente : même arrivée, autre chemin. Un chemin relatif est plus court ; un chemin absolu ne dépend pas de l’endroit où l’on est (dans un script, par exemple).],
)

== `.` et `..` : ici, et un cran plus haut

#anime(
  contexte: k => ici(at + "/projets/site", ici: [ici], caches: (at + "/projets/site",),
    parcours: if k == 2 { (at + "/projets",) } else if k == 3 { (at + "/projets", at, at + "/journaux") } else { () },
    ouverts: if k >= 2 { (at + "/projets",) } else { () }),
  scene(3, k => stack(spacing: px(10),
    cmd(k, 1, ("$ cd atelier/projets/site", "$ ls -a", ".  ..  index.html"),
      annote((ligne: 2, cols: (0, 4)), clic: 1, legende: [`.` : ce répertoire ; `..` : son parent ; dans tout répertoire])),
    cmd(k, 2, ("$ ls ..", "scripts  site"),
      annote((ligne: 0, texte: ".."), cote: "haut", clic: 2, legende: [#pastille(1) le parent de `site` : `projets`])),
    cmd(k, 3, ("$ ls ../../journaux", "serveur-2025-novembre.log  serveur-2026-novembre.log"),
      annote((ligne: 0, texte: "../../journaux"), cote: "haut", clic: 3, legende: [#pastille(1) `projets`, #pastille(2) `atelier`, #pastille(3) `journaux`])),
  )),
  note: [#versions . et .. existent dans tout répertoire (ls -a les montre) ; la racine est son propre parent. ls .. liste le parent sans changer de répertoire : la colonne garde le repère dans site. Le chemin ../../journaux se lit en remontant deux fois, puis en descendant.],
)

== `~`, `cd` seul, `cd -`

#anime(
  contexte: k => ici(if k <= 2 { at + "/notes" } else if k == 3 { "/tmp" } else if k == 4 { at + "/notes" } else { maison },
    ici: [ici]),
  commande-annotee(taille: px(30),
    ("$ echo ~", "/home/ada", ("$ cd ~/atelier/notes", 2), ("$ cd /tmp", 3), ("$ pwd", 3), ("/tmp", 3),
      ("$ cd -", 4), ("/home/ada/atelier/notes", 4), ("$ cd", 5), ("$ pwd", 5), ("/home/ada", 5)),
    annote((ligne: 1, texte: "/home/ada"), cote: "droite", clic: 1, legende: [Bash remplace `~` par le répertoire personnel]),
    annote("$ cd ~/atelier/notes", cote: "droite", clic: 2, legende: [`~/…` : un chemin absolu, abrégé]),
    annote((ligne: 5, texte: "/tmp"), cote: "droite", clic: 3, legende: [ailleurs dans l’arbre]),
    annote((ligne: 7, texte: "/home/ada/atelier/notes"), cote: "droite", clic: 4, legende: [`cd -` : retour au répertoire précédent, qu’il affiche]),
    annote((ligne: 10, texte: "/home/ada"), cote: "droite", clic: 5, legende: [`cd` seul : retour au répertoire personnel]),
  ),
  note: [#versions Une commande par clic, le repère suit. echo affiche ses arguments : c’est Bash qui a remplacé \~ avant de lancer echo (le module « Guillemets et expansions » détaille ces remplacements). cd - échange le répertoire courant et le précédent : deux cd - de suite font l’aller-retour.],
)

// ======================================================================
= À vous

== À vous : où arrive-t-on ? <exercice-arbo>

#anime(
  contexte: ici(at + "/notes", ici: [ici]),
  rang(bloc(role: "question", revele: "bloc", taille: px(28))[Prédisez, sans taper, chaque commande l’une après l’autre][
    + `cd ../projets/scripts` : dans quel répertoire est-on ?
    + Puis `cd ../..` : et maintenant ?
    + Puis `ls ./vieux` : qu’affiche-t-il ?
    + Puis `cd -` : où revient-on ?
    + Depuis `~/atelier`, que désigne `notes/../projets/./site` ?
  ]),
  note: [À faire en direct : chacun écrit ses cinq réponses, en suivant les branches sur l’arbre de gauche, avant le corrigé. La question 5 est celle de l’index (sait-faire du module).],
)

== Où arrive-t-on : corrigé

#let _cs = at + "/projets/scripts"
#anime(
  contexte: k => ici(if k <= 1 { at + "/notes" } else if k == 2 { _cs } else if k <= 4 { at } else if k == 5 { _cs } else { at },
    ici: [ici], ouverts: if k == 4 { (at + "/vieux",) } else { () },
    parcours: if k == 2 { (at, at + "/projets", _cs) } else if k == 3 { (at + "/projets", at) } else if k == 4 { (at, at + "/vieux") }
      else if k == 6 { (at + "/notes", at, at + "/projets", at + "/projets", at + "/projets/site") } else { () }),
  commande-annotee(taille: px(27),
    ("$ cd ~/atelier/notes", ("$ cd ../projets/scripts", 2), ("$ pwd", 2), ("/home/ada/atelier/projets/scripts", 2),
      ("$ cd ../..", 3), ("$ pwd", 3), ("/home/ada/atelier", 3), ("$ ls ./vieux", 4), ("brouillon-1.txt  brouillon-2.txt", 4),
      ("$ cd -", 5), ("/home/ada/atelier/projets/scripts", 5), ("$ cd ~/atelier", 6), ("$ ls notes/../projets/./site", 6), ("index.html", 6)),
    annote((ligne: 3, texte: "/home/ada/atelier/projets/scripts"), cote: "droite", clic: 2, legende: [#pastille(1) remonter, #pastille(2) #pastille(3) descendre]),
    annote((ligne: 6, texte: "/home/ada/atelier"), cote: "droite", clic: 3, legende: [deux crans plus haut]),
    annote("brouillon-2.txt", cote: "droite", clic: 4, legende: [`./vieux` : `vieux`, depuis ici]),
    annote((ligne: 10, texte: "/home/ada/atelier/projets/scripts"), cote: "droite", clic: 5, legende: [le répertoire d’avant `cd ../..`]),
    annote("index.html", cote: "droite", clic: 6, legende: [un détour : `projets/site`]),
  ),
  note: [#versions Un clic par réponse : la commande, sa sortie réelle, et le chemin suivi sur l’arbre (pastilles). Question 5 : on entre dans notes (1), on en ressort (2, atelier), on entre dans projets (3), on y reste (4, .), puis site (5).],
)

== À retenir

#slide[
  #rangee(
    h => tableau((auto, 1fr), taille: px(26), inset: (x: px(12), y: px(9)),
      ([Commande], [Effet]),
      [`pwd`], [affiche le répertoire courant],
      [`ls`, `ls rep`], [le contenu du répertoire courant, ou de `rep`],
      [`ls -a`], [aussi les noms cachés (et `.`, `..`)],
      [`cd chemin`], [change de répertoire courant],
      [`cd -`, `cd`], [répertoire précédent ; répertoire personnel]),
    h => tableau((auto, 1fr), taille: px(26), inset: (x: px(12), y: px(9)),
      ([Écriture], [Désigne]),
      [`/`], [la racine ; en tête de chemin : chemin absolu],
      [`~`], [le répertoire personnel (`/home/ada`)],
      [`.`, `..`], [ce répertoire ; son parent],
      [`a/b`], [chemin relatif : depuis le répertoire courant]),
  )
  #v(px(24))
  #note(role: "retenir", taille: px(26))[La colonne de gauche des diapos suivantes est cet arbre : le compte, le répertoire courant sur fond bleu, ce que la commande emploie encadré. Suite : #module-ref("fichiers").]
  #speaker-note[Une énumération : elle s’affiche d’un coup. Le TP « Premiers pas dans le shell » (étapes 2 et 4) et la page de cours du module reprennent ces commandes sur la même arborescence.]
]

#cloture(illustration: "tube")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
