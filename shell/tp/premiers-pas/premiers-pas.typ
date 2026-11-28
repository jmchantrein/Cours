// TP « Premiers pas dans le shell » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/tp/premiers-pas/premiers-pas.typ build/shell/premiers-pas.html
// Les corrigés sont les scripts de corrige/, exécutés par tester.sh dans un conteneur Debian 13 neuf ;
// corrige/etape-N.sortie est la sortie réelle de corrige/etape-N.sh, que tester.sh --up recompare.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/shell-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Script du corrigé.
#let f(nom) = fichier("corrige/" + nom, read("corrige/" + nom))
// Sortie réelle d’un script du corrigé, telle qu’un terminal l’affiche.
#let sortie(nom) = terminal(raw(read("corrige/" + nom).trim("\n", at: end), block: true, lang: "console"))

#show: page-web.with(
  titre: [Premiers pas dans le shell],
  surtitre: [Fondements de l’administration système GNU/Linux · travaux pratiques],
  sous-titre: [Se repérer, se déplacer, lire l’aide, manipuler des fichiers, et brancher ses premiers tubes],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("vm", "host-shell-access"),
  depart: (script: "shell/tp/premiers-pas/preparer.sh", cree: "~/atelier", ici: "~"),   // état de départ : la VM l’installe à son démarrage
  liens: (
    ([Le cours], "../../index.html"),
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/shell/tp/premiers-pas/corrige"),
    ([TP suivant : droits et archives], "../fichiers/index.html"),
  ),
)

= Avant de commencer <avant>

Ce TP s’adresse à qui ouvre un terminal pour la première fois. Vous y tapez des commandes dans un répertoire
d’exemples créé pour l’occasion : vous pouvez tout y casser, un script le recrée. Chaque commande suit la forme
présentée en cours : #diapo("../../cm/intro-projection.pdf", "ligne-de-commande")[Lire une ligne de commande].

#bloc(role: "pratique")[Prérequis][
  - Un terminal Bash : sur Debian ou Ubuntu, l’application « Terminal » ; sinon, le terminal de cette page.
  - Un compte ordinaire, pas root : l’invite finit par `$`, pas par `#`.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Chaque corrigé est un script de `corrige/` qui
  rejoue les commandes attendues ; il est exécuté automatiquement, à chaque modification, dans un Debian 13 neuf,
  et la sortie montrée est celle de cette exécution. Le compte s’y appelle `ada` : chez vous, votre nom de compte
  et votre répertoire personnel le remplacent.
]

#note(role: "precaution")[
  Les messages et les dates suivent la langue du système. Les sorties montrées sont en anglais (locale
  `C.UTF-8`) ; sur un système en français, `No such file or directory` devient « Aucun fichier ou dossier de ce
  nom » et `Sep  1` devient `sept.  1`. L’ordre de `ls` peut aussi changer : en français, il ignore le point
  initial des fichiers cachés. Dans le terminal de cette page, les fichiers sont en mémoire : la taille d’un
  répertoire dans `ls -l` (`80` au lieu de `4096`) et la ligne `total` diffèrent de celles montrées.
]

= Étape 1 : le répertoire de travail <etape-1>

Le script `preparer.sh` crée le répertoire `~/atelier` (`~` désigne votre répertoire personnel). Il refuse d’écraser un
répertoire existant.

#bloc(role: "question")[Consignes][
  - Dans le terminal de cette page (VM), `~/atelier` est déjà là : la VM l’a créé à son démarrage. Sur votre
    machine, téléchargez `preparer.sh` dans votre répertoire personnel, puis lancez-le avec `bash`.
  - Faites afficher par le shell votre nom de compte, puis le mot `Bonjour`.
  - Faites afficher `Bonjour     tout     le     monde`, avec ses espaces en trop : une fois sans guillemets, une
    fois entre guillemets doubles. Combien d’arguments la commande reçoit-elle dans chaque cas ? Vérifiez à
    l’écran : les espaces en trop restent-elles ?
]

#terminal(host-shell-access: true)[```console
$ cd
$ wget https://jmchantrein.github.io/Cours/shell/tp/premiers-pas/preparer.sh
$ bash preparer.sh
Dossier de travail prêt : /home/ada/atelier
Pour y entrer : cd /home/ada/atelier
```]
#note(role: "pratique")[
  Sans `wget`, `curl -O` suivi de la même adresse télécharge aussi le fichier. Pour repartir de zéro plus tard :
  `rm -r ~/atelier`, puis `bash preparer.sh` à nouveau ; dans le terminal de cette page, le bouton « Remettre à
  l’état de départ » fait de même. Le script, en entier :
]
#fichier("preparer.sh", read("preparer.sh"))

#indice(titre: [Indice : les arguments])[
  Le shell découpe la ligne en mots aux espaces, avant de lancer la commande ; les guillemets font d’un texte un
  seul mot. Le cours y revient : #d("ordre-expansions")[Avant d’exécuter, Bash réécrit la ligne]. L’artefact
  #link("../../artefacts/expansions-bash/")[Avant d’exécuter, Bash réécrit la ligne] montre les arguments que la commande reçoit.
]

#indice(titre: [Indice : quelles commandes ?])[
  Une commande répond, en anglais, à la question « qui suis-je ? » ; une autre affiche ses arguments, tels qu’elle
  les reçoit.
]
#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ whoami
$ echo Bonjour
$ echo Bonjour     tout     le     monde
$ echo "Bonjour     tout     le     monde"
```]]

#corrige[
  Sans guillemets, `echo` reçoit quatre arguments, qu’il affiche séparés d’une espace : les espaces en trop ont
  disparu avant même son lancement. Entre guillemets, il en reçoit un seul, espaces comprises.
  #sortie("etape-1.sortie")
  #f("etape-1.sh")
]

= Étape 2 : se repérer <etape-2>

#bloc(role: "question")[Consignes][
  - Entrez dans `~/atelier`, puis faites afficher le répertoire courant : vous devez lire `/home/ada/atelier` (votre
    compte à la place d’`ada`).
  - Listez son contenu ; puis tout son contenu, noms cachés compris ; puis son contenu en détail (type, droits,
    taille, date). Quel fichier la première liste ne montrait-elle pas ?
  - Dans le détail, lesquels sont des répertoires ? Quelle est la taille de `pionnieres.csv` ?
  - Listez le répertoire `notes` sans y entrer ; puis le détail de `journaux`. Quel journal est le plus gros ?
]

#indice(titre: [Indice : lire ls -l])[
  Le premier caractère d’une ligne de `ls -l` donne le type : `d` pour un répertoire, `-` pour un fichier ; la
  taille, en octets, précède la date. Les colonnes sont décodées dans #d("ls-l")[Décoder une ligne de ls -l].
]
#indice(titre: [Indice : les fichiers cachés])[
  Un nom qui commence par un point est caché : `ls` le tait, `ls -a` (_all_) le montre. `.` est le répertoire
  courant, `..` son parent.
]

#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ cd ~/atelier
$ pwd
$ ls
$ ls -a
$ ls -l
$ ls notes
$ ls -l journaux
```]]

#corrige[
  `ls -a` montre en plus `.reglages`, fichier caché, ainsi que `.` et `..`. Les lignes qui commencent par `d`
  sont les répertoires : `journaux`, `notes`, `projets` et `vieux`. `pionnieres.csv` fait 474 octets ; le journal de
  2026 fait 72 375 octets.
  #sortie("etape-2.sortie")
  #f("etape-2.sh")
]

= Étape 3 : complétion et historique <etape-3>

Deux réflexes à prendre dès maintenant : la touche Tab complète ce que vous tapez, et le shell garde la liste
des commandes déjà lancées.

#bloc(role: "question")[Consignes][
  - Dans `~/atelier`, tapez `wc -l jo` sans valider, puis appuyez sur Tab. Appuyez encore sur Tab, puis deux
    fois de suite. Que se passe-t-il à chaque fois ? Complétez jusqu’au journal de 2026, puis validez.
  - Tapez `whoa`, puis Tab : la complétion vaut aussi pour les commandes.
  - Rappelez la commande précédente avec la flèche vers le haut, puis cherchez la commande `wc` avec Ctrl+R
    (tapez `wc`, puis Entrée).
  - Affichez l’historique (la commande porte son nom, en anglais). Abandonnez une ligne commencée avec Ctrl+C, effacez l’écran avec Ctrl+L.
]

#indice(titre: [Indice : quand Tab ne complète pas])[
  Tab complète jusqu’où le début tapé n’a qu’une suite possible. S’il y en a plusieurs, rien ne s’ajoute, et un
  second Tab les liste : tapez alors un caractère de plus, puis Tab.
]

#corrige[
  `jo` + Tab donne `journaux/` (seul nom qui commence par `jo`) ; Tab ajoute `serveur-202`, début commun aux
  deux journaux ; deux Tab de plus listent `serveur-2025-novembre.log` et `serveur-2026-novembre.log` ; `6` + Tab
  termine le nom. `whoa` + Tab donne `whoami`. Ctrl+R cherche en arrière dans l’historique la dernière commande
  qui contient le texte tapé. Les touches ne se rejouent pas dans un script : le corrigé contient les commandes
  qu’elles ont produites.
  #sortie("etape-3.sortie")
  #f("etape-3.sh")
]

= Étape 4 : se déplacer <etape-4>

Un chemin *absolu* part de la racine `/` : `/home/ada/atelier/notes`. Un chemin *relatif* part du répertoire courant :
`notes`, `../projets`. Dans un chemin, `..` désigne le répertoire parent et `.` le répertoire lui-même ; `~` est
remplacé par le chemin absolu de votre répertoire personnel.

#bloc(role: "question")[Consignes][
  + Entrez dans `~/atelier/notes`. Rejoignez `~/atelier/projets/site` par un chemin relatif ; vérifiez où vous êtes :
    `/home/ada/atelier/projets/site`.
  + Rejoignez le même répertoire par un chemin absolu, et vérifiez de même.
  + Depuis `projets/site`, listez `journaux` sans changer de répertoire : les deux journaux s’affichent.
  + Depuis `~/atelier`, que désigne `notes/../projets/./site` ? Vérifiez en listant ce chemin.
  + Allez dans `/tmp`, puis revenez au répertoire précédent en une commande courte. Où vous mène la commande de
    déplacement sans argument ?
]

#indice(titre: [Indice : relatif])[
  Depuis `notes`, il faut remonter d’un cran (`..`) pour atteindre `atelier`, puis descendre dans `projets`,
  puis dans `site`. Les morceaux d’un chemin se séparent par `/`.
]

#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ cd ~/atelier/notes
$ cd ../projets/site
$ pwd
$ cd ~/atelier/projets/site
$ pwd
$ ls ../../journaux
$ cd ~/atelier
$ ls notes/../projets/./site
$ cd /tmp
$ cd -
$ cd
$ pwd
```]]

#corrige[
  + `cd ../projets/site`.
  + `cd ~/atelier/projets/site` ; `~` étant remplacé par `/home/ada`, c’est un chemin absolu.
  + `ls ../../journaux` : deux crans plus haut, `atelier`, puis `journaux`.
  + Le répertoire `projets/site`, par un détour : on entre dans `notes`, on en ressort, on entre dans `projets`, on y
    reste (`.`), puis `site`.
  + `cd -` affiche puis rejoint le répertoire précédent ; `cd` seul ramène dans le répertoire personnel.
  #sortie("etape-4.sortie")
  #f("etape-4.sh")
  Le `cd` d’un script ne change pas le répertoire du terminal qui le lance : le script tourne dans son propre
  processus, qui a son propre répertoire courant.
]

= Étape 5 : lire l’aide <etape-5>

Personne ne retient toutes les options : le manuel est installé avec le système (#diapo("../../cm/intro-projection.pdf", "ligne-de-commande")[Lire une
ligne de commande], bloc « Se documenter »).

#bloc(role: "question")[Consignes][
  - Ouvrez le manuel de `ls`. Déplacez-vous avec les flèches et Espace ; cherchez le mot `size` avec `/size`,
    puis Entrée ; `n` passe à l’occurrence suivante ; `q` quitte.
  - Trouvez l’option qui trie par taille, celle qui inverse l’ordre, et celle qui écrit les tailles en Kio ou Mio.
    Essayez-les sur `journaux` : le journal de 2026 vient d’abord, puis en dernier, puis sa taille s’écrit `71K`.
  - Comparez avec l’aide courte de `ls`.
  - Demandez au shell ce que sont `cd` et `sort` : lequel est une commande interne de Bash ? Ouvrez l’aide de
    celle-là.
]

#note(role: "precaution")[
  Le terminal de cette page a `man` (mandoc) pour les commandes de ces TP, mais pas pour toutes. Sur Debian, `man`
  vient du paquet `man-db`, installé avec le système, mais absent des images de conteneur : sans lui, utilisez
  `ls --help` et `help cd`.
]

#indice(titre: [Indice : les options])[
  Dans `man ls`, cherchez `sort by` : les options de tri sont regroupées. `--human-readable` a une forme courte.
]

#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ man ls
$ ls -lS journaux
$ ls -lSr journaux
$ ls -lh journaux
$ ls --help
$ type cd
$ type sort
$ help cd
```]]

#corrige[
  `-S` trie par taille, du plus gros au plus petit ; `-r` (_reverse_) inverse l’ordre ; `-h`
  (`--human-readable`), avec `-l`, écrit `71K` au lieu de `72375`. `cd` est une commande interne de Bash
  (_builtin_), décrite par `help cd` et `man bash` ; `sort` est un programme, `/usr/bin/sort`, décrit par `man sort`. Avec une commande que vous avez déjà lancée,
  comme `wc` à l’étape 3, `type` répond `wc is hashed (/usr/bin/wc)` : Bash garde dans une table de hachage le chemin
  des programmes qu’il a déjà trouvés, pour ne plus les chercher dans `PATH`.
  #sortie("etape-5.sortie")
  #f("etape-5.sh")
]

= Étape 6 : afficher un fichier <etape-6>

Le fichier `pionnieres.csv` est le fil rouge du cours : #d("fil-rouge")[Le fil rouge : pionnieres.csv].

#bloc(role: "question")[Consignes][
  - Affichez en entier `notes/a-faire.txt`, puis `pionnieres.csv`.
  - N’affichez que les trois premières lignes de `pionnieres.csv`, puis les deux dernières.
  - Combien de lignes compte `pionnieres.csv` ? Et le journal de 2026 ?
  - À quelle heure le journal de 2026 a-t-il enregistré sa dernière requête ?
  - Ouvrez ce journal dans un afficheur page par page. Cherchez la première erreur (`ERROR`) : à quelle heure est-elle ? Et la
    suivante ? Quittez.
]

#indice(titre: [Indice : les commandes])[
  `head` affiche le début, `tail` la fin ; `-n 3` en fixe le nombre de lignes. `wc -l` compte les lignes. Dans
  `less`, on se déplace et on cherche comme dans `man` (`/`, `n`, `q`) : `man` affiche ses pages avec `less`.
]

#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ cat notes/a-faire.txt
$ cat pionnieres.csv
$ head -n 3 pionnieres.csv
$ tail -n 2 pionnieres.csv
$ wc -l pionnieres.csv
$ wc -l journaux/serveur-2026-novembre.log
$ tail -n 1 journaux/serveur-2026-novembre.log
```]]

#corrige[
  `pionnieres.csv` compte 9 lignes : l’en-tête et huit pionnières. Le journal en compte 1 500, et sa dernière
  requête date de 12:05:00. Dans `less`, `/ERROR` trouve la première erreur à 00:24:10, `n` la suivante à
  00:48:20. `cat` convient à un petit fichier ; pour un long, `less`, `head` ou `tail`.
  #sortie("etape-6.sortie")
  #f("etape-6.sh")
]

= Étape 7 : créer, copier, déplacer, supprimer <etape-7>

#bloc(role: "danger")[Pas de corbeille][
  `rm` supprime pour de bon : rien ne permet de récupérer le fichier. `rm -r` supprime un répertoire et tout ce qu’il
  contient. Relisez la commande avant Entrée ; `rm -i` demande confirmation pour chaque fichier.
]

#bloc(role: "question")[Consignes][
  Dans `~/atelier`, en une commande par point :
  + Créez le répertoire `archives`, et dedans le répertoire `2025`, en une seule commande.
  + Copiez `pionnieres.csv` dans `archives`, sous le nom `pionnieres-copie.csv`.
  + Renommez cette copie `pionnieres-v1.csv`.
  + Déplacez le journal de 2025 dans `archives/2025`.
  + Copiez le répertoire `notes` entier dans `archives`, sous le nom `notes-sauvegarde`.
  + Créez un fichier vide `notes/brouillon.txt`, vérifiez qu’il existe, puis supprimez-le.
  + Supprimez le répertoire `vieux`. Pourquoi `rmdir vieux` échoue-t-il ?
  Résultat attendu : `archives` contient `2025`, `notes-sauvegarde` et `pionnieres-v1.csv` ; `vieux` a disparu.
]

#indice(titre: [Indice : les commandes])[
  `mkdir` crée un répertoire, et `-p` ses parents manquants. `cp source destination` copie ; `-r` (récursif) copie
  un répertoire. `mv` déplace et renomme : renommer, c’est déplacer vers un autre nom. `touch` crée un fichier vide.
  `rm` supprime un fichier ; `rmdir` un répertoire vide seulement.
]

#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ cd ~/atelier
$ mkdir -p archives/2025
$ cp pionnieres.csv archives/pionnieres-copie.csv
$ mv archives/pionnieres-copie.csv archives/pionnieres-v1.csv
$ mv journaux/serveur-2025-novembre.log archives/2025/
$ cp -r notes archives/notes-sauvegarde
$ touch notes/brouillon.txt
$ ls notes
$ rm notes/brouillon.txt
$ rmdir vieux
$ rm -r vieux
```]]

#corrige[
  `rmdir` refuse un répertoire qui contient encore des fichiers : `Directory not empty`. `rm -r` le supprime avec son
  contenu. Si `archives/notes-sauvegarde` existait déjà, `cp -r notes archives/notes-sauvegarde` copierait `notes`
  à l’intérieur.
  #sortie("etape-7.sortie")
  #f("etape-7.sh")
]

= Étape 8 : premiers tubes et redirections <etape-8>

Une commande lit son entrée standard et écrit sur sa sortie standard et son erreur standard
(#d("flux-standards")[Trois flux par processus]). Une redirection branche un flux sur un fichier
(#d("redirections")[Rediriger vers un fichier]) ; un tube, `|`, branche la sortie d’une commande sur l’entrée de
la suivante (#d("tubes")[Le tube branche une sortie sur une entrée]).

#bloc(role: "question")[Consignes][
  Dans `~/atelier` :
  + Enregistrez la sortie de `ls -l` dans `liste.txt`, puis affichez ce fichier. Pourquoi `liste.txt` y figure-t-il,
    avec une taille nulle ?
  + Ajoutez la ligne `- relire les diapos` à la fin de `notes/a-faire.txt`, sans effacer les trois autres.
  + Lancez `ls pionnieres.csv absent.txt`. Relancez-la en envoyant les erreurs seules dans `erreurs.txt`.
  + Comptez les lignes `ERROR` du journal de 2026, en un tube.
  + Affichez seulement la 4#super[e] ligne de `pionnieres.csv`, en un tube.
  + Affichez les trois pionnières les plus anciennes, sans la ligne d’en-tête.
  + Enregistrez les trois dernières erreurs du journal dans `dernieres-erreurs.txt`.
]

#bloc(role: "avertissement")[`>` écrase][
  `>` vide le fichier avant de lancer la commande ; `>>` ajoute à la fin. Une erreur de chevron, et
  `a-faire.txt` est perdu : #d("troncature")[> vide le fichier avant de lancer la commande].
]

#indice(titre: [Indice : redirections])[
  `> f` : la sortie standard dans `f`, écrasé ; `>> f` : ajoutée à la fin ; `2> f` : l’erreur standard dans `f`.
]
#indice(titre: [Indice : tubes])[
  `grep motif fichier` garde les lignes qui contiennent le motif ; `wc -l` compte les lignes qu’il reçoit.
  La 4#super[e] ligne est la dernière des quatre premières. `tail -n +2` affiche à partir de la ligne 2 ;
  `sort -t';' -k2 -n` trie sur la 2#super[e] colonne, séparée par `;`, en nombres.
]

#indice(titre: [Dernier indice : les commandes, à écrire ou à exécuter])[#terminal[```console
$ cd ~/atelier
$ ls -l > liste.txt
$ cat liste.txt
$ echo "- relire les diapos" >> notes/a-faire.txt
$ ls pionnieres.csv absent.txt
$ ls pionnieres.csv absent.txt 2> erreurs.txt
$ grep ERROR journaux/serveur-2026-novembre.log | wc -l
$ head -n 4 pionnieres.csv | tail -n 1
$ tail -n +2 pionnieres.csv | sort -t';' -k2 -n | head -n 3
$ grep ERROR journaux/serveur-2026-novembre.log | tail -n 3 > dernieres-erreurs.txt
```]]

#corrige[
  + Bash crée et vide `liste.txt` avant de lancer `ls` : `ls` le voit donc, encore vide.
  + `>>` ajoute à la fin du fichier.
  + Seul `ls: cannot access 'absent.txt'…` part dans `erreurs.txt` ; `pionnieres.csv` reste à l’écran.
  + 30 erreurs. `grep -c ERROR` compte aussi, sans tube.
  + `Hopper Grace`, la 4#super[e] ligne en comptant l’en-tête.
  + Lovelace, Booth, Hopper ; sans `tail -n +2`, l’en-tête, dont l’année n’est pas un nombre, sortirait en premier.
  + `tail -n 3` reçoit les 30 erreurs et garde les trois dernières.
  #sortie("etape-8.sortie")
  #f("etape-8.sh")
  Pour aller plus loin, l’exercice du cours sur les tubes : #d("exercice-tubes")[À vous : deux pipelines sur
  pionnieres.csv]. Le TP suivant, #link("../fichiers/index.html")[Droits, liens, recherche et archives], part
  d’un nouveau répertoire.
]
