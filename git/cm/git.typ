// Cours « Git : versionner et collaborer » — Typst + Touying.
// Compilation (depuis la racine du dépôt) : typst compile --root . --font-path commun/fonts git/cm/git.typ build/git/git.pdf
// Une diapo = un titre `==` ; une section (surtitre bleu) = un titre `=`.
// Structure : règles de .claude/skills/structurer-diapos-cours ; apparence : charte de commun/.
// Sorties : relevées par git/cm/rejouer.sh (Git 2.43.0, identité et date fixées, messages en anglais : LC_ALL=C).

#import "../../commun/theme-cours.typ": *

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Git : versionner et collaborer],
)

// ---------- Graphe des commits ----------
// Composants propres à ce cours, faute d’équivalent dans la charte (besoin signalé pour commun/).
// Coordonnées en px de la maquette ; (x, y) est le centre d’un commit. Chaque commit pointe vers son parent :
// la flèche part de l’enfant (à droite) et arrive au parent (à gauche), comme le champ « parent » d’un commit.
#let gc-l = 150
#let gc-h = 56
// Couleurs du graphe : commits de main en bleu (notion), commits d’une autre branche en vert (pratique).
#let g-main = c.bleu
#let g-branche = roles.pratique.entete

#let g-commit(x, y, id, couleur: g-main, fantome: false) = pose(x - gc-l / 2, y - gc-h / 2, box(
  width: px(gc-l), height: px(gc-h), radius: px(gc-h / 2),
  fill: if fantome { none } else { couleur },
  stroke: if fantome { (paint: c.gris, thickness: px(3), dash: "dashed") } else { none },
  align(center + horizon, text(font: mono, size: px(24), weight: 600,
    fill: if fantome { c.gris } else { texte-sur(couleur) }, id))))

#let g-fleche(x1, y1, x2, y2, couleur: c.gris, tirets: false, ep: 4) = {
  let dx = x2 - x1
  let dy = y2 - y1
  let l = calc.sqrt(dx * dx + dy * dy)
  let (ux, uy) = (dx / l, dy / l)
  let t = 16
  let (bx, by) = (x2 - ux * t, y2 - uy * t)
  let (nx, ny) = (-uy * 9, ux * 9)
  let trait = if tirets { (paint: couleur, thickness: px(ep), dash: "dashed") } else { px(ep) + couleur }
  place(top + left, line(start: (px(x1), px(y1)), end: (px(bx), px(by)), stroke: trait))
  place(top + left, polygon(fill: couleur, (px(x2), px(y2)), (px(bx + nx), px(by + ny)), (px(bx - nx), px(by - ny))))
}
// Flèche d’un commit enfant vers son parent.
#let g-parent(enfant, parent, ..args) = g-fleche(enfant.at(0) - gc-l / 2, enfant.at(1),
  parent.at(0) + gc-l / 2, parent.at(1), ..args)

// Étiquette d’un pointeur : branche (fond nuit), HEAD (contour), branche de suivi origin/… (fond gris).
#let g-etiquette(nom) = {
  let (fond, trait, encre) = if nom == "HEAD" { (c.fond, px(3) + c.encre, c.encre) }
    else if nom.starts-with("origin/") { (c.gris, none, c.fond) } else { (c.nuit, none, c.fond) }
  box(fill: fond, stroke: trait, radius: px(8), inset: (x: px(12), y: px(4)),
    text(font: mono, size: px(22), weight: 600, fill: encre, nom))
}
// Pile de pointeurs au-dessus (ou au-dessous) d’un commit, du plus proche au plus éloigné :
// g-pointeurs(x, y, "main", "HEAD") dessine main → commit, puis HEAD → main.
#let g-pointeurs(x, y, ..noms, bas: false) = {
  let s = if bas { 1 } else { -1 }
  let bord = y + s * gc-h / 2
  for (i, n) in noms.pos().enumerate() {
    let centre = bord + s * (44 + i * 60)
    pose(x - 130, centre - 18, box(width: px(260), height: px(36), align(center + horizon, g-etiquette(n))))
    let cible = if i == 0 { bord } else { bord + s * (44 + (i - 1) * 60) + s * 18 }
    g-fleche(x, centre - s * 18, x, cible, couleur: c.encre, ep: 3)
  }
}
// Canevas d’un graphe : hauteur fixe, éléments posés en coordonnées de la maquette.
#let canevas(hauteur, corps) = block(width: 100%, height: px(hauteur), corps)
// Titre court au-dessus d’un schéma.
#let titre-schema(t) = text(size: px(28), weight: 600, fill: c.bleu, t)

// Terminal par morceaux, chaque explication apparaissant avec le morceau qu’elle explique
// (decalage : nombre de morceaux sans explication au début). cote : explications à droite du terminal.
// colonnes : n > 1 range les morceaux en grille de n colonnes, chaque explication sous son morceau.
#let terminal-explique(taille: px(20), decalage: 0, cle: px(64), poids: (1.45, 1), colonnes: 1,
  morceaux, explications) = pas(morceaux.len(), (u, d) => {
  let expl(i) = {
    let j = i - decalage
    if j >= 0 and j < explications.len() {
      let (k, v) = explications.at(j)
      grid(columns: (cle, 1fr), column-gutter: px(16),
        text(size: px(26), weight: 600, fill: c.bleu, k), text(size: px(23), v))
    } else { [] }
  }
  if colonnes > 1 {
    grid(columns: (1fr,) * colonnes, column-gutter: px(32), row-gutter: px(20),
      ..morceaux.enumerate().map(((i, m)) => u(str(d + i) + "-", stack(spacing: px(10),
        terminal(titre: none, taille: taille, m), expl(i)))))
  } else {
    grid(columns: poids.map(x => x * 1fr), column-gutter: px(32), row-gutter: px(6), align: (left + top, left + horizon),
      ..morceaux.enumerate().map(((i, m)) =>
        (u(str(d + i) + "-", terminal(titre: none, taille: taille, m)), u(str(d + i) + "-", expl(i)))).flatten())
  }
})

// Corrigés côte à côte : une colonne par question, la réponse sous la question, un clic par réponse.
#let corriges-cote(note: none, ..items) = {
  let qa = items.pos()
  slide(repeat: qa.len() + 1, self => {
    let (uncover,) = utils.methods(self)
    grid(columns: (1fr,) * qa.len(), column-gutter: px(40),
      ..qa.enumerate().map(((i, it)) => stack(spacing: px(14),
        question(it.at(0), it.at(1)), uncover(str(i + 2) + "-", it.at(2)))))
    if note != none { utils.speaker-note(self: self, note) }
  })
}

// ---------- Trois zones ----------
#let zone(titre, sous-titre, corps) = block(width: px(380), height: px(220), fill: c.appli, radius: px(14),
  inset: px(18), stack(spacing: px(10),
    align(center, text(size: px(30), weight: 600, titre)),
    align(center, text(size: px(22), fill: c.ardoise, sous-titre)),
    v(px(6)),
    align(center, text(size: px(24), corps))))
#let commande-fleche(x1, x2, y, cmd, dessous: false) = {
  g-fleche(x1, y, x2, y, couleur: c.encre, ep: 4)
  let gauche = calc.min(x1, x2)
  pose(gauche, if dessous { y + 10 } else { y - 46 }, box(width: px(calc.abs(x2 - x1)),
    align(center, text(font: mono, size: px(20), weight: 600, fill: c.bleu, cmd))))
}

#couverture(illustration: "couches")[Git][Versionner et collaborer][Jean-Mathieu Chantrein][25 novembre 2026]
#speaker-note[Illustration provisoire (la charte n’a que « vm » et « couches ») : un graphe de commits conviendrait mieux. Toutes les sorties de terminal du cours sont relevées par git/cm/rejouer.sh avec Git 2.43.0 (Ubuntu 24.04), dans un dossier jetable, identité « Ada Lovelace » et date fixées, messages de Git en anglais (LC\_ALL=C) ; dans une session en français, Git traduit ses messages.]

// ======================================================================
= Sommaire

== Plan du cours

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  lignes(largeur: px(480), taille-cle: px(34), taille: px(28), uncover: uncover,
    ([Introduction], [Versions et collaboration : le problème ; Git ; se présenter à Git]),
    ([Concepts], [Trois zones, cycle de travail, objets, graphe des commits, branches et `HEAD`]),
    ([Branches], [Fusion par avance rapide ou par commit de fusion, conflit, rebasage]),
    ([Dépôts distants], [`clone`, `push`, `fetch`, `pull` ; un `push` refusé]),
    ([Annuler], [`restore`, `revert`, `reset` et ses trois modes, `reflog`]),
    ([En équipe], [Branches et demandes de fusion, bonnes pratiques, `.gitignore`]),
  )
  utils.speaker-note(self: self)[Une partie par clic. Trois exercices faits en séance : après le cycle de travail, après le conflit, après reset. Fil rouge : le petit site web d’Ada (index.html, contact.html…), partagé ensuite avec Grace ; exercices : un script de sauvegarde versionné.]
})

// ======================================================================
= Introduction

== Sans outil : copies en vrac, travail écrasé

#anime(
  rang(
    bloc(role: "avertissement", taille: px(26))[Des versions à la main][
      - `sauvegarde.sh`, `sauvegarde_v2.sh`, `sauvegarde_v2_final_OK.sh` : laquelle tourne en production ?
      - Une configuration nginx modifiée casse le service : quelle était la version qui marchait ?
      - Qui a changé cette ligne, quand, et pourquoi ?
    ],
    bloc(role: "avertissement", taille: px(26))[À plusieurs sur les mêmes fichiers][
      - Deux administrateurs modifient le même script : le dernier enregistré écrase l’autre
      - On s’envoie des fichiers par courriel ou sur une clé USB
      - Personne ne relit un changement avant qu’il parte en production
    ],
  ),
  rang(bloc(role: "pratique", taille: px(26))[Ce que fait un gestionnaire de versions][
    - Garde chaque version enregistrée, avec son auteur, sa date et son message : on revient à n’importe laquelle
    - Fusionne le travail de plusieurs personnes et signale les modifications incompatibles
    - Pour l’administrateur : scripts, fichiers de configuration, inventaires Ansible, tout ce qui est du texte
  ]),
  source-de: link("https://git-scm.com/book/en/v2/Getting-Started-About-Version-Control")[Pro Git, § 1.1 About Version Control],
  note: [Cas réels d’abord ; Git vient à la diapositive suivante. Exemples d’administration du cours d’origine : versionner les scripts, versionner les configurations critiques (Apache, nginx, Ansible) pour revenir à une version qui fonctionne, partager l’infrastructure avec les équipes DevOps.],
)

== Git : un gestionnaire de versions distribué

#anime(
  rang(
    bloc(taille: px(26))[Centralisé : un serveur détient l’historique][
      - CVS (_Concurrent Versions System_), Subversion (SVN) : chaque poste n’a qu’une version des fichiers
      - Sans le serveur, ni historique ni enregistrement
    ],
    bloc(taille: px(26))[Distribué : chaque copie est complète][
      - Git, Mercurial : chaque *dépôt* (_repository_) contient tout l’historique
      - On enregistre, on compare, on revient en arrière hors ligne ; on synchronise ensuite
    ],
  ),
  rang(bloc(role: "retenir", taille: px(26))[Git][
    - Créé en 2005 par Linus Torvalds pour les sources du noyau Linux, quand l’outil précédent, BitKeeper, a cessé d’être gratuit pour le projet
    - Logiciel libre, sous licence GPL v2 (_GNU General Public License_)
    - Une *forge* (GitHub, GitLab, Forgejo) héberge des dépôts Git et ajoute comptes, interface web, demandes de fusion : ce n’est pas Git
  ]),
  source-de: [#link("https://git-scm.com/book/en/v2/Getting-Started-A-Short-History-of-Git")[Pro Git, § 1.2 A Short History of Git] · #link("https://git-scm.com/about")[git-scm.com/about]],
  note: [« Distribué » : un clone est un dépôt entier, pas une simple copie de travail ; d’où des opérations locales rapides et une sauvegarde naturelle (chaque clone peut reconstituer le serveur). GitHub (Microsoft), GitLab et Forgejo (forge libre, celle de Codeberg) ajoutent ce que Git n’a pas : comptes, interface web, demandes de fusion, intégration continue.],
)

== Installer Git et se présenter

#anime(
  rang(
    bloc(role: "pratique", poids: 1.2, taille: px(24))[Une fois par poste][
      #terminal(taille: px(21))[
        ```
        # Debian, Ubuntu : paquet git
        $ sudo apt install git
        $ git --version
        git version 2.43.0
        # nom et adresse inscrits dans chaque version enregistrée
        $ git config --global user.name "Ada Lovelace"
        $ git config --global user.email ada@example.org
        $ git config --global --list
        user.name=Ada Lovelace
        user.email=ada@example.org
        ```
      ]
    ],
    bloc(taille: px(26))[À savoir][
      - `--global` écrit dans `~/.gitconfig` : la configuration vaut pour tous vos dépôts
      - Le nom et l’adresse figurent dans l’historique, que les autres liront : choisissez ceux que vous voulez rendre publics
      - Prérequis du cours : Git ≥ 2.28, pour `git init -b main` ; version employée ici : 2.43.0
    ],
  ),
  source-de: [#link("https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup")[Pro Git, § 1.6 First-Time Git Setup] · #link("https://git-scm.com/docs/git-config")[git-config(1)]],
  note: [Git 2.43.0 est celui d’Ubuntu 24.04 ; Debian 13 fournit une version plus récente. Sans user.name ni user.email, git commit refuse d’enregistrer ou devine une identité à partir du nom de la machine. Option utile : git config -\-global init.defaultBranch main, pour que git init crée la branche main sans l’option -b (annexe « Sans -b main »). Sorties relevées par git/cm/rejouer.sh.],
)

// ======================================================================
= Concepts

== Trois zones : travail, index, dépôt <trois-zones>

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  canevas(270, {
    pose(0, 20, zone([Répertoire de travail], [_working tree_], [les fichiers que vous éditez]))
    uncover("2-", pose(642, 20, zone([Index], [_staging area_ : zone de préparation], [le contenu du prochain commit])))
    uncover("3-", pose(1284, 20, zone([Dépôt], [le dossier `.git`], [l’historique : tous les commits])))
    uncover("2-", commande-fleche(380, 642, 90, [git add]))
    uncover("3-", commande-fleche(1022, 1284, 90, [git commit]))
    uncover("4-", commande-fleche(642, 380, 170, [git restore], dessous: true))
    uncover("5-", commande-fleche(1284, 1022, 170, [git restore -\-staged], dessous: true))
  })
  lignes(largeur: px(330), taille-cle: px(24), taille: px(24), uncover: uncover, debut: 2,
    ([`git add`], [copie l’état actuel d’un fichier dans l’index]),
    ([`git commit`], [enregistre le contenu de l’index dans le dépôt : un nouveau commit]),
    ([`git restore`], [remet dans le fichier la version de l’index : la modification est perdue]),
    ([`git restore --staged`], [remet dans l’index la version du dernier commit ; le fichier ne change pas]),
  )
  uncover("6-", note(role: "retenir")[Un commit enregistre l’index, pas le répertoire de travail : ce qui n’a pas été ajouté par `git add` n’y entre pas.])
  source[#link("https://git-scm.com/book/en/v2/Getting-Started-What-is-Git%3F")[Pro Git, § 1.3 What is Git? (The Three States)] · #link("https://git-scm.com/docs/git-restore")[git-restore(1)]]
  utils.speaker-note(self: self)[Une zone puis une commande par clic. Pro Git parle de trois états d’un fichier suivi : modifié (modified), indexé (staged), validé (committed), qui correspondent aux trois zones. L’index est un fichier, .git/index. Commit se traduit parfois par « validation » ; on garde « commit », le terme de toutes les sorties de Git. git restore (Git 2.23, 2019) remplace ici l’ancien git checkout -\- fichier (annexe). La page de manuel de Git 2.43 qualifie encore restore et switch d’expérimentales ; git status les propose pourtant dans ses conseils (diapositive suivante).]
})

== Créer un dépôt : git init

#anime(
  rang(
    bloc(role: "pratique", poids: 1.25, taille: px(24))[Démonstration][
      #terminal(taille: px(21))[
        ```
        $ mkdir mon_projet
        $ cd mon_projet
        # -b main : nom de la première branche
        $ git init -b main
        Initialized empty Git repository in /tmp/git-cours/ada/mon_projet/.git/
        $ ls -A
        .git
        $ git status
        On branch main

        No commits yet

        nothing to commit (create/copy files and use "git add" to track)
        ```
      ]
    ],
    bloc(taille: px(26))[Lire la sortie][
      - `git init` crée le dossier caché `.git` : c’est lui, le dépôt (historique, index, configuration)
      - Supprimer `.git` retire le suivi de versions ; les fichiers restent
      - `git status` : où en suis-je ? Ici, branche `main`, aucun commit encore
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-init")[git-init(1)] · #link("https://git-scm.com/docs/git-status")[git-status(1)]],
  note: [Fil rouge du cours : le petit site d’Ada, dans mon\_projet (exemple du cours d’origine). Le chemin affiché est celui du relevé (HOME=/tmp/git-cours/ada) ; chez vous, votre dossier personnel. Sans -b main ni init.defaultBranch, Git 2.43 crée une branche master et affiche une dizaine de lignes « hint: » (annexe). Sorties relevées par git/cm/rejouer.sh.],
)

== Le cycle : modifier, indexer, enregistrer <cycle>

#anime(
  terminal-explique(taille: px(21), cle: px(160),
    (
      [```
      # 1. modifier : un fichier nouveau, que Git ne suit pas encore
      $ echo '<h1>Bienvenue sur mon site</h1>' > index.html
      $ git status --short
      ?? index.html
      ```],
      [```
      # 2. indexer : le fichier entre dans le prochain commit
      $ git add index.html
      $ git status --short
      A  index.html
      ```],
      [```
      # 3. enregistrer : un commit, avec son message
      $ git commit -m "Ajout de la page d'accueil"
      [main (root-commit) 30b6212] Ajout de la page d'accueil
       1 file changed, 1 insertion(+)
       create mode 100644 index.html
      ```],
    ),
    (
      ([`??`], [fichier non suivi (_untracked_) : Git le voit, ne l’enregistre pas]),
      ([`A`], [ajouté à l’index (_added_) : première colonne = index]),
      ([`30b6212`], [début de l’identifiant du commit ; `root-commit` : le premier, sans parent]),
    ),
  ),
  source-de: [#link("https://git-scm.com/docs/git-status#_short_format")[git-status(1), format court] · #link("https://git-scm.com/docs/git-commit")[git-commit(1)]],
  note: [Un clic par geste, avec son explication en face. Dans le cours d’origine, le fichier est écrit avec Vim ; echo montre ici son contenu exact. Format court de git status : deux colonnes, la première pour l’index, la seconde pour le répertoire de travail. L’identifiant 30b6212 est celui du relevé : il dépend du contenu, de l’auteur et de la date, il sera différent chez vous (annexe « Rejouer le cours à l’identique »). Sorties relevées par git/cm/rejouer.sh, Git 2.43.0.],
)

== Voir ce qui change : git diff

#anime(
  rang(
    bloc(role: "pratique", taille: px(24))[Modifier : écart travail ↔ index][
      #terminal(titre: none, taille: px(19))[
        ```
        $ echo '<p>Ceci est un paragraphe.</p>' >> index.html
        $ git status --short
         M index.html
        $ git diff
        diff --git a/index.html b/index.html
        index 2db0a09..1031066 100644
        --- a/index.html
        +++ b/index.html
        @@ -1 +1,2 @@
         <h1>Bienvenue sur mon site</h1>
        +<p>Ceci est un paragraphe.</p>
        ```
      ]
    ],
    bloc(role: "pratique", taille: px(24))[Indexer : écart index ↔ dernier commit][
      #terminal(titre: none, taille: px(19))[
        ```
        $ git add index.html
        $ git status --short
        M  index.html
        $ git diff --staged
        diff --git a/index.html b/index.html
        # … (les 7 mêmes lignes que git diff ci-contre)
        $ git commit -m "Ajout d'un paragraphe"
        [main 286f82b] Ajout d'un paragraphe
         1 file changed, 1 insertion(+)
        ```
      ]
    ],
  ),
  rang(bloc(taille: px(24))[Lire la sortie][
    - ` M` (seconde colonne) : modifié, non indexé ; `M ` (première colonne) : modifié et indexé
    - `+` : ligne ajoutée, `-` : ligne retirée ; `@@ -1 +1,2 @@` : la ligne 1 avant, les lignes 1 et 2 après
    - Il faut refaire `git add` : il indexe un état du fichier, pas le fichier une fois pour toutes
  ]),
  source-de: [#link("https://git-scm.com/docs/git-diff")[git-diff(1)] · #link("https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository")[Pro Git, § 2.2]],
  note: [Après git add, git diff ne montre plus rien et git diff -\-staged montre exactement le même extrait (relevé complet dans rejouer.sh) : la modification est passée de l’écart travail/index à l’écart index/commit. 2db0a09..1031066 : les blobs du fichier avant et après. Le cours d’origine écrivait git commit index.html -m … ; on sépare ici git add et git commit, qui rend l’index visible. Raccourci : git commit -a -m … indexe d’abord tous les fichiers déjà suivis (pas les nouveaux) ; pratique, mais on ne choisit plus ce qui entre. Sorties relevées par git/cm/rejouer.sh.],
)

== Lire l’historique : git log

#anime(
  rang(
    bloc(role: "pratique", poids: 1.25, taille: px(24))[Démonstration][
      #terminal(taille: px(21))[
        ```
        $ git log
        commit 286f82be85f6361d95d0469b15e617bb42f376e0 (HEAD -> main)
        Author: Ada Lovelace <ada@example.org>
        Date:   Wed Nov 25 10:00:00 2026 +0100

            Ajout d'un paragraphe

        commit 30b62123f5f917cc83446434c6e38aa37bc55223
        Author: Ada Lovelace <ada@example.org>
        Date:   Wed Nov 25 10:00:00 2026 +0100

            Ajout de la page d'accueil
        $ git log --oneline
        286f82b (HEAD -> main) Ajout d'un paragraphe
        30b6212 Ajout de la page d'accueil
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la sortie][
      - Le plus récent en haut ; un identifiant de 40 chiffres hexadécimaux par commit
      - `--oneline` : 7 premiers chiffres, assez pour désigner un commit sans ambiguïté
      - `(HEAD -> main)` : la branche courante et le commit où elle se trouve, expliqués plus loin
    ],
  ),
  source-de: link("https://git-scm.com/docs/git-log")[git-log(1)],
  note: [Les deux commits portent la même date parce que le relevé fixe la date (GIT\_AUTHOR\_DATE, GIT\_COMMITTER\_DATE) pour obtenir des identifiants reproductibles ; chez vous, la date du moment. Dans un terminal, git log ouvre un afficheur (less, touche q pour quitter) et ajoute des couleurs. Les décorations (HEAD -> main) n’apparaissent que lorsque la sortie est un terminal : rejouer.sh se lance donc dans un pseudo-terminal. Sorties relevées par git/cm/rejouer.sh.],
)

== À vous : versionner un script de sauvegarde

#anime(
  rang(bloc(role: "pratique", taille: px(24))[Prérequis][
    - Git ≥ 2.28, nom et adresse configurés (diapositive « Installer Git et se présenter ») ; un éditeur (Vim…)
  ]),
  rang(bloc(role: "question", taille: px(27))[À vous][
    + Créez un répertoire `admin` et faites-en un dépôt Git dont la branche s’appelle `main`
    + Créez `sauvegarde.sh` de deux lignes, `#!/bin/sh` et `tar -cf /tmp/etc.tar /etc` ; ajoutez-le à l’index, affichez l’état du dépôt, puis enregistrez un commit
    + Ajoutez la ligne `echo Sauvegarde terminée` et enregistrez un nouveau commit. Faut-il refaire `git add` ?
    + Affichez l’historique, un commit par ligne
  ]),
  note: [Exercice du cours d’origine (étapes 1 à 4), transposé à un script d’administration. Une question par clic ; laisser chercher, corrigé sur la diapositive suivante. Le dépôt admin sert aux trois exercices du cours.],
)

== Versionner un script : corrigé (1/2)

#corriges-cote(note: [La question reste affichée ; un clic par réponse. Identifiants du relevé (git/cm/rejouer.sh, Git 2.43.0, identité et date fixées) : les vôtres diffèrent. printf écrit les deux lignes d’un coup ; avec Vim, le résultat est le même fichier.],
  (1, [Un dépôt `admin`, branche `main`],
    reponse(terminal(titre: none, taille: px(18))[```
    $ mkdir admin
    $ cd admin
    $ git init -b main
    Initialized empty Git repository in /tmp/git-cours/ada/admin/.git/
    ```])),
  (2, [`sauvegarde.sh` : indexer, contrôler l’état, enregistrer],
    reponse(terminal(titre: none, taille: px(18))[```
    $ printf '%s\n' '#!/bin/sh' 'tar -cf /tmp/etc.tar /etc' \
      > sauvegarde.sh
    $ git add sauvegarde.sh
    $ git status --short
    A  sauvegarde.sh
    $ git commit -m "Script de sauvegarde"
    [main (root-commit) d5aaf89] Script de sauvegarde
     1 file changed, 2 insertions(+)
     create mode 100644 sauvegarde.sh
    ```])),
)

== Versionner un script : corrigé (2/2)

#corriges-cote(note: [Un clic par réponse. git status -\-short montre M dans la seconde colonne : modifié, pas encore indexé. Sorties relevées par git/cm/rejouer.sh.],
  (3, [Une ligne de plus, un commit de plus : refaire `git add` ?],
    reponse(terminal(titre: none, taille: px(19))[```
    $ echo 'echo Sauvegarde terminée' >> sauvegarde.sh
    $ git status --short
     M sauvegarde.sh
    # oui : la modification n’est pas encore dans l’index
    $ git add sauvegarde.sh
    $ git commit -m "Message de fin"
    [main 87218ff] Message de fin
     1 file changed, 1 insertion(+)
    ```])),
  (4, [L’historique, un commit par ligne],
    reponse(terminal(titre: none, taille: px(19))[```
    $ git log --oneline
    87218ff (HEAD -> main) Message de fin
    d5aaf89 Script de sauvegarde
    ```])),
)

== Trois objets : blob, arbre, commit <objets>

#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  let objet(x, y, genre, id, corps, couleur) = pose(x, y, block(width: px(560), stroke: px(3) + couleur, radius: px(12),
    inset: px(14), fill: c.fond, stack(spacing: px(8),
      text(size: px(24), weight: 600, fill: couleur)[#genre #text(font: mono, id)],
      text(size: px(21), corps))))
  grid(columns: (1fr, px(640)), column-gutter: px(40),
    terminal(titre: none, taille: px(19))[
      ```
      # HEAD : le dernier commit de la branche (expliqué plus loin)
      $ git cat-file -t HEAD
      commit
      $ git cat-file -p HEAD
      tree bf2cf2d91c8f8f0cb790110e50863faefe93dc73
      parent 30b62123f5f917cc83446434c6e38aa37bc55223
      author Ada Lovelace <ada@example.org> 1795597200 +0100
      committer Ada Lovelace <ada@example.org> 1795597200 +0100

      Ajout d'un paragraphe
      ```
      #uncover("3-")[```
      # l’arbre (tree) du commit : un répertoire
      $ git cat-file -p "HEAD^{tree}"
      100644 blob 103106636f13071ed0eec006dd20c9aae3d58b07    index.html
      ```]
      #uncover("4-")[```
      # le blob : le contenu du fichier, sans son nom
      $ git cat-file -p "HEAD:index.html"
      <h1>Bienvenue sur mon site</h1>
      <p>Ceci est un paragraphe.</p>
      ```]
    ],
    canevas(600, {
      objet(0, 0, [commit], [286f82b], [auteur, date, message ; un arbre ; un parent], c.bleu)
      uncover("2-", {
        pose(0, 150, block(width: px(430), stroke: px(3) + c.gris, radius: px(12), inset: px(14), fill: c.fond,
          stack(spacing: px(8), text(size: px(24), weight: 600, fill: c.gris)[commit parent #text(font: mono)[30b6212]],
            text(size: px(21))[le commit précédent, son propre arbre])))
        g-fleche(40, 95, 40, 150, couleur: c.gris)
      })
      uncover("3-", {
        objet(0, 300, [arbre (_tree_)], [bf2cf2d], [noms de fichiers, droits, et l’objet de chacun], g-branche)
        g-fleche(520, 95, 520, 300, couleur: g-branche)
      })
      uncover("4-", {
        objet(0, 450, [blob], [1031066], [le contenu de `index.html`, octet pour octet], g-branche)
        g-fleche(520, 395, 520, 450, couleur: g-branche)
      })
    }),
  )
  source[#link("https://git-scm.com/book/en/v2/Git-Internals-Git-Objects")[Pro Git, § 10.2 Git Objects] · #link("https://git-scm.com/docs/git-cat-file")[git-cat-file(1)]]
  utils.speaker-note(self: self)[Un objet par clic : le commit, son parent, son arbre, le blob. git cat-file -t donne le type d’un objet, -p l’affiche. Un commit contient l’identifiant de son arbre (l’instantané complet du projet, pas une différence), de son ou ses parents, l’auteur et le validateur (committer) avec une date en secondes depuis le 1er janvier 1970 (1795597200 = 25 novembre 2026, 10 h, heure de Paris), puis le message. Un arbre peut contenir d’autres arbres (sous-répertoires). HEAD^\{tree\} : l’arbre du commit HEAD ; HEAD:index.html : le blob de ce fichier dans ce commit. Sorties relevées par git/cm/rejouer.sh.]
})

== Un identifiant est l’empreinte du contenu

#anime(
  rang(
    bloc(role: "pratique", poids: 1.1, taille: px(24))[Démonstration][
      #terminal(taille: px(21))[
        ```
        # l’empreinte que Git calcule pour ce contenu
        $ git hash-object index.html
        103106636f13071ed0eec006dd20c9aae3d58b07
        # c’est l’identifiant du blob de la diapo précédente
        ```
      ]
    ],
    bloc(taille: px(25))[Conséquences][
      - Même contenu, même identifiant : un fichier inchangé n’est stocké qu’une fois
      - Un commit inclut l’identifiant de son parent : modifier un commit ancien change tous ceux qui suivent
      - L’historique enregistré ne se modifie donc pas : on en crée un autre
    ],
  ),
  rang(bloc(role: "retenir", taille: px(26))[À retenir][
    L’identifiant d’un objet est son empreinte SHA-1 (_Secure Hash Algorithm 1_, 40 chiffres hexadécimaux) : il désigne un contenu, pas un emplacement.
  ]),
  source-de: [#link("https://git-scm.com/book/en/v2/Git-Internals-Git-Objects")[Pro Git, § 10.2] · #link("https://git-scm.com/docs/git-hash-object")[git-hash-object(1)]],
  note: [Empreinte (hash) : voir le cours Virtualisation, diapositive « Une empreinte résume un fichier ». Git calcule le SHA-1 de « blob \<taille\>\\0 » suivi du contenu, d’où une valeur différente de sha1sum index.html. Git sait aussi employer SHA-256 (git init -\-object-format=sha256), encore peu répandu. Les identifiants changent avec l’auteur et la date : d’où l’annexe pour rejouer le cours à l’identique. Sortie relevée par git/cm/rejouer.sh.],
)

== Le graphe des commits <graphe>

#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  canevas(330, {
    let (a, b, cc) = ((100, 160), (340, 160), (580, 160))
    g-commit(..a, [A])
    g-commit(..b, [B])
    g-parent(b, a)
    uncover("2-", {
      g-commit(..cc, [C])
      g-parent(cc, b)
      g-commit(820, 60, [D])
      g-parent((820, 60), cc)
      g-commit(820, 260, [E], couleur: g-branche)
      g-parent((820, 260), cc)
    })
    uncover("3-", {
      g-commit(1080, 160, [F])
      g-parent((1080, 160), (820, 60))
      g-parent((1080, 160), (820, 260))
    })
  })
  lignes(largeur: px(80), taille-cle: px(28), taille: px(25), uncover: uncover,
    ([1], [Chaque commit désigne son parent : B pointe vers A ; A, le commit racine, n’a pas de parent]),
    ([2], [Deux commits peuvent avoir le même parent : l’histoire se sépare (D et E partent de C)]),
    ([3], [Un commit de fusion a deux parents : l’histoire se rejoint (F)]),
  )
  uncover("4-", note(role: "retenir")[L’historique n’est pas une liste mais un graphe orienté sans cycle ; les flèches vont toujours du plus récent vers le plus ancien.])
  source[#link("https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell")[Pro Git, § 3.1 Branches in a Nutshell]]
  utils.speaker-note(self: self)[Lettres à la place des identifiants, pour la lisibilité. Le sens des flèches suit les données : un commit contient l’identifiant de son parent (diapositive « Trois objets ») ; un parent ne connaît pas ses enfants. git log -\-graph dessine ce graphe en mode texte, de haut (récent) en bas (ancien), comme on le verra avec les fusions. E est en vert : un commit d’une autre branche que main, convention gardée dans tout le cours.]
})

== Branches et HEAD : de simples pointeurs <pointeurs>

#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1fr, px(700)), column-gutter: px(40),
    canevas(560, {
      let (a, b, cc) = ((100, 280), (340, 280), (580, 280))
      g-commit(..a, [30b6212])
      g-commit(..b, [286f82b])
      g-parent(b, a)
      g-pointeurs(..b, "main", bas: true)
      uncover("1", g-pointeurs(..b, "main", "HEAD", bas: true))
      uncover("2", g-pointeurs(..b, "contact", "HEAD"))
      uncover("3-", {
        g-commit(..cc, [1420e6a], couleur: g-branche)
        g-parent(cc, b)
        g-pointeurs(..cc, "contact", "HEAD")
      })
    }),
    terminal(titre: none, taille: px(19))[
      ```
      # une branche : un fichier qui contient un identifiant
      $ cat .git/refs/heads/main
      286f82be85f6361d95d0469b15e617bb42f376e0
      # HEAD : la branche courante
      $ cat .git/HEAD
      ref: refs/heads/main
      ```
      #uncover("2-")[```
      # -c : créer la branche, puis s’y placer
      $ git switch -c contact
      Switched to a new branch 'contact'
      $ cat .git/HEAD
      ref: refs/heads/contact
      ```]
      #uncover("3-")[```
      $ echo '<p>Écrire à ada@example.org</p>' > contact.html
      $ git add contact.html
      $ git commit -m "Ajout de la page contact"
      [contact 1420e6a] Ajout de la page contact
       1 file changed, 1 insertion(+)
       create mode 100644 contact.html
      ```]
    ],
  )
  uncover("4-", note(role: "retenir")[Une branche est un pointeur mobile vers un commit ; `HEAD` désigne la branche courante. Un commit fait avancer la branche courante, et elle seule.])
  source[#link("https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell")[Pro Git, § 3.1] · #link("https://git-scm.com/docs/git-switch")[git-switch(1)]]
  utils.speaker-note(self: self)[Clic 1 : main pointe vers 286f82b, HEAD vers main. Clic 2 : git switch -c crée le pointeur contact sur le même commit et y déplace HEAD ; aucun fichier n’est copié. Clic 3 : le commit avance contact (et HEAD, qui le suit) ; main reste où il était. Créer une branche coûte 41 octets (un identifiant et un saut de ligne). Ancienne forme : git checkout -b contact (annexe). Les branches peuvent aussi être rangées dans .git/packed-refs : lire .git/refs n’est qu’une démonstration ; la commande officielle est git rev-parse main. Sorties relevées par git/cm/rejouer.sh.]
})

// ======================================================================
= Branches

== Une branche se voit dans `git log --graph`

#anime(
  rang(
    bloc(role: "pratique", poids: 1.2, taille: px(24))[Démonstration][
      #terminal(taille: px(21))[
        ```
        # * : branche courante
        $ git branch
        * contact
          main
        # --all : toutes les branches, pas seulement la courante
        $ git log --oneline --graph --all
        * 1420e6a (HEAD -> contact) Ajout de la page contact
        * 286f82b (main) Ajout d'un paragraphe
        * 30b6212 Ajout de la page d'accueil
        $ git switch main
        Switched to branch 'main'
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la sortie][
      - Chaque `*` est un commit ; les décorations entre parenthèses sont les pointeurs
      - `git switch main` remet dans le répertoire de travail les fichiers du commit de `main` : `contact.html` disparaît du disque, pas du dépôt
      - Changer de branche avec des modifications non enregistrées : Git refuse s’il devait les écraser
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-branch")[git-branch(1)] · #link("https://git-scm.com/docs/git-switch")[git-switch(1)]],
  note: [Le graphe est encore une ligne : contact est simplement en avance sur main. git log -\-graph dessine une colonne par ligne d’histoire parallèle (diapositives de fusion). Sorties relevées par git/cm/rejouer.sh.],
)

== Fusionner : avance rapide ou commit de fusion <fusion>

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1fr, 1fr), column-gutter: px(48),
    stack(spacing: px(8),
      titre-schema[Avance rapide (_fast-forward_)],
      canevas(370, {
        let (a, b, cc) = ((90, 180), (300, 180), (510, 180))
        g-commit(..a, [30b6212])
        g-commit(..b, [286f82b])
        g-parent(b, a)
        g-commit(..cc, [1420e6a], couleur: g-branche)
        g-parent(cc, b)
        g-pointeurs(..cc, "contact", bas: true)
        uncover("1", g-pointeurs(..b, "main", "HEAD"))
        uncover("2-", g-pointeurs(..cc, "main", "HEAD"))
      }),
      lignes(largeur: px(48), taille-cle: px(26), taille: px(22), uncover: uncover,
        ([1], [`main` n’a pas bougé depuis `contact`]),
        ([2], [`git merge contact` : `main` avance, sans nouveau commit]),
      ),
    ),
    uncover("3-", stack(spacing: px(8),
      titre-schema[Commit de fusion (_merge commit_)],
      canevas(370, {
        let (base, d, e, m) = ((90, 215), (320, 150), (320, 280), (560, 150))
        g-commit(..base, [1420e6a])
        g-commit(..d, [964810d])
        g-parent(d, base)
        g-commit(..e, [4dcef0c], couleur: g-branche)
        g-parent(e, base)
        g-pointeurs(..e, "style", bas: true)
        uncover("3", g-pointeurs(..d, "main", "HEAD"))
        uncover("4-", {
          g-commit(..m, [91e2508])
          g-parent(m, d)
          g-parent(m, e)
          g-pointeurs(..m, "main", "HEAD")
        })
      }),
      lignes(largeur: px(48), taille-cle: px(26), taille: px(22), uncover: uncover, debut: 3,
        ([3], [un commit de chaque côté depuis l’ancêtre commun]),
        ([4], [`git merge style` crée `91e2508`, à deux parents]),
      ),
    )),
  )
  uncover("5-", note(role: "retenir")[`git merge X` intègre la branche X dans la branche courante. Avance rapide si la branche courante est un ancêtre de X ; sinon, commit de fusion à deux parents.])
  source[#link("https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging")[Pro Git, § 3.2 Basic Branching and Merging] · #link("https://git-scm.com/docs/git-merge")[git-merge(1)]]
  utils.speaker-note(self: self)[Un clic par étape ; les identifiants sont ceux du fil rouge (terminal sur la diapositive suivante). Avance rapide : rien à combiner, Git déplace le pointeur. Commit de fusion : Git combine les modifications des deux côtés depuis l’ancêtre commun (1420e6a), ce qu’on appelle une fusion à trois points (three-way merge). L’option -\-no-ff force un commit de fusion même quand l’avance rapide est possible, pour garder la trace de la branche ; -\-ff-only refuse toute fusion qui ne serait pas une avance rapide.]
})

== Les deux fusions dans le terminal

#anime(
  pas(3, (u, d) => grid(columns: (1fr, 1fr), column-gutter: px(32),
    terminal(titre: none, taille: px(19))[
      #u(str(d) + "-")[```
      # avance rapide : main est un ancêtre de contact
      $ git merge contact
      Updating 286f82b..1420e6a
      Fast-forward
       contact.html | 1 +
       1 file changed, 1 insertion(+)
       create mode 100644 contact.html
      ```]
      #u(str(d + 1) + "-")[```
      # histoire divergente : un commit sur style, un sur main
      $ git log --oneline --graph --all
      * 964810d (HEAD -> main) Délai de réponse
      | * 4dcef0c (style) Ajout d'une feuille de style
      |/
      * 1420e6a Ajout de la page contact
      # … (deux commits plus anciens)
      $ git merge style -m "Fusion de la branche style"
      Merge made by the 'ort' strategy.
       style.css | 1 +
       1 file changed, 1 insertion(+)
       create mode 100644 style.css
      ```]
    ],
    u(str(d + 2) + "-", terminal(titre: none, taille: px(19))[```
      $ git log --oneline --graph -4
      *   91e2508 (HEAD -> main) Fusion de la branche style
      |\
      | * 4dcef0c (style) Ajout d'une feuille de style
      * | 964810d Délai de réponse
      |/
      * 1420e6a Ajout de la page contact
      # deux lignes parent : un commit de fusion
      $ git cat-file -p HEAD | grep parent
      parent 964810d7331184767b57908f92eb3ca92c48819c
      parent 4dcef0ce5db1797c4a4b1ea61391bfd31b00c535
      ```]),
  )),
  source-de: link("https://git-scm.com/docs/git-merge")[git-merge(1)],
  note: [Entre les deux fusions : git branch -d contact (« Deleted branch contact (was 1420e6a). »), puis git switch -c style, un commit style.css ; retour sur main et un commit sur contact.html (git commit -am, qui indexe les fichiers déjà suivis). « ort » est la stratégie de fusion par défaut depuis Git 2.34. Sans -m, git merge ouvre l’éditeur sur le message « Merge branch 'style' ». -4 limite le log aux quatre derniers commits. Sorties relevées par git/cm/rejouer.sh.],
)

== Conflit : deux modifications de la même ligne <conflit>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Démonstration][
      #terminal(taille: px(19))[
        ```
        # sur la branche titre, commit « Titre personnel » :
        #   sur mon site → chez Ada
        # sur main, commit « Titre collectif » :
        #   sur mon site → sur notre site
        $ git merge titre
        Auto-merging index.html
        CONFLICT (content): Merge conflict in index.html
        Automatic merge failed; fix conflicts and then commit the result.
        $ cat index.html
        <<<<<<< HEAD
        <h1>Bienvenue sur notre site</h1>
        =======
        <h1>Bienvenue chez Ada</h1>
        >>>>>>> titre
        <p>Ceci est un paragraphe.</p>
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la sortie][
      - Git a fusionné ce qu’il pouvait ; il s’arrête sur la ligne modifiée des deux côtés
      - Entre `<<<<<<< HEAD` et `=======` : la version de la branche courante (`main`)
      - Entre `=======` et `>>>>>>> titre` : la version de la branche fusionnée
      - Le reste du fichier est déjà fusionné
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-merge#_how_conflicts_are_presented")[git-merge(1), How conflicts are presented] · #link("https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging")[Pro Git, § 3.2]],
  note: [Les deux commits ont été faits avec sed -i 's/sur mon site/chez Ada/' index.html (sur titre) et sed -i 's/sur mon site/sur notre site/' index.html (sur main), puis git commit -am. Un conflit n’est pas une erreur : Git refuse de choisir à votre place entre deux intentions. Deux modifications de lignes différentes du même fichier ne sont pas en conflit. Sorties relevées par git/cm/rejouer.sh.],
)

== Résoudre un conflit, puis terminer la fusion

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Démonstration][
      #terminal(taille: px(18))[
        ```
        $ git status
        On branch main
        You have unmerged paths.
          (fix conflicts and run "git commit")
          (use "git merge --abort" to abort the merge)

        Unmerged paths:
          (use "git add <file>..." to mark resolution)
                both modified:   index.html

        no changes added to commit (use "git add" and/or "git commit -a")
        # on édite index.html : une seule ligne h1, sans marqueurs
        $ cat index.html
        <h1>Bienvenue chez Ada et ses amis</h1>
        <p>Ceci est un paragraphe.</p>
        $ git add index.html
        # --no-edit : garde le message proposé par Git
        $ git commit --no-edit
        [main 9d21555] Merge branch 'titre'
        ```
      ]
    ],
    bloc(role: "retenir", taille: px(25))[Résoudre en quatre gestes][
      + `git status` : repérer les fichiers en conflit (_both modified_)
      + Éditer chaque fichier : garder, combiner ou réécrire, et retirer les marqueurs
      + `git add` : marquer le fichier comme résolu
      + `git commit` : terminer la fusion ; `git merge --abort` l’annule à la place
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-merge")[git-merge(1)] · #link("https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging")[Pro Git, § 3.2, Basic Merge Conflicts]],
  note: [Les quatre étapes du cours d’origine (identifier, modifier, ajouter, terminer par un commit), avec le conseil d’origine : git status d’abord. La résolution peut ne ressembler à aucune des deux versions : ici, on combine. Le commit de fusion 9d21555 a deux parents, b76f56e (Titre collectif) et a9458a0 (Titre personnel). Outils graphiques : git mergetool, ou l’éditeur (VS Code, IntelliJ…), qui proposent des boutons « accepter l’une, l’autre ou les deux ». Sorties relevées par git/cm/rejouer.sh.],
)

== Rebaser : rejouer ses commits ailleurs <rebasage>

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (px(1060), 1fr), column-gutter: px(40),
    canevas(560, {
      let (m, d1, d2, f) = ((100, 300), (330, 140), (560, 140), (330, 300))
      let (d1b, d2b) = ((560, 300), (790, 300))
      g-commit(..m, [9d21555])
      g-commit(..f, [03bb87d])
      g-parent(f, m)
      uncover("1", {
        g-commit(..d1, [6b5b179], couleur: g-branche)
        g-commit(..d2, [81f39fc], couleur: g-branche)
        g-parent(d1, m)
        g-parent(d2, d1)
        g-pointeurs(..d2, "faq", "HEAD")
      })
      uncover("2-", {
        g-commit(..d1, [6b5b179], fantome: true)
        g-commit(..d2, [81f39fc], fantome: true)
        g-parent(d1, m, tirets: true)
        g-parent(d2, d1, tirets: true)
        g-commit(..d1b, [1754732], couleur: g-branche)
        g-commit(..d2b, [07dafe9], couleur: g-branche)
        g-parent(d1b, f)
        g-parent(d2b, d1b)
      })
      uncover("2", g-pointeurs(..d2b, "faq", "HEAD"))
      uncover("1-2", g-pointeurs(..f, "main", bas: true))
      uncover("3-", {
        g-pointeurs(..d2b, "faq")
        g-pointeurs(..d2b, "main", "HEAD", bas: true)
      })
    }),
    lignes(largeur: px(48), taille-cle: px(26), taille: px(23), uncover: uncover,
      ([1], [`faq` part de `9d21555` ; `main` a avancé depuis]),
      ([2], [`git rebase main` rejoue chaque commit de `faq` au-dessus de `main` : de nouveaux commits, de nouveaux identifiants]),
      ([3], [Sur `main`, `git merge faq` est une avance rapide : l’historique reste une ligne]),
      ([4], [Les anciens commits (en tirets) ne sont plus sur aucune branche ; le _reflog_ les garde un temps]),
    ),
  )
  uncover("5-", note(role: "retenir")[Rebaser réécrit l’historique : même contenu, autres commits. On ne rebase que des commits qui n’ont pas encore été publiés.])
  source[#link("https://git-scm.com/book/en/v2/Git-Branching-Rebasing")[Pro Git, § 3.6 Rebasing] · #link("https://git-scm.com/docs/git-rebase")[git-rebase(1)]]
  utils.speaker-note(self: self)[Un clic par étape. Rebaser (rebase, « changer de base ») : Git calcule les modifications de chaque commit de faq depuis l’ancêtre commun, se place sur main et les réapplique une à une. Les copies ont le même message et le même auteur, mais un autre parent, donc un autre identifiant (diapositive « Un identifiant est l’empreinte du contenu »). Règle d’or de Pro Git : « Do not rebase commits that exist outside your repository and that people may have based work on. » Les commits abandonnés restent accessibles par git reflog (section Annuler) jusqu’à leur nettoyage (git gc ; par défaut, les entrées du reflog qui désignent des commits devenus inaccessibles expirent au bout de 30 jours, les autres au bout de 90).]
})

== Rebaser dans le terminal

#anime(
  terminal-explique(taille: px(19), colonnes: 2,
    ([```
    $ git log --oneline --graph --all -4
    * 81f39fc (faq) Première réponse
    * 6b5b179 Ajout de la FAQ
    | * 03bb87d (HEAD -> main) Adresse du bureau
    |/
    *   9d21555 Merge branch 'titre'
    |\
    ```],
    [```
    $ git switch faq
    Switched to branch 'faq'
    $ git rebase main
    Successfully rebased and updated refs/heads/faq.
    $ git log --oneline --graph --all -4
    * 07dafe9 (HEAD -> faq) Première réponse
    * 1754732 Ajout de la FAQ
    * 03bb87d (main) Adresse du bureau
    *   9d21555 Merge branch 'titre'
    |\
    ```],
    [```
    $ git switch main
    Switched to branch 'main'
    $ git merge faq
    Updating 03bb87d..07dafe9
    Fast-forward
     faq.html | 1 +
     1 file changed, 1 insertion(+)
     create mode 100644 faq.html
    ```]),
    (),
  ),
  source-de: link("https://git-scm.com/docs/git-rebase")[git-rebase(1)],
  note: [-4 : les quatre derniers commits ; le « |\\ » final est le début de la fusion 9d21555, coupée par -4. Pendant le rebasage, Git affiche « Rebasing (1/2) » puis « Rebasing (2/2) » sur la même ligne, que le message final remplace : la ligne ci-dessus est ce qui reste à l’écran. En cas de conflit, le rebasage s’arrête sur le commit en cause : on résout, git add, puis git rebase -\-continue (ou -\-abort pour tout annuler). Mêmes messages et même contenu : seuls les identifiants des deux commits de faq ont changé. Sorties relevées par git/cm/rejouer.sh.],
)

== Fusionner ou rebaser ?

#anime(
  rang(
    bloc(taille: px(26))[Fusionner (`merge`)][
      - Garde l’histoire telle qu’elle s’est déroulée, avec ses branches
      - Ne réécrit rien : sans risque sur des commits publiés
      - Un graphe plus touffu à lire
    ],
    bloc(taille: px(26))[Rebaser (`rebase`)][
      - Une histoire linéaire, plus simple à lire et à parcourir
      - Crée de nouveaux commits : les anciens disparaissent des branches
      - Pour mettre à jour sa propre branche avant de la proposer
    ],
  ),
  rang(bloc(role: "danger", taille: px(26))[Ne rebasez pas des commits déjà publiés][
    - Vos collègues ont les anciens commits : leur prochain `pull` mélange anciens et nouveaux, avec des doublons et des conflits
  ]),
  source-de: link("https://git-scm.com/book/en/v2/Git-Branching-Rebasing")[Pro Git, § 3.6, The Perils of Rebasing ; Rebase vs. Merge],
  note: [Pro Git résume : rebaser ses changements locaux avant de les pousser, pour un historique propre, mais jamais ce qui a été poussé ailleurs. Les équipes fixent leur règle : certaines fusionnent toujours, d’autres rebasent les branches de fonctionnalité puis fusionnent par avance rapide, d’autres font des fusions « écrasées » (squash) depuis l’interface de la forge.],
)

== À vous : une branche, un conflit

#anime(
  rang(bloc(role: "pratique", taille: px(24))[Prérequis][
    - Le dépôt `admin` de l’exercice précédent, sur `main`, avec ses deux commits
  ]),
  rang(bloc(role: "question", taille: px(27))[À vous][
    + Créez la branche `compression` ; remplacez `tar -cf /tmp/etc.tar` par `tar -czf /tmp/etc.tar.gz` et enregistrez un commit
    + Revenez sur `main` ; remplacez `/tmp/etc.tar` par `/srv/etc.tar` et enregistrez un commit. Dessinez le graphe, puis comparez avec `git log --oneline --graph --all`
    + Fusionnez `compression` dans `main`. Que se passe-t-il ? Résolvez en gardant les deux intentions : une archive compressée, dans `/srv`
  ]),
  note: [Exercice à écrire en séance (le cours d’origine ne contenait pas d’exercice de branches). sed -i fait les remplacements, ou un éditeur. Laisser dessiner le graphe à la main avant de le faire afficher. Corrigé sur les deux diapositives suivantes.],
)

== Une branche, un conflit : corrigé (1/2)

#corriges-cote(note: [Un clic par réponse. Les commandes sed font les remplacements demandés ; Vim convient aussi. Identifiants du relevé (git/cm/rejouer.sh, Git 2.43.0) : les vôtres diffèrent.],
  (1, [Branche `compression` : archive compressée],
    reponse(terminal(titre: none, taille: px(18))[```
    $ git switch -c compression
    Switched to a new branch 'compression'
    $ sed -i 's|tar -cf /tmp/etc.tar|tar -czf /tmp/etc.tar.gz|' \
      sauvegarde.sh
    $ git commit -am "Archive compressée"
    [compression a7de27c] Archive compressée
     1 file changed, 1 insertion(+), 1 deletion(-)
    ```])),
  (2, [Sur `main` : archive dans `/srv` ; le graphe],
    reponse(terminal(titre: none, taille: px(18))[```
    $ git switch main
    Switched to branch 'main'
    $ sed -i 's|/tmp/etc.tar|/srv/etc.tar|' sauvegarde.sh
    $ git commit -am "Archive dans /srv"
    [main e59c559] Archive dans /srv
     1 file changed, 1 insertion(+), 1 deletion(-)
    $ git log --oneline --graph --all
    * a7de27c (compression) Archive compressée
    | * e59c559 (HEAD -> main) Archive dans /srv
    |/
    * 87218ff Message de fin
    * d5aaf89 Script de sauvegarde
    ```])),
)

== Une branche, un conflit : corrigé (2/2)

#corriges-cote(note: [La résolution se fait à l’éditeur : on supprime les marqueurs et on écrit la ligne voulue (dans le relevé, un sed le fait). UU dans git status -\-short : modifié des deux côtés, non fusionné. Ensuite, git branch -d compression supprime le pointeur, devenu inutile. Sorties relevées par git/cm/rejouer.sh.],
  (3, [Fusionner `compression` dans `main` : que se passe-t-il ? Résoudre en gardant les deux intentions],
    reponse(grid(columns: (1fr, 1fr), column-gutter: px(24),
      terminal(titre: none, taille: px(18))[```
      $ git merge compression
      Auto-merging sauvegarde.sh
      CONFLICT (content): Merge conflict in sauvegarde.sh
      Automatic merge failed; fix conflicts and then commit the result.
      # conflit : la même ligne, modifiée des deux côtés
      $ git status --short
      UU sauvegarde.sh
      $ cat sauvegarde.sh
      #!/bin/sh
      <<<<<<< HEAD
      tar -cf /srv/etc.tar /etc
      =======
      tar -czf /tmp/etc.tar.gz /etc
      >>>>>>> compression
      echo Sauvegarde terminée
      ```],
      terminal(titre: none, taille: px(18))[```
      # on édite : une seule ligne tar, sans marqueurs
      $ cat sauvegarde.sh
      #!/bin/sh
      tar -czf /srv/etc.tar.gz /etc
      echo Sauvegarde terminée
      $ git add sauvegarde.sh
      $ git commit --no-edit
      [main a83ef73] Merge branch 'compression'
      $ git log --oneline --graph
      *   a83ef73 (HEAD -> main) Merge branch 'compression'
      |\
      | * a7de27c (compression) Archive compressée
      * | e59c559 Archive dans /srv
      |/
      * 87218ff Message de fin
      * d5aaf89 Script de sauvegarde
      ```],
    ))),
)

// ======================================================================
= Dépôts distants

== Un dépôt distant et ses branches de suivi <distants>

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  let depot(x, titre, sous-titre, contenu) = pose(x, 0, block(width: px(560), height: px(270), fill: c.appli,
    radius: px(14), inset: px(18), stack(spacing: px(10),
      align(center, text(size: px(30), weight: 600, titre)),
      align(center, text(size: px(22), fill: c.ardoise, sous-titre)),
      v(px(10)),
      align(center, contenu))))
  canevas(280, {
    depot(0, [Dépôt distant `origin`], [GitHub, GitLab, un serveur, ou un dépôt nu],
      g-etiquette("main"))
    uncover("2-", depot(1104, [Votre dépôt], [un clone complet, sur votre poste],
      stack(spacing: px(14), g-etiquette("main"), g-etiquette("origin/main"))))
    uncover("2-", commande-fleche(560, 1104, 60, [git clone (une fois)]))
    uncover("3-", commande-fleche(560, 1104, 125, [git fetch → origin/main]))
    uncover("4-", commande-fleche(560, 1104, 190, [git pull = fetch + intégration]))
    uncover("5-", commande-fleche(1104, 560, 220, [git push], dessous: true))
  })
  v(px(10))
  lignes(largeur: px(200), taille-cle: px(28), taille: px(24), uncover: uncover, debut: 2,
    ([`clone`], [copie tout le dépôt ; crée `origin` et la branche `main` locale]),
    ([`fetch`], [rapatrie les nouveaux commits ; met à jour `origin/main` seulement]),
    ([`pull`], [`fetch`, puis intègre `origin/main` dans `main` (fusion ou rebasage)]),
    ([`push`], [envoie vos commits ; refusé si le distant a des commits que vous n’avez pas]),
  )
  uncover("6-", note(role: "retenir")[`origin/main` est une branche de suivi : la dernière position connue de `main` sur `origin`. Seuls `fetch`, `pull` et `push` parlent au réseau.])
  source[#link("https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches")[Pro Git, § 3.5 Remote Branches] · #link("https://git-scm.com/docs/git-fetch")[git-fetch(1)] · #link("https://git-scm.com/docs/git-pull")[git-pull(1)]]
  utils.speaker-note(self: self)[Un élément par clic. origin est le nom donné par défaut au dépôt cloné. Un dépôt nu (bare) n’a pas de répertoire de travail : c’est la forme d’un dépôt sur un serveur, et ce qu’on emploie ici pour simuler une forge sans réseau (diapositive suivante). git pull rapatrie puis intègre : avance rapide si possible ; si les deux côtés ont divergé, Git 2.43 exige de choisir fusion ou rebasage (diapositive « Pull sur une histoire divergente »).]
})

== Publier : git remote add, puis git push

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Démonstration][
      #terminal(taille: px(18))[
        ```
        # --bare : dépôt nu, sans répertoire de travail (un serveur)
        $ cd ~
        $ git init --bare -b main depot-central.git
        Initialized empty Git repository in /tmp/git-cours/ada/depot-central.git/
        $ cd mon_projet
        $ git remote add origin ~/depot-central.git
        $ git remote -v
        origin  /tmp/git-cours/ada/depot-central.git (fetch)
        origin  /tmp/git-cours/ada/depot-central.git (push)
        # -u : main suivra désormais origin/main
        $ git push -u origin main
        Enumerating objects: 35, done.
        Counting objects: 100% (35/35), done.
        Delta compression using up to 4 threads
        Compressing objects: 100% (28/28), done.
        Writing objects: 100% (35/35), 3.20 KiB | 1.60 MiB/s, done.
        Total 35 (delta 8), reused 0 (delta 0), pack-reused 0
        To /tmp/git-cours/ada/depot-central.git
         * [new branch]      main -> main
        branch 'main' set up to track 'origin/main'.
        ```
      ]
    ],
    bloc(taille: px(24))[Lire la sortie][
      - `origin` : un nom court pour l’adresse du dépôt distant
      - `Enumerating objects: 35` : tous les blobs, arbres et commits du fil rouge, envoyés compressés
      - `* [new branch] main -> main` : la branche `main` est créée sur le distant
      - Avec une forge, l’adresse est une URL : `git@github.com:ada/site.git` (SSH, _Secure Shell_) ou `https://…`
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-remote")[git-remote(1)] · #link("https://git-scm.com/docs/git-push")[git-push(1)] · #link("https://git-scm.com/book/en/v2/Git-on-the-Server-Getting-Git-on-a-Server")[Pro Git, § 4.2]],
  note: [Le dépôt nu (git init -\-bare) remplace ici GitHub ou GitLab : mêmes commandes, sans compte ni réseau. Les lignes de progression (Enumerating…, Writing…) ne s’affichent que dans un terminal ; débit et nombre de fils (threads) varient d’une machine à l’autre. Authentification sur une forge : de préférence par clé SSH (cours Accès distants) ; en HTTPS, un jeton d’accès remplace le mot de passe sur GitHub et GitLab. Sorties relevées par git/cm/rejouer.sh.],
)

== Cloner, puis publier un commit

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Grace rejoint le projet][
      #terminal(titre: none, taille: px(18))[
        ```
        $ git clone depot-central.git grace
        Cloning into 'grace'...
        done.
        $ cd grace
        # sans --global : identité de ce dépôt seulement
        $ git config user.name "Grace Hopper"
        $ git config user.email grace@example.org
        # -a : branches locales et branches de suivi
        $ git branch -a
        * main
          remotes/origin/HEAD -> origin/main
          remotes/origin/main
        $ echo 'Site de démonstration du cours Git.' > README
        $ git add README
        $ git commit -m "Ajout du README"
        [main 885281c] Ajout du README
         1 file changed, 1 insertion(+)
         create mode 100644 README
        $ git push
        # … (4 lignes de progression)
        To /tmp/git-cours/ada/depot-central.git
           07dafe9..885281c  main -> main
        ```
      ]
    ],
    bloc(taille: px(24))[Lire la sortie][
      - `git clone` a créé `origin` et une branche `main` qui suit `origin/main` : `git push` suffit, sans argument
      - `07dafe9..885281c` : la branche distante passe de l’un à l’autre, par avance rapide
      - `origin/HEAD` : la branche par défaut du distant
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-clone")[git-clone(1)] · #link("https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes")[Pro Git, § 2.5]],
  note: [Grace est simulée dans le même compte : un second clone, avec user.name et user.email fixés dans ce dépôt seulement. Sur une vraie forge : git clone git\@github.com:ada/site.git. Lignes de progression du push omises (voir la diapositive précédente pour leur forme). Sorties relevées par git/cm/rejouer.sh.],
)

== Push refusé : le distant a avancé

#anime(
  terminal-explique(taille: px(18), cle: px(64),
    (
      [```
      # Ada, sans le commit de Grace, enregistre un commit, puis :
      $ git push
      To /tmp/git-cours/ada/depot-central.git
       ! [rejected]        main -> main (fetch first)
      error: failed to push some refs to '/tmp/git-cours/ada/depot-central.git'
      hint: Updates were rejected because the remote contains work that you do not
      hint: have locally. This is usually caused by another repository pushing to
      hint: the same ref. If you want to integrate the remote changes, use
      hint: 'git pull' before pushing again.
      hint: See the 'Note about fast-forwards' in 'git push --help' for details.
      ```],
      [```
      $ git fetch
      # … (5 lignes de progression)
      From /tmp/git-cours/ada/depot-central
         07dafe9..885281c  main       -> origin/main
      $ git log --oneline --graph --all -4
      * edf4af0 (HEAD -> main) Jour d'ouverture
      | * 885281c (origin/main) Ajout du README
      |/
      * 07dafe9 Première réponse
      ```],
    ),
    (
      ([1], [Le distant a un commit qu’Ada n’a pas : pousser l’effacerait, Git refuse]),
      ([2], [`fetch` ne met à jour que `origin/main` : on voit la divergence (un commit de chaque côté) avant de l’intégrer]),
    ),
  ),
  source-de: [#link("https://git-scm.com/docs/git-push#_note_about_fast_forwards")[git-push(1), Note about fast-forwards]],
  note: [Commit d’Ada : echo '\<p\>Ouvert le lundi.\</p\>' >> contact.html, puis git commit -am "Jour d'ouverture". Un push n’est accepté que s’il fait avancer la branche distante (avance rapide). git push -\-force passerait outre et effacerait le commit de Grace du distant : à proscrire sur une branche partagée ; -\-force-with-lease, plus prudent, refuse si le distant a bougé depuis le dernier fetch. Dernier log : 4 commits seulement (-4). git status, à ce moment, dit la même chose en mots : « Your branch and 'origin/main' have diverged, and have 1 and 1 different commits each » (relevé de rejouer.sh). Sorties relevées par git/cm/rejouer.sh.],
)

== Pull sur une histoire divergente

#anime(
  terminal-explique(taille: px(18), cle: px(64),
    (
      [```
      $ git pull
      hint: You have divergent branches and need to specify how to reconcile them.
      hint: You can do so by running one of the following commands sometime before
      hint: your next pull:
      hint:
      hint:   git config pull.rebase false  # merge
      hint:   git config pull.rebase true   # rebase
      hint:   git config pull.ff only       # fast-forward only
      hint:
      # … (4 lignes hint: sur --global et les options de la ligne de commande)
      fatal: Need to specify how to reconcile divergent branches.
      ```],
      [```
      # rejouer le commit local au-dessus de origin/main
      $ git pull --rebase
      Successfully rebased and updated refs/heads/main.
      $ git log --oneline --graph -3
      * 735f248 (HEAD -> main) Jour d'ouverture
      * 885281c (origin/main) Ajout du README
      * 07dafe9 Première réponse
      $ git push
      # … (6 lignes de progression)
      To /tmp/git-cours/ada/depot-central.git
         885281c..735f248  main -> main
      ```],
    ),
    (
      ([1], [Git 2.43 refuse de choisir entre fusion et rebasage : à vous de le dire]),
      ([2], [Rebaser un commit pas encore publié est sans danger : `edf4af0` devient `735f248`, puis le push passe]),
    ),
  ),
  source-de: [#link("https://git-scm.com/docs/git-pull")[git-pull(1)]],
  note: [La règle de git-pull(1), Git 2.43 : si la branche courante est en retard, pull fait une avance rapide ; si les histoires ont divergé, il faut -\-rebase, -\-no-rebase (fusion) ou le réglage pull.rebase. Pour fixer un choix une fois pour toutes : git config -\-global pull.rebase true. Grace, elle, n’a rien de local : son git pull est une avance rapide (Updating 885281c..735f248, Fast-forward). Lignes hint: et de progression abrégées par « \# … » ; texte complet dans le relevé. Sorties relevées par git/cm/rejouer.sh.],
)

// ======================================================================
= Annuler

== Annuler : quelle commande pour quoi ? <annuler>

#anime(
  rang(bloc(taille: px(23))[Selon ce qu’il faut défaire][
    #table(columns: (1.2fr, 1.1fr, 1.4fr), stroke: none, inset: (x: px(10), y: px(8)),
      fill: (x, y) => if y == 0 or calc.even(y) { c.bleu-clair } else { c.fond },
      table.header(..([Défaire…], [Commande], [Effet]).map(t => strong(t))),
      [une modification non indexée], [`git restore f`], [fichier ← index : modification perdue],
      [un `git add`], [`git restore --staged f`], [index ← dernier commit ; fichier intact],
      [un commit déjà publié], [`git revert C`], [un commit de plus, qui défait C],
      [des commits non publiés], [`git reset`], [la branche recule (trois modes)],
      [une erreur de `reset`], [`git reflog`], [les positions passées de `HEAD`],
    )
  ]),
  rang(bloc(role: "danger", taille: px(25))[Attention][
    - `git restore f` et `git reset --hard` effacent des modifications jamais enregistrées : aucune commande ne les rend
  ]),
  source-de: [#link("https://git-scm.com/docs/git#_reset_restore_and_revert")[git(1), Reset, restore and revert] · #link("https://git-scm.com/book/en/v2/Git-Basics-Undoing-Things")[Pro Git, § 2.4]],
  note: [La page git(1) distingue elle-même les trois commandes : restore agit sur des fichiers, revert crée un commit qui défait un autre, reset déplace la branche. Le reflog ne garde que des positions de HEAD, donc des commits : une modification jamais indexée ni enregistrée n’y est pas.],
)

== restore : défaire une modification non enregistrée

#anime(
  rang(
    bloc(role: "pratique", poids: 1.2, taille: px(24))[Démonstration][
      #terminal(taille: px(20))[
        ```
        $ echo '<p>une erreur' >> index.html
        $ git status --short
         M index.html
        # répertoire de travail ← index
        $ git restore index.html
        $ git status --short
        $ echo '<p>une erreur' >> index.html
        $ git add index.html
        $ git status --short
        M  index.html
        # index ← dernier commit ; le fichier garde l’erreur
        $ git restore --staged index.html
        $ git status --short
         M index.html
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la sortie][
      - Après `git restore`, `git status --short` n’affiche rien : le fichier est revenu à la version enregistrée
      - `--staged` défait seulement le `git add` : le `M` repasse de la première à la seconde colonne
      - Un second `git restore index.html` efface ensuite l’erreur du fichier
    ],
  ),
  source-de: link("https://git-scm.com/docs/git-restore")[git-restore(1)],
  note: [Étape 5 du cours d’origine (« ajoutez une erreur… »), faite avec git checkout index.html ; git restore (Git 2.23) en est la forme actuelle, que git status conseille (« use "git restore \<file\>..." to discard changes »). Ancienne forme en annexe. La sortie vide de git status -\-short est réelle : rien à signaler. Sorties relevées par git/cm/rejouer.sh.],
)

== revert : annuler en ajoutant un commit

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Démonstration][
      #terminal(taille: px(19))[
        ```
        # un bandeau publié par erreur
        $ echo '<p>Promotion : -50 % ce jour</p>' >> index.html
        $ git commit -am "Bandeau de promotion"
        [main c6ea6bb] Bandeau de promotion
         1 file changed, 1 insertion(+)
        $ git push
        # … (progression, puis 735f248..c6ea6bb  main -> main)
        # --no-edit : message proposé par Git ; HEAD : le dernier commit
        $ git revert --no-edit HEAD
        [main 5fb152b] Revert "Bandeau de promotion"
         Date: Wed Nov 25 10:00:00 2026 +0100
         1 file changed, 1 deletion(-)
        $ git log --oneline -3
        5fb152b (HEAD -> main) Revert "Bandeau de promotion"
        c6ea6bb (origin/main) Bandeau de promotion
        735f248 Jour d'ouverture
        $ git push
        # … (progression, puis c6ea6bb..5fb152b  main -> main)
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la sortie][
      - Rien n’est supprimé : un nouveau commit défait les lignes du commit visé
      - Le push passe : `revert` fait avancer la branche, sans réécrire l’historique
      - L’historique garde la trace de l’erreur et de sa correction
    ],
  ),
  source-de: link("https://git-scm.com/docs/git-revert")[git-revert(1)],
  note: [Étapes 6 et 7 du cours d’origine. Le cours d’origine désignait le commit par son identifiant complet ; HEAD (ou HEAD\~1, HEAD\~2… pour les précédents) se recopie tel quel chez vous. Un revert défait tous les fichiers du commit visé, pas seulement un. La ligne « Date: » est réelle : git revert affiche la date d’auteur du nouveau commit. Revert d’un commit de fusion : il faut dire quel parent garder (-m 1). Sorties relevées par git/cm/rejouer.sh ; lignes de progression du push abrégées.],
)

== reset : trois modes <reset-modes>

#anime(
  rang(bloc(taille: px(25))[`git reset <commit>` : la branche courante recule jusqu’à `<commit>`, puis…][
    #table(columns: (0.9fr, 1fr, 1fr, 1.6fr), stroke: none, inset: (x: px(10), y: px(8)),
      fill: (x, y) => if y == 0 or calc.even(y) { c.bleu-clair } else { c.fond },
      table.header(..([Mode], [Index], [Répertoire de travail], [Les modifications des commits défaits]).map(t => strong(t))),
      [`--soft`], [inchangé], [inchangé], [restent indexées : prêtes pour un nouveau commit],
      [`--mixed` (défaut)], [remis à `<commit>`], [inchangé], [restent dans les fichiers, non indexées],
      [`--hard`], [remis à `<commit>`], [remis à `<commit>`], [sont effacées],
    )
  ]),
  rang(
    bloc(role: "retenir", taille: px(25))[À retenir][
      - Les trois modes déplacent la branche ; ils diffèrent par les zones qu’ils remettent à l’état de `<commit>`
    ],
    bloc(role: "danger", taille: px(25))[Danger][
      - `--hard` efface aussi les modifications non enregistrées du répertoire de travail
      - Sur des commits publiés, `reset` réécrit l’historique des autres : préférez `revert`
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-reset")[git-reset(1)] · #link("https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified")[Pro Git, § 7.7 Reset Demystified]],
  note: [Lecture de git-reset(1), Git 2.43 : -\-soft « does not touch the index file or the working tree at all » ; -\-mixed « resets the index but not the working tree », c’est l’action par défaut ; -\-hard « resets the index and working tree ». Pro Git § 7.7 raconte la même chose en trois temps : déplacer la branche (soft), puis mettre à jour l’index (mixed), puis le répertoire de travail (hard). Les autres modes (-\-merge, -\-keep) sortent du cadre du cours. git reset fichier (sans mode) est une autre forme : elle équivaut à git restore -\-staged fichier.],
)

== reset : un même commit, trois fois

#anime(
  terminal-explique(taille: px(19), cle: px(140), decalage: 1, colonnes: 2,
    (
      [```
      $ echo '<p>Brouillon</p>' >> contact.html
      $ git commit -am "Brouillon"
      [main fc5e14d] Brouillon
       1 file changed, 1 insertion(+)
      ```],
      [```
      # HEAD~1 : le parent de HEAD
      $ git reset --soft HEAD~1
      $ git status --short
      M  contact.html
      $ git commit -m "Brouillon"
      [main fc5e14d] Brouillon
       1 file changed, 1 insertion(+)
      ```],
      [```
      $ git reset HEAD~1
      Unstaged changes after reset:
      M       contact.html
      $ git status --short
       M contact.html
      $ git commit -am "Brouillon"
      [main fc5e14d] Brouillon
       1 file changed, 1 insertion(+)
      ```],
      [```
      $ git reset --hard HEAD~1
      HEAD is now at 5fb152b Revert "Bandeau de promotion"
      $ git status --short
      $ tail -1 contact.html
      <p>Ouvert le lundi.</p>
      ```],
    ),
    (
      ([`--soft`], [modification encore indexée (`M` à gauche)]),
      ([`--mixed`], [modification dans le fichier, plus dans l’index (`M` à droite)]),
      ([`--hard`], [plus rien : le paragraphe a disparu du fichier]),
    ),
  ),
  source-de: link("https://git-scm.com/docs/git-reset")[git-reset(1)],
  note: [Un clic par mode. Même contenu, même parent, même auteur, même date (fixée par le relevé) : le commit refait a le même identifiant, fc5e14d, preuve qu’un identifiant ne dépend que du contenu de l’objet. Chez vous, la date change d’une seconde à l’autre, donc l’identifiant aussi. HEAD\~1 se recopie tel quel, contrairement à un identifiant. Sorties relevées par git/cm/rejouer.sh.],
)

== reflog : retrouver un commit « perdu »

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Démonstration][
      #terminal(taille: px(19))[
        ```
        # les dernières positions de HEAD, la plus récente en haut
        $ git reflog -4
        5fb152b (HEAD -> main, origin/main) HEAD@{0}: reset: moving to HEAD~1
        fc5e14d HEAD@{1}: commit: Brouillon
        5fb152b (HEAD -> main, origin/main) HEAD@{2}: reset: moving to HEAD~1
        fc5e14d HEAD@{3}: commit: Brouillon
        # HEAD@{1} : la position précédente
        $ git reset --hard HEAD@{1}
        HEAD is now at fc5e14d Brouillon
        $ tail -1 contact.html
        <p>Brouillon</p>
        ```
      ]
    ],
    bloc(taille: px(25))[Lire la sortie][
      - Chaque changement de `HEAD` (commit, `reset`, `switch`, `rebase`…) ajoute une ligne
      - Un commit « défait » par `reset` existe encore : le reflog donne son identifiant
      - Le reflog est local : il n’est ni poussé ni cloné
    ],
  ),
  source-de: [#link("https://git-scm.com/docs/git-reflog")[git-reflog(1)] · #link("https://git-scm.com/book/en/v2/Git-Internals-Maintenance-and-Data-Recovery")[Pro Git, § 10.7 Data Recovery]],
  note: [Les quatre lignes viennent de la diapositive précédente (reset -\-soft, commit, reset -\-mixed, commit, reset -\-hard). Les entrées du reflog expirent : 90 jours par défaut (gc.reflogExpire), 30 jours pour les commits qui ne sont plus sur aucune branche (gc.reflogExpireUnreachable). Une modification jamais enregistrée n’y figure pas. Après cette démonstration, le relevé refait git reset -\-hard HEAD\~1 pour revenir à 5fb152b. Sorties relevées par git/cm/rejouer.sh.],
)

== À vous : annuler de trois façons

#anime(
  rang(bloc(role: "pratique", taille: px(24))[Prérequis][
    - Le dépôt `admin` après la fusion de l’exercice précédent
  ]),
  rang(bloc(role: "question", taille: px(26))[À vous][
    + Ajoutez à `sauvegarde.sh` une ligne fautive, `tar -cf /tmp/home.tar /hoem` ; constatez-la avec `git diff`, puis annulez-la sans commit
    + Ajoutez la ligne `logger Sauvegarde faite`, enregistrez le commit « Journalisation », puis annulez-le avec `git revert`. Observez l’historique : que constatez-vous ?
    + Revenez au commit de fusion avec `git reset --hard`, sans recopier d’identifiant. Observez l’historique : que constatez-vous ?
    + Quelle différence entre `revert` et `reset` ? Comment retrouver le commit « Journalisation » ?
  ]),
  note: [Étapes 5 à 10 du cours d’origine, transposées au dépôt admin, plus la question du reflog. Laisser chercher ; corrigé sur les deux diapositives suivantes.],
)

== Annuler de trois façons : corrigé (1/2)

#corriges-cote(note: [Un clic par réponse. Identifiants du relevé (git/cm/rejouer.sh, Git 2.43.0) : les vôtres diffèrent.],
  (1, [Une ligne fautive, annulée sans commit],
    reponse(terminal(titre: none, taille: px(18))[```
    $ echo 'tar -cf /tmp/home.tar /hoem' >> sauvegarde.sh
    $ git diff
    diff --git a/sauvegarde.sh b/sauvegarde.sh
    index 152a3bd..adac2a0 100644
    --- a/sauvegarde.sh
    +++ b/sauvegarde.sh
    @@ -1,3 +1,4 @@
     #!/bin/sh
     tar -czf /srv/etc.tar.gz /etc
     echo Sauvegarde terminée
    +tar -cf /tmp/home.tar /hoem
    $ git restore sauvegarde.sh
    $ git status --short
    ```])),
  (2, [« Journalisation », puis `git revert` : que constatez-vous ?],
    reponse(terminal(titre: none, taille: px(18))[```
    $ echo 'logger Sauvegarde faite' >> sauvegarde.sh
    $ git commit -am "Journalisation"
    [main 738cc5e] Journalisation
     1 file changed, 1 insertion(+)
    $ git revert --no-edit HEAD
    [main 5e94ad6] Revert "Journalisation"
     Date: Wed Nov 25 10:00:00 2026 +0100
     1 file changed, 1 deletion(-)
    $ git log --oneline -3
    5e94ad6 (HEAD -> main) Revert "Journalisation"
    738cc5e Journalisation
    a83ef73 Merge branch 'compression'
    # → le commit annulé reste ; un commit s’ajoute
    ```])),
)

== Annuler de trois façons : corrigé (2/2)

#corriges-cote(note: [Après le revert, HEAD\~1 est « Journalisation » et HEAD\~2 le commit de fusion : on désigne un commit par sa position, qui ne dépend pas de la machine. Pour récupérer « Journalisation » : git reset -\-hard 738cc5e, ou git switch -c journal 738cc5e pour le garder sur une branche à part. Réponse 4 : formulation du cours d’origine. Dernière ligne du reflog coupée (« Merge… ») : en entier, « commit (merge): Merge branch 'compression' ». Sorties relevées par git/cm/rejouer.sh.],
  (3, [Retour au commit de fusion avec `reset --hard` : que constatez-vous ?],
    reponse(terminal(titre: none, taille: px(18))[```
    $ git reset --hard HEAD~2
    HEAD is now at a83ef73 Merge branch 'compression'
    $ git log --oneline -2
    a83ef73 (HEAD -> main) Merge branch 'compression'
    e59c559 Archive dans /srv
    # → les deux commits ont disparu de l’historique de main
    ```])),
  (4, [`revert` ou `reset` ? Retrouver « Journalisation »],
    reponse(stack(spacing: px(10),
      text(size: px(22))[`revert` crée un commit qui défait un autre, sans toucher à l’historique ; `reset` déplace la branche et réécrit l’historique : destructeur, à réserver aux commits non publiés.],
      terminal(titre: none, taille: px(17))[```
      $ git reflog -4
      a83ef73 (HEAD -> main) HEAD@{0}: reset: moving to HEAD~2
      5e94ad6 HEAD@{1}: revert: Revert "Journalisation"
      738cc5e HEAD@{2}: commit: Journalisation
      a83ef73 (HEAD -> main) HEAD@{3}: commit (merge): Merge…
      # → 738cc5e : le commit à retrouver
      ```]))),
)

// ======================================================================
= En équipe

== Branches et demandes de fusion <demande-de-fusion>

#slide(repeat: 7, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1fr, px(720)), column-gutter: px(40),
    lignes(largeur: px(64), taille-cle: px(30), taille: px(24), uncover: uncover,
      ([1], [Partir d’un `main` à jour : `git switch main`, `git pull`]),
      ([2], [Une branche par sujet : `git switch -c horaires`, des commits]),
      ([3], [La publier : `git push -u origin horaires`]),
      ([4], [Ouvrir une demande de fusion sur la forge : _pull request_ (GitHub), _merge request_ (GitLab)]),
      ([5], [Relecture par un collègue et tests automatiques (intégration continue) ; nouveaux commits si besoin]),
      ([6], [Fusion dans `main` par la forge, puis suppression de la branche]),
    ),
    uncover("3-", terminal(taille: px(18))[
      ```
      $ git switch -c horaires
      Switched to a new branch 'horaires'
      $ echo '<p>De 9 h à 17 h.</p>' >> contact.html
      $ git commit -am "Horaires d'ouverture"
      [horaires 5e2d708] Horaires d'ouverture
       1 file changed, 1 insertion(+)
      $ git push -u origin horaires
      # … (6 lignes de progression)
      To /tmp/git-cours/ada/depot-central.git
       * [new branch]      horaires -> horaires
      branch 'horaires' set up to track 'origin/horaires'.
      ```
    ]),
  )
  uncover("7-", note(role: "retenir")[`main` ne reçoit que du travail relu, et passé par les tests automatiques ; personne n’y pousse directement. La forge peut l’imposer (branche protégée).])
  source[#link("https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests")[GitHub Docs, About pull requests] · #link("https://docs.gitlab.com/user/project/merge_requests/")[GitLab Docs, Merge requests]]
  utils.speaker-note(self: self)[Une étape par clic ; le terminal montre les étapes 2 et 3 du fil rouge. La demande de fusion n’est pas une commande Git : c’est une fonction de la forge (GitHub, GitLab, Forgejo), qui montre les différences, recueille les commentaires et lance l’intégration continue (GitHub Actions, GitLab CI). Sur une forge, git push d’une nouvelle branche répond en général par un lien pour ouvrir la demande : sortie à rejouer sur une forge réelle, le relevé n’emploie qu’un dépôt nu. Ce flux est souvent appelé « GitHub flow ». Bonnes pratiques du cours d’origine : une branche par fonctionnalité ou correctif, git pull régulier, intégration continue.]
})

== Bonnes pratiques

#anime(
  rang(
    bloc(role: "pratique", taille: px(25))[Des commits utiles][
      - Petits et fréquents : un commit, un changement cohérent
      - Un message qui dit pourquoi : une ligne de résumé (une cinquantaine de caractères), puis un paragraphe si besoin
      - `git diff --staged` avant chaque commit : relire ce qu’on enregistre
    ],
    bloc(role: "pratique", taille: px(25))[À plusieurs][
      - Une branche par fonctionnalité ou correctif, fusionnée par demande de fusion
      - `git pull` avant de commencer : moins de conflits
      - Ne jamais réécrire (`reset`, `rebase`, `push --force`) une branche partagée
    ],
  ),
  rang(bloc(role: "avertissement", taille: px(25))[Ce qui ne va pas dans un dépôt][
    - Mots de passe, clés, jetons : dans un gestionnaire de secrets, jamais dans l’historique
    - Fichiers produits (binaires, journaux, archives) : ils se régénèrent ; `.gitignore`, diapositive suivante
  ]),
  source-de: [#link("https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project")[Pro Git, § 5.2 Contributing to a Project (Commit Guidelines)] · #link("https://git-scm.com/docs/git-commit#_discussion")[git-commit(1), Discussion]],
  note: [Pro Git § 5.2 recommande une ligne de résumé d’environ 50 caractères, une ligne vide, puis une explication ; git-commit(1) conseille aussi moins de 50 caractères pour la première ligne. Bonnes pratiques du cours d’origine : commits fréquents et descriptifs, branches pour les nouvelles fonctionnalités, git pull régulier, intégration continue (GitLab CI, GitHub Actions, Jenkins) ; et pour l’administration système, Git avec Ansible pour des configurations cohérentes (cours Ansible).],
)

== .gitignore : ne pas suivre ce qui ne doit pas l’être <gitignore>

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  let b-demo = bloc(role: "pratique", taille: px(24))[Démonstration][
    #terminal(titre: none, taille: px(19))[
      ```
      $ touch acces.log
      $ mkdir -p secrets
      $ echo "mot-de-passe" > secrets/bdd.txt
      $ git status --short
      ?? acces.log
      ?? secrets/
      # on écrit .gitignore (ci-contre), puis :
      $ git status --short
      ?? .gitignore
      # quelle règle ignore quel fichier ?
      $ git check-ignore -v acces.log secrets/bdd.txt
      .gitignore:2:*.log      acces.log
      .gitignore:4:secrets/   secrets/bdd.txt
      $ git add .gitignore
      $ git commit -m "Fichiers à ignorer"
      [main 8f76f98] Fichiers à ignorer
       1 file changed, 4 insertions(+)
       create mode 100644 .gitignore
      ```
    ]
  ]
  let b-fichier = bloc(taille: px(23))[`.gitignore`][
    #terminal(titre: none, taille: px(19))[```
    # journaux
    *.log
    # jamais de secret dans le dépôt
    secrets/
    ```]
    - Un motif par ligne ; `#` : commentaire ; `/` final : un répertoire
    - Il se versionne : ses règles valent pour toute l’équipe
  ]
  let b-danger = bloc(role: "danger", taille: px(23))[Attention][
    - Un fichier déjà suivi le reste : `git rm --cached` l’en retire
    - Un secret déjà publié reste dans l’historique : changez-le
  ]
  grid(columns: (1.3fr, 1fr), column-gutter: px(32),
    bloc-anime(b-demo, 1, uncover),
    stack(spacing: px(20), bloc-anime(b-fichier, 2, uncover), bloc-anime(b-danger, 4, uncover)),
  )
  source[#link("https://git-scm.com/docs/gitignore")[gitignore(5)] · #link("https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository")[GitHub Docs, Removing sensitive data]]
  utils.speaker-note(self: self)[Le contenu de .gitignore est écrit par printf dans le relevé (git/cm/rejouer.sh) ; cat .gitignore donne les quatre lignes ci-contre. .gitignore n’agit que sur les fichiers non suivis. Le dossier secrets/ est un exemple d’école : la bonne pratique est de garder les secrets hors du répertoire du projet (gestionnaire de secrets, Ansible Vault, variables d’environnement de l’intégration continue). git rm -\-cached fichier retire le fichier de l’index sans l’effacer du disque ; il reste dans les commits passés. Réécrire tout l’historique (git filter-repo) est possible mais lourd : GitHub recommande d’abord de révoquer le secret. Sorties relevées par git/cm/rejouer.sh.]
})

// ======================================================================
= Annexes

== Ancienne syntaxe : git checkout fait tout

#anime(
  rang(bloc(taille: px(26))[Avant Git 2.23 (2019), une seule commande pour deux métiers][
    #table(columns: (1.2fr, 1fr, 1fr), stroke: none, inset: (x: px(10), y: px(8)),
      fill: (x, y) => if y == 0 or calc.even(y) { c.bleu-clair } else { c.fond },
      table.header(..([Pour…], [Forme actuelle], [Ancienne forme]).map(t => strong(t))),
      [changer de branche], [`git switch main`], [`git checkout main`],
      [créer une branche et s’y placer], [`git switch -c contact`], [`git checkout -b contact`],
      [défaire une modification], [`git restore f`], [`git checkout -- f`],
      [défaire un `git add`], [`git restore --staged f`], [`git reset f`],
    )
  ]),
  rang(bloc(role: "precaution", taille: px(26))[Précaution][
    - `git checkout x` change de branche si `x` est une branche, et écrase le fichier `x` si c’est un fichier : d’où le `--` et la séparation en deux commandes
  ]),
  source-de: [#link("https://git-scm.com/docs/git-checkout")[git-checkout(1)] · #link("https://git-scm.com/docs/git-switch")[git-switch(1)] · #link("https://git-scm.com/docs/git-restore")[git-restore(1)]],
  note: [Le cours d’origine employait git checkout index.html. Les tutoriels et beaucoup de scripts emploient encore checkout, qui reste disponible. git checkout \<commit\> place HEAD sur un commit, hors de toute branche (« detached HEAD ») : hors du cadre de ce cours.],
)

== Rejouer le cours à l’identique

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Mêmes identifiants que les diapositives][
      #terminal(taille: px(20))[
        ```
        # un dossier personnel jetable : ~/.gitconfig n’est pas lu
        $ export HOME="$(mktemp -d)"
        $ cd
        # la même date pour chaque commit
        $ export GIT_AUTHOR_DATE="2026-11-25T10:00:00+01:00"
        $ export GIT_COMMITTER_DATE="2026-11-25T10:00:00+01:00"
        # puis toutes les commandes du cours, dans l’ordre,
        # en commençant par la diapositive « Installer Git… »
        $ git config --global user.name "Ada Lovelace"
        ```
      ]
    ],
    bloc(taille: px(25))[Pourquoi ça marche][
      - Un identifiant est l’empreinte du contenu, de l’auteur, de la date et du parent
      - Mêmes fichiers, mêmes commandes, même date : mêmes objets, donc mêmes identifiants
      - Le script `git/cm/rejouer.sh` du dépôt des supports refait tout le cours ainsi
    ],
  ),
  source-de: link("https://git-scm.com/docs/git-commit-tree#_commit_information")[git-commit-tree(1), Commit Information],
  note: [rejouer.sh fixe aussi GIT\_CONFIG\_NOSYSTEM=1 (ignorer /etc/gitconfig) et LC\_ALL=C (messages en anglais), et se lance dans un pseudo-terminal pour afficher ce qu’affiche un terminal. Seul l’ordre des commandes compte : sautez-en une, et les identifiants suivants changent. Grace garde son identité, fixée par git config dans son clone : les variables ne fixent que les dates. Fermer le terminal remet HOME à sa valeur.],
)

== Sans -b main : la branche master et des conseils

#anime(
  rang(
    bloc(role: "pratique", poids: 2.3, taille: px(24))[Git 2.43, sans réglage][
      #terminal(titre: none, taille: px(18))[
        ```
        $ git init sans-config
        hint: Using 'master' as the name for the initial branch. This default branch name
        hint: is subject to change. To configure the initial branch name to use in all
        hint: of your new repositories, which will suppress this warning, call:
        hint:
        hint:   git config --global init.defaultBranch <name>
        hint:
        hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
        hint: 'development'. The just-created branch can be renamed via this command:
        hint:
        hint:   git branch -m <name>
        Initialized empty Git repository in /tmp/git-cours/ada/sans-config/.git/
        ```
      ]
    ],
    bloc(taille: px(25))[Deux remèdes][
      - Une fois par poste : `git config --global init.defaultBranch main`
      - Ou à chaque dépôt : `git init -b main`, la forme de ce cours
    ],
  ),
  source-de: link("https://git-scm.com/docs/git-init")[git-init(1)],
  note: [L’avertissement annonce lui-même que le nom par défaut peut changer. GitHub et GitLab nomment main la branche par défaut des nouveaux dépôts. Sortie relevée par git/cm/rejouer.sh (tabulations des lignes de commande remplacées par deux espaces).],
)

== Sources

#anime(
  rang(bloc(taille: px(26))[Documentation de référence][
    - _Pro Git_, Scott Chacon et Ben Straub, 2#super[e] édition, libre (CC BY-NC-SA) : #link("https://git-scm.com/book/fr/v2")[git-scm.com/book/fr/v2] (français), #link("https://git-scm.com/book/en/v2")[git-scm.com/book/en/v2]
    - Pages de manuel de Git, `man git-<commande>` ou `git help <commande>` : #link("https://git-scm.com/docs")[git-scm.com/docs] ; version employée : 2.43.0
    - GitHub Docs et GitLab Docs, pour les demandes de fusion : #link("https://docs.github.com/en/pull-requests")[docs.github.com] · #link("https://docs.gitlab.com/user/project/merge_requests/")[docs.gitlab.com]
  ]),
  rang(bloc(role: "pratique", taille: px(26))[Pour s’exercer][
    - _Learn Git Branching_, branches et fusions en images : #link("https://learngitbranching.js.org/?locale=fr_FR")[learngitbranching.js.org]
    - Toutes les sorties de ce cours : `git/cm/rejouer.sh`, dans le dépôt des supports
  ]),
  note: [Liens donnés sur les diapositives au fil du cours ; les sections de Pro Git citées sont celles de l’édition anglaise en ligne. Supports d’origine de l’auteur : diapositives « Outils de l’administration système », partie 2, section Git.],
)

// ======================================================================
= Pour rappel

== Pour rappel · liste non exhaustive

#anime(
  rang(bloc(role: "retenir", taille: px(25))[L’essentiel du cours][
    - Trois zones : répertoire de travail → `git add` → index → `git commit` → dépôt
    - Un commit est un instantané, désigné par l’empreinte de son contenu, qui pointe vers son ou ses parents
    - Une branche est un pointeur mobile ; `HEAD` désigne la branche courante
    - Fusion : avance rapide, ou commit à deux parents ; un conflit se résout à la main, puis `add` et `commit`
    - Rebaser rejoue des commits ailleurs, avec de nouveaux identifiants : jamais sur ce qui est publié
    - `fetch` rapatrie, `pull` rapatrie et intègre, `push` publie s’il fait avancer la branche distante
    - Annuler : `restore` (fichiers), `revert` (ajoute un commit), `reset --soft | --mixed | --hard` (recule), `reflog` (retrouve)
    - En équipe : une branche par sujet, une demande de fusion, un `.gitignore`, aucun secret
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

#cloture(illustration: "couches")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
