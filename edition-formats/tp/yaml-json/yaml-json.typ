// TP « Décrire des livres en YAML et en JSON » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     edition-formats/tp/yaml-json/yaml-json.typ build/edition-formats/yaml-json.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.
// Les sorties sont celles des paquets de Debian 13 : yq 3.4.3 (Python), jq 1.7.1, yamllint 1.37.1, PyYAML 6.0.2.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/edition-formats-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé ou fichier fourni.
#let f(chemin, lang: auto) = fichier(chemin, read(chemin), lang: lang)
#let site = "https://jmchantrein.github.io/Cours/edition-formats/tp/yaml-json/fichiers/"

#show: page-web.with(
  titre: [Décrire des livres en YAML et en JSON],
  surtitre: [Éditer et structurer du texte · travaux pratiques],
  sous-titre: [Écrire un document YAML, le valider, le convertir en JSON, factoriser par des ancres, l’interroger avec yq et jq],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/edition-formats/tp/yaml-json/corrige"),
    ([Manuel de jq], "https://jqlang.org/manual/"),
    ([YAML 1.2.2], "https://yaml.org/spec/1.2.2/"),
  ),
)

= Avant de commencer <avant>

Le cours a décrit le même arbre dans deux syntaxes : #d("yaml-json-correspondance")[YAML et JSON : une même
structure]. Ce TP le fait écrire : trois livres, en YAML puis en JSON, validés par yamllint, factorisés par des
ancres, interrogés par yq et jq. En chemin, il montre qu’un même fichier YAML ne se lit pas de la même façon
selon l’analyseur.

#bloc(role: "pratique")[Les données][
  - Livre 1 : « 1984 », de George Orwell, publié en 1949, genre Dystopie ; mots-clés : dystopie, politique,
    science-fiction.
  - Livre 2 : « Le meilleur des mondes », d’Aldous Huxley, publié en 1932, genre Dystopie ; mots-clés :
    dystopie, politique, science-fiction.
  - Livre 3 : « Les portes de la perception », d’Aldous Huxley, publié en 1954, genre Essai ; mots-clés :
    philosophie, perception, science.
  - À partir de l’étape 6 : Aldous Huxley est né en 1894, George Orwell en 1903 ; tous deux sont de nationalité
    britannique.
]

#bloc(role: "pratique")[Prérequis][
  - Un Debian 13 (ou un Ubuntu récent) et les paquets `yamllint`, `yq` et `jq` ; ils tirent `python3-yaml`, le
    module PyYAML de Python.
  - Un dossier de travail : tous les fichiers du TP y sont créés.
  - Vos fichiers YAML doivent passer `yamllint` sans remarque.
]

#terminal[```console
$ sudo apt update
$ sudo apt install yamllint yq jq
$ mkdir ~/tp-yaml && cd ~/tp-yaml
$ yq --version
yq 3.4.3
```]

#note(role: "avertissement")[Ce TP emploie le `yq` du paquet Debian : un programme en Python (dépôt `kislyuk/yq`)
qui convertit le YAML en JSON et le passe à jq ; ses filtres sont ceux de jq. Un autre programme, en Go
(`mikefarah/yq`), porte le même nom et n’accepte pas les mêmes commandes : #d("deux-yq")[Deux outils nommés yq].
Le paquet de Debian 13 est la 3.4.3 (celui d’Ubuntu 24.04, la 3.1.0) ; les sorties de ce TP sont celles de la
3.4.3. Si `yq --version` n’affiche pas `yq 3.` suivi de la version, sans autre texte, vérifiez lequel est installé.]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification, avec les paquets de Debian 13 : yamllint, égalité des données des
  fichiers YAML et JSON, lectures de PyYAML et de yq, requêtes rejouées et leur sortie comparée.
]

= Étape 1 : un livre en YAML <etape-1>

#bloc(role: "question")[Consignes][
  - Écrivez `livre.yaml`, qui décrit le livre 1 : titre, auteur, année de publication, genre et liste de
    mots-clés.
  - Validez-le avec `yamllint`.
  - Quel est le type du titre, une fois lu ? Et sans guillemets ?
]

#indice(titre: [Indice : la syntaxe])[
  Un mapping `clé: valeur` par champ, une séquence `- élément` pour les mots-clés, deux espaces par niveau :
  #d("yaml-syntaxe")[YAML : la hiérarchie par l’indentation]. Préférez des clés sans espace ni accent
  (`annee_publication`). Si vous avez fait l’exercice en séance, #d("yaml-exercice")[À vous : un livre en YAML,
  puis en JSON], reprenez votre fichier.
]

#corrige[
  #f("corrige/livre.yaml")
  #terminal[```console
  $ yamllint livre.yaml
  $ echo $?
  0
  $ yq -c '[.titre, .annee_publication] | map(type)' livre.yaml
  ["string","number"]
  ```]
  `yamllint` ne dit rien : le fichier est valide. Sans guillemets, `1984` serait lu comme le nombre 1984 : un
  scalaire nu prend le type dont il a la forme, #d("yaml-typage")[Le typage implicite des scalaires].
]

= Étape 2 : trois livres <etape-2>

#bloc(role: "question")[Consignes][
  - Écrivez `livres.yaml`, qui décrit les trois livres, avec les mêmes champs.
  - Validez-le avec `yamllint`.
]

#indice(titre: [Indice : la structure])[
  Une seule clé à la racine, `livres`, dont la valeur est une séquence ; chaque élément de la séquence est un
  mapping, celui de l’étape 1. Le `- ` d’un élément ouvre son mapping : la première clé suit le tiret, les
  autres s’alignent sur elle.
]

#corrige[
  #f("corrige/livres.yaml")
]

= Étape 3 : lire les verdicts de yamllint <etape-3>

#bloc(role: "question")[Consignes][
  - Téléchargez `livres-fautif.yaml`, un début de `livres.yaml` qui contient deux erreurs.
  - Lancez `yamllint`, corrigez l’erreur signalée, relancez-le, jusqu’à ce qu’il ne dise plus rien. Gardez le
    fichier corrigé sous le nom `livres-repare.yaml`.
  - Quelle différence entre un `error` et un `warning` ?
]

#terminal(raw(lang: "console", block: true,
  "$ curl -fsSLO " + site + "livres-fautif.yaml\n$ yamllint livres-fautif.yaml"))

#indice(titre: [Indice : voir l’invisible])[
  `cat -T` affiche une tabulation sous la forme `^I`. Un verdict se lit `ligne:colonne`, niveau, message,
  (règle) : #d("yamllint")[Valider avant d’appliquer : yamllint].
]

#corrige[
  #terminal[```console
  $ yamllint livres-fautif.yaml
  livres-fautif.yaml
    1:1       warning  missing document start "---"  (document-start)
    8:1       error    syntax error: found character '\t' that cannot start any token (syntax)
  $ cat -T livres-fautif.yaml | sed -n 7,11p
        - dystopie
  ^I- politique
        - science-fiction
    - titre: Le meilleur des mondes
       auteur: Aldous Huxley
  # dans Vim, la tabulation remplacée par six espaces : yamllint s’arrête à l’erreur suivante
  $ yamllint livres-fautif.yaml
  livres-fautif.yaml
    1:1       warning  missing document start "---"  (document-start)
    11:12     error    syntax error: mapping values are not allowed here (syntax)
  # l’espace de trop retirée, --- ajouté en tête, puis enregistré sous livres-repare.yaml
  $ yamllint livres-repare.yaml
  ```]
  Deux erreurs : une tabulation en début de ligne 8, interdite dans l’indentation, puis, ligne 11, une espace de
  trop devant `auteur` ; l’analyseur y voit la suite de la valeur du titre, puis bute sur les deux-points.
  yamllint ne signale qu’une erreur de syntaxe à la fois : l’analyse s’arrête à la première. Reste
  l’avertissement : le `---` de début de document manque. Un `error` dit que le fichier n’est pas du YAML (code
  de retour 1) ; un `warning`, que c’est du YAML, mais qu’une règle de style ou de prudence n’est pas suivie.
  #f("corrige/livres-repare.yaml")
]

= Étape 4 : convertir en JSON, et retour <etape-4>

#bloc(role: "question")[Consignes][
  - Écrivez `livres.json` à la main : les mêmes données que `livres.yaml`, en JSON.
  - Convertissez `livres.yaml` en JSON avec `yq`, puis avec `python3` et PyYAML.
  - Votre `livres.json` et celui de `yq` sont-ils identiques ? Contiennent-ils les mêmes données ? Prouvez-le.
  - Dans l’autre sens : `livres.json` est-il un fichier YAML valide ?
]

#indice(titre: [Indice : les commandes])[
  Sans option, `yq` écrit du JSON ; `-S` trie les clés, `cmp` compare deux fichiers octet par octet :
  #d("yaml-convertir")[Convertir et comparer : python3, yq, jq]. Les règles de JSON, guillemets doubles et ni
  commentaire ni virgule finale : #d("json-syntaxe")[JSON : une syntaxe stricte, six types].
]
#indice(titre: [Indice : dans l’autre sens])[
  YAML 1.2 est conçu pour qu’un document JSON soit un document YAML. Passez `livres.json` à `yq` comme s’il
  était un fichier YAML.
]

#corrige[
  #f("corrige/livres.json", lang: "json")
  #terminal[```console
  $ yq . livres.yaml > livres-yq.json
  $ cmp livres.json livres-yq.json
  livres.json livres-yq.json differ: byte 159, line 8
  $ jq -S . livres.json > a.json
  $ yq -S . livres.yaml > b.json
  $ cmp a.json b.json && echo identiques
  identiques
  $ python3 -c 'import sys, json, yaml; json.dump(yaml.safe_load(sys.stdin), sys.stdout, indent=2)' < livres.yaml > livres-python.json
  $ jq -S . livres-python.json > c.json
  $ cmp b.json c.json && echo identiques
  identiques
  $ yq -y . livres.json | head -3
  livres:
    - titre: '1984'
      auteur: George Orwell
  ```]
  Les deux fichiers JSON diffèrent par leur mise en forme : à la main, les mots-clés tiennent sur une ligne ;
  `yq` en met un par ligne. Les données sont les mêmes : `jq -S` et `yq -S` réécrivent chacun le même arbre dans
  la même forme, clés triées, et `cmp` ne trouve plus de différence. La conversion de Python, mise dans la même
  forme, donne le même fichier. Dans l’autre sens, `yq -y` lit `livres.json` comme du YAML et le réécrit en
  YAML : les commentaires et le `---` de `livres.yaml`, que JSON ne sait pas écrire, sont perdus.
]

= Étape 5 : un même fichier, deux lectures <etape-5>

#bloc(role: "question")[Consignes][
  - Téléchargez `pieges.yaml`, la fiche d’un livre écrite sans précaution.
  - Lisez-le avec `yq`, puis avec PyYAML. Pour chaque clé, notez le type et la valeur obtenus, et dites si c’est
    ce que l’auteur de la fiche voulait.
  - Que signale `yamllint` ? Que ne signale-t-il pas ?
  - Écrivez `pieges-corrige.yaml`, que les deux analyseurs lisent de la même façon, avec les types voulus : le
    titre, la cote et la durée sont des chaînes, `no` est le code de la langue norvégienne, `disponible` est un
    booléen.
]

#terminal(raw(lang: "console", block: true,
  "$ curl -fsSLO " + site + "pieges.yaml\n$ cat pieges.yaml\n$ yq -c . pieges.yaml\n"
  + "$ python3 -c 'import sys, yaml; print(yaml.safe_load(sys.stdin))' < pieges.yaml\n$ yamllint pieges.yaml"))

#f("fichiers/pieges.yaml")

Pour voir comment chaque version de YAML type un scalaire et ce que JSON en fait, essayez
#link("../../artefacts/typage-yaml/")[l’artefact « Le typage des scalaires YAML »] (mode document : `pieges.yaml`).

#indice(titre: [Indice : deux versions de YAML])[
  PyYAML suit YAML 1.1, où `yes`, `no`, `on`, `off` sont des booléens, où un nombre qui commence par 0 est en
  octal et où `7:30` est un nombre en base 60 : #d("yaml-norvege")[Le problème de la Norvège] et
  #d("yaml-pieges")[Autres pièges : octal, base 60, versions, dates]. Le `yq` de Debian ne suit exactement ni
  la 1.1 ni la 1.2 : relevez ce qu’il lit, sans le supposer.
]

#corrige[
  #terminal[```console
  $ yq -c . pieges.yaml
  {"titre":1984,"traductions":["fr","de","no"],"disponible":"yes","cote":83,"duree_lecture":"7:30","publication":"1949-06-08"}
  $ python3 -c 'import sys, yaml; print(yaml.safe_load(sys.stdin))' < pieges.yaml
  {'titre': 1984, 'traductions': ['fr', 'de', False], 'disponible': True, 'cote': 83, 'duree_lecture': 450, 'publication': datetime.date(1949, 6, 8)}
  $ yamllint pieges.yaml
  pieges.yaml
    3:23      warning  truthy value should be one of [false, true]  (truthy)
    4:13      warning  truthy value should be one of [false, true]  (truthy)
  ```]
  #bloc(role: "precaution")[Ce que chacun a lu][
    - `titre` : le nombre 1984 pour les deux ; une chaîne était voulue.
    - `no` : la chaîne `"no"` pour `yq`, le booléen `False` pour PyYAML : la Norvège disparaît.
    - `disponible: yes` : la chaîne `"yes"` pour `yq`, le booléen `True` pour PyYAML.
    - `cote: 0123` : 83 pour les deux, lu en octal ; `yq` suit ici YAML 1.1. La cote voulue était `0123`.
    - `duree_lecture: 7:30` : la chaîne `"7:30"` pour `yq`, le nombre 450 (7 × 60 + 30) pour PyYAML.
    - `publication` : une chaîne pour `yq`, une date Python pour PyYAML, que le module `json` refuse d’écrire.
  ]
  `yamllint` signale les deux valeurs « vraies ou fausses » qui ne sont pas `true` ou `false`, lignes 3 et 4 ;
  il ne dit rien du titre, de la cote, de la durée ni de la date, qui sont des valeurs valides : c’est leur
  type qui surprend. Avec des guillemets et `true`, les deux analyseurs lisent les mêmes valeurs :
  #f("corrige/pieges-corrige.yaml")
  #terminal[```console
  $ yq -cS . pieges-corrige.yaml
  {"cote":"0123","disponible":true,"duree_lecture":"7:30","publication":"1949-06-08","titre":"1984","traductions":["fr","de","no"]}
  $ python3 -c 'import sys, yaml; print(yaml.safe_load(sys.stdin))' < pieges-corrige.yaml
  {'titre': '1984', 'traductions': ['fr', 'de', 'no'], 'disponible': True, 'cote': '0123', 'duree_lecture': '7:30', 'publication': '1949-06-08'}
  ```]
]

= Étape 6 : ancres et alias <etape-6>

#bloc(role: "question")[Consignes][
  - `livres.yaml` répète l’auteur. Écrivez `livres-ancres.yaml`, où l’auteur devient un objet : nom, année de
    naissance, nationalité.
  - Par défaut, un auteur est Aldous Huxley, né en 1894, britannique : décrivez-le une seule fois, et
    réutilisez-le par un alias.
  - L’année de naissance est typée explicitement comme un entier.
  - Pour « 1984 », reprenez l’auteur par défaut et surchargez ce qui diffère. Les mots-clés peuvent rester
    répétés.
  - Validez avec `yamllint`, puis vérifiez avec `yq` que les alias sont résolus comme prévu.
]

#indice(titre: [Indice : les trois mécanismes])[
  `&nom` pose une ancre sur un nœud, `*nom` le réutilise tel quel, `<<: *nom` en recopie les clés dans un
  mapping où les clés écrites à côté l’emportent : #d("yaml-ancres")[Ancres, alias et clé de fusion]. Une
  étiquette impose un type : `!!int`.
]

#corrige[
  #f("corrige/livres-ancres.yaml")
  #terminal[```console
  $ yamllint livres-ancres.yaml
  $ yq -c '.livres[0].auteur, .livres[1].auteur' livres-ancres.yaml
  {"nom":"George Orwell","naissance":1903,"nationalite":"britannique"}
  {"nom":"Aldous Huxley","naissance":1894,"nationalite":"britannique"}
  ```]
  L’ancre est posée sur une clé à part, `auteur_defaut`, qui ne décrit aucun livre : en JSON, elle reste une clé
  de plus. Les livres 2 et 3 reprennent l’auteur par l’alias ; « 1984 » le recopie par la clé de fusion et
  remplace le nom et l’année. Sans `!!int`, `1894` serait déjà un entier : l’étiquette l’impose et le dit à qui
  lit le fichier. La clé de fusion vient de YAML 1.1 : PyYAML et `yq` l’appliquent, mais elle ne fait pas partie
  de la spécification 1.2.
]

= Étape 7 : interroger et modifier avec yq et jq <etape-7>

#bloc(role: "question")[Consignes][
  Écrivez un script `requetes.sh` qui, depuis le dossier de travail :
  - extrait avec `yq` le titre du deuxième livre de `livres.yaml` ;
  - extrait avec `yq` *uniquement les titres* des livres d’Aldous Huxley ;
  - fait la même extraction avec `jq`, sur `livres.json` ;
  - modifie en place, avec `yq`, le titre « 1984 » en « 2024 » dans `livres.yaml`.

  Sauvegardez d’abord `livres.yaml` par `cp` : le script le modifie en place. Lancez-le, puis examinez le fichier modifié.
]

#indice(titre: [Indice : les filtres])[
  `.livres[1]` est le deuxième élément : on compte à partir de 0. `.livres[]` énumère les livres,
  `select(condition)` ne garde que ceux qui la vérifient, `-r` écrit les chaînes sans guillemets :
  #d("yq-jq")[Interroger et modifier : jq et yq].
]
#indice(titre: [Indice : modifier en place])[
  `-i` modifie le fichier ; le `yq` de Debian exige alors `-y`, pour écrire du YAML. Le membre gauche d’une
  affectation peut être un chemin filtré : `(… | select(…) | .titre) = "2024"`.
]

#corrige[
  #f("corrige/requetes.sh")
  #terminal[```console
  $ cp livres.yaml livres-original.yaml
  $ chmod +x requetes.sh
  $ ./requetes.sh
  Le meilleur des mondes
  Le meilleur des mondes
  Les portes de la perception
  Le meilleur des mondes
  Les portes de la perception
  $ head -4 livres.yaml
  livres:
    - titre: '2024'
      auteur: George Orwell
      annee_publication: 1949
  $ yamllint livres.yaml
  livres.yaml
    1:1       warning  missing document start "---"  (document-start)
  $ yq -i '.livres[0].titre = "2024"' livres.yaml
  yq: -i/--in-place can only be used with -y/-Y/-t/-x
  ```]
  `yq -yi` réécrit tout le fichier à partir de l’arbre : le commentaire et le `---` disparaissent, et les
  guillemets deviennent simples. Sans `-y`, le `yq` de Debian refuse `-i` et laisse le fichier intact. Les
  filtres de `yq` et de `jq` sont les mêmes : `yq` n’est qu’un convertisseur placé devant jq.
]
