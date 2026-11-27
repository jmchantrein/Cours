// Module 0 du cours « Fondements de l’administration système GNU/Linux » : « Le terminal, le shell, la commande »
// — Typst + Touying, un diaporama par module.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts shell/cm/intro.typ build/shell/intro.pdf
//   (une variante : --input variante=dyslexie ; le site publie shell/cm/intro-<variante>.pdf)
// Contenu : les notions du module `intro` de shell/progression.yaml, pour qui n’a jamais ouvert de terminal ; et la
// présentation du cours (pourquoi, carte, supports). Pas de colonne de contexte : l’arborescence vient au module 1.
// Sorties : rejouées par shell/cm/rejouer-intro.sh comme dans la VM du terminal des pages web (Alpine 3.22.8, Bash
// 5.2.37, GNU coreutils 9.7, mandoc ; machine « cours », compte ada) : la page de cours du module rejoue ces exemples.

#import "../../commun/theme-cours.typ": *
#import "partage/carte.typ": carte-progression, module, prog

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Administration système GNU/Linux · module 0],
)

#let versions = [Sortie réelle, rejouée par shell/cm/rejouer-intro.sh comme dans la VM du terminal : Alpine 3.22.8, bash 5.2.37, GNU coreutils 9.7, machine « cours », compte ada.]
#let invite = "ada@cours:~$ "
#let des(k, d, x) = if k >= d { x } else { hide(x) }
// Tailles de texte : la variante dyslexie espace lettres, mots et lignes ; elle réduit un peu le corps pour que chaque
// diapo tienne dans la même hauteur (la géométrie, elle, ne change pas).
#let z(n) = px(if dys { n * 0.88 } else { n })

#couverture(illustration: "tube", surtitre: "Fondements de l’administration système GNU/Linux · module 0")[Le terminal, le shell, la commande][Taper une commande, lire ce qu’elle répond, trouver de l’aide][Jean-Mathieu Chantrein][27 novembre 2026]
#speaker-note[Trente minutes. Module 0 de l’index (shell/progression.yaml) : il ne suppose rien, et présente le cours. Les exemples sont ceux de la page de cours du module, que chacun rejoue dans le terminal de la page.]

// ======================================================================
= Le cours

== Pourquoi la ligne de commande

#let _dossier(n) = box(width: px(146), stack(
  box(width: px(56), height: px(14), fill: c.bleu.transparentize(45%), radius: (top: px(4))),
  box(width: px(146), height: px(78), fill: c.appli, stroke: px(2) + c.bleu.transparentize(50%),
    radius: (right: px(6), bottom: px(6)),
    align(center + horizon, text(font: mono, size: z(24), tracking: 0pt, fill: c.encre, "seance-" + n))),
))
#let _etiquette-pourquoi(n, t) = text(size: z(30), weight: 700, fill: c.ardoise)[#pastille(n) #t]
#anime(
  scene(3, k => stack(spacing: px(22),
    text(size: z(32))[La tâche : un dossier par séance du semestre, de `seance-01` à `seance-12`.],
    grid(columns: (px(230), 1fr), column-gutter: px(20), row-gutter: px(24), align: horizon,
      _etiquette-pourquoi(1)[À la souris],
      grid(columns: (auto, 1fr), column-gutter: px(32), align: horizon,
        grid(columns: 6, gutter: px(10), ..range(1, 13).map(i => _dossier(if i < 10 { "0" + str(i) } else { str(i) }))),
        stack(spacing: px(14),
          text(size: z(28))[pour chacun : clic droit, « Nouveau dossier », taper le nom, Entrée],
          text(size: z(38), weight: 700)[12 × 4 = 48 gestes])),
      des(k, 2, _etiquette-pourquoi(2)[En une ligne]),
      des(k, 2, terminal-annote(etape: k, taille: z(30), taille-legende: z(28),
        (("$ mkdir -p semestre/seance-{01..12}", 2), ("$ ls semestre", 2),
          ("seance-01  seance-03  seance-05  seance-07  seance-09  seance-11", 2),
          ("seance-02  seance-04  seance-06  seance-08  seance-10  seance-12", 2)),
        annote("{01..12}", cote: "haut", clic: 2, reste: true, legende: [Bash écrit les douze noms ; `ls` le prouve]),
      )),
    ),
    des(k, 3, note(role: "retenir", taille: z(28))[#pastille(3) La ligne se relit, se corrige, se rejoue : sur dix machines, ou à chaque rentrée, c’est la même. Un serveur n’a ni écran ni souris : on l’administre ainsi, par des lignes de texte.]),
  )),
  note: [#versions Une tâche que chacun a déjà faite à la souris. On ne demande pas de comprendre la ligne : mkdir (make directory) crée des répertoires, -p crée aussi semestre, et {01..12} est une expansion de Bash (module « Guillemets et expansions »). Dans un terminal, ls range les noms en colonnes, comme ici (le relevé le demande par ls -C, sa sortie n’allant pas à un terminal). Le sujet du cours : administrer une machine GNU/Linux en ligne de commande, avec Bash, puis sed et awk. La connexion à distance (SSH) est l’objet d’un autre cours.],
)

== La carte du cours

#slide[
  #carte-progression(ici: "intro", etiquette: [Départ], h: 118, px-y: 130, taille: z(20))
  #v(px(6))
  #note(role: "retenir", taille: z(25))[À la fin : se repérer et agir sur les fichiers, gérer les droits, enchaîner des commandes par des tubes, écrire des scripts robustes, transformer du texte avec sed et awk. Chaque module tient pour acquis ceux d’où partent ses flèches.]
  #speaker-note[La carte est calculée à partir de l’index (shell/progression.yaml) : quinze modules, numérotés dans l’ordre des séances ; une flèche va d’un module à celui qui en a besoin. On part du module 0 ; le module 1 (l’arborescence) suit.]
]

== Quatre supports pour chaque module

#slide[
  #colonnes(
    bloc(taille: z(38))[Le diaporama][En salle : les notions, dessinées ; une question à prédire. \ _Quand : pendant le cours._],
    bloc(role: "pratique", taille: z(38))[La page de cours][Un terminal dans la page : on tape les exemples du diaporama, on voit ce qu’ils répondent. \ _Quand : juste après._],
    bloc(role: "question", taille: z(38))[Le TP][Une séance au clavier, sur un dossier de travail ; un corrigé pour chaque étape. \ _Quand : en séance._],
    bloc(role: "notion", taille: z(38))[L’artefact][Un petit logiciel qui fait manipuler un modèle : on prédit, puis on vérifie. \ _Quand : pour s’entraîner._],
  )
  #v(px(32))
  #note(role: "pratique", taille: z(32))[Pour ce module : le diaporama et la page de cours. Les exemples des diapos sont ceux de la page : vous les rejouerez tels quels.]
  #speaker-note[Une énumération : elle s’affiche d’un coup. Les supports existants de chaque module sont marqués sur la carte de travail (shell/carte-progression.typ) ; tous les modules n’ont pas de TP ni d’artefact.]
]

// ======================================================================
= Le terminal et le shell

== Une fenêtre de terminal

#let _fenetre(k) = block(width: px(860), radius: px(12), clip: true, stroke: px(2) + c.filet, stack(
  block(width: 100%, fill: c.filet, inset: (x: px(16), y: px(8)), {
    for _ in range(3) { box(circle(radius: px(7), fill: c.gris)); h(px(8)) }
    h(px(10)); text(size: z(24), fill: c.encre)[Terminal — ada\@cours: \~]
  }),
  block(width: 100%, fill: c.nuit, inset: (x: px(20), y: px(14)), {
    // du texte clair sur le fond sombre (pas de raw : son bleu de la charte y serait illisible)
    set text(font: mono, size: z(40), fill: c.texte-term, tracking: 0pt)
    let t(x) = x.replace(" ", "\u{a0}")
    t(invite + "whoami"); linebreak()
    t("ada"); linebreak()
    t(invite); box(width: px(24), height: px(42), fill: c.texte-term, baseline: 20%)
  }),
))
#anime(
  scene(6, k => stack(spacing: px(24),
    grid(columns: (px(860), 1fr), column-gutter: px(40), align: horizon,
      _fenetre(k),
      text(size: z(32))[La fenêtre : un *émulateur de terminal* (GNOME Terminal, Konsole, Terminal de macOS…). Dedans, un programme lit ce qu’on tape : le *shell*, ici *Bash*.]),
    des(k, 2, terminal-annote(etape: k, taille: z(66), taille-legende: z(32), (invite + "whoami",),
      annote("ada", cote: "haut", clic: 2, reste: true, legende: [le compte : qui tape]),
      annote("cours", clic: 3, reste: true, legende: [la machine]),
      annote("~", cote: "haut", clic: 4, reste: true, legende: [où l’on est (module 1)]),
      annote("$", clic: 5, reste: true, legende: [`$` : compte ordinaire ; `#` : root, l’administrateur]),
      annote("whoami", cote: "haut", clic: 6, reste: true, legende: [la commande tapée ; sa réponse, dessous : `ada`]),
    )),
  )),
  note: [#versions Un clic : la fenêtre, puis l’invite décodée en loupe. L’invite (prompt) est écrite par le shell ; son format dépend du réglage PS1 : ici celui de la VM des pages de cours, « \\u\@\\h:\\w\\\$ ». Le rectangle plein est le curseur. whoami (who am I) affiche le compte. root est le compte qui a tous les droits ; on l’évite pour travailler.],
)

== De la frappe au résultat

#anime(
  scene(5, k => schema-etats(echelle: 1.25, hauteur: 520, etape: k, numero: k => k, taille: z(24),
    noeuds: (
      term: (x: 0, y: 0, l: 640, h: 250, genre: "terminal", titre: "Le terminal", taille: z(28), contenu: (invite,),
        ports: (vers-shell: ("d", 0.3), depuis-prog: ("d", 0.78), clavier: ("b", 0.5))),
      bash: (x: 940, y: 0, l: 380, h: 140, titre: [bash, le shell], sous: [attend une ligne]),
      txt: (x: 0, y: 470, l: 1380, genre: "texte", taille: z(28), contenu: [Le terminal affiche l’invite du shell ; le shell attend une ligne.]),
    ),
    etats: (
      (noeuds: (term: (:), bash: (:))),
      (noeuds: (
        clavier: (x: 170, y: 330, l: 300, h: 100, titre: [Le clavier]),
        term: (contenu: (invite + "whoami",)),
        txt: (contenu: [On tape `whoami`, puis Entrée : le terminal transmet la ligne au shell.]),
      ), liens: (
        f: (de: "clavier.h", vers: "term.clavier", etiquette: [whoami, Entrée]),
        l: (de: "term.vers-shell", vers: "bash.g", etiquette: [la ligne]),
      )),
      (noeuds: (
        bash: (sous: [lit la ligne, lance whoami, attend]),
        prog: (x: 940, y: 330, l: 380, h: 120, titre: [whoami], sous: [un programme]),
        txt: (contenu: [Le shell coupe la ligne en mots, trouve le programme `whoami`, le lance, et attend qu’il se termine.]),
      ), liens: (f: none, lance: (de: "bash.b", vers: "prog.h", etiquette: [lance]))),
      (noeuds: (
        term: (contenu: (invite + "whoami", "ada")),
        txt: (contenu: [`whoami` écrit `ada` ; le terminal l’affiche.]),
      ), liens: (r: (de: "prog.g", vers: "term.depuis-prog", donnee: raw("ada"), pos-donnee: 0.5))),
      (noeuds: (
        prog: none, bash: (sous: [attend une ligne]),
        term: (contenu: (invite + "whoami", "ada", invite)),
        txt: (contenu: [`whoami` s’est terminé : le shell réaffiche l’invite, prêt pour la ligne suivante.]),
      ), liens: (lance: none, r: none)),
    ),
  )),
  note: [#versions Un clic par étape, numérotée sur le schéma et devant sa légende. Le terminal ne fait qu’afficher et transmettre les touches ; c’est le shell qui comprend la ligne. Le découpage de la ligne en mots est le sujet du module « Guillemets et expansions ». Ce qui circule entre le programme et le terminal (les flux) est le sujet du module « Flux, redirections et tubes ».],
)

// ======================================================================
= La commande

== Lire une ligne de commande <ligne-de-commande>

#anime(
  commande-annotee(taille: z(60), taille-legende: z(32),
    ("$ date -u +%H:%M", ("17:31", 6)),
    annote("$", cote: "haut", clic: 2, reste: true, legende: [l’invite, abrégée en `$` dans les diapos]),
    annote("date", cote: "haut", clic: 3, reste: true, legende: [la commande : `date`]),
    annote("-u", cote: "haut", clic: 4, reste: true, legende: [une option : `-u`, l’heure universelle (UTC)]),
    annote("+%H:%M", cote: "haut", clic: 5, reste: true, legende: [un argument : le format, heures:minutes]),
    annote("17:31", ligne: 1, clic: 6, reste: true, legende: [la réponse : l’heure UTC du relevé]),
  ),
  note(role: "retenir", taille: z(30))[Une ligne de commande : la commande, puis ses options (qui commencent par `-`), puis ses arguments (ce sur quoi elle porte), séparés par des espaces.],
  source-de: link("https://www.gnu.org/software/coreutils/manual/html_node/date-invocation.html")[GNU coreutils, date invocation],
  note: [#versions Un morceau par clic. L’heure dépend du moment où l’on tape la commande : chez vous, une autre. UTC : Temps universel coordonné, l’heure de référence des serveurs et de leurs journaux. Dans les diapos, l’invite est abrégée en \$ ; dans le terminal de la page, elle s’écrit ada\@cours:\~\$.],
)

== Une option peut prendre un argument

#anime(
  scene(3, k => stack(spacing: px(16),
    terminal-annote(etape: k, taille: z(46), taille-legende: z(30),
      ("$ date -d 1906-12-09 +%A", ("Sunday", 2)),
      annote("-d 1906-12-09", cote: "haut", clic: 1, reste: true, legende: [l’option `-d` et *son* argument : une date, celle de la naissance de Grace Hopper]),
      annote("Sunday", ligne: 1, cote: "droite", clic: 2, reste: true, legende: [`+%A` demande le jour de la semaine : un dimanche]),
    ),
    des(k, 3, terminal-annote(etape: k, taille: z(46), taille-legende: z(30),
      ("$ date --date=1906-12-09 +%A", "Sunday"),
      annote("--date=1906-12-09", cote: "haut", clic: 3, legende: [option longue : la même, en toutes lettres ; même réponse]),
    )),
  )),
  note(role: "pratique", taille: z(27))[Grace Hopper (1906-1992), officière de la marine des États-Unis, écrit en 1952 le premier compilateur, A-0, et inspire le langage COBOL : on écrit enfin des programmes avec des mots plutôt qu’en codes machine.],
  source-de: [#link("https://www.gnu.org/software/coreutils/manual/html_node/date-invocation.html")[GNU coreutils, date invocation] · #link("https://www.britannica.com/biography/Grace-Hopper")[Britannica, Grace Hopper]],
  note: [#versions 1906-12-09 n’est pas un deuxième argument de date : c’est l’argument de l’option -d. Une option courte peut coller son argument (-d1906-12-09) ; une option longue le donne après = ou après une espace. Le jour s’affiche en anglais : la VM et les relevés emploient la locale C.UTF-8.],
)

== Les guillemets : un texte, un seul argument

#anime(
  commande-annotee(taille: z(60), taille-legende: z(34),
    ("$ echo Grace     Hopper", "Grace Hopper", ("$ echo \"Grace     Hopper\"", 2), ("Grace     Hopper", 2)),
    annote((ligne: 1, texte: "Grace Hopper"), cote: "droite", clic: 1, reste: true, legende: [echo reçoit #arguments("Grace", "Hopper") et les sépare d’une espace]),
    annote((ligne: 3, texte: "Grace     Hopper"), cote: "droite", clic: 2, reste: true, legende: [echo reçoit #arguments("Grace     Hopper") : un seul, espaces compris]),
  ),
  note(role: "retenir", taille: z(30))[Les espaces séparent les arguments ; entre guillemets, un texte reste *un seul* argument, tel quel.],
  note: [#versions echo affiche ses arguments, séparés par une espace. Sans guillemets, les cinq espaces ne font que séparer deux arguments ; entre guillemets, elles font partie de l’argument. Le détail (guillemets simples, doubles, ce que Bash fait de la ligne) : module « Guillemets et expansions ».],
)

== Le clavier du shell

// Un écran de terminal, avant ou après une touche : lignes (l’invite abrégée en $), puis le curseur.
#let _ecran(lignes, curseur: true) = block(width: 100%, fill: c.nuit, radius: px(10), inset: (x: px(18), y: px(12)), {
  set text(font: mono, size: z(38), fill: c.texte-term, tracking: 0pt)
  let t(x) = x.replace(" ", "\u{a0}")
  for (i, l) in lignes.enumerate() {
    if l.starts-with("$ ") { text(fill: c.prompt, "$"); t(l.slice(1)) } else { t(l) }
    if i == lignes.len() - 1 and curseur { box(width: px(24), height: px(42), fill: c.texte-term, baseline: 20%) }
    if i < lignes.len() - 1 { linebreak() }
  }
})
#let _touches(..ts) = align(center, text(size: z(34), ts.pos().map(x => touche(x)).join(h(px(8))) + h(px(10)) + sym.arrow.r))
#let _rangee(n, avant, touches, apres, legende) = grid(columns: (px(540), px(180), px(540), 1fr), column-gutter: px(24),
  align: horizon, _ecran(avant), _touches(..touches), _ecran(apres), text(size: z(28))[#pastille(n) #legende])
#anime(
  scene(4, k => stack(spacing: px(22),
    grid(columns: (px(540), px(180), px(540)), column-gutter: px(24),
      text(size: z(26), fill: c.ardoise)[avant], [], text(size: z(26), fill: c.ardoise)[après]),
    des(k, 1, _rangee(1, ("$ whoa",), ([Tab],), ("$ whoami ",), [un seul nom commence par `whoa` : #touche[Tab] l’achève])),
    des(k, 2, _rangee(2, ("$ who",), ([Tab], [Tab]), ("who     whoami  whois", "$ who"),
      [trois noms commencent par `who` : le second #touche[Tab] les montre])),
    des(k, 3, _rangee(3, ("$ whoami", "ada", "$ "), ([↑],), ("$ whoami", "ada", "$ whoami"),
      [la ligne précédente revient (l’historique) : Entrée la relance])),
    des(k, 4, tableau((auto, 1fr), taille: z(28), inset: (x: px(14), y: px(10)),
      ([Touche], [Effet]),
      [#touche[Ctrl+R]], [cherche dans l’historique : quelques lettres, et la dernière ligne qui les contient revient],
      [#touche[Ctrl+C]], [abandonne la ligne en cours, ou interrompt la commande qui tourne],
    )),
  )),
  note: [#versions Un clic par touche ; ce qui s’affiche après Tab Tab est relevé dans un vrai terminal, Bash interactif de la VM (whois est un applet de BusyBox, présent dans Alpine). Ces raccourcis sont ceux de Readline, la bibliothèque d’édition de ligne de Bash (man bash, section READLINE). À refaire dans le terminal de la page de cours.],
)

== Se documenter : man, `--help`, type, help

#let _man = ("DATE(1)                          User Commands                         DATE(1)", "",
  "NAME", "       date - print or set the system date and time", "",
  "SYNOPSIS", "       date [OPTION]... [+FORMAT]", "       date [-u|--utc|--universal] [MMDDhhmm[[CC]YY][.ss]]", "# …")
#anime(
  scene(4, k => if k == 3 { stack(spacing: px(18),
    text(size: z(28))[#pastille(3) Après `$ man date`, le manuel occupe le terminal : flèches pour avancer, #touche[q] pour revenir à l’invite.],
    terminal-annote(etape: 1, taille: z(24), taille-legende: z(28), _man,
      annote("NAME", cote: "droite", clic: 1, reste: true, legende: [ce que fait la commande]),
      annote("SYNOPSIS", cote: "droite", clic: 1, reste: true, legende: [comment l’écrire ; entre crochets, le facultatif]),
    ),
  ) } else {
    terminal-annote(etape: k, taille: z(36), taille-legende: z(32),
      ("$ type cd", "cd is a shell builtin", "$ type whoami", "whoami is /usr/bin/whoami", ("$ help -d cd", 2),
        ("cd - Change the shell working directory.", 2), ("$ man date", 3), ("$ whoami --help", 4),
        ("Usage: whoami [OPTION]...", 4), ("# … (la suite : ses options)", 4)),
      annote("cd is a shell builtin", cote: "droite", clic: 1, legende: [`type` : interne au shell, ou un programme ?]),
      annote("cd - Change the shell working directory.", cote: "droite", clic: 2, legende: [interne : `help`]),
      annote("Usage: whoami [OPTION]...", cote: "droite", clic: 4, legende: [programme : `man` (clic précédent), ou l’aide courte, `--help`]),
    )
  }),
  note: [#versions Un clic par question. type dit ce qu’est une commande : interne à Bash (alors help), ou un programme sur le disque (alors man, ou `--help`). man affiche le manuel page par page, à la place des lignes du terminal ; q le ferme et rend l’invite, / y cherche un mot. L’écran de man et l’aide de whoami sont coupés (« \# … ») ; ils se lisent en entier dans le terminal de la page. Dans la VM, man est mandoc ; les pages de manuel de coreutils et de Bash y sont installées.],
)

// ======================================================================
= À vous

== À vous : qu’affiche-t-on ? combien d’arguments ? <exercice-intro>

#anime(
  rang(bloc(role: "question", revele: "bloc", taille: z(50))[Prédisez, avant de taper][
    + `echo Ada     Lovelace` : qu’affiche-t-il ?
    + `echo "Ada     Lovelace"` : et celui-ci ?
    + Dans `date -d 1815-12-10 +%A`, combien d’arguments reçoit `date` ? Lesquels ?
    + `type echo` : commande interne ou programme ?
  ]),
  note: [À faire en direct : chacun écrit ses réponses, puis on tape les commandes dans la page de cours. Le 10 décembre 1815 est la date de naissance d’Ada Lovelace.],
)

== Qu’affiche-t-on : corrigé

#anime(
  commande-annotee(taille: z(42), taille-legende: z(30),
    (("$ echo Ada     Lovelace", 2), ("Ada Lovelace", 2), ("$ echo \"Ada     Lovelace\"", 3), ("Ada     Lovelace", 3),
      ("$ date -d 1815-12-10 +%A", 4), ("Sunday", 4), ("$ type echo", 5), ("echo is a shell builtin", 5)),
    annote((ligne: 1, texte: "Ada Lovelace"), cote: "droite", clic: 2, legende: [1 : deux arguments, séparés d’une espace]),
    annote((ligne: 3, texte: "Ada     Lovelace"), cote: "droite", clic: 3, legende: [2 : un seul argument, espaces compris]),
    annote((ligne: 5, texte: "Sunday"), cote: "droite", clic: 4, legende: [3 : trois arguments, #arguments("-d", "1815-12-10", "+%A")]),
    annote("echo is a shell builtin", cote: "droite", clic: 5, legende: [4 : interne : `help echo`]),
  ),
  note(role: "pratique", taille: z(27))[Ada Lovelace (1815-1852) publie en 1843 les notes où figure le premier programme destiné à une machine, la machine analytique de Charles Babbage.],
  source-de: link("https://www.britannica.com/biography/Ada-Lovelace")[Britannica, Ada Lovelace],
  note: [#versions Une réponse par clic, avec la sortie réelle. Le premier clic montre seulement la diapositive, avant toute commande. Question 3 : les options comptent parmi les arguments que reçoit le programme ; -d prend 1815-12-10 pour lui.],
)

== À retenir

#slide[
  #tableau((auto, 1fr), taille: z(34), inset: (x: px(18), y: px(16)),
    ([Mot], [Sens]),
    [terminal], [la fenêtre qui affiche et transmet les touches (un émulateur de terminal)],
    [shell (Bash)], [le programme qui lit la ligne, lance la commande, réaffiche l’invite],
    [invite], [`ada@cours:~$` : compte, machine, répertoire ; `$` ordinaire, `#` root],
    [commande, option, argument], [`date -u +%H:%M` ; une option peut prendre un argument (`-d 1906-12-09`)],
    [guillemets], [un texte entre guillemets reste un seul argument],
    [aide], [`type`, puis `help` (interne) ou `man`, `--help` (programme)],
  )
  #v(px(28))
  #note(role: "retenir", taille: z(28))[Suite : module 1, « #module.at("arbo").titre » : où est-on, et comment aller ailleurs.]
  #speaker-note[Une énumération : elle s’affiche d’un coup.]
]

#cloture(illustration: "tube")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
