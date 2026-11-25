// TP « sed et awk : exercices progressifs » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/tp/sed-awk/sed-awk.typ build/shell/sed-awk.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.
// Sorties : rejouées commande par commande sur ces fichiers (Debian 13 : GNU sed 4.9, mawk 1.3.4), locale C.UTF-8 ;
// tester.sh --up les compare à corrige/attendu/ sous mawk, gawk et BusyBox.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/shell-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [sed et awk : exercices progressifs],
  surtitre: [Shell : Bash, sed et awk · travaux pratiques],
  sous-titre: [Substituer, adresser, capturer et modifier avec sed ; filtrer, calculer et agréger avec awk ;
    puis durcir un fichier `sshd_config` avec les deux],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tube",
  terminal: ("vm", "compagnon"),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/shell/tp/sed-awk/corrige"),
    ([Manuel de GNU sed], "https://www.gnu.org/software/sed/manual/sed.html"),
    ([Manuel de GNU awk], "https://www.gnu.org/software/gawk/manual/gawk.html"),
  ),
)

= Avant de commencer <avant>

Le cours a présenté sed (#d("cycle-sed")[Le cycle de sed : une ligne à la fois]) puis awk
(#d("modele-awk")[awk : enregistrements, champs, motif → action]), et proposé quatre exercices pour chacun
(#d("exercice-sed")[À vous : sed sur les données], #d("exercice-awk")[À vous : awk sur les données]). Ce TP les
prolonge : treize exercices en onze étapes, des mêmes fichiers, du plus simple au cas d’administration réel. Les
étapes 2 à 5 n’emploient que sed, les étapes 6 à 9 que awk ; l’étape 10 transforme `services.conf` en tableau ;
l’étape 11 durcit un fichier `sshd_config` avec sed, puis relit le résultat avec awk.

#bloc(role: "pratique")[Prérequis][
  - Un terminal Bash : celui de la page, ou le vôtre (Debian, Ubuntu, WSL, macOS). Rien à installer : `sed` et
    `awk` font partie du système.
  - Les trois diapositives de départ : #d("sed-substitution")[Substituer], #d("sed-adresses")[Adresser],
    #d("awk-champs")[Les champs : \$1, \$2…].
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels : à chaque
  modification, un harnais les rejoue dans un conteneur Debian 13 et compare leur sortie à celle montrée ici, sous
  `mawk` (l’`awk` par défaut de Debian, 1.3.4), sous `gawk` (5.2) et sous BusyBox. Les sorties sont les mêmes
  partout, sauf l’ordre de `for (… in …)` (étape 9). Sous macOS, `sed -i` demande un argument de plus
  (#d("sed-in-place")[-i : modifier le fichier, avec une copie de secours]).
]

= Étape 1 : préparer l’atelier <etape-1>

#bloc(role: "question")[Consignes][
  - Créez le dossier `~/tp-sed-awk` et placez-vous dedans : tout le TP s’y déroule.
  - Recréez-y `pionnieres.csv` (#d("fil-rouge")[Le fil rouge : pionnieres.csv]), `services.conf`, et un extrait de
    `sshd_config`, le fichier de configuration du serveur SSH, avec les commandes ci-dessous.
  - Vérifiez les nombres de lignes : 9, 15 et 28.
]

#terminal[```console
$ mkdir -p ~/tp-sed-awk
$ cd ~/tp-sed-awk
$ printf '%s\n' 'nom;annee;domaine;contribution' \
  'Lovelace Ada;1843;programmation;premier programme publié' \
  "Booth Kathleen;1947;langages;premier langage d'assemblage" \
  'Hopper Grace;1952;langages;premier compilateur A-0' \
  'Johnson Katherine;1962;calcul;trajectoires de Friendship 7' \
  "Hamilton Margaret;1969;logiciel;logiciel embarqué d'Apollo 11" \
  'Conway Lynn;1978;materiel;révolution VLSI' \
  'Perlman Radia;1985;reseau;protocole spanning tree' \
  'Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste' \
  > pionnieres.csv
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
  > services.conf
$ printf '%s\n' '# This is the sshd server system-wide configuration file.  See' \
  '# sshd_config(5) for more information.' \
  '' \
  'Include /etc/ssh/sshd_config.d/*.conf' \
  '' \
  '#Port 22' \
  '#ListenAddress 0.0.0.0' \
  '' \
  '# Authentication:' \
  '' \
  '#PermitRootLogin prohibit-password' \
  '#PubkeyAuthentication yes' \
  '' \
  '# To disable tunneled clear text passwords, change to "no" here!' \
  '#PasswordAuthentication yes' \
  '#PermitEmptyPasswords no' \
  '' \
  'KbdInteractiveAuthentication no' \
  'UsePAM yes' \
  '' \
  'X11Forwarding yes' \
  'PrintMotd no' \
  '' \
  '# Allow client to pass locale and color environment variables' \
  'AcceptEnv LANG LC_* COLORTERM NO_COLOR' \
  '' \
  '# override default of no subsystems' \
  > sshd_config
$ printf 'Subsystem\tsftp\t/usr/lib/openssh/sftp-server\n' >> sshd_config
$ wc -l pionnieres.csv services.conf sshd_config
   9 pionnieres.csv
  15 services.conf
  28 sshd_config
  52 total
```]

#note[`printf '%s\n'` écrit chacun de ses arguments suivi d’un saut de ligne ; l’antislash en fin de ligne
continue la commande. Les lignes qui contiennent une apostrophe sont entre guillemets doubles
(#d("guillemets")[Les guillemets décident des expansions]). L’extrait de `sshd_config` reprend, dans l’ordre,
des lignes du fichier installé par le paquet `openssh-server` de Debian 13. Les trois fichiers sont aussi dans les
corrigés : #link("corrige/donnees/pionnieres.csv")[`pionnieres.csv`],
#link("corrige/donnees/services.conf")[`services.conf`],
#link("corrige/donnees/sshd_config")[`sshd_config`].]

= Étape 2 : substituer <etape-2>

#bloc(role: "question")[Consignes][
  Sur `pionnieres.csv`, avec `sed`, en n’affichant que les trois premières lignes (`| head -n 3`) :
  + remplacez le premier `;` de chaque ligne par ` | ` ;
  + remplacez tous les `;` de chaque ligne par ` | `.
  Que devient le fichier `pionnieres.csv` ?
]

#indice(titre: [Indice : la commande s])[
  `s/motif/remplacement/drapeaux` : #d("sed-substitution")[Substituer : s/motif/remplacement/drapeaux]. Sans
  drapeau, `s` ne remplace que la première correspondance de chaque ligne ; le drapeau `g` les remplace toutes.
]

#corrige[
  #f("sed-1-substitution.sh")
  #terminal[```console
$ sed 's/;/ | /' pionnieres.csv | head -n 3
nom | annee;domaine;contribution
Lovelace Ada | 1843;programmation;premier programme publié
Booth Kathleen | 1947;langages;premier langage d'assemblage
$ sed 's/;/ | /g' pionnieres.csv | head -n 3
nom | annee | domaine | contribution
Lovelace Ada | 1843 | programmation | premier programme publié
Booth Kathleen | 1947 | langages | premier langage d'assemblage
```]
  `sed` écrit sur sa sortie standard et ne touche pas au fichier : `pionnieres.csv` est inchangé. Pour modifier
  le fichier, il faut `-i` (étape 5).
]

= Étape 3 : adresser par numéro, par motif, par plage <etape-3>

#bloc(role: "question")[Consignes][
  + Affichez les lignes 2 à 4 de `pionnieres.csv`, et rien d’autre.
  + Affichez `services.conf` sans ses lignes de commentaire (celles qui commencent par `#`) ni ses lignes vides.
  + Affichez la section `[base_de_donnees]` seule, de son en-tête à la ligne vide qui la termine.
  + Passez à 8443 le port de la section `[web]` *seulement*, et vérifiez que les deux autres ports n’ont pas
    bougé : `| grep -n '^port'`.
]

#indice(titre: [Indice : n’afficher que ce qu’on demande])[
  `-n` coupe l’affichage automatique ; la commande `p` affiche. `d` supprime la ligne. `^` ancre le motif en
  début de ligne, `$` en fin de ligne : une ligne vide est `^$`. Les adresses :
  #d("sed-adresses")[Adresser : numéro, plage, motif].
]
#indice(titre: [Indice : une plage entre deux motifs])[
  `/début/,/fin/` désigne les lignes de la première qui contient `début` à la suivante qui contient `fin`. Une
  commande placée après une adresse ne s’applique qu’aux lignes adressées : `/plage/ s/…/…/`. Les crochets sont
  spéciaux dans une expression régulière : écrivez `\[web\]` pour le texte `[web]`.
]

#corrige[
  Les questions 1 et 2 :
  #f("sed-2-adresses.sh")
  #terminal[```console
$ sed -n '2,4p' pionnieres.csv
Lovelace Ada;1843;programmation;premier programme publié
Booth Kathleen;1947;langages;premier langage d'assemblage
Hopper Grace;1952;langages;premier compilateur A-0
$ sed '/^#/d; /^$/d' services.conf
[web]
port = 8080
user = www-data
autostart = yes
[base_de_donnees]
port = 5432
user = postgres
autostart = yes
[sauvegarde]
port = 0
user = backup
autostart = no
```]
  Les questions 3 et 4 :
  #f("sed-3-plages.sh")
  #terminal[```console
$ sed -n '/^\[base_de_donnees\]/,/^$/p' services.conf
[base_de_donnees]
port = 5432
user = postgres
autostart = yes

$ sed '/^\[web\]/,/^$/ s/^port = .*/port = 8443/' services.conf | grep -n '^port'
3:port = 8443
8:port = 5432
13:port = 0
```]
  La plage de la question 3 s’arrête sur la ligne vide et l’affiche, d’où la ligne vide après `autostart = yes`.
  Dans la question 4, la substitution n’a lieu que dans la plage de `[web]` : les lignes 8 et 13 gardent leur
  port, `grep -n` montrant leurs numéros.
]

= Étape 4 : capturer et réordonner <etape-4>

#bloc(role: "question")[Consignes][
  Dans `pionnieres.csv`, chaque ligne commence par « Nom Prénom ». Affichez, pour chaque pionnière (sans la ligne
  d’en-tête), une ligne de la forme `Ada Lovelace (1843)` : prénom, nom, puis l’année entre parenthèses, rien d’autre.
]

#indice(titre: [Indice : les groupes])[
  Avec `-E`, une paire de parenthèses capture un morceau du motif ; `\1`, `\2`… le restituent dans le remplacement :
  #d("sed-captures")[Groupes de capture : réutiliser ce qu’on a trouvé]. `[^;]+` désigne un ou plusieurs
  caractères autres que `;` ; `[^ ;]+`, ni espace ni `;`. `.*` en fin de motif absorbe la fin de la ligne.
]
#indice(titre: [Indice : par où commencer])[
  Écrivez d’abord le motif qui décrit toute la ligne : nom (sans espace), espace, prénom (sans `;`), `;`, année
  (quatre chiffres : `[0-9]{4}`), `;`, le reste. Mettez trois paires de parenthèses, puis ordonnez `\2`, `\1`, `\3`
  dans le remplacement. Pour l’en-tête : `1d`, séparé du `s` par un `;`.
]

#corrige[
  #f("sed-4-captures.sh")
  #terminal[```console
$ sed -E '1d; s/^([^ ;]+) ([^;]+);([0-9]{4});.*/\2 \1 (\3)/' pionnieres.csv
Ada Lovelace (1843)
Kathleen Booth (1947)
Grace Hopper (1952)
Katherine Johnson (1962)
Margaret Hamilton (1969)
Lynn Conway (1978)
Radia Perlman (1985)
Shafi Goldwasser (1982)
```]
  Le groupe 1 (`[^ ;]+`) prend le nom, jusqu’à l’espace ; le groupe 2 (`[^;]+`) le prénom, jusqu’au `;` ; le
  groupe 3 l’année. Le `.*` final fait entrer le reste de la ligne dans la correspondance, donc dans ce qui est
  remplacé : il n’apparaît pas à l’affichage. Un prénom composé passerait dans le groupe 2, puisqu’il accepte les
  espaces.
]

= Étape 5 : modifier le fichier avec -i <etape-5>

#bloc(role: "question")[Consignes][
  Sur une *copie* de `services.conf`, nommée `services.copie`, commentez toute la section `[sauvegarde]` (un `# `
  devant chacune de ses lignes), *dans le fichier*, en gardant l’original sous `services.copie.bak`. Montrez le
  résultat avec `diff`.
]

#indice(titre: [Indice : -i et sa copie de secours])[
  `-i.bak` modifie le fichier et garde l’original sous le même nom suivi de `.bak` :
  #d("sed-in-place")[-i : modifier le fichier, avec une copie de secours]. `s/^/# /` insère `# ` en début de
  ligne ; `diff avant après` montre les lignes qui diffèrent.
]
#indice(titre: [Indice : jusqu’où va la plage])[
  La section `[sauvegarde]` est la dernière : aucune ligne vide ne la termine. Que fait une plage
  `/début/,/fin/` quand `fin` ne se présente jamais ?
]

#corrige[
  #f("sed-5-en-place.sh")
  #terminal[```console
$ cp services.conf services.copie
$ sed -i.bak '/^\[sauvegarde\]/,/^$/ s/^/# /' services.copie
$ diff services.copie.bak services.copie
12,15c12,15
< [sauvegarde]
< port = 0
< user = backup
< autostart = no
---
> # [sauvegarde]
> # port = 0
> # user = backup
> # autostart = no
```]
  Une plage dont la fin ne vient jamais court jusqu’à la dernière ligne : les quatre lignes de `[sauvegarde]`
  sont commentées. Sans `-i`, la même commande n’aurait rien écrit dans le fichier ; avec `-i` seul, l’original
  aurait disparu. Réflexe : essayer sans `-i`, puis avec `-i.bak`.
]

= Étape 6 : les champs d’awk <etape-6>

#bloc(role: "question")[Consignes][
  Avec `awk`, sur `pionnieres.csv` :
  + affichez le domaine puis le nom des trois premières pionnières, sans l’en-tête, sous la forme
    `langages: Booth Kathleen` ;
  + affichez le nombre de champs de la ligne 2 et son dernier champ, sans écrire de numéro de colonne ;
  + vérifiez que chaque ligne du fichier compte le même nombre de champs : une seule valeur doit sortir.
]

#indice(titre: [Indice : séparateur, numéro de ligne, nombre de champs])[
  Le séparateur par défaut est l’espace ; `-F';'` le remplace. `NR` est le numéro de la ligne lue, `NF` le nombre
  de ses champs, `$NF` le dernier : #d("awk-champs")[Les champs : \$1, \$2… et le séparateur -F]. Un motif peut
  combiner des conditions : `NR > 1 && NR <= 4`.
]
#indice(titre: [Indice : une seule valeur])[
  Affichez `NF` pour chaque ligne et laissez `sort -u` ne garder qu’un exemplaire de chaque valeur.
]

#corrige[
  #f("awk-1-champs.sh")
  #terminal[```console
$ awk -F';' 'NR > 1 && NR <= 4 { print $3 ": " $1 }' pionnieres.csv
programmation: Lovelace Ada
langages: Booth Kathleen
langages: Hopper Grace
$ awk -F';' 'NR == 2 { print NF " champs, le dernier : " $NF }' pionnieres.csv
4 champs, le dernier : premier programme publié
$ awk -F';' '{ print NF }' pionnieres.csv | sort -u
4
```]
  Les deux points de `: ` sont du texte entre guillemets, concaténé aux champs : deux expressions côte à côte
  n’ont pas besoin d’opérateur. Quatre champs partout : le fichier est sain. Une ligne qui contiendrait un `;`
  de trop ferait sortir une seconde valeur.
]

= Étape 7 : des motifs, des comparaisons <etape-7>

#bloc(role: "question")[Consignes][
  Avec `awk`, sur `pionnieres.csv` :
  + affichez les lignes entières dont le domaine est `langages`, sans action `{ … }` ;
  + affichez, année d’abord, puis nom, les contributions de 1950 à 1979 (1950 inclus, 1980 exclu).
]

#indice(titre: [Indice : motif seul, motif et action])[
  Un motif sans action affiche la ligne. `==` compare : `$3 == "langages"`. `&&` combine deux conditions. Sans
  `NR > 1`, l’en-tête passerait la comparaison de nombres comme une ligne : `nom` n’est pas un nombre.
]
#indice(titre: [Indice : nombre ou chaîne ?])[
  Un champ qui ressemble à un nombre se compare comme un nombre à une constante *sans* guillemets :
  `$2 >= 1950`. Avec des guillemets (`$2 >= "1950"`), awk compare des chaînes, caractère par caractère :
  #d("awk-comparaison")[Comparer : nombre ou chaîne ?].
]

#corrige[
  #f("awk-2-motifs.sh")
  #terminal[```console
$ awk -F';' '$3 == "langages"' pionnieres.csv
Booth Kathleen;1947;langages;premier langage d'assemblage
Hopper Grace;1952;langages;premier compilateur A-0
$ awk -F';' 'NR > 1 && $2 >= 1950 && $2 < 1980 { print $2, $1 }' pionnieres.csv
1952 Hopper Grace
1962 Johnson Katherine
1969 Hamilton Margaret
1978 Conway Lynn
```]
  Sur ces données, la comparaison de chaînes `$2 >= "1950" && $2 < "1980"` donnerait le même résultat, par chance : toutes les
  années ont quatre chiffres. Dès qu’une valeur en a trois (`"100" < "30"`, vrai : « 1 » vient avant « 3 »), le
  filtre se trompe sans rien signaler. Écrivez les nombres sans guillemets.
]

= Étape 8 : BEGIN, END et un accumulateur <etape-8>

#bloc(role: "question")[Consignes][
  En une seule commande `awk` : afficher le titre `Contributions :`, puis, après la lecture du fichier, le nombre de
  pionnières et l’année moyenne de leur contribution, sous la forme `8 pionnières, année moyenne 1952.25`.
]

#indice(titre: [Indice : avant, pendant, après])[
  Le bloc `BEGIN { … }` s’exécute avant la première ligne, `END { … }` après la dernière :
  #d("awk-begin-end")[Calculer, puis résumer avec END]. Entre les deux, une action avec `NR > 1` accumule :
  `somme += $2` ; `n++`. Une variable jamais affectée vaut 0.
]

#corrige[
  #f("awk-3-begin-end.sh")
  #terminal[```console
$ awk -F';' 'BEGIN { print "Contributions :" }
           NR > 1 { somme += $2; n++ }
           END { print n, "pionnières, année moyenne", somme / n }' pionnieres.csv
Contributions :
8 pionnières, année moyenne 1952.25
```]
  Le programme tient sur plusieurs lignes dans les apostrophes : le shell attend la fermeture de la seconde
  apostrophe avant de lancer `awk`. Les huit années totalisent 15 618, divisées par 8 : 1952,25.
]

= Étape 9 : un tableau associatif <etape-9>

#bloc(role: "question")[Consignes][
  Comptez les contributions par *décennie* (1840, 1940, 1950…), sans l’en-tête : une ligne `décennie nombre` par
  décennie, rangées de la plus ancienne à la plus récente. Que constatez-vous si vous retirez le `sort -n` ?
]

#indice(titre: [Indice : un compteur par clé])[
  `n[clé]++` crée la case au premier passage et l’incrémente ensuite :
  #d("awk-tableaux")[Tableaux associatifs : compter par domaine]. `int($2 / 10) * 10` ramène l’année à sa
  décennie : `int` garde la partie entière. `for (d in n) print d, n[d]` parcourt les clés dans un ordre non défini.
]

#corrige[
  #f("awk-4-tableaux.sh")
  #terminal[```console
$ awk -F';' 'NR > 1 { d = int($2 / 10) * 10; n[d]++ } END { for (d in n) print d, n[d] }' pionnieres.csv | sort -n
1840 1
1940 1
1950 1
1960 2
1970 1
1980 2
```]
  `for (d in n)` ne promet aucun ordre, et `mawk` et `gawk` n’ont pas le même : c’est `sort -n`, hors d’`awk`,
  qui range les décennies, pour que la sortie ne dépende pas de l’implémentation. Comparez avec la sortie sans
  `sort -n` dans votre terminal : elle peut varier d’un système à l’autre.
]

= Étape 10 : une section par ligne <etape-10>

#bloc(role: "question")[Consignes][
  Transformez `services.conf` en tableau : une ligne par section, avec le nom de la section, son port et son
  démarrage (`web 8080 yes`), dans l’ordre du fichier. Le commentaire du début ne doit rien produire.
]

#indice(titre: [Indice : retenir la section courante])[
  Une ligne qui commence par `[` ouvre une section : `/^\[/`. `substr($0, 2, length($0) - 2)` retire les deux
  crochets. Gardez le nom dans une variable `s` ; les lignes `port = …` et `autostart = …` suivantes la
  retrouveront. Découpées sur les espaces, `port = 8080` a trois champs : la valeur est `$3`.
]
#indice(titre: [Indice : garder l’ordre])[
  Rangez le nom de chaque section dans un tableau indexé par un compteur (`ordre[++n] = s`), puis parcourez
  `for (i = 1; i <= n; i++)` dans `END` : l’ordre du fichier est celui des indices, ce que `for (… in …)` ne
  garantit pas.
]

#corrige[
  #f("awk-5-sections.sh")
  #terminal[```console
$ awk '/^\[/ { s = substr($0, 2, length($0) - 2); ordre[++n] = s }
     $1 == "port" { port[s] = $3 }
     $1 == "autostart" { auto[s] = $3 }
     END { for (i = 1; i <= n; i++) print ordre[i], port[ordre[i]], auto[ordre[i]] }' services.conf
web 8080 yes
base_de_donnees 5432 yes
sauvegarde 0 no
```]
  Trois tableaux, `ordre`, `port` et `auto`, indexés respectivement par un rang et par un nom de section. Le
  commentaire de la ligne 1 n’ouvre pas de section et ne contient pas de champ `port` : il ne produit rien.
]

= Étape 11 : durcir un fichier sshd_config <etape-11>

#bloc(role: "question")[Consignes][
  Sur `sshd_config` (l’extrait de l’étape 1, sans danger : ce n’est pas le fichier du système) :
  + affichez les directives actives, sans commentaires ni lignes vides ;
  + durcissez le fichier *en place*, avec une copie de secours : `PasswordAuthentication no` et
    `PermitRootLogin no`, que la ligne soit commentée ou non, en capturant le nom de la directive plutôt qu’en le
    réécrivant ; montrez le résultat avec `diff` ;
  + relisez le résultat avec `awk` : les deux directives avec leur numéro de ligne, puis le nombre de directives
    actives.
]

#indice(titre: [Indice : la question 1])[
  C’est l’étape 3 : supprimer les lignes qui commencent par `#`, puis les lignes vides.
]
#indice(titre: [Indice : la question 2])[
  `#?` rend le `#` facultatif ; `(A|B)` capture l’un ou l’autre mot ; `\1` le restitue, avec `-E` :
  #d("sed-regex")[Expressions régulières : basiques ou étendues]. Le motif décrit la ligne entière, jusqu’à sa
  fin : `.*`. Pensez à `-i.bak`, comme à l’étape 5.
]
#indice(titre: [Indice : la question 3])[
  `$1 == "A" || $1 == "B"` retient les deux directives ; `NR` donne leur numéro de ligne. Une ligne vide a `NF`
  égal à 0 : `NF` seul est vrai pour une ligne non vide. `!/^#/ && NF` retient les directives actives.
]

#corrige[
  #f("sshd-1-directives.sh")
  #terminal[```console
$ sed '/^#/d; /^$/d' sshd_config
Include /etc/ssh/sshd_config.d/*.conf
KbdInteractiveAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_* COLORTERM NO_COLOR
Subsystem	sftp	/usr/lib/openssh/sftp-server
```]
  #f("sshd-2-durcir.sh")
  #terminal[```console
$ sed -E -i.bak 's/^#?(PasswordAuthentication|PermitRootLogin) .*/\1 no/' sshd_config
$ diff sshd_config.bak sshd_config
11c11
< #PermitRootLogin prohibit-password
---
> PermitRootLogin no
15c15
< #PasswordAuthentication yes
---
> PasswordAuthentication no
```]
  #f("sshd-3-verifier.sh")
  #terminal[```console
$ awk '$1 == "PasswordAuthentication" || $1 == "PermitRootLogin" { print NR ": " $0 }' sshd_config
11: PermitRootLogin no
15: PasswordAuthentication no
$ awk '!/^#/ && NF { n++ } END { print n, "directives actives" }' sshd_config
9 directives actives
```]
  Le motif `^#?(PasswordAuthentication|PermitRootLogin) .*` désigne ces deux directives, commentées ou non ; la
  capture évite une faute de frappe dans le remplacement. Les lignes 11 et 15 du fichier changent, et elles
  seules. L’extrait compte sept directives actives au départ, neuf après : les deux lignes décommentées s’y ajoutent.
]

#bloc(role: "precaution")[Sur un vrai serveur][
  Ce que vous venez de faire sur un extrait ne se fait pas tel quel sur `/etc/ssh/sshd_config` :
  - il faut `sudo` ; gardez *une session SSH ouverte* pendant que vous testez, sans quoi une erreur vous enferme
    dehors ; vérifiez d’abord la syntaxe avec `sudo sshd -t` ;
  - sur Debian 13, la ligne `Include /etc/ssh/sshd_config.d/*.conf` est *en tête* du fichier, et sshd garde la
    *première* valeur lue : un fichier de `sshd_config.d` qui dit `PasswordAuthentication yes` l’emporte sur votre
    `no` ; `sudo sshd -T | grep -i passwordauthentication` montre la valeur effective ;
  - pour que votre réglage gagne, écrivez-le dans un fichier de `sshd_config.d` lu avant les autres (`00-…conf`).
]

#bloc(role: "retenir")[Ce que ce TP a montré][
  - sed travaille ligne à ligne et n’écrit que sur sa sortie ; `-i.bak` modifie le fichier en gardant l’original.
  - Une adresse (numéro, motif, plage) choisit les lignes ; sans adresse, la commande vaut pour toutes.
  - Les groupes de capture réordonnent ou conservent des morceaux de ligne : `\1`, `\2`.
  - awk découpe chaque ligne en champs ; `motif { action }` filtre et calcule ; `BEGIN` et `END` encadrent la
    lecture.
  - Un nombre se compare sans guillemets ; les guillemets font comparer des chaînes.
  - Un tableau associatif compte ou regroupe, mais `for (… in …)` ne promet aucun ordre : triez à part.
]
