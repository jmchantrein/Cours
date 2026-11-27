// Page de cours du module 1 du cours « Shell » : « Se repérer dans l’arborescence » (shell/progression.yaml, module arbo).
// Une page de cours se suit à son rythme, les mains sur le terminal : une notion, la commande qui la montre, un clic,
// le résultat dans le terminal à côté, ce qu’il faut y regarder. Voir commun/README.md, « Pages web : pages de cours ».
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/pages/arbo/arbo.typ shell/pages/arbo/index.html
// Sorties : celles de la VM du terminal (Alpine, compte ada), où commun/terminal/tester-vm.mjs rejoue chaque commande
// de la page, dans l’ordre, et compare sa sortie à celle de la page et le repère de contexte déclaré au réel.
// Mêmes commandes et même arborescence que le diaporama du module (shell/cm/arbo.typ) et le TP premiers-pas (étapes
// 2 et 4) : celle que crée shell/tp/premiers-pas/preparer.sh sous ~/atelier.

#import "../../../commun/theme-tp.typ": *

#let diaporama = "../../cm/arbo-projection.pdf"
#let tp = "../../tp/premiers-pas/index.html"
#let preparer = "https://jmchantrein.github.io/Cours/shell/tp/premiers-pas/preparer.sh"

// L’arborescence de la VM que la page parcourt : la racine, et ~/atelier tel que preparer.sh le crée.
#let at = "/home/ada/atelier/"
#let arbre = (
  ..("bin", "dev", "etc", "home", "lib", "media", "mnt", "opt", "proc", "root", "run", "sbin", "srv", "sys", "tmp",
    "usr", "var").map(d => "/" + d + "/"),
  "/init", "/tmp/.", "/home/ada/.",
  "/home/ada/preparer.sh",
  ..(".reglages", "pionnieres.csv", "journaux/serveur-2025-novembre.log", "journaux/serveur-2026-novembre.log",
    "notes/a-faire.txt", "notes/idees.txt", "notes/lisezmoi.txt", "projets/scripts/bonjour.sh", "projets/site/index.html",
    "vieux/brouillon-1.txt", "vieux/brouillon-2.txt").map(f => at + f),
)

#show: page-web.with(
  titre: [Se repérer dans l’arborescence],
  surtitre: [Shell : Bash, sed et awk · module 1 · page de cours],
  sous-titre: [Où suis-je, que contient ce répertoire, comment aller ailleurs],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tube",
  cours: true,
  terminal: ("vm", "compagnon"),
  contexte: (compte: "ada", depart: "/home/ada", personnel: "/home/ada", arbre: arbre,
    creations: (("wget ", ("/home/ada/preparer.sh",)), ("bash preparer.sh", ("/home/ada/atelier/",)))),
  liens: (
    ([Diaporama du module], diaporama),
    ([TP : Premiers pas dans le shell], tp),
  ),
)

= Avant de commencer <avant>

Cette page se suit à votre rythme, les mains sur le terminal. Chaque commande a un bouton *Exécuter* : un clic
l’écrit et la lance dans le terminal, à côté du texte. Au-dessus du terminal, le repère *Où vous êtes* dessine
l’arborescence et le répertoire où vous êtes ; avec la VM, il est lu dans la VM après chaque commande.

#bloc(role: "pratique")[Pour commencer][
  - Dans la colonne de droite, cliquez sur *Démarrer la VM* : une VM Linux démarre dans le navigateur, sous le compte
    `ada`, en une vingtaine de secondes. Sur un petit écran, le terminal s’ouvre en bas (bouton *Terminal*).
  - Cliquez ensuite les commandes dans l’ordre de la page. Vous pouvez aussi taper les vôtres : le repère suit.
]

#bloc(role: "question")[Ce que vous savez déjà][
  Dans `ls -a notes`, qu’est-ce qui est la commande, l’option, l’argument ?
  #corrige(titre: [Réponse])[
    `ls` est la commande, `-a` une option (elle commence par un tiret), `notes` un argument. Une hésitation ? C’est le
    module 0, « Le terminal, le shell, la commande » : voyez la diapo
    #diapo("../../cm/shell-projection.pdf", "ligne-de-commande")[Lire une ligne de commande] et l’étape 1 du
    #link(tp + "#etape-1")[TP Premiers pas].
  ]
]

= Préparer le terrain <terrain>

Toute la page explore la même arborescence d’exemple, celle du TP. Ces deux commandes la créent : la première
télécharge un script, la seconde le lance. Vous n’avez pas besoin d’en savoir plus pour la suite.

#terminal[```console
$ wget https://jmchantrein.github.io/Cours/shell/tp/premiers-pas/preparer.sh
$ bash preparer.sh
Dossier de travail prêt : /home/ada/atelier
Pour y entrer : cd /home/ada/atelier
```]
#regardez[*Dans le repère*, sous `ada/`, apparaissent `preparer.sh` après le premier clic, puis `atelier/` après le
second, avec ce qu’il contient.]

#note(role: "precaution")[
  Avec le compagnon (votre propre shell), le script refuse d’écraser un `atelier` qui existe déjà : c’est le cas si
  vous avez fait le TP. Votre compte remplace alors `ada`, et le repère décrit la VM, pas votre machine.
]

= Des répertoires dans des répertoires <arborescence>

Les fichiers sont rangés dans des *répertoires* (des dossiers), qui contiennent eux-mêmes des fichiers et d’autres
répertoires : une *arborescence*. Tout part d’un répertoire unique, la *racine*, qui s’écrit `/`. La commande `ls`
(_list_) affiche ce que contient le répertoire qu’on lui donne en argument :

#terminal[```console
$ ls /
bin  dev  etc  home  init  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```]
#regardez[*Dans le repère*, la racine `/` est en tête : ses noms sont ceux que `ls` affiche. Deux nous servent :
`home`, qui contient un répertoire par compte, et `tmp`, pour les fichiers temporaires.]

= Le répertoire courant : pwd <pwd>

Le shell travaille toujours *dans* un répertoire : le *répertoire courant*. C’est là qu’agit une commande à qui l’on ne
dit pas où agir. `pwd` (_print working directory_) l’affiche :

#terminal[```console
$ pwd
/home/ada
```]
#regardez[*Dans le repère*, les pastilles lisent ce chemin depuis la racine : `/` puis #pastille(1) `home`, #pastille(2) `ada`,
séparés par `/`. Le répertoire courant porte « vous êtes ici ».]

À l’ouverture d’un terminal, le shell part du *répertoire personnel* du compte : `/home/ada` pour `ada`. Le repère
le marque `~`, son abréviation, que l’on retrouvera plus bas.

= Ce que contient un répertoire : ls, ls -a <ls>

Sans argument, `ls` liste le répertoire courant ; avec un répertoire en argument, il liste celui-là, sans y aller :

#terminal[```console
$ ls
atelier  preparer.sh
$ ls atelier
journaux  notes  pionnieres.csv  projets  vieux
```]

#predire[
  Le repère montre dans `atelier/` un nom en italique gris que `ls atelier` n’affiche pas. Que montrera `ls -a atelier`
  de plus que `ls atelier` ?
][#terminal[```console
$ ls -a atelier
.  ..  .reglages  journaux  notes  pionnieres.csv  projets  vieux
```]][
  L’option `-a` (_all_) montre aussi les noms *cachés*, ceux qui commencent par un point : `.reglages`, que le repère
  écrit en gris. `.` et `..` sont dans tout répertoire : `.` désigne le répertoire lui-même, `..` son parent, un cran
  plus haut. Ils serviront dans les chemins.
]

= Changer de répertoire courant : cd <cd>

`cd` (_change directory_) change le répertoire courant. Il n’affiche rien quand il réussit : c’est `pwd`, ou le repère,
qui le montre.

#terminal[```console
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
l’étiquette « avant ». *Dans le terminal*, l’invite le rappelle aussi : `ada@cours:~/atelier/notes$`.]

#terminal[```console
$ cd lisezmoi.txt
bash: cd: lisezmoi.txt: Not a directory
```]
#regardez[`cd` n’entre que dans un répertoire : sur un fichier, il refuse, et le répertoire courant ne change pas.]

= Un chemin relatif part du répertoire courant <relatif>

Un *chemin* enchaîne des noms séparés par `/`. Sans `/` en tête, il est *relatif* : il se lit depuis le répertoire
courant. `atelier`, puis `notes`, étaient déjà des chemins relatifs, d’un seul nom.

#predire[
  Vous êtes dans `notes`. Où mène `cd ../projets/site` ? Suivez-le dans le repère avant de cliquer : `..` remonte d’un
  cran.
][#terminal[```console
$ cd ../projets/site
$ pwd
/home/ada/atelier/projets/site
```]][
  #pastille(1) `..` remonte de `notes` dans `atelier`, #pastille(2) on descend dans `projets`, #pastille(3) puis dans `site` : le repère numérote chaque
  pas, depuis le *départ*, le répertoire courant.
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
#regardez[*Dans le repère*, le départ est la racine `/`, puis une pastille par nom : même arrivée que tout à l’heure,
par un autre chemin.]

#bloc(role: "retenir")[Relatif ou absolu][
  - *Relatif* (`../projets/site`) : depuis le répertoire courant ; court, mais il dépend de l’endroit où l’on est.
  - *Absolu* (`/home/ada/atelier/projets/site`) : depuis la racine ; il mène au même endroit d’où qu’on parte.
]

= `.` et `..` : ici, et un cran plus haut <points>

`ls -a` les montrait dans tout répertoire : `.` est le répertoire lui-même, `..` son parent. Dans un chemin, `..`
remonte d’un cran ; `.` ne bouge pas.

#terminal[```console
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
  #pastille(1) `..` remonte dans `projets`, #pastille(2) `..` dans `atelier`, #pastille(3) on descend dans `journaux`, dont `ls` affiche les deux
  journaux.
]

#terminal[```console
$ cd ../..
$ pwd
/home/ada/atelier
```]

#predire[
  Vous êtes dans `atelier`. Que désigne `notes/../projets/./site` ? Que va afficher `ls` ?
][#terminal[```console
$ ls notes/../projets/./site
index.html
```]][
  #pastille(1) on entre dans `notes`, #pastille(2) `..` en ressort, #pastille(3) on entre dans `projets`, #pastille(4) `.` y reste, #pastille(5) puis `site` : c’est
  `projets/site` par un détour, et `ls` affiche son contenu, `index.html`.
]

= `~`, `cd` seul, `cd -` <retours>

`~` est l’abréviation du répertoire personnel : le shell la remplace par son chemin absolu avant de lancer la
commande. `echo` le montre, puisqu’il affiche ses arguments :

#terminal[```console
$ echo ~
/home/ada
$ cd ~/atelier/notes
```]
#regardez[*Dans le repère*, `~` part du répertoire personnel, marqué `~` : `~/atelier/notes` est un chemin absolu.]

Deux retours rapides : `cd -` ramène au répertoire précédent (et l’affiche), `cd` sans argument au répertoire
personnel.

#terminal[```console
$ cd /tmp
$ pwd
/tmp
$ cd -
/home/ada/atelier/notes
$ cd
$ pwd
/home/ada
```]
#regardez[*Dans le repère*, « vous êtes ici » saute de `notes` à `/tmp`, hors du répertoire personnel, revient dans
`notes`, puis remonte à `~`.]

= Pour la suite <suite>

#bloc(role: "retenir")[À retenir][
  - L’arborescence part de la racine `/` ; le shell est toujours dans un répertoire, le répertoire courant (`pwd`).
  - `ls` montre un répertoire sans y aller ; `-a` ajoute les noms cachés, et `.` et `..`.
  - `cd chemin` change de répertoire courant ; `cd -` revient au précédent, `cd` seul au répertoire personnel `~`.
  - Un chemin absolu commence par `/` ; un chemin relatif se lit depuis le répertoire courant ; `..` remonte, `.` reste.
]

#bloc(role: "pratique")[S’exercer][
  - Le TP #link(tp + "#etape-2")[Premiers pas dans le shell], étapes 2 (se repérer) et 4 (se déplacer), dans le même
    `atelier`.
  - Le #link(diaporama)[diaporama du module], et son exercice « Où arrive-t-on ? ».
  - Module suivant : regarder et agir sur des fichiers (`cat`, `head`, `cp`, `mv`…), dans ce même atelier.
]
