// TP « Du pipeline au script robuste » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/tp/scripts/scripts.typ build/shell/scripts.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.
// Sorties : rejouées dans un conteneur debian:13-slim (bash 5.2.37, coreutils de Debian 13, bats 1.11.1,
// ShellCheck 0.10.0), locale C.UTF-8 : messages des outils en anglais.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/shell-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Du pipeline au script robuste],
  surtitre: [Shell : Bash, sed et awk · travaux pratiques],
  sous-titre: [Un pipeline sur le fichier du cours, puis des scripts qui reçoivent des arguments, rendent un code
    de sortie par erreur, passent ShellCheck et sont testés par Bats],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tube",
  terminal: ("vm", "compagnon"),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/shell/tp/scripts/corrige"),
    ([Manuel de Bash], "https://www.gnu.org/software/bash/manual/"),
  ),
)

= Avant de commencer <avant>

Le cours a écrit des pipelines sur `pionnieres.csv` (#d("exercice-tubes")[À vous : deux pipelines]), puis deux
scripts, `liste_fichiers.bash` et `copie_fichiers.bash` (#d("exercice-scripts")[À vous : deux scripts]). Ce TP
reprend ces deux scripts et les rend robustes : arguments plutôt que saisie, un code de sortie par erreur,
`set -euo pipefail`, relecture par ShellCheck, tests automatiques avec Bats, puis une fonction `main`. Les tests
écrits à l’étape 7 servent de filet à l’étape 8 : on restructure le script, les tests disent s’il fait toujours la
même chose.

#bloc(role: "pratique")[Prérequis][
  - Un terminal Bash : celui de la page, ou le vôtre (Debian, Ubuntu, WSL). Les étapes 6 à 8 demandent les paquets
    `shellcheck` et `bats` : `sudo apt install shellcheck bats` sous Debian ou Ubuntu. Dans le terminal de cette
    page, `bats` est installé ; `shellcheck` n’existe pas pour la VM (Alpine x86) : il demande le compagnon.
  - Un éditeur de texte pour écrire les scripts : `nano`, `vim`, ou celui de votre choix.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification : ShellCheck, puis les 15 tests Bats de l’étape 7, dans un conteneur
  Debian 13. Les sorties montrées viennent de Debian 13 (bash 5.2, Bats 1.11, ShellCheck 0.10), en anglais ; sur un
  système en français, les messages de `cut`, `mkdir` ou `cp` sont traduits.
]

= Étape 1 : préparer l’atelier <etape-1>

#bloc(role: "question")[Consignes][
  - Créez le répertoire `~/tp-scripts/donnees/` et placez-vous dans `~/tp-scripts` : tout le TP s’y déroule.
  - Recréez-y les deux fichiers du cours, `donnees/pionnieres.csv` (#d("fil-rouge")[Le fil rouge]) et
    `donnees/services.conf`, avec les commandes ci-dessous.
  - Vérifiez : 9 lignes pour le premier, 15 pour le second.
]

#terminal[```console
$ mkdir -p ~/tp-scripts/donnees
$ cd ~/tp-scripts
$ printf '%s\n' 'nom;annee;domaine;contribution' \
  'Lovelace Ada;1843;programmation;premier programme publié' \
  "Booth Kathleen;1947;langages;premier langage d'assemblage" \
  'Hopper Grace;1952;langages;premier compilateur A-0' \
  'Johnson Katherine;1962;calcul;trajectoires de Friendship 7' \
  "Hamilton Margaret;1969;logiciel;logiciel embarqué d'Apollo 11" \
  'Conway Lynn;1978;materiel;révolution VLSI' \
  'Perlman Radia;1985;reseau;protocole spanning tree' \
  'Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste' \
  > donnees/pionnieres.csv
$ printf '%s\n' '# Services gérés (fichier d’exemple de l’atelier)' \
  '[web]' \
  'port = 8080' \
  'user = www-data' \
  'autostart = yes' \
  '' \
  '[base_de_donnees]' \
  'port = 5432' \
  'user = postgres' \
  'autostart = yes' \
  '' \
  '[sauvegarde]' \
  'port = 0' \
  'user = backup' \
  'autostart = no' \
  > donnees/services.conf
$ wc -l donnees/pionnieres.csv donnees/services.conf
  9 donnees/pionnieres.csv
 15 donnees/services.conf
 24 total
```]

#note[`printf '%s\n'` écrit chacun de ses arguments suivi d’un saut de ligne ; l’antislash en fin de ligne
continue la commande sur la ligne suivante. Les lignes qui contiennent une apostrophe sont entre guillemets
doubles : #d("guillemets")[Les guillemets décident des expansions]. Les deux fichiers sont aussi dans les
corrigés : #link("corrige/donnees/pionnieres.csv")[`pionnieres.csv`],
#link("corrige/donnees/services.conf")[`services.conf`].]

= Étape 2 : trois pipelines, puis un script <etape-2>

#bloc(role: "question")[Consignes][
  En un pipeline chacun, sur `donnees/pionnieres.csv`, sans compter la ligne d’en-tête :
  + le nombre de pionnières par domaine, du domaine le plus fréquent au moins fréquent ;
  + la contribution la plus ancienne (l’année la plus petite), sa ligne entière ;
  + la colonne 1 de `donnees/pionnieres.csv` *et* de `donnees/absent.csv`, qui n’existe pas : la sortie standard
    dans `noms.txt`, l’erreur standard dans `erreurs.txt`. Que vaut le code de retour ? Combien de lignes compte
    `noms.txt` ?
  Rangez enfin les trois pipelines dans un script `pipelines.sh`, exécutable.
]

#indice(titre: [Indice : les commandes])[
  `tail -n +2` saute l’en-tête ; `cut -d';' -f3` extrait la colonne 3 ; `uniq -c` compte les lignes identiques
  *consécutives* (d’où un `sort` avant) ; `sort -rn` trie numériquement, en ordre décroissant.
  `sort -t';' -k2,2n` trie sur la colonne 2 seulement, comme des nombres. Les commandes du cours :
  #d("tubes")[Le tube branche une sortie sur une entrée].
]
#indice(titre: [Indice : deux flux de sortie])[
  `>` redirige la sortie standard (flux 1), `2>` l’erreur standard (flux 2) :
  #d("redirections")[Rediriger vers un fichier]. `$?` vaut le code de retour de la dernière commande :
  #d("codes-retour")[Code de retour : && et ||].
]

#corrige[
  #f("pipelines.sh")
  #terminal[```console
  $ chmod u+x pipelines.sh
  $ ./pipelines.sh
        2 langages
        1 reseau
        1 programmation
        1 materiel
        1 logiciel
        1 cryptographie
        1 calcul
  Lovelace Ada;1843;programmation;premier programme publié
  code de retour de cut : 1
  9
  cut: donnees/absent.csv: No such file or directory
  ```]
  `cut` traite les fichiers qu’il peut lire et signale les autres sur l’erreur standard : `noms.txt` reçoit les
  9 lignes de `pionnieres.csv` (en-tête compris), `erreurs.txt` le message, et le code de retour vaut 1 : un
  fichier au moins a manqué. À égalité de compte, `sort -rn` range les domaines dans l’ordre inverse de
  l’alphabet. `-k2,2n` limite la clé de tri à la colonne 2 ; `-k2 -n` (la forme du cours) donne ici le même
  résultat, car la clé commence par l’année et le tri numérique s’arrête au premier `;`.
]

= Étape 3 : liste_fichiers.bash <etape-3>

#bloc(role: "question")[Consignes][
  - Écrivez `liste_fichiers.bash` : il demande le chemin d’un répertoire, puis affiche « Fichier : … » pour chacun
    de ses fichiers ; si le répertoire n’existe pas, il le dit sur l’erreur standard et sort avec le code 1.
  - Rendez-le exécutable, puis lancez-le sur `donnees`, puis sur `/nulle/part`, en donnant la réponse sans la
    taper : `<<<`. Affichez le code de retour après chaque exécution.
  - Prouvez que le message d’erreur part bien sur l’erreur standard.
]

#indice(titre: [Indice : le squelette])[
  Shebang, `chmod u+x`, `./` : #d("script-executable")[Un script : shebang, droit x, ./]. `read -r` lit une
  ligne de l’entrée standard ; `[ -d "$repertoire" ]` teste un répertoire ; `for fichier in "$repertoire"/*`
  parcourt son contenu ; `exit 1` termine avec un code : #d("exit")[exit, pas return].
]
#indice(titre: [Indice : l’erreur standard])[
  `echo "…" >&2` écrit sur l’erreur standard. Pour le prouver, jetez ce flux : `2> /dev/null`. Le message doit
  disparaître, la question rester.
]

#corrige[
  #f("liste_fichiers.bash")
  #terminal[```console
  $ chmod u+x liste_fichiers.bash
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
  $ ./liste_fichiers.bash <<< /nulle/part 2> /dev/null
  Entrez le chemin du répertoire :
  ```]
  Le motif `"$repertoire"/*` est développé hors des guillemets, le nom du répertoire reste protégé : un
  répertoire nommé `mes données` marche aussi. Le test `[ -f "$fichier" ]` écarte les sous-répertoires.
]

= Étape 4 : copie_fichiers.bash et ses codes de sortie <etape-4>

#bloc(role: "question")[Consignes][
  - Écrivez `copie_fichiers.bash` : il demande une source, puis une destination ; il crée la destination si elle
    n’existe pas, copie le contenu de la source dedans, et le confirme.
  - Un code de sortie par cas, documenté dans le script : 0 succès, 1 source absente, 2 destination impossible à
    créer, 3 copie impossible.
  - Provoquez chacun des quatre codes, en donnant les deux réponses par `printf '%s\n' source destination |`.
]

#indice(titre: [Indice : traiter l’échec là où il survient])[
  `commande || { echo "…" >&2; exit 2; }` : si la commande échoue, le bloc s’exécute. Le cours d’origine écrit
  ainsi `mkdir -p` et `cp -r` : #d("exercice-scripts")[À vous : deux scripts].
]
#indice(titre: [Indice : provoquer les codes 2 et 3])[
  `mkdir` ne peut pas créer un répertoire *dans un fichier* : essayez `donnees/pionnieres.csv/copie`. Et dans un
  répertoire vide, que devient le motif `"$source"/*` ? Le cours le montre :
  #d("ordre-expansions")[Avant d’exécuter, Bash réécrit la ligne].
]

#corrige[
  #f("copie_fichiers.bash")
  #terminal[```console
  $ chmod u+x copie_fichiers.bash
  $ printf '%s\n' donnees copie | ./copie_fichiers.bash
  Entrez le répertoire source :
  Entrez le répertoire destination :
  Le répertoire destination n’existe pas. Création de copie.
  Les fichiers ont été copiés de donnees vers copie.
  $ echo $?
  0
  $ printf '%s\n' absent copie2 | ./copie_fichiers.bash
  Entrez le répertoire source :
  Entrez le répertoire destination :
  Le répertoire source absent n’existe pas.
  $ echo $?
  1
  $ printf '%s\n' donnees donnees/pionnieres.csv/copie | ./copie_fichiers.bash
  Entrez le répertoire source :
  Entrez le répertoire destination :
  Le répertoire destination n’existe pas. Création de donnees/pionnieres.csv/copie.
  mkdir: cannot create directory ‘donnees/pionnieres.csv’: Not a directory
  Erreur lors de la création du répertoire destination.
  $ echo $?
  2
  $ mkdir vide
  $ printf '%s\n' vide copie3 | ./copie_fichiers.bash
  Entrez le répertoire source :
  Entrez le répertoire destination :
  Le répertoire destination n’existe pas. Création de copie3.
  cp: cannot stat 'vide/*': No such file or directory
  Erreur lors de la copie des fichiers.
  $ echo $?
  3
  ```]
  Dans un répertoire vide, le motif `vide/*` ne correspond à rien : Bash le laisse tel quel, et `cp` cherche un
  fichier nommé `vide/*`. Le code 3 signale donc aussi une source vide. Un code par cas permet à l’appelant
  (`&&`, `||`, cron, un autre script) de savoir *ce qui* a échoué, sans lire les messages.
]

= Étape 5 : des arguments et set -euo pipefail <etape-5>

#bloc(role: "question")[Consignes][
  - Copiez `copie_fichiers.bash` en `copie_fichiers_args.bash`. Le nouveau script ne pose plus de question : la
    source et la destination arrivent en arguments (`./copie_fichiers_args.bash donnees copie4`). Il garde les
    codes 0 à 3.
  - Ajoutez `set -euo pipefail` en tête. Lancez le script sans argument : que se passe-t-il, et pourquoi ?
  - Faites-lui afficher un message d’usage sur l’erreur standard, avec le code 4, s’il ne reçoit pas exactement
    deux arguments.
  - Vérifiez que le code 3 sort toujours, malgré `set -e`.
]

#indice(titre: [Indice : pourquoi des arguments])[
  Un script qui attend une saisie ne peut pas tourner sous cron ni dans un déploiement :
  #d("saisie-ou-arguments")[Saisie interactive ou arguments]. Les arguments : `$1`, `$2`, et leur nombre `$#` :
  #d("arguments")[Recevoir des arguments].
]
#indice(titre: [Indice : set -u])[
  Avec `set -u`, lire une variable non définie est une erreur, `$1` compris quand il manque :
  #terminal[```console
  $ bash -u -c 'echo "source : $1"'
  bash: line 1: $1: unbound variable
  ```]
  Testez donc `$#` *avant* de lire `$1` et `$2`. Les trois options :
  #d("set-euo-pipefail")[set -e : s’arrêter à la première erreur].
]
#indice(titre: [Indice : set -e et ||])[
  Une commande dont l’échec est testé (`if`, `&&`, `||`) n’arrête pas le script :
  #d("limites-set-e")[Les limites de set -e].
]

#corrige[
  #f("copie_fichiers_args.bash")
  #terminal[```console
  $ chmod u+x copie_fichiers_args.bash
  $ ./copie_fichiers_args.bash
  Usage : ./copie_fichiers_args.bash SOURCE DESTINATION
  $ echo $?
  4
  $ ./copie_fichiers_args.bash donnees copie4
  Le répertoire destination n’existe pas. Création de copie4.
  Les fichiers ont été copiés de donnees vers copie4.
  $ echo $?
  0
  $ ./copie_fichiers_args.bash vide copie5
  Le répertoire destination n’existe pas. Création de copie5.
  cp: cannot stat 'vide/*': No such file or directory
  Erreur lors de la copie des fichiers.
  $ echo $?
  3
  ```]
  Sans le test de `$#`, le script s’arrête sur `source=$1` avec le message « `$1: unbound variable` » : c’est
  `set -u` qui joue son rôle, mais l’utilisateur ne sait pas quoi faire. Le message d’usage le lui dit. `cp`
  échoue dans un `||` : `set -e` le laisse au bloc qui suit, qui sort avec le code 3. `pipefail` ne change rien
  ici (aucun tube) ; il compte dès qu’un script enchaîne des commandes par `|`.
]

= Étape 6 : ShellCheck relit les scripts <etape-6>

#bloc(role: "question")[Consignes][
  - Passez vos quatre scripts à ShellCheck : `pipelines.sh`, `liste_fichiers.bash`, `copie_fichiers.bash` et
    `copie_fichiers_args.bash`. Corrigez ce qu’il signale, jusqu’à un code de retour 0.
  - Recréez `a-relire.sh`, le script de la diapositive #d("shellcheck")[ShellCheck relit le script avant
    l’exécution], avec la commande ci-dessous. Lancez-le sur un répertoire `mes documents` qui contient
    `rapport.txt` : trouve-t-il le fichier ?
  - Lisez le rapport de ShellCheck sur `a-relire.sh`, puis corrigez le script : il doit trouver `rapport.txt` et
    ShellCheck ne doit plus rien signaler.
]

#terminal[```console
$ printf '%s\n' '#!/bin/bash' 'dossier=$1' 'for fichier in $(ls $dossier); do' \
  '    if [ $fichier = "rapport.txt" ]; then' '        echo "Trouvé : $fichier"' '    fi' 'done' > a-relire.sh
$ chmod u+x a-relire.sh
$ mkdir "mes documents"
$ touch "mes documents/rapport.txt" "mes documents/notes de cours.txt"
$ ./a-relire.sh "mes documents"
$ shellcheck a-relire.sh
```]

#note(role: "precaution")[Les commandes `shellcheck` de cette étape et des deux suivantes demandent le terminal
  en mode compagnon (ou le vôtre) : la VM de la page n’a pas ShellCheck. Le reste du TP, `bats` compris, s’y
  exécute.]

#indice(titre: [Indice : lire le rapport])[
  Chaque avertissement a un code (SC2045, SC2086…) et une page d’explication sur shellcheck.net. SC2045 :
  la sortie de `ls` se découpe en mots, d’où #d("for-ls")[for sur \$(ls) : un nom à espace se coupe en deux]. Un
  motif (`"$dossier"/*`) donne un mot par chemin ; l’artefact
  #link("../../artefacts/expansions-bash/")[Avant d’exécuter, Bash réécrit la ligne] le montre pas à pas.
]

#corrige[
  #terminal[```console
  $ shellcheck pipelines.sh liste_fichiers.bash copie_fichiers.bash copie_fichiers_args.bash
  $ echo $?
  0
  $ ./a-relire.sh "mes documents"
  ls: cannot access 'mes': No such file or directory
  ls: cannot access 'documents': No such file or directory
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
  `$dossier` sans guillemets est découpé en deux mots : `ls` cherche `mes`, puis `documents`, et le script ne
  trouve rien, sans échouer (code 0). La version corrigée :
  #f("a-relire.sh")
  #terminal[```console
  $ ./a-relire.sh "mes documents"
  Trouvé : rapport.txt
  $ shellcheck a-relire.sh
  $ echo $?
  0
  ```]
  Corriger seulement les guillemets, comme le propose « Did you mean », ne suffit pas : `$(ls "$dossier")`
  produirait `notes`, `de`, `cours.txt`, découpés à leur tour. Le motif règle les deux défauts.
]

= Étape 7 : tester avec Bats <etape-7>

#bloc(role: "question")[Consignes][
  - Gardez la sortie actuelle de `pipelines.sh` comme référence : `attendu/pipelines.txt`.
  - Écrivez `solutions.bats`, dans `~/tp-scripts`, avec au moins un test par code de sortie de
    `liste_fichiers.bash`, de `copie_fichiers.bash` et de `copie_fichiers_args.bash`, un test qui compare la
    sortie de `pipelines.sh` à la référence, et un test de `a-relire.sh` sur `mes documents`.
  - Chaque test doit partir d’un répertoire neuf : il ne doit dépendre ni de l’ordre des tests, ni des répertoires
    `copie*` laissés par les étapes précédentes.
  - Cassez exprès `liste_fichiers.bash` (`exit 1` devient `exit 0`) : quel test échoue ? Réparez-le.
]

#terminal[```console
$ bats --version
Bats 1.11.1
$ mkdir attendu
$ ./pipelines.sh > attendu/pipelines.txt
```]

#indice(titre: [Indice : la forme d’un test])[
  La diapositive #d("bats")[Tester un script avec Bats] teste déjà `liste_fichiers.bash`. `run` lance une
  commande et range son code dans `$status`, sa sortie dans `$output` (et ligne par ligne dans `${lines[@]}`) ;
  `run --separate-stderr` range l’erreur standard à part, dans `$stderr`.
]
#indice(titre: [Indice : un répertoire neuf par test])[
  Bats appelle la fonction `setup` avant chaque test, et donne à chacun un répertoire temporaire,
  `$BATS_TEST_TMPDIR`, qu’il efface ensuite. `$BATS_TEST_DIRNAME` est le répertoire du fichier de tests : celui des
  scripts et des données. Dans `setup`, placez-vous dans le répertoire temporaire et copiez-y `donnees/`.
]

#corrige[
  #f("solutions.bats", lang: "bash")
  À cette étape, la liste `versions` ne contient que `copie_fichiers_args.bash` : l’étape 8 y ajoute
  `copie_fichiers_robuste.bash`.
  #terminal[```console
  $ bats solutions.bats
  solutions.bats
   ✓ pipelines.sh : sorties attendues (attendu/pipelines.txt)
   ✓ pipelines.sh : la sortie de cut dans noms.txt, son erreur dans erreurs.txt
   ✓ liste_fichiers : liste les fichiers d’un répertoire, code 0
   ✓ liste_fichiers : code 1 et message sur l’erreur standard si le répertoire n’existe pas
   ✓ liste_fichiers : un nom de répertoire à espace
   ✓ copie_fichiers : crée la destination et copie, code 0
   ✓ copie_fichiers : code 1 si la source n’existe pas
   ✓ copie_fichiers : code 2 si la destination ne peut pas être créée
   ✓ copie_fichiers : code 3 si la copie échoue (source vide)
   ✓ a-relire.sh corrigé : trouve rapport.txt dans un dossier à espace
   ✓ versions à arguments : code 4 et usage sur l’erreur standard sans argument
   ✓ versions à arguments : code 4 avec un seul ou trois arguments
   ✓ versions à arguments : copie, code 0, contenu identique
   ✓ versions à arguments : codes 1, 2 et 3
   ✓ versions à arguments : ne lisent pas l’entrée standard

  15 tests, 0 failures
  $ cp liste_fichiers.bash liste_fichiers.bak
  $ sed -i 's/exit 1 /exit 0 /' liste_fichiers.bash
  $ bats --filter 'liste_fichiers' solutions.bats
  solutions.bats
   ✓ liste_fichiers : liste les fichiers d’un répertoire, code 0
   ✗ liste_fichiers : code 1 et message sur l’erreur standard si le répertoire n’existe pas
     (in test file solutions.bats, line 46)
       `[ "$status" -eq 1 ]' failed
   ✓ liste_fichiers : un nom de répertoire à espace

  3 tests, 1 failure
  $ mv liste_fichiers.bak liste_fichiers.bash
  ```]
  Le test nomme la vérification qui a échoué et sa ligne. `attendu/pipelines.txt` est un test de
  non-régression : il ne dit pas que la sortie est juste, seulement qu’elle n’a pas changé depuis qu’on l’a
  vérifiée à la main. Dans un tube ou en intégration continue, Bats écrit le format TAP (`ok 1 …`), que le
  harnais de ce TP relit.
]

= Étape 8 : une fonction par tâche, et main <etape-8>

#bloc(role: "question")[Consignes][
  - Écrivez `copie_fichiers_robuste.bash`, même comportement que `copie_fichiers_args.bash` (mêmes messages,
    mêmes codes), découpé en fonctions : une pour l’erreur, une par vérification ou action, et `main`, appelée
    avec les arguments du script.
  - Ajoutez `copie_fichiers_robuste.bash` à la liste `versions` de `solutions.bats`, puis relancez les tests :
    sans rien changer aux tests, ils doivent tous passer.
  - Passez le nouveau script à ShellCheck.
]

#indice(titre: [Indice : la forme])[
  #d("fonctions-main")[Fonctions et main()] : chaque fonction reçoit ses propres `$1`, `$2` ; `local` garde ses
  variables pour elle ; le script finit par `main "$@"`, qui transmet tous les arguments
  (#d("arguments-tous")[Tous les arguments : "\$\@"]). Une fonction `erreur code message` évite de répéter
  `echo "…" >&2; exit N`.
]

#corrige[
  #f("copie_fichiers_robuste.bash")
  #terminal[```console
  $ chmod u+x copie_fichiers_robuste.bash
  $ ./copie_fichiers_robuste.bash donnees
  Usage : ./copie_fichiers_robuste.bash SOURCE DESTINATION
  $ echo $?
  4
  $ shellcheck copie_fichiers_robuste.bash
  $ grep -n '^versions=' solutions.bats
  97:versions=(copie_fichiers_args.bash copie_fichiers_robuste.bash)
  $ bats solutions.bats
  solutions.bats
   ✓ pipelines.sh : sorties attendues (attendu/pipelines.txt)
   ✓ pipelines.sh : la sortie de cut dans noms.txt, son erreur dans erreurs.txt
   ✓ liste_fichiers : liste les fichiers d’un répertoire, code 0
   ✓ liste_fichiers : code 1 et message sur l’erreur standard si le répertoire n’existe pas
   ✓ liste_fichiers : un nom de répertoire à espace
   ✓ copie_fichiers : crée la destination et copie, code 0
   ✓ copie_fichiers : code 1 si la source n’existe pas
   ✓ copie_fichiers : code 2 si la destination ne peut pas être créée
   ✓ copie_fichiers : code 3 si la copie échoue (source vide)
   ✓ a-relire.sh corrigé : trouve rapport.txt dans un dossier à espace
   ✓ versions à arguments : code 4 et usage sur l’erreur standard sans argument
   ✓ versions à arguments : code 4 avec un seul ou trois arguments
   ✓ versions à arguments : copie, code 0, contenu identique
   ✓ versions à arguments : codes 1, 2 et 3
   ✓ versions à arguments : ne lisent pas l’entrée standard

  15 tests, 0 failures
  ```]
  `main` se lit comme le déroulé du script ; chaque fonction se relit et se teste seule. `erreur` termine le
  script même appelée depuis une fonction : `exit` quitte le shell, pas seulement la fonction (ce que ferait
  `return`). Les tests n’ont pas changé : ils prouvent que la nouvelle structure fait la même chose que
  l’ancienne. `cp -r "$source"/*` ne copie pas les fichiers cachés (`.config`…) ; `cp -r "$source"/.` les
  copierait, et accepterait une source vide : un autre comportement, que les tests du code 3 signaleraient.
]

#bloc(role: "retenir")[Ce que ce TP a montré][
  - Un pipeline se range dans un script, et sa sortie vérifiée devient une référence pour les tests.
  - Un script automatisable lit ses arguments, vérifie `$#`, écrit ses erreurs sur `>&2` et rend un code par cas.
  - `set -euo pipefail` arrête le script sur une erreur non traitée ; les échecs testés par `||` restent au script.
  - ShellCheck trouve, avant l’exécution, les guillemets manquants et les boucles sur `ls`.
  - Bats rejoue les cas d’usage à chaque modification : on restructure en `main` sans craindre de régression.
  - Pour lancer `copie_fichiers_robuste.bash` chaque nuit : #d("cron")[Digression : planifier avec cron].
]
