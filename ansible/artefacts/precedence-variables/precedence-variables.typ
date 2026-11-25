// Artefact « Quelle valeur gagne ? » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     ansible/artefacts/precedence-variables/precedence-variables.typ ansible/artefacts/precedence-variables/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/ansible-projection.pdf"

#show: page-web.with(
  titre: [Quelle valeur gagne ?],
  surtitre: [Ansible : automatiser les configurations · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Une variable déclarée à plusieurs endroits : d’abord la source, selon un ordre fixe. Dans l’inventaire,
    un groupe enfant bat son parent ; à profondeur égale, la plus grande `ansible_group_priority`, puis l’ordre
    alphabétique ; l’hôte bat ses groupes. Un `vars:` de play bat `host_vars`, et `-e` bat tout.
    #diapo(pdf, "precedence-variables")[Précédence : un ordre fixe de sources]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : playbooks et variables], "../../tp/playbooks/"),
  ),
)

#artefact(read("precedence-variables.js"), style: read("precedence-variables.css"))[
  #experiences(
    ([Un rôle déclare la variable dans `defaults/`, `group_vars/all` la déclare aussi. Que voit `srv1` ? Et si le rôle la déclare encore dans `vars/` ?],
      [`group_vars/all` bat `defaults/` : les `defaults/` d’un rôle sont tout en bas de l’ordre (niveau 2), faits pour être
        surchargés. Les `vars/` du même rôle, eux, sont au niveau 15 : ils battent même le `vars:` du play
        (#diapo(pdf, "precedence-variables")[l’ordre des 22 niveaux]).], "defaults"),
    ([`host_vars/srv1` vise un seul hôte, `vars:` du play les vise tous. Lequel l’emporte ? Et si on ajoute `-e` ?],
      [Le `vars:` du play : il est plus loin dans l’ordre fixe (niveau 12 contre l’inventaire, 3 à 10), bien qu’il soit moins
        spécifique que `host_vars`. `-e` (niveau 22) bat tout. « Le plus spécifique gagne » n’est vrai qu’à l’intérieur de
        l’inventaire (#diapo(pdf, "precedence-demo")[un `vars:` de play bat `host_vars`]).], "specifique"),
    ([`srv1` est dans deux groupes frères, `prod` et `nouveaux`, qui ont chacun un `group_vars`. Qui gagne ? Et avec `ansible_group_priority: 10` sur `nouveaux`, puis sur les deux ?],
      [`prod` : même profondeur, même priorité, l’ordre alphabétique décide et le dernier chargé gagne. Avec 10 sur
        `nouveaux`, c’est `nouveaux` : la priorité passe avant l’alphabet. Avec 10 sur les deux, l’égalité renvoie à
        l’alphabet : `prod` (#diapo(pdf, "precedence-groupes")[entre groupes]).], "freres"),
    ([`web` est un enfant de `prod`. `srv1` est dans `web` et dans `nouveaux`. La priorité peut-elle faire gagner un groupe moins profond ?],
      [Non : la profondeur est comparée avant la priorité. `web` (profondeur 2) bat `nouveaux` même avec une priorité de 100.
        Seule la place dans l’arbre y change quelque chose : si `web` devient enfant direct de `all`, il passe à la
        profondeur 1 et `nouveaux` l’emporte par sa priorité.], "profondeur"),
    ([Un play, un bloc, une tâche, un `set_fact` et `-e` déclarent la même variable. Dans quel ordre l’emportent-ils ?],
      [Du plus faible au plus fort : `vars:` du play (12), du bloc (16), de la tâche (17), `set_fact` (18 à 21), `-e` (22). Le
        `set_fact` bat donc le `vars:` de la tâche qui le suit, et `-e` bat tout, `set_fact` compris.], "echelle"),
  )
]
