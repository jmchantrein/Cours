// Module `clavier` du cours « Fondements de l’administration système GNU/Linux » : « Le clavier du shell »
// — Typst + Touying, un diaporama par module.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts shell/cm/clavier.typ build/shell/clavier.pdf
//   (une variante : --input variante=dyslexie ; le site publie shell/cm/clavier-<variante>.pdf)
// Contenu : les notions du module `clavier` de shell/progression.yaml ; il tient pour acquis le module `intro`.
// Chaque diapo est une transformation de la ligne : la ligne avant, la touche, la ligne après (sorties réelles).
// Numéros de module : lus dans l’index (partage/carte.typ : numero, module-ref), jamais écrits ici.
// Relevé : shell/cm/rejouer-clavier.sh rejoue chaque geste, touche par touche, dans un pseudo-terminal (Alpine 3.22.8,
// Bash 5.2.37, bash-completion, ~/atelier de premiers-pas) ; les mêmes gestes ont été joués dans la VM du terminal des
// pages web (v86, port série). La page de cours du module reprend ces gestes dans le même ordre.

#import "../../commun/theme-cours.typ": *
#import "partage/carte.typ": carte-progression, module, numero, module-ref, titre-de, surtitre-module, pied-module

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: pied-module("clavier"),
)

#let versions = [Écrans réels, relevés touche par touche par shell/cm/rejouer-clavier.sh dans un pseudo-terminal (Alpine 3.22.8, bash 5.2.37, bash-completion, compte ada, \~/atelier de premiers-pas), et rejoués dans la VM du terminal des pages.]
#let des(k, d, x) = if k >= d { x } else { hide(x) }
// La variante dyslexie espace lettres, mots et lignes : un corps un peu plus petit garde chaque diapo sur une page.
#let z(n) = px(if dys { n * 0.88 } else { n })
// Une rangée « avant → touche → après » à la taille de ce diaporama.
#let rangee(t: 34, tl: 27, ..args) = rangee-touche(..args, taille: z(t), taille-legende: z(tl))
// L’en-tête d’un clic des diapos à schéma : son numéro, ses touches, ce qu’elles font.
#let geste(n, touches, texte) = text(size: z(32))[#pastille(n, t: z(30)) #touches.map(x => touche(x)).join(h(px(6))) #h(px(10)) #texte]

#couverture(illustration: "tube", surtitre: surtitre-module("clavier"))[#titre-de("clavier")][#module.at("clavier").sous-titre][Jean-Mathieu Chantrein][27 novembre 2026]
#speaker-note[Vingt minutes. À partir du module suivant, on tape des chemins et des lignes longues : ce module fait gagner chaque frappe qui suit. Les gestes sont ceux de la page de cours du module, que chacun refait dans le terminal de la page, dans le même ordre.]

// ======================================================================
= Ouverture

== Où en est-on dans le cours

#slide[
  #carte-progression(ici: "clavier")
  #speaker-note[La carte est calculée à partir de l’index (shell/progression.yaml). On est au module #numero("clavier") ; le module #numero("intro") est acquis.]
]

== Ce qu’on tient pour acquis

#let _q = module.at("clavier").ouverture.first()
#anime(
  rang(bloc(role: "question", revele: "bloc", taille: z(34))[Question à la salle][#eval(_q.question, mode: "markup")]),
  rang(bloc(role: "reponse", revele: "bloc", taille: z(32))[Le shell][Le terminal transmet chaque touche ; Bash tient la ligne, la modifie à chaque touche, et ne la lance qu’à Entrée. Ses raccourcis travaillent sur cette ligne : ce module.]),
  note(role: "retenir", taille: z(28))[Une hésitation ? C’est le #module-ref(_q.renvoi), diapo « De la frappe au résultat ».],
  note: [La question vient de l’index (champ ouverture du module). Laisser répondre la salle avant de dévoiler. La bibliothèque qui tient la ligne s’appelle Readline : on la nomme à la dernière diapo.],
)

// ======================================================================
= Compléter et retrouver

== Compléter : Tab

#anime(
  scene(4, k => stack(spacing: px(28),
    grid(columns: (px(540), px(180), px(540)), column-gutter: px(24),
      text(size: z(26), fill: c.ardoise)[avant], [], text(size: z(26), fill: c.ardoise)[après]),
    des(k, 1, rangee(1, ("$ whoa",), ([Tab],), ("$ whoami ",),
      [un seul nom de commande commence par `whoa` : #touche[Tab] l’achève ; Entrée : `ada`])),
    des(k, 2, rangee(2, ("$ who",), ([Tab], [Tab]), ("who     whoami  whois", "$ who"),
      [trois noms commencent par `who` : le premier #touche[Tab] ne choisit pas, le second les montre])),
    des(k, 3, rangee(3, ("$ ls", "atelier", "$ ls at"), ([Tab],), ("$ ls", "atelier", "$ ls atelier/"),
      [un nom de fichier : `ls` d’abord, pour voir ; le `/` final dit que c’est un répertoire])),
    des(k, 4, rangee(4, ("$ date --ut",), ([Tab],), ("$ date --utc ",),
      [une option longue : `--utc`, la forme longue de `-u`])),
  )),
  note: [#versions Un clic par geste. Avant le geste 3, effacer « who » (Retour arrière) ; après le geste 3, Entrée liste atelier/ (journaux notes pionnieres.csv projets vieux) ; après le geste 4, Entrée affiche la date en UTC. La complétion des commandes et des fichiers est celle de Bash ; celle des options vient du paquet bash-completion, installé dans la VM (et dans la plupart des distributions).],
)

== Retrouver : flèches, Ctrl+R, history

#anime(
  scene(4, k => stack(spacing: px(22),
    grid(columns: (px(540), px(180), px(540)), column-gutter: px(24),
      text(size: z(26), fill: c.ardoise)[avant], [], text(size: z(26), fill: c.ardoise)[après]),
    des(k, 1, rangee(t: 28, tl: 25, 1, ("$ ",), ([↑],), ("$ date --utc",),
      [la ligne précédente revient, prête à relancer ou à corriger])),
    des(k, 2, rangee(t: 28, tl: 25, 2, ("$ date --utc",), ([↑],), ("$ ls atelier/",),
      [celle d’avant ; #touche[↓] redescend, jusqu’à la ligne vide])),
    des(k, 3, rangee(t: 28, tl: 25, 3, ("$ ",), ([Ctrl+R], [w], [h]), (lignes: ("(reverse-i-search)`wh': whoami",), curseur: (0, 24)),
      [la dernière ligne qui contient `wh` ; Entrée la relance])),
    des(k, 4, rangee(t: 28, tl: 25, 4, ("$ history",), ([Entrée],), (lignes: ("    1  whoami", "    2  ls", "    3  ls atelier/", "    4  date --utc", "    5  whoami", "    6  history"), curseur: none, taille: z(24)),
      [les lignes tapées, numérotées, de la plus ancienne à la plus récente])),
  )),
  note: [#versions Un clic par geste, sur les lignes tapées à la diapo précédente. Avant Ctrl+R, redescendre à la ligne vide (↓ deux fois). Ctrl+R encore : l’occurrence d’avant ; Ctrl+C abandonne la recherche. L’historique est gardé à la fermeture du shell (\~/.bash_history), et !! ou !n le rappellent aussi : ce sont des expansions, au #module-ref("expansions").],
)

// ======================================================================
= Corriger une ligne

== Se déplacer dans la ligne

#let _kj = "$ echo Katherine Johnson calcule la trajectoire"
// Les places du curseur, relevées : au bout (47), au début (2), sur « trajectoire » (36), sur « la » (33), après « la » (35).
#let _deplacements = (
  (([Ctrl+A],), [au début de la ligne], 47, 2),
  (([Ctrl+E],), [au bout (_end_)], 2, 47),
  (([Ctrl+←],), [un mot en arrière : au début de `trajectoire`], 47, 36),
  (([Ctrl+←],), [encore un : au début de `la`], 36, 33),
  (([Ctrl+→],), [un mot en avant : après `la`, à la fin du mot], 33, 35),
)
#anime(
  scene(5, k => {
    let (touches, texte, avant, apres) = _deplacements.at(calc.min(k, 5) - 1)
    let fini = k > 5
    stack(spacing: px(36),
      if fini { text(size: z(32))[Le curseur saute par lignes et par mots ; #touche[←] et #touche[→] avancent d’un caractère.] }
        else { geste(k, touches, texte) },
      ligne-curseur(_kj, curseur: apres, ancien: if fini { none } else { avant }, taille: z(54)),
      grid(columns: (auto, 1fr), column-gutter: px(20), align: horizon,
        text(size: z(26), fill: c.ardoise)[à l’écran],
        ecran-ligne(("ada@cours:~" + _kj,), curseur: (0, apres + 11), taille: z(32), largeur: px(1180))),
      note(role: "pratique", taille: z(26))[Katherine Johnson (1918-2020), mathématicienne de la NASA, calcule les trajectoires des premiers vols habités américains : Alan Shepard en 1961, John Glenn en 1962.],
    )
  }),
  source-de: link("https://www.nasa.gov/people/katherine-johnson-biography/")[NASA, Katherine Johnson Biography],
  note: [#versions Un clic par touche, sur la ligne tapée sans Entrée. Le trait est le curseur ; à l’écran, c’est le pavé du caractère qui le suit. Alt+B et Alt+F font comme Ctrl+← et Ctrl+→ dans un terminal ; dans la page, le navigateur peut prendre Alt+F (son menu Fichier) : Ctrl+← et Ctrl+→ y marchent.],
)

== Effacer et recoller

// Chaque coupe : touches, ce qu’elle fait, la ligne dessinée (le morceau coupé reste, barré), curseur, morceau.
#let _coupes = (
  (([Ctrl+W],), [coupe le mot avant le curseur], _kj, 36, (36, 47), none, "trajectoire"),
  (([Ctrl+Y],), [recolle le dernier morceau coupé, au curseur], _kj, 47, none, (36, 47), "trajectoire"),
  (([Ctrl+←], [Ctrl+←], [Ctrl+K]), [coupe du curseur au bout], _kj, 33, (33, 47), none, "la trajectoire"),
  (([Ctrl+Y],), [recolle], _kj, 47, none, (33, 47), "la trajectoire"),
  (([Ctrl+←], [Ctrl+←], [Ctrl+U]), [coupe du début au curseur], _kj, 33, (2, 33), none, "echo Katherine Johnson calcule "),
)
// La ligne à l’écran après chaque coupe (relevée) et la colonne du curseur, invite comprise.
#let _ecrans = (
  ("ada@cours:~$ echo Katherine Johnson calcule la ", 47),
  ("ada@cours:~$ echo Katherine Johnson calcule la trajectoire", 58),
  ("ada@cours:~$ echo Katherine Johnson calcule ", 44),
  ("ada@cours:~$ echo Katherine Johnson calcule la trajectoire", 58),
  ("ada@cours:~$ la trajectoire", 13),
)
#anime(
  scene(5, k => {
    let i = calc.min(k, 5) - 1
    let (touches, texte, ligne, curseur, retire, ajoute, morceau) = _coupes.at(i)
    let (ecran, col) = _ecrans.at(i)
    stack(spacing: px(32),
      geste(i + 1, touches, texte),
      ligne-curseur(ligne, curseur: curseur, retire: retire, ajoute: ajoute, taille: z(54)),
      grid(columns: (auto, 1fr), column-gutter: px(20), row-gutter: px(16), align: horizon,
        text(size: z(26), fill: c.ardoise)[à l’écran],
        ecran-ligne((ecran,), curseur: (0, col), taille: z(32), largeur: px(1180)),
        text(size: z(26), fill: c.ardoise)[mis de côté],
        box(fill: c.espace, stroke: px(1.5) + c.filet, radius: px(8), inset: (x: px(14), y: px(8)),
          text(font: mono, size: z(28), tracking: 0pt, morceau.replace(" ", "\u{a0}")))),
      note(role: "precaution", taille: z(25))[Dans le terminal de la page, #touche[Ctrl+W] ferme l’onglet du navigateur : #touche[Alt+⌫] (Alt et Retour arrière) coupe aussi le mot avant le curseur.],
    )
  }),
  note: [#versions Un clic par geste, sur la même ligne, curseur au bout (Ctrl+E). Ce qui est coupé n’est pas perdu : Ctrl+Y le recolle au curseur, autant de fois qu’on veut. Le morceau coupé est dessiné barré, à sa place : à l’écran, il a disparu. Alt+Retour arrière coupe le mot comme Ctrl+W tant que la ligne n’a que des lettres et des espaces ; Ctrl+W coupe jusqu’à l’espace précédente, Alt+Retour arrière s’arrête aussi aux signes (/, -, .).],
)

== L’écran et la session

#anime(
  scene(3, k => stack(spacing: px(24),
    grid(columns: (px(540), px(180), px(540)), column-gutter: px(24),
      text(size: z(26), fill: c.ardoise)[avant], [], text(size: z(26), fill: c.ardoise)[après]),
    des(k, 1, rangee(t: 30, 1, (lignes: ("    5  whoami", "    6  history", "$ la trajectoire"), curseur: (2, 2)), ([Ctrl+L],),
      (lignes: ("$ la trajectoire", "", ""), curseur: (0, 2)), [l’écran se vide ; la ligne en cours reste, en haut])),
    des(k, 2, rangee(t: 30, 2, ("$ la trajectoire",), ([Ctrl+C],), ("$ la trajectoire^C", "$ "),
      [abandonne la ligne (ici après #touche[Ctrl+E]), ou interrompt une commande qui tourne])),
    des(k, 3, rangee(t: 30, 3, ("$ cat", "Ada", "Ada"), ([Ctrl+D],), ("$ cat", "Ada", "Ada", "$ "),
      [`cat` recopie ce qu’on tape ; #touche[Ctrl+D] : fin de saisie, `cat` s’arrête])),
    des(k, 3, note(role: "danger", taille: z(25))[#touche[Ctrl+D] sur une ligne vide ferme le shell, et le terminal avec lui. Dans la page, une nouvelle session s’ouvre aussitôt.]),
  )),
  note: [#versions Un clic par touche. Ce qu’est une commande qui tourne, et ce que Ctrl+C lui envoie (un signal) : #module-ref("processus"). Ctrl+D ne tue rien : il dit « fin de ce qu’on tape » au programme qui lit le clavier ; à l’invite, c’est le shell qui lit, et il se termine.],
)

// ======================================================================
= À vous

== À vous : où est le curseur ? que reste-t-il ? <exercice-clavier>

#let _hl = "$ echo Hedy Lamarr brevette un signal radio secret"
#anime(
  ligne-curseur(_hl, curseur: 50, taille: z(50)),
  rang(bloc(role: "question", revele: "bloc", taille: z(34))[Le curseur au bout : prédisez, touche après touche][
    + #touche[Ctrl+W] : que reste-t-il de la ligne ?
    + #touche[Ctrl+A] : où est le curseur ?
    + #touche[Ctrl+→] : où est-il ?
    + #touche[Ctrl+K] : que reste-t-il ?
    + #touche[Ctrl+Y], puis Entrée : qu’affiche `echo` ?
  ]),
  note: [À faire en direct : chacun écrit ses cinq réponses, puis tape la ligne et les touches dans le terminal de la page. Le piège : la question 5 (ce que Ctrl+Y recolle).],
)

== Où est le curseur : corrigé

// États relevés : ligne, curseur, morceau coupé ou recollé.
#let _hl2 = "$ echo Hedy Lamarr brevette un signal radio "
#let _corrige = (
  ([Ctrl+W], [`secret` est coupé], _hl, 44, (44, 50), none, none),
  ([Ctrl+A], [au début, sur le `e` de `echo`], _hl2, 2, none, none, 44),
  ([Ctrl+→], [après `echo`], _hl2, 6, none, none, 2),
  ([Ctrl+K], [il reste `echo`], _hl2, 6, (6, 44), none, none),
  ([Ctrl+Y], [le dernier morceau coupé revient : pas `secret`, coupé avant], _hl2, 44, none, (6, 44), none),
)
#anime(
  scene(6, k => stack(spacing: px(24),
    if k <= 5 {
      let (t, texte, ligne, cur, retire, ajoute, ancien) = _corrige.at(k - 1)
      stack(spacing: px(24), text(size: z(32))[#pastille(k, t: z(30)) #touche(t) #h(px(10)) #texte],
        ligne-curseur(ligne, curseur: cur, ancien: ancien, retire: retire, ajoute: ajoute, taille: z(50)))
    } else {
      stack(spacing: px(24), text(size: z(32))[#pastille(5, t: z(30)) Entrée : `echo` affiche ce qui reste],
        terminal-annote(etape: 1, taille: z(34), taille-legende: z(28),
          ("$ echo Hedy Lamarr brevette un signal radio", "Hedy Lamarr brevette un signal radio"),
          annote((ligne: 1, texte: "radio"), cote: "droite", clic: 1, legende: [`secret` est perdu : Ctrl+Y recolle la dernière coupe])))
    },
    note(role: "pratique", taille: z(26))[Hedy Lamarr (1914-2000), actrice, brevette en 1942 avec George Antheil un système de communication secrète par saut de fréquence, un principe qu’emploie aujourd’hui le Bluetooth.],
  )),
  source-de: link("https://patents.google.com/patent/US2292387A")[Brevet US 2 292 387, Secret Communication System (1942)],
  note: [#versions Une réponse par clic, avec l’état réel de la ligne. Ctrl+Y recolle le morceau de la dernière coupe (Ctrl+K), pas celui de Ctrl+W : chaque coupe remplace la précédente sous Ctrl+Y.],
)

== Pour rappel

#slide[
  #grid(columns: (1fr, 1fr), column-gutter: px(32),
    tableau((auto, 1fr), taille: z(28), inset: (x: px(12), y: px(10)),
      ([Touche], [Effet]),
      [#touche[Tab]], [complète une commande, un fichier, une option],
      [#touche[Tab] #touche[Tab]], [montre les possibilités],
      [#touche[↑] #touche[↓]], [lignes précédentes, suivantes],
      [#touche[Ctrl+R]], [cherche dans l’historique],
      [`history`], [l’historique, numéroté],
      [#touche[Ctrl+L]], [vide l’écran, garde la ligne],
      [#touche[Ctrl+C]], [abandonne la ligne, interrompt],
    ),
    tableau((auto, 1fr), taille: z(28), inset: (x: px(12), y: px(10)),
      ([Touche], [Effet]),
      [#touche[Ctrl+A] #touche[Ctrl+E]], [début, bout de la ligne],
      [#touche[Ctrl+←] #touche[Ctrl+→]], [un mot en arrière, en avant],
      [#touche[Ctrl+W]], [coupe le mot avant (page : #touche[Alt+⌫])],
      [#touche[Ctrl+U] #touche[Ctrl+K]], [coupe jusqu’au début, jusqu’au bout],
      [#touche[Ctrl+Y]], [recolle la dernière coupe],
      [#touche[Ctrl+D]], [fin de saisie ; ligne vide : ferme le shell],
    ),
  )
  #v(px(20))
  #note(role: "notion", taille: z(25))[Ces raccourcis sont ceux de la bibliothèque GNU Readline, qui tient la ligne de Bash ; d’autres programmes l’emploient, avec les mêmes touches (celles de l’éditeur Emacs).]
  #v(px(12))
  #note(role: "retenir", taille: z(26))[Suite : #module-ref("arbo") : on y tape des chemins, avec #touche[Tab].]
  #source[#link("https://www.gnu.org/software/bash/manual/html_node/Command-Line-Editing.html")[Bash Reference Manual, Command Line Editing]]
  #speaker-note[Une énumération : elle s’affiche d’un coup. « Command line editing is provided by the Readline library, which is used by several different programs, including Bash » ; par défaut, ses commandes d’édition sont celles d’Emacs (man bash, section READLINE) ; set -o vi passe à celles de vi.]
]

#cloture(illustration: "tube")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
