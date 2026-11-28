// TP « Droits, liens, recherche et archives » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/tp/fichiers/fichiers.typ build/shell/fichiers.html
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
  titre: [Droits, liens, recherche et archives],
  surtitre: [Fondements de l’administration système GNU/Linux · travaux pratiques],
  sous-titre: [Lire et régler les droits, comprendre le umask et les propriétaires, lier, chercher avec find, archiver avec tar],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("vm", "compagnon"),
  depart: (script: "shell/tp/fichiers/preparer.sh", cree: "~/fichiers", ici: "~"),   // état de départ : la VM l’installe à son démarrage
  liens: (
    ([Le cours], "../../index.html"),
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/shell/tp/fichiers/corrige"),
    ([TP précédent : premiers pas], "../premiers-pas/index.html"),
  ),
)

= Avant de commencer <avant>

Ce TP suit #link("../premiers-pas/index.html")[Premiers pas dans le shell] : `cd`, `ls`, les chemins, `>` et `|`
sont supposés connus. Il part d’un nouveau répertoire d’exemples, `~/fichiers`.

#bloc(role: "pratique")[Prérequis][
  - Un terminal Bash, sous un *compte ordinaire* : root passe outre les droits de lecture et d’écriture, et les
    refus que ce TP fait constater ne se produiraient pas. L’invite doit finir par `$`.
  - De préférence un Debian ou un Ubuntu. Le terminal de cette page ouvre le compte ordinaire `ada` (groupes `ada`
    et `etudiants`), mais ses fichiers sont en mémoire : la taille d’un répertoire dans `ls -l` (`40` ou `80` au lieu
    de `4096`) et les numéros d’inode ne sont pas ceux d’un disque.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Chaque corrigé est un script de `corrige/` qui
  rejoue les commandes attendues ; il est exécuté automatiquement, à chaque modification, dans un Debian 13 neuf,
  sous le compte `ada`, membre des groupes `ada` et `etudiants`. La sortie montrée est celle de cette exécution :
  chez vous, votre nom, vos groupes, les dates et les numéros d’inode diffèrent.
]

#note(role: "precaution")[
  Les messages suivent la langue du système. Les sorties montrées sont en anglais : sur un système en français,
  `Permission denied` devient « Permission non accordée », `Operation not permitted` « Opération non permise ».
]

= Étape 1 : qui suis-je, que dit ls -l ? <etape-1>

#bloc(role: "question")[Consignes][
  - Dans le terminal de cette page (VM), `~/fichiers` est déjà là. Sur votre machine, téléchargez `preparer.sh` et
    lancez-le, comme au TP précédent.
  - `id` : quel est votre nom de compte, votre groupe principal, vos autres groupes ?
  - Dans `~/fichiers`, lisez `ls -l`, puis `ls -l scripts` et `ls -ld coffre`. Pour chaque ligne : type, droits du
    propriétaire, du groupe, des autres. Qui peut lire `pionnieres.csv` ? Qui peut exécuter `scripts/bonjour.sh` ?
]

#terminal(compagnon: true)[```console
$ cd
$ wget https://jmchantrein.github.io/Cours/shell/tp/fichiers/preparer.sh
$ bash preparer.sh
Dossier de travail prêt : /home/ada/fichiers
Pour y entrer : cd /home/ada/fichiers
```]
#note(role: "pratique")[Dans le terminal de cette page, la VM a lancé ce script à son démarrage ; « Remettre à l’état
  de départ » le relance sur une VM neuve.]
#fichier("preparer.sh", read("preparer.sh"))

#indice(titre: [Indice : lire les droits])[
  Après le caractère de type viennent trois groupes de trois lettres : propriétaire (`u`, _user_), groupe (`g`),
  autres (`o`, _others_) ; `r` lire, `w` écrire, `x` exécuter, `-` droit absent :
  #d("ls-l")[Décoder une ligne de ls -l]. `ls -ld` montre la ligne du répertoire lui-même, pas son contenu.
]

#corrige[
  `id` donne le numéro et le nom du compte (`uid`), du groupe principal (`gid`) et la liste des groupes. Tous les
  fichiers sont `rw-r--r--` : le propriétaire lit et écrit, le groupe et les autres lisent seulement. Personne ne
  peut exécuter `bonjour.sh`, faute de `x`. Les répertoires sont `rwxr-xr-x`.
  #sortie("etape-1.sortie")
  #f("etape-1.sh")
  Pour s’exercer, le décodage du cours : #d("exercice-ls-l")[À vous : décoder ls -l].
]

= Étape 2 : chmod, notation symbolique <etape-2>

`chmod` change les droits : à qui (`u`, `g`, `o`, ou `a` pour tous), quelle opération (`+` ajouter, `-` retirer,
`=` fixer exactement), quels droits (`r`, `w`, `x`). Plusieurs changements se séparent par une virgule.

#bloc(role: "question")[Consignes][
  + Lancez `./scripts/bonjour.sh`. Donnez-vous, à vous seul, le droit de l’exécuter, puis relancez-le.
  + Donnez au groupe le droit d’écrire `documents/rapport.txt`, et retirez aux autres celui de le lire, en une
    commande.
  + Mettez `journaux/serveur.log` en lecture seule pour tout le monde, vous compris. Tentez d’y ajouter une ligne
    avec `>>`. Rendez-vous ensuite le droit d’écrire.
]

#indice(titre: [Indice : u+x])[
  La diapositive #d("script-executable")[Un script : shebang, droit x, ./] montre ce même script. `./` est
  nécessaire : le répertoire courant n’est pas dans la liste des répertoires où le shell cherche les commandes.
]

#corrige[
  + `chmod u+x` ; `a+x` donnerait le droit à tout le monde : n’accordez un droit qu’à qui en a besoin.
  + `chmod g+w,o-r` donne `rw-rw----`.
  + `chmod a=r` donne `r--r--r--` : même le propriétaire ne peut plus écrire, et Bash refuse d’ouvrir le fichier
    pour `>>`. Le propriétaire garde cependant le droit de changer les droits : `chmod u+w` les rétablit.
  #sortie("etape-2.sortie")
  #f("etape-2.sh")
]

= Étape 3 : chmod, notation octale <etape-3>

Chaque groupe de trois droits s’écrit aussi par un chiffre, somme de `r` = 4, `w` = 2, `x` = 1 : `rwx` = 7,
`r-x` = 5, `r--` = 4. Trois chiffres décrivent donc les trois publics : `754` = `rwxr-xr--`.
`stat -c '%a %A %n'` affiche les deux notations et le nom.

#bloc(role: "question")[Consignes][
  Trouvez le nombre, appliquez-le, puis vérifiez avec `stat` :
  + `pionnieres.csv` : vous lisez et écrivez, le groupe lit, les autres rien.
  + `scripts/sauvegarde.sh` : vous faites tout, le groupe lit et exécute, les autres rien.
  + `documents/notes` : vous faites tout, personne d’autre n’y entre.
]

#corrige[
  640, 750 et 700. La question 4 de #d("exercice-ls-l")[À vous : décoder ls -l] fait le chemin inverse.
  #sortie("etape-3.sortie")
  #f("etape-3.sh")
]

= Étape 4 : les droits d’un répertoire <etape-4>

Sur un répertoire, les lettres changent de sens : `r` permet de lire la liste des noms, `w` d’y créer, renommer ou
supprimer des noms, `x` de le traverser (y entrer, atteindre ce qu’il contient).

#bloc(role: "question")[Consignes][
  Sur le répertoire `coffre`, qui contient `secret.txt` ; prédisez chaque résultat avant de lancer la commande :
  + Retirez-vous `r`. `ls coffre` ? `cat coffre/secret.txt` ?
  + Donnez-vous `rw` sans `x`. `ls coffre` ? `cat coffre/secret.txt` ? `cd coffre` ?
  + Donnez-vous `rx` sans `w`. Pouvez-vous créer `coffre/nouveau.txt` ? Supprimer `secret.txt` ? Lui ajouter une
    ligne ?
  + Rendez à `coffre` ses droits d’origine, `rwxr-xr-x`.
]

#indice(titre: [Indice : supprimer un fichier])[
  Supprimer un fichier, c’est retirer son nom du répertoire : c’est le répertoire qu’on modifie, pas le fichier.
]

#corrige[
  + Sans `r`, la liste est illisible, mais un nom connu s’atteint encore grâce à `x`.
  + Sans `x`, la liste se lit, mais rien ne s’atteint à travers le répertoire : ni `cat`, ni `cd`. Le corrigé écrit
    `\ls`, qui lance la commande sans l’alias. Sur Debian, dans un terminal, `ls` est l’alias `ls --color=auto` :
    pour colorer le nom, il lit les attributs de `secret.txt`, ce que l’absence de `x` interdit, et il affiche
    d’abord `ls: cannot access 'coffre/secret.txt': Permission denied`, puis le nom `secret.txt`. Sans `x`, on lit
    donc les noms, mais pas leurs attributs. La VM du navigateur n’a pas cet alias : elle n’affiche que
    `secret.txt`.
  + Sans `w`, ni création ni suppression : le répertoire ne change pas. Le contenu de `secret.txt`, lui, dépend des
    droits du fichier, `rw-` : l’ajout réussit.
  #sortie("etape-4.sortie")
  #f("etape-4.sh")
]

= Étape 5 : le umask <etape-5>

Un programme qui crée un fichier demande en général `rw-rw-rw-` (666), et `rwxrwxrwx` (777) pour un répertoire.
Le *umask* du shell retire ses bits de cette demande : avec un umask de `022`, un fichier naît `644`, un répertoire
`755`.

#bloc(role: "question")[Consignes][
  + Affichez votre umask, en octal puis en symbolique (`umask -S`). Prédisez les droits d’un fichier et d’un
    répertoire neufs. Créez `public.txt` et le répertoire `public`, puis vérifiez.
  + Réglez le umask à `077`. Prédisez, puis créez `prive.txt` et le répertoire `prive`, et vérifiez.
  + Ouvrez un nouveau terminal et affichez le umask : que s’est-il passé ?
]

#note(role: "precaution")[
  Le umask dépend du système. Sur Debian 13, une session vaut `0002` : chaque compte a son propre groupe
  (`ada`, groupe `ada`), et le groupe reçoit les mêmes droits que le propriétaire. Ailleurs, et pour root, il vaut
  souvent `0022`.
]

#corrige[
  + Avec `0002` : fichier `664` (`rw-rw-r--`), répertoire `775`. Avec `0022` : `644` et `755`.
  + Avec `077` : `600` et `700`, rien pour le groupe ni pour les autres.
  + Le umask appartient au shell qui l’a réglé : un nouveau terminal repart de la valeur par défaut. Pour le
    garder, la commande `umask 077` s’écrit dans `~/.bashrc`.
  #sortie("etape-5.sortie")
  #f("etape-5.sh")
]

= Étape 6 : propriétaires et groupes <etape-6>

#bloc(role: "question")[Consignes][
  + `id -un` et `id -Gn` : votre nom, vos groupes.
  + Lisez les droits de `/etc/passwd` et de `/etc/shadow` (les mots de passe chiffrés). Pouvez-vous lire l’un,
    l’autre ?
  + Tentez de donner `pionnieres.csv` à root avec `chown`.
  + Donnez `pionnieres.csv` à l’un de vos groupes secondaires avec `chgrp`, puis tentez de le donner au groupe
    `root`.
  + Copiez `/etc/passwd` dans `copie-passwd` : à qui appartient la copie ?
]

#indice(titre: [Indice : qui peut quoi])[
  Changer le propriétaire d’un fichier est réservé à root. Son propriétaire peut changer son groupe, mais
  seulement pour un groupe dont il est membre.
]

#corrige[
  `/etc/passwd` est lisible par tous ; `/etc/shadow` seulement par root et le groupe `shadow`. `chown` est refusé
  à un compte ordinaire, de même que `chgrp` vers un groupe dont on n’est pas membre. Une copie est un nouveau
  fichier : il appartient à qui l’a créé. Remplacez `etudiants` par l’un de vos groupes.
  #sortie("etape-6.sortie")
  #f("etape-6.sh")
]

= Étape 7 : liens physiques et symboliques <etape-7>

Un fichier est un *inode* (son contenu et ses droits) ; un nom de répertoire pointe vers lui. Un *lien physique*
(`ln`) est un nom de plus pour le même inode : le nombre de liens de `ls -l` le compte. Un *lien symbolique*
(`ln -s`) est un petit fichier, de type `l`, qui contient un chemin.

#bloc(role: "question")[Consignes][
  + Créez `rapport-dur.txt`, lien physique vers `documents/rapport.txt`, et `rapport-lien.txt`, lien symbolique
    vers le même. Comparez avec `ls -li` : inode, nombre de liens, type, taille.
  + Ajoutez une ligne par `rapport-dur.txt`, puis affichez `documents/rapport.txt`.
  + Renommez `documents/rapport.txt` en `documents/rapport-2026.txt`. Que deviennent les deux liens ?
  + Réparez le lien symbolique.
  + Tentez un lien physique vers le répertoire `documents`.
]

#indice(titre: [Indice : réparer])[
  `ln -s` refuse d’écraser un nom qui existe ; `-f` (_force_) le remplace.
]

#corrige[
  Les deux noms physiques ont le même inode et un nombre de liens de 2 : c’est le même fichier, et l’ajout se lit
  par l’un comme par l’autre. Le renommage ne change rien pour le lien physique, qui désigne l’inode ; le lien
  symbolique contient toujours le chemin `documents/rapport.txt`, qui n’existe plus : il pointe dans le vide.
  Sa taille, 21 octets, est la longueur de ce chemin.
  #sortie("etape-7.sortie")
  #f("etape-7.sh")
]

= Étape 8 : jokers et find <etape-8>

Le joker `*` remplace n’importe quelle suite de caractères ; c’est le shell qui le remplace par les noms du
répertoire, avant de lancer la commande. `find` cherche dans toute une arborescence : `find point-de-départ critères`.

#bloc(role: "question")[Consignes][
  + Listez les fichiers `.txt` du répertoire courant, puis les comptes rendus de réunion de `documents/notes`.
  + Avec `find`, depuis `~/fichiers` : tous les `.txt`, sous-répertoires compris ; tous les répertoires ; les fichiers
    de plus de 10 Kio ; ce qui est vide ; les liens symboliques ; les fichiers modifiés depuis moins d’un jour.
  + Rendez exécutables tous les scripts `.sh` de `scripts`, en une commande `find`.
  + Cherchez dans `/etc` les noms qui commencent par `host`, en écartant les messages d’erreur.
]

#indice(titre: [Indice : les critères])[
  `-name '*.txt'` (entre guillemets, pour que le shell ne remplace pas le joker trop tôt), `-type f` (fichier),
  `-type d` (répertoire), `-type l` (lien), `-size +10k`, `-empty`, `-mtime -1`. `-exec commande {} +` lance la
  commande sur les noms trouvés. `find` rend les noms dans l’ordre où le disque les range : `| sort` les trie.
]
#indice(titre: [Indice : les erreurs])[
  Un compte ordinaire ne peut pas lire certains répertoires de `/etc` : `find` le signale sur l’erreur standard,
  qu’on redirige vers `/dev/null` (#d("redirections")[Rediriger vers un fichier]).
]

#corrige[
  `ls *.txt` ne regarde que le répertoire courant ; `find` descend partout. `-mtime -1` trouve les fichiers créés
  ou modifiés pendant ce TP ; `chmod` ne change pas la date de modification d’un fichier. Sans guillemets,
  `find . -name *.txt` recevrait les noms du répertoire courant à la place du motif.
  #sortie("etape-8.sortie")
  #f("etape-8.sh")
]

= Étape 9 : archiver et compresser <etape-9>

`tar` regroupe un répertoire en un seul fichier, l’*archive* : `-c` crée, `-t` liste, `-x` extrait, `-f` nomme
l’archive, `-z` compresse ou décompresse avec gzip. `.tar.gz` dit ce qui a été fait : archivé, puis compressé.

#bloc(role: "question")[Consignes][
  + Archivez `journaux` dans `journaux.tar`, puis dans `journaux.tar.gz`. Comparez les tailles avec celle du
    journal. Listez le contenu de l’archive compressée sans l’extraire.
  + Extrayez-la dans un répertoire `restauration`, puis vérifiez avec `diff -r` qu’elle est identique à l’original.
  + Compressez `journaux/serveur.log` seul, en gardant l’original. Affichez sa dernière ligne sans le
    décompresser sur le disque.
  + Lancez le script de sauvegarde du cours, `scripts/sauvegarde.sh`, sur `documents`. Listez l’archive produite,
    supprimez `documents`, puis restaurez-le.
]

#indice(titre: [Indice : les options])[
  `tar -tzf archive` liste ; `-C répertoire` extrait ailleurs que dans le répertoire courant. `gzip -k` garde
  l’original ; `zcat` décompresse vers la sortie standard. Le script :
  #d("sauvegarder-dossier")[Exemple : sauvegarder un répertoire].
]

#bloc(role: "danger")[Supprimer avant d’avoir vérifié l’archive][
  `rm -r documents` ne se fait qu’après avoir listé l’archive : une sauvegarde qu’on n’a jamais relue n’en est
  pas une.
]

#corrige[
  Le texte se compresse bien : l’archive compressée pèse moins d’un dixième du journal. L’archive non compressée
  est plus grosse que le journal : `tar` ajoute un en-tête par fichier et complète l’archive par blocs.
  `diff -r` ne dit rien quand les répertoires sont identiques, et réussit : `&&` lance alors `echo`. À l’extraction,
  un compte ordinaire reçoit des droits filtrés par son umask ; `tar -p` garde ceux de l’archive.
  #sortie("etape-9.sortie")
  #f("etape-9.sh")
  D’autres compresseurs existent : `.tar.xz` (`tar -J`, paquet `xz-utils`) compresse mieux, plus lentement.
]
