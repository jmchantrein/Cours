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
    ([Un commit sur `main`, la branche `contact` avec un commit, puis un commit de plus sur `main`. Que désignent `main`,
      `contact` et `HEAD` ? Quels commits ont le même parent ?],
      [`main` désigne D, `contact` C, et `HEAD` désigne `main` : chaque commit n’a avancé que la branche courante
        (#diapo(pdf, "pointeurs")[un commit avance la branche courante]), `switch` n’a déplacé que `HEAD`. C et D ont
        le même parent, B : l’histoire se sépare (#diapo(pdf, "graphe")[le graphe]).], "pointeurs"),
    ([`main` n’a pas bougé depuis la création de `contact`, qui a un commit de plus. Fusionnez `contact` dans `main` :
      quelle fusion, et le graphe gagne-t-il un commit ?],
      [Avance rapide : `main` (B) est un ancêtre de `contact` (C), rien à combiner. `main` avance jusqu’à C, sans
        nouveau commit : seul le pointeur bouge (#diapo(pdf, "fusion")[avance rapide ou commit de fusion]).], "avance-rapide"),
    ([Un commit de plus sur chacune des branches `main` et `style`. Fusionnez `style` dans `main`, puis recommencez :
      combien de parents a le commit de fusion ? Que dit la seconde fusion ?],
      [Les lignes ont divergé depuis B : le commit de fusion E a deux parents, D (`main`) puis C (`style`) ; `style` n’a
        pas bougé (#diapo(pdf, "fusion")[le commit de fusion]). Recommencée, la fusion affiche « Already up to date » :
        C est déjà un ancêtre de `main`, rien ne bouge.], "fusion"),
    ([`faq` a deux commits depuis A, `main` un. Rebasez `faq` sur `main`, puis fusionnez `faq` dans `main`. Que
      deviennent les commits de `faq` ? Quelle fusion obtient-on ?],
      [Le rebasage rejoue B et C au-dessus de D : de nouveaux commits E et F, même changement, autre parent. B et C, sur
        aucune branche, passent en tirets : `git reflog` les retrouve (#diapo(pdf, "rebasage")[rebaser] ;
        #diapo(pdf, "reflog")[reflog]). `main` est alors un ancêtre de `faq` : avance rapide, historique en ligne.], "rebasage"),
    ([Un commit B, défait par `reset --soft`, `--mixed` puis `--hard`. Où est son fichier à chaque fois ? Comment
      revient-on à B ?],
      [`--soft` garde `b.txt` indexé (`A  b.txt`), `--mixed` non indexé (`?? b.txt`), `--hard` l’efface. `reset --hard B`,
        trouvé par `git reflog`, ramène à B (#diapo(pdf, "reset-modes")[modes] ; #diapo(pdf, "reflog")[reflog]). Rien
        n’est perdu : le fichier est dans B. Une modification jamais enregistrée, `--hard` l’efface pour de bon.], "reset"),
  )
]
