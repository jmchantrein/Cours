// Page de cours du module 1 du cours « Fondements de l’administration système GNU/Linux » (dossier shell/) :
// « Se repérer dans l’arborescence » (shell/progression.yaml, module arbo).
// Une page de cours se suit à son rythme, les mains sur le terminal : une notion, la commande qui la montre, un clic,
// le résultat dans le terminal à côté, ce qu’il faut y regarder. Voir commun/README.md, « Pages web : pages de cours ».
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/pages/arbo/arbo.typ shell/pages/arbo/index.html
// Les exemples sont ceux du diaporama du module (shell/cm/arbo.typ), dans le même ordre ; la page y ajoute la pratique.
// Sorties : celles de la VM du terminal (Alpine, compte ada), où commun/terminal/tester-vm.mjs rejoue chaque commande
// de la page, dans l’ordre, depuis l’état de départ, et compare sa sortie à celle de la page et le repère de contexte
// déclaré au réel. État de départ : ~/atelier, créé par shell/tp/premiers-pas/preparer.sh (celui du TP).

#import "../../../commun/theme-tp.typ": *

#let diaporama = "../../cm/arbo-projection.pdf"
#let tp = "../../tp/premiers-pas/index.html"

// L’arborescence de la VM que la page parcourt : la racine, et ~/atelier tel que preparer.sh le crée.
#let at = "/home/ada/atelier/"
#let arbre = (
  ..("bin", "dev", "etc", "home", "lib", "media", "mnt", "opt", "proc", "root", "run", "sbin", "srv", "sys", "tmp",
    "usr", "var").map(d => "/" + d + "/"),
  "/init", "/tmp/.",
  ..(".reglages", "pionnieres.csv", "journaux/serveur-2025-novembre.log", "journaux/serveur-2026-novembre.log",
    "notes/a-faire.txt", "notes/idees.txt", "notes/lisezmoi.txt", "projets/scripts/bonjour.sh", "projets/site/index.html",
    "vieux/brouillon-1.txt", "vieux/brouillon-2.txt").map(f => at + f),
)

#show: page-web.with(
  titre: [Se repérer dans l’arborescence],
  surtitre: [Fondements de l’administration système GNU/Linux · module 1 · page de cours],
  sous-titre: [Où suis-je, que contient ce répertoire, comment aller ailleurs],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tube",
  cours: true,
  terminal: ("vm", "compagnon"),
  depart: (script: "shell/tp/premiers-pas/preparer.sh", cree: "~/atelier", ici: "~"),
  contexte: (compte: "ada", depart: "/home/ada", personnel: "/home/ada", arbre: arbre),
  liens: (
    ([Diaporama du module], diaporama),
    ([TP : Premiers pas dans le shell], tp),
  ),
)

= Avant de commencer <avant>

Cette page reprend les exemples du #link(diaporama)[diaporama du module], à suivre à votre rythme, les mains sur le
terminal. Chaque commande a un bouton *Exécuter* : un clic l’écrit et la lance dans le terminal, à côté du texte.
Au-dessus du terminal, le repère *Où vous êtes* dessine l’arborescence et le répertoire où vous êtes ; avec la VM,
il est lu dans la VM après chaque commande.

#bloc(role: "pratique")[Pour commencer][
  - Dans la colonne de droite, cliquez sur *Démarrer la VM* : une VM Linux démarre dans le navigateur, sous le compte
    `ada`, avec l’arborescence d’exemple déjà en place dans `~/atelier`. Sur un petit écran, le terminal s’ouvre en
    bas (bouton *Terminal*).
  - Cliquez les commandes dans l’ordre de la page. Vous pouvez aussi taper les vôtres : le repère suit. Tout cassé ?
    *Remettre à l’état de départ* redémarre la VM, et vous repartez du début de la page.
]

#bloc(role: "question")[Ce que vous savez déjà][
  Dans `ls -a notes`, qu’est-ce qui est la commande, l’option, l’argument ?
  #corrige(titre: [Réponse])[
    `ls` est la commande, `-a` une option, `notes` un argument. Une hésitation ? C’est le module 0, « Le terminal,
    le shell, la commande » : voyez la diapo
    #diapo("../../cm/shell-projection.pdf", "ligne-de-commande")[Lire une ligne de commande] et l’étape 1 du
    #link(tp + "#etape-1")[TP Premiers pas]. Ce que fait `-a`, et ce qu’est `notes`, c’est l’objet de cette page.
  ]
]

= Des répertoires dans des répertoires <arborescence>

Un *répertoire* contient des fichiers et d’autres répertoires : une *arborescence*, qui part d’un répertoire unique,
la *racine*, écrite `/`. La commande `ls` (_list_) affiche ce que contient le répertoire qu’on lui donne :

#terminal[```console
$ ls /
bin  dev  etc  home  init  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```]
#regardez[*Dans le repère*, la racine `/` est en tête : ses noms sont ceux que `ls` affiche. Deux nous servent :
`home`, un répertoire par compte, dont `ada`, et `tmp`, pour les fichiers temporaires.]

#note(role: "precaution")[La VM est une Alpine Linux : sa racine diffère un peu de celle d’un Debian, montrée dans
les diapos (`boot`, `lib64` y figurent ; `init` est propre à la VM).]

= Le répertoire courant : pwd <pwd>

Le shell travaille toujours *dans* un répertoire, le *répertoire courant* : c’est là qu’agissent les commandes.
`pwd` (_print working directory_) l’affiche :

#terminal[```console
$ pwd
/home/ada
```]
#regardez[*Dans le repère*, les pastilles lisent ce chemin depuis la racine : `/`, puis #pastille(1) `home`,
#pastille(2) `ada`. Ce chemin part de la racine ; le répertoire courant porte « vous êtes ici ».]

À l’ouverture d’un terminal, le shell part du *répertoire personnel* du compte : `/home/ada` pour `ada`. On l’abrège
`~` : le repère le marque ainsi.

= Ce que contient un répertoire : ls, ls -a <ls>

Sans argument, `ls` montre le contenu du répertoire courant ; avec un répertoire en argument, celui de ce
répertoire, sans y aller :

#terminal[```console
$ ls
atelier
$ ls atelier
journaux  notes  pionnieres.csv  projets  vieux
```]

#predire[
  Dans `atelier/`, le repère montre un nom en italique gris que `ls atelier` n’affiche pas. Que montrera
  `ls -a atelier` de plus ?
][#terminal[```console
$ ls -a atelier
.  ..  .reglages  journaux  notes  pionnieres.csv  projets  vieux
```]][
  `-a` (_all_) montre aussi les noms *cachés*, qui commencent par un point : `.reglages`. Un fichier caché n’a rien
  de secret : `ls` le tait par défaut. `.` et `..` sont dans tout répertoire ; ils reviennent plus bas.
]

= Changer de répertoire courant : cd <cd>

`cd` (_change directory_) change le répertoire courant. Il n’affiche rien quand il réussit : `pwd`, ou le repère, le
montre.

#terminal[```console
$ pwd
/home/ada
$ cd atelier
$ pwd
/home/ada/atelier
$ cd notes
$ pwd
/home/ada/atelier/notes
$ ls
a-faire.txt  idees.txt  lisezmoi.txt
```]
#regardez[*Dans le repère*, « vous êtes ici » descend d’un cran à chaque `cd`, et l’ancien répertoire garde
l’étiquette « avant ». `ls` montre désormais `notes`. *Dans le terminal*, l’invite le rappelle aussi :
`ada@cours:~/atelier/notes$`.]

= Un chemin relatif part du répertoire courant <relatif>

Un chemin enchaîne des noms séparés par `/`. Sans `/` en tête, il est *relatif* : il se lit depuis le répertoire
courant, une branche par nom.

#predire[
  Depuis `~`, on entre dans `atelier/notes`. Où mène ensuite `cd ../projets/site` ? Cherchez-le dans le repère
  (`..` remonte d’un cran), puis cliquez : le repère trace le chemin, pas à pas.
][#terminal[```console
$ cd
# retour au répertoire personnel, d’où partent les diapos (cd seul : expliqué plus bas)
$ cd atelier/notes
$ cd ../projets/site
$ pwd
/home/ada/atelier/projets/site
```]][
  #pastille(1) `..` remonte de `notes` dans `atelier`, #pastille(2) on descend dans `projets`, #pastille(3) puis
  dans `site` : `pwd` le confirme.
]

= Un chemin absolu part de la racine <absolu>

Un chemin qui commence par `/` est *absolu* : il part de la racine, et désigne le même endroit quel que soit le
répertoire courant. `pwd` en affiche un.

#terminal[```console
$ cd /home/ada/atelier/notes
$ cd /home/ada/atelier/projets/site
$ pwd
/home/ada/atelier/projets/site
```]
#regardez[*Dans le repère*, le départ est la racine `/`, puis une pastille par nom : le même répertoire que tout à
l’heure, d’où qu’on parte.]

= `.` et `..` : ici, et un cran plus haut <points>

`.` désigne le répertoire lui-même, `..` son parent ; `ls -a` les montre dans tout répertoire.

#terminal[```console
$ cd
# retour au répertoire personnel, d’où partent les diapos
$ cd atelier/projets/site
$ ls -a
.  ..  index.html
$ ls ..
scripts  site
```]
#regardez[`ls ..` liste le parent de `site`, `projets`, sans changer de répertoire : « vous êtes ici » reste sur `site`.]

#predire[
  Toujours dans `site` : que liste `ls ../../journaux` ?
][#terminal[```console
$ ls ../../journaux
serveur-2025-novembre.log  serveur-2026-novembre.log
```]][
  #pastille(1) `..` remonte dans `projets`, #pastille(2) `..` dans `atelier`, #pastille(3) on descend dans
  `journaux`.
]

= `~`, `cd` seul, `cd -` <retours>

Bash remplace `~` par le répertoire personnel avant de lancer la commande ; `echo`, qui affiche ses arguments, le
montre. `cd -` revient au répertoire précédent (et l’affiche), `cd` seul au répertoire personnel.

#terminal[```console
$ echo ~
/home/ada
$ cd ~/atelier/notes
$ cd /tmp
$ pwd
/tmp
$ cd -
/home/ada/atelier/notes
$ cd
$ pwd
/home/ada
```]
#regardez[*Dans le repère*, `~/atelier/notes` part du répertoire personnel, marqué `~` : un chemin absolu, abrégé.
Puis « vous êtes ici » saute à `/tmp`, hors du répertoire personnel, revient dans `notes`, et remonte à `~`.]

= À vous : où arrive-t-on ? <exercice>

L’exercice du diaporama, à faire dans l’ordre : prédisez chaque réponse en suivant les branches dans le repère, puis
cliquez. On part de `notes` :

#terminal[```console
$ cd ~/atelier/notes
```]

#predire[`cd ../projets/scripts` : dans quel répertoire est-on ?][#terminal[```console
$ cd ../projets/scripts
$ pwd
/home/ada/atelier/projets/scripts
```]][#pastille(1) remonter dans `atelier`, #pastille(2) #pastille(3) descendre dans `projets`, puis `scripts`.]

#predire[Puis `cd ../..` : et maintenant ?][#terminal[```console
$ cd ../..
$ pwd
/home/ada/atelier
```]][Deux crans plus haut : `projets`, puis `atelier`.]

#predire[Puis `ls ./vieux` : qu’affiche-t-il ?][#terminal[```console
$ ls ./vieux
brouillon-1.txt  brouillon-2.txt
```]][`./vieux` : `vieux`, depuis ici ; `.` ne bouge pas.]

#predire[Puis `cd -` : où revient-on ?][#terminal[```console
$ cd -
/home/ada/atelier/projets/scripts
```]][Au répertoire d’avant `cd ../..`, que `cd -` affiche.]

#predire[Depuis `~/atelier`, que désigne `notes/../projets/./site` ?][#terminal[```console
$ cd ~/atelier
$ ls notes/../projets/./site
index.html
```]][
  #pastille(1) on entre dans `notes`, #pastille(2) on en ressort, #pastille(3) on entre dans `projets`,
  #pastille(4) on y reste (`.`), #pastille(5) puis `site` : c’est `projets/site`, par un détour.
]

= Pour la suite <suite>

#bloc(role: "retenir")[À retenir][
  #table(columns: (auto, 1fr),
    [*Commande*], [*Effet*],
    [`pwd`], [affiche le répertoire courant],
    [`ls`, `ls rep`], [le contenu du répertoire courant, ou de `rep`],
    [`ls -a`], [aussi les noms cachés (et `.`, `..`)],
    [`cd chemin`], [change de répertoire courant],
    [`cd -`, `cd`], [répertoire précédent ; répertoire personnel],
  )
  #table(columns: (auto, 1fr),
    [*Écriture*], [*Désigne*],
    [`/`], [la racine ; en tête de chemin : chemin absolu],
    [`~`], [le répertoire personnel (`/home/ada`)],
    [`.`, `..`], [ce répertoire ; son parent],
    [`a/b`], [chemin relatif : depuis le répertoire courant],
  )
]

#bloc(role: "pratique")[S’exercer][
  - Le TP #link(tp + "#etape-2")[Premiers pas dans le shell], étapes 2 (se repérer) et 4 (se déplacer), dans le même
    `atelier`, avec d’autres exemples.
  - Module suivant : « Regarder et agir sur des fichiers », dans ce même atelier.
]
