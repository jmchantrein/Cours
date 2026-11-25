// Artefact « Le typage des scalaires YAML » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     edition-formats/artefacts/typage-yaml/typage-yaml.typ edition-formats/artefacts/typage-yaml/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/edition-formats-projection.pdf"

#show: page-web.with(
  titre: [Le typage des scalaires YAML],
  surtitre: [Éditer et structurer du texte · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Un scalaire nu prend le type dont il a la forme, selon les motifs de la version de YAML que suit l’analyseur ;
    entre guillemets, c’est une chaîne. JSON réécrit ensuite l’arbre lu.
    #diapo(pdf, "yaml-typage")[Le typage implicite des scalaires] ·
    #diapo(pdf, "yaml-json-correspondance")[YAML et JSON : une même structure]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : décrire des livres en YAML et en JSON], "../../tp/yaml-json/#etape-5"),
  ),
)

#artefact(read("typage-yaml.js"), style: read("typage-yaml.css"))[
  #experiences(
    ([Écrivez `NO` sans guillemets : quel type et quelle valeur en YAML 1.1 (PyYAML), puis en 1.2 (ruamel.yaml) ? Et `yes` ? Et `"NO"` ?],
      [En 1.1, `NO` est le booléen `False` (motif _yes, no, on, off_) ; en 1.2, le schéma de base ne connaît que `true` et
        `false` : c’est la chaîne `'NO'`. Même chose pour `yes`. Entre guillemets, c’est une chaîne dans les deux versions
        (#diapo(pdf, "yaml-norvege")[le problème de la Norvège]).], "norvege"),
    ([`0644`, puis `0o644` : que valent-ils selon la version ? Et `'0644'` entre guillemets simples ?],
      [`0644` est l’entier 420 en 1.1 (octal) et 644 en 1.2 (décimal) ; `0o644` est la chaîne `'0o644'` en 1.1 et l’entier 420
        en 1.2 ; `'0644'` est une chaîne partout : une cote ou des droits s’écrivent entre guillemets
        (#diapo(pdf, "yaml-pieges")[octal, base 60, versions, dates]).], "octal"),
    ([`22:22` (un port de Compose), puis `1:30` : que lit chaque version ? Et `"22:22"` ?],
      [En 1.1, `22:22` est un entier en base 60 : 22 × 60 + 22 = 1342, et `1:30` vaut 90. En 1.2, ce sont des chaînes.
        Entre guillemets, `"22:22"` est une chaîne partout.], "base-60"),
    ([`2026-11-25` : quel type, et que devient-il en JSON ? Et `"2026-11-25"` ? Et `2026-13-45` ?],
      [Une date dans les deux lectures, mais pas pour la même raison : en 1.1, c’est le schéma ; en 1.2, le schéma de base n’a
        pas de type date, et c’est ruamel.yaml qui en construit une, hors schéma. JSON n’a pas de date : `json.dumps` échoue (_TypeError_). Entre guillemets, c’est une
        chaîne, qui s’écrit sans difficulté. `2026-13-45` a la forme d’une date, pas la valeur : le document est refusé
        (_ValueError : month must be in 1..12_).], "date-json"),
    ([Mode document : `norvege.yaml`, puis corrigé (`"NO"`, `true`), puis avec `mode: 0644`. Où les versions divergent-elles ?],
      [`norvege.yaml` donne deux JSON différents (`false` ou `"NO"`, `true` ou `"yes"`). Corrigé, les deux versions lisent le
        même arbre. `mode: 0644` les fait diverger de nouveau (420 ou 644)
        (#diapo(pdf, "yaml-json-correspondance")[l’arbre commun]).], "document-json"),
  )
]
