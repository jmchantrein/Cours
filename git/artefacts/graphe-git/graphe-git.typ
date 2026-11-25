// Artefact « Le graphe des commits » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     git/artefacts/graphe-git/graphe-git.typ git/artefacts/graphe-git/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/git-projection.pdf"

#show: page-web.with(
  titre: [Le graphe des commits],
  surtitre: [Git : versionner et collaborer · artefact],
  // Le modèle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Chaque commit désigne son parent ; une branche n’est qu’un pointeur vers un commit, et `HEAD` désigne la
    branche courante. Un commit fait avancer la branche courante, et elle seule. `merge` : avance rapide, ou commit à deux
    parents ; `rebase` : de nouveaux commits ; `reset` : déplace la branche, puis remet l’index et le répertoire selon le mode.
    #diapo(pdf, "pointeurs")[Branches et HEAD : de simples pointeurs]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : Git en local, étape 7 (branches)], "../../tp/git-local/#etape-7"),
    ([étape 8 (fusion)], "../../tp/git-local/#etape-8"),
    ([étape 10 c (reset)], "../../tp/git-local/#etape-10c"),
    ([TP : Git à plusieurs, étape 8 (rebaser)], "../../tp/git-distant/#etape-8"),
  ),
)

#artefact(read("graphe-git.js"), style: read("graphe-git.css"))[
  #experiences(
    ([Un commit sur `main`, puis la branche `contact` : placez-vous dessus et faites-y un commit. Revenez sur `main` et
      faites-y un commit aussi. Que désignent `main`, `contact` et `HEAD` ? Quels commits ont le même parent ?],
      [`main` désigne D, `contact` désigne C, et `HEAD` désigne `main`. Chaque commit n’a fait avancer que la branche sur
        laquelle `HEAD` se trouvait (#diapo(pdf, "pointeurs")[un commit avance la branche courante, et elle seule]) ;
        `switch` n’a déplacé que `HEAD`. C et D ont le même parent, B : l’histoire se sépare
        (#diapo(pdf, "graphe")[deux commits peuvent avoir le même parent]).], "pointeurs"),
    ([`contact` a un commit de plus que `main`, qui n’a pas bougé depuis. Placez-vous sur `main` et fusionnez `contact`.
      Quelle sorte de fusion, et le graphe gagne-t-il un commit ?],
      [Avance rapide : `main` (B) est un ancêtre de `contact` (C), il n’y a rien à combiner. `main` avance jusqu’à C, et
        le graphe ne gagne aucun commit (#diapo(pdf, "fusion")[avance rapide ou commit de fusion]). Le pointeur
        avance, rien d’autre.], "avance-rapide"),
    ([Chaque branche reçoit un commit depuis leur ancêtre commun. Fusionnez `style` dans `main`, puis relancez la même
      fusion. Combien de parents a le commit de fusion ? Que dit la seconde commande ?],
      [Les deux lignes ont divergé depuis B : le commit de fusion E a deux parents, D (`main`) puis C (`style`), et
        `style` n’a pas bougé (#diapo(pdf, "fusion")[le commit de fusion]). La même fusion relancée affiche
        « Already up to date » : C est déjà un ancêtre de `main`, il n’y a rien à fusionner, rien ne bouge.], "fusion"),
    ([`faq` a deux commits depuis A ; `main` en a un. Rebasez `faq` sur `main`, puis fusionnez `faq` dans `main`. Que
      deviennent les commits de `faq` ? Quelle fusion obtient-on ?],
      [Le rebasage rejoue B et C au-dessus de D : de nouveaux commits E et F, même changement, autre parent. B et C ne
        sont plus sur aucune branche : en tirets, `git reflog` les retrouve
        (#diapo(pdf, "rebasage")[rebaser : rejouer ses commits ailleurs] ; #diapo(pdf, "reflog")[reflog]). Ensuite
        `main` est un ancêtre de `faq` : la fusion est une avance rapide, et l’historique reste une ligne.], "rebasage"),
    ([Un commit B, défait trois fois par `reset` : `--soft`, `--mixed` puis `--hard`. Où est passé son fichier à chaque
      fois, et comment revient-on à B ?],
      [Les trois modes déplacent `main` de B à A ; B passe en tirets. `--soft` laisse `b.txt` dans l’index (`A  b.txt`),
        `--mixed` le laisse dans le répertoire sans l’indexer (`?? b.txt`), `--hard` l’efface du répertoire : plus rien
        dans `git status`. On revient à B par `reset --hard B`, que `git reflog` désigne
        (#diapo(pdf, "reset-modes")[trois modes] ; #diapo(pdf, "reflog")[reflog]). Ici rien n’est perdu : le
        fichier vivait dans un commit. Une modification jamais enregistrée, `--hard` l’efface pour de bon.], "reset"),
  )
]
