// Artefact « Avant d’exécuter, Bash réécrit la ligne » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/artefacts/expansions-bash/expansions-bash.typ shell/artefacts/expansions-bash/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/shell-projection.pdf"

#show: page-web.with(
  titre: [Avant d’exécuter, Bash réécrit la ligne],
  surtitre: [Fondements de l’administration système GNU/Linux · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Bash découpe la ligne en mots, développe chaque mot, puis retire les guillemets : la commande reçoit la liste d’arguments
    qui en résulte. Les guillemets doubles empêchent le découpage et les chemins, les simples tout.
    #diapo(pdf, "ordre-expansions")[Avant d’exécuter, Bash réécrit la ligne] ·
    #diapo(pdf, "guillemets")[Les guillemets décident des expansions]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : premiers pas dans le shell], "../../tp/premiers-pas/#etape-1"),
    ([TP : du pipeline au script robuste], "../../tp/scripts/#etape-6"),
  ),
)

#artefact(read("expansions-bash.js"), style: read("expansions-bash.css"))[
  #experiences(
    ([Avec `p="Ada Lovelace"`, combien d’arguments `printf '[%s]\n'` reçoit-il après le format pour `$p`, puis `"$p"`, puis `'$p'` ?
        (Le simulateur compte le format avec les autres : il écrit « 3 arguments (le format compris) » pour deux mots.)],
      [Deux arguments après le format (`Ada`, `Lovelace`) : hors guillemets, l’étape 4 recoupe la valeur aux espaces. Un seul (`Ada Lovelace`, soit 2 affichés avec le format) entre
        guillemets doubles : la valeur est insérée, mais ni découpée ni cherchée sur le disque. Entre guillemets simples,
        le dollar est un caractère ordinaire : l’argument après le format est `$p`
        (#diapo(pdf, "exercice-expansions")[l’exercice : combien de mots ?]).], "guillemets"),
    ([`*.txt` et `$motif` (qui vaut `*.txt`) : que reçoit la commande sans guillemets, puis entre guillemets doubles ?],
      [`*.txt` donne trois noms de fichiers (4 arguments avec le format), comme `$motif` : la valeur développée à l’étape 3 passe par l’étape 5.
        Entre guillemets, `"*.txt"` et `"$motif"` restent le texte `*.txt` ; si aucun fichier ne correspondait,
        Bash laisserait aussi le motif tel quel
        (#diapo(pdf, "guillemets")[le tableau des guillemets]).], "chemins"),
    ([`cd $dossier` avec `dossier="Mon dossier important"`, puis `[ $nom = "Etudiant" ]` avec `nom` vide : que reçoivent `cd` et `[`,
        avec et sans guillemets autour de la variable ?],
      [`cd` reçoit trois arguments sans guillemets, un seul avec. `[` reçoit `=`, `Etudiant`, `]` : la variable vide a disparu et `=`
        n’a plus d’opérande à gauche ; avec guillemets, le premier argument est vide mais présent
        (#diapo(pdf, "guillemets")[les guillemets décident]). Le TP « Du pipeline au script robuste » en tire `"$dossier"/*`.], "vide"),
    ([`"$fichierext"` et `"${fichier}.${ext}"` : que valent-ils ? Et `${p}{a,b}`, puis `"${p}"{a,b}` ?],
      [`$fichierext` est la variable `fichierext`, qui n’existe pas : argument vide ; les accolades de `${fichier}` délimitent le nom
        (#diapo(pdf, "accolades")[les accolades délimitent le nom]). Les accolades `{a,b}` sont développées à l’étape 2, avant les
        variables : `${p}{a,b}` donne quatre arguments après le format (`Ada`, `Lovelacea`, `Ada`, `Lovelaceb` : 5 affichés avec lui), `"${p}"{a,b}` deux (3 affichés).], "accolades"),
    ([Une ligne proche de celle de la diapo « Voir les mots produits » : quelles étapes modifient chaque mot ? Elle emploie `$p`
        à la place de `$nom` et n’a pas `$((6 * 7))`, que le simulateur ne sait pas calculer. Et `"$(echo *.txt)"`, puis `$(echo *.txt)` ?],
      [`{1..2}` : étape 2 ; `~`, `$p`, `$(echo ok)` : étape 3 ; `$p` nu : étape 4 ; `*.txt` : étape 5 ; les guillemets partent à l’étape 6.
        `"$(echo *.txt)"` donne un seul argument après le format, `ada.txt grace.txt hedy.txt` (la substitution a cherché les fichiers dans son `echo`), sans
        guillemets trois arguments
        (#diapo(pdf, "ordre-expansions")[l’ordre des expansions]).], "ligne"),
  )
  #note(role: "precaution")[Le simulateur suit le sous-ensemble de Bash vu en cours (mots, guillemets, `$nom`, `${nom}`, `$(echo …)`,
    accolades, tilde, `*` et `?`). Tout le reste (arithmétique, `${x:-…}`, `$@`, tubes, `[…]`…) est signalé « Limitation du simulateur ». Les noms de fichiers sont triés dans l’ordre des octets (locale `C.UTF-8`, celle des sorties du cours).
    Dans le chemin, un fond teinté marque le résultat d’une expansion, un trait ce que des guillemets protègent, `·` une espace, `∅` un argument vide.]
]
