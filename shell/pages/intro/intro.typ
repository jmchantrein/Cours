// Page de cours du module 0 du cours « Fondements de l’administration système GNU/Linux » (dossier shell/) :
// « Le terminal, le shell, la commande » (shell/progression.yaml, module intro). La toute première page de l’étudiant.
// Une page de cours se suit à son rythme, les mains sur le terminal : voir commun/README.md, « Pages web : pages de cours ».
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/pages/intro/intro.typ shell/pages/intro/index.html
// Les exemples sont ceux du diaporama du module (shell/cm/intro.typ, rejoués par shell/cm/rejouer-intro.sh), dans le
// même ordre ; la page y ajoute la pratique. commun/terminal/tester-vm.mjs rejoue chaque commande dans une VM neuve et
// compare sa sortie à celle de la page (l’heure : sa forme ; le manuel : rien).
// Pas de repère de contexte : l’arborescence est l’objet du module suivant (arbo).

#import "../../../commun/theme-tp.typ": *

#let diaporama = "../../cm/intro-projection.pdf"
// Numéros et titres des modules : lus dans l’index du cours (un module inséré renumérote la page).
#let index = yaml("../../progression.yaml")
#let ici = module-de(index, "intro")
#let mod(id) = module-de(index, id)
// Un module se rejoint par la page du cours, où sont ses supports.
#let vers(id) = "../../index.html#" + id

#show: page-web.with(
  titre: [Le terminal, le shell, la commande],
  surtitre: [#index.titre · module #ici.numero · page de cours],
  sous-titre: [Taper une commande, la lire, se faire aider],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tube",
  cours: true,
  terminal: ("vm", "compagnon"),
  depart: (ici: "~"),
  liens: (
    ([Diaporama du module], diaporama),
    ([Le cours], "../../index.html"),
    ([Module suivant : #mod(ici.suivant).titre], vers(ici.suivant)),
  ),
)

= Avant de commencer <avant>

À droite (en bas sur un petit écran), un *terminal* : une fenêtre où l’on tape des commandes, reliée ici à une
machine Linux qui tourne dans votre navigateur. Cliquez sur *Démarrer la VM* ; ensuite, chaque commande de la page a
un bouton *Exécuter* qui l’écrit et la lance dans le terminal, et vous pouvez aussi cliquer dans le terminal et taper
vous-même, puis #touche[Entrée].

#note(role: "pratique")[Rien ne peut casser : cette machine n’existe que dans votre onglet. Si vous êtes perdu,
*Remettre à l’état de départ* (au-dessus du terminal) la redémarre telle qu’au début.]

Cette page reprend les exemples du #link(diaporama)[diaporama du module], dans le même ordre.

= Pourquoi la ligne de commande <pourquoi>

Une démonstration, pour commencer : une seule ligne crée douze répertoires, un par séance. Vous saurez la lire au
module #mod("expansions").numero ; ici, regardez seulement ce qu’elle fait.

#terminal[```console
$ mkdir -p semestre/seance-{01..12}
$ ls semestre
seance-01  seance-03  seance-05  seance-07  seance-09  seance-11
seance-02  seance-04  seance-06  seance-08  seance-10  seance-12
```]
#regardez[*Dans le terminal*, douze noms, écrits par une seule ligne. La ligne se relit, se corrige, se rejoue :
demain, ou sur dix machines, c’est la même. Un serveur n’a ni écran ni souris : on l’administre ainsi.]

= Une fenêtre de terminal <terminal>

Le *terminal* affiche une *invite* et attend : le *shell*, ici Bash, lit ce que vous tapez, le fait exécuter, puis
rend l’invite. Première commande : qui suis-je ?

#terminal[```console
$ whoami
ada
```]
#regardez[*Dans le terminal*, l’invite `ada@cours:~$` se lit morceau par morceau : `ada`, le compte, qui tape ;
`cours`, la machine ; `~`, où l’on est (le module #mod("arbo").numero en parlera) ; `$`, un compte ordinaire (`#` pour root,
l’administrateur). Après l’invite, la commande tapée ; dessous, sa réponse : `ada`.]

= De la frappe au résultat <frappe>

Tapez-la cette fois vous-même : cliquez dans le terminal, tapez `whoami`, puis #touche[Entrée].

#terminal[```console
$ whoami
ada
```]
#regardez[*Dans le terminal*, trois temps : la ligne tapée, la réponse du programme `whoami`, puis l’invite qui
revient : le shell attend la commande suivante.]

= Lire une ligne de commande <ligne-de-commande>

Une ligne de commande se lit en mots, séparés par des espaces : la *commande*, puis ses *options* (qui commencent par
`-`), puis ses *arguments* (ce sur quoi elle porte).

#terminal[```console
$ date -u +%H:%M
# l’heure universelle (UTC) à cet instant, sous la forme HH:MM : 17:31 sur la diapo, autre chose chez vous
```]
#regardez[`date` est la commande ; `-u`, une option (l’heure universelle, UTC) ; `+%H:%M`, un argument (le format :
heures, deux-points, minutes). *Dans le terminal*, la réponse a cette forme.]

= Une option peut prendre un argument <option-argument>

Certaines options attendent leur propre argument. `-d` attend une date : ici le 9 décembre 1906, naissance de Grace
Hopper, officière de la marine des États-Unis, qui écrit en 1952 le premier compilateur, A-0, et inspire le langage
COBOL. `+%A` demande le jour de la semaine :

#terminal[```console
$ date -d 1906-12-09 +%A
Sunday
$ date --date=1906-12-09 +%A
Sunday
```]
#regardez[La même option, en version courte (`-d 1906-12-09`) puis longue (`--date=1906-12-09`) : même réponse, un
dimanche.]

= Les guillemets : un texte, un seul argument <guillemets>

#predire[
  Les espaces séparent les arguments. Que va afficher `echo Grace     Hopper`, avec ses espaces en trop ? Et la même
  ligne entre guillemets ?
][#terminal[```console
$ echo Grace     Hopper
Grace Hopper
$ echo "Grace     Hopper"
Grace     Hopper
```]][
  Sans guillemets, `echo` reçoit deux arguments, `Grace` et `Hopper`, qu’il affiche séparés d’une espace : les
  espaces en trop ont disparu avant même son lancement. Entre guillemets, il en reçoit un seul, espaces comprises.
]

= Le clavier du shell <clavier>

Ici, pas de bouton : la *complétion* et l’*historique* se font au clavier. Cliquez dans le terminal, puis :

+ Tapez `whoa` (sans Entrée), puis #touche[Tab] : un seul nom de commande commence par `whoa`, la ligne devient
  `whoami`. Validez par #touche[Entrée].
+ Tapez `who`, puis #touche[Tab] : rien ne change, plusieurs noms commencent par `who`. Un second #touche[Tab] les
  montre : `who`, `whoami`, `whois`. Effacez la ligne (#touche[Ctrl+C]).
+ Appuyez sur #touche[↑] : la commande précédente revient (l’historique) ; #touche[Entrée] la relance.
+ #touche[Ctrl+R], puis tapez `date` : la dernière ligne qui contient `date` revient ; #touche[Entrée] la relance,
  #touche[Ctrl+C] abandonne.

#regardez[*Dans le terminal*, chaque touche change la ligne en cours, avant même Entrée : c’est le shell qui écrit
pour vous.]

= Se documenter : man, `--help`, type, help <documentation>

Personne ne retient toutes les options. `type` dit ce qu’est une commande : interne au shell, ou un programme sur le
disque.

#terminal[```console
$ type cd
cd is a shell builtin
$ type whoami
whoami is hashed (/usr/bin/whoami)
```]
#regardez[`whoami` est un programme, `/usr/bin/whoami`. Le mot _hashed_ vient de ce que vous l’avez déjà lancé plus
haut : Bash a mémorisé où il l’a trouvé. Dans un terminal neuf, `type` répond `whoami is /usr/bin/whoami`, comme sur
la diapo.]

Une commande interne se documente avec `help` :

#terminal[```console
$ help -d cd
cd - Change the shell working directory.
```]

Un programme a son manuel. `man date` l’affiche à la place des lignes du terminal : les flèches avancent, #touche[q]
rend l’invite.

#terminal[```console
$ man date
```]
#regardez[*Dans le terminal*, `NAME` dit ce que fait la commande ; `SYNOPSIS`, comment l’écrire (entre crochets, le
facultatif). Appuyez sur #touche[q] pour revenir à l’invite.]

L’aide courte d’un programme : `--help`.

#terminal[```console
$ whoami --help
Usage: whoami [OPTION]...
Print the user name associated with the current effective user ID.
Same as id -un.

      --help        display this help and exit
      --version     output version information and exit

GNU coreutils online help: <https://www.gnu.org/software/coreutils/>
Report any translation bugs to <https://translationproject.org/team/>
Full documentation <https://www.gnu.org/software/coreutils/whoami>
or available locally via: info '(coreutils) whoami invocation'
```]

= À vous : qu’affiche-t-on ? combien d’arguments ? <exercice>

L’exercice du diaporama : prédisez, puis cliquez. Le 10 décembre 1815 est la naissance d’Ada Lovelace, qui publie
en 1843 les notes où figure le premier programme destiné à une machine.

#predire[`echo Ada     Lovelace` : qu’affiche-t-il ?][#terminal[```console
$ echo Ada     Lovelace
Ada Lovelace
```]][Deux arguments, séparés d’une espace.]

#predire[`echo "Ada     Lovelace"` : et celui-ci ?][#terminal[```console
$ echo "Ada     Lovelace"
Ada     Lovelace
```]][Un seul argument, espaces comprises.]

#predire[Dans `date -d 1815-12-10 +%A`, combien d’arguments reçoit `date` ? Lesquels ?][#terminal[```console
$ date -d 1815-12-10 +%A
Sunday
```]][Trois : `-d`, `1815-12-10` et `+%A`. Les options comptent parmi les arguments que reçoit le programme ; `-d`
prend `1815-12-10` pour lui.]

#predire[`type echo` : commande interne ou programme ?][#terminal[```console
$ type echo
echo is a shell builtin
```]][Interne : sa documentation est `help echo`.]

= Pour la suite <suite>

#bloc(role: "retenir")[À retenir][
  - Le terminal affiche l’invite ; le shell (Bash) lit la ligne, la fait exécuter, rend l’invite.
  - Une ligne : la commande, ses options (`-u`, `--date=…`), ses arguments ; une option peut prendre le sien.
  - Les espaces séparent les arguments ; entre guillemets, un texte reste un seul argument.
  - #touche[Tab] complète, #touche[↑] et #touche[Ctrl+R] rappellent l’historique, #touche[Ctrl+C] abandonne.
  - `type` : interne (`help`) ou programme (`man`, `--help`).
]

#bloc(role: "pratique")[Ensuite][
  - Le #link(diaporama)[diaporama du module].
  - Module suivant : #link(vers(ici.suivant))[#mod(ici.suivant).titre] ; tous les modules : #link("../../index.html")[le cours].
]
