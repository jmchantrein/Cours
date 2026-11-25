// Artefact « La chaîne d’images qcow2 » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     virtualisation/artefacts/chaine-qcow2/chaine-qcow2.typ virtualisation/artefacts/chaine-qcow2/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/virtualisation-projection.pdf"

#show: page-web.with(
  titre: [La chaîne d’images qcow2],
  surtitre: [Fondements de la virtualisation de machines · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Un disque qcow2 est fait de grappes de 64 Kio. On écrit dans l’image visée, jamais dans sa base ;
    on lit la grappe dans l’image du haut, puis dans chaque image de base, en descendant la chaîne ; introuvable,
    elle vaut zéro. #diapo(pdf, "qcow2-backing")[qcow2 : copie sur écriture et chaîne d’images]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : administrer des VM avec libvirt, étape 8], "../../tp/libvirt/#etape-8"),
  ),
)

#artefact(read("chaine-qcow2.js"), style: read("chaine-qcow2.css"))[
  #experiences(
    ([`base.qcow2` contient `0xaa` dans ses 16 grappes (1 Mio). `vm1.qcow2` s’appuie sur elle, puis écrit `0xbb` dans sa
      grappe 0. Quelle image fournit chaque grappe que lit `vm1`, et que pèsent les deux images ?],
      [La grappe 0 vient de `vm1`, les 15 autres de `base` : c’est ce que montre `qemu-img map`
        (#diapo(pdf, "backing-file")[la démonstration]). `vm1` ne garde que sa grappe écrite : 324 Kio (196 Kio de
        métadonnées, la grappe et la table L2 qu’elle a fait naître), contre 1284 Kio pour `base`, soit les « 1,3 M » de
        la diapo. `base` n’a pas changé : la grappe est copiée sur écriture, dans l’image du haut.], "ecriture-cow"),
    ([Une deuxième VM s’appuie sur la même base, puis écrit dans sa grappe 3. Que coûte-t-elle, et que lit la première VM ?],
      [Adossée, elle occupe 196 Kio, comme `vm1` : la base est partagée, pas copiée. Son écriture ajoute 128 Kio (la
        grappe et la table L2) à `vm2` seule ; `vm1` ne dépend pas de `vm2` et lit comme avant. C’est le « une VM de
        plus pour 196 Kio » (#diapo(pdf, "backing-file")[Une VM de plus]).], "vm-de-plus"),
    ([`vm1` a écrit `0xbb` dans sa grappe 0, `vm2` n’a rien écrit. On écrit `0xdd` dans la grappe 0 de la base, puis dans
      sa grappe 5. Que lisent `vm1` et `vm2` ?],
      [Grappe 0 : `vm2` lit maintenant `dd`, `vm1` garde son `bb` (sa propre grappe cache celle de la base). Grappe 5 :
        `vm1` et `vm2` lisent `dd` au lieu de `aa`. Une grappe écrite dans la base change sous les pieds des VM qui ne
        l’avaient pas réécrite : leurs disques deviennent incohérents (#diapo(pdf, "qcow2-backing")[le danger]).
        D’où une base en lecture seule, jamais démarrée.], "danger-base"),
    ([Trois étages : `base`, `vm1` (`0xbb` en grappe 1), `vm2` (`0xcc` en grappe 2). Qui fournit les grappes 0, 1 et 2 à
      `vm2` ? Que fait `qemu-img commit vm2.qcow2` ?],
      [`vm2` fournit la 2, `vm1` la 1, `base` la 0 : la recherche descend la chaîne. `commit` reverse les grappes
        propres de `vm2` dans sa base immédiate `vm1`, puis vide `vm2` : ce que lit `vm2` ne change pas, mais ses
        grappes viennent maintenant de `vm1` (#diapo(pdf, "qcow2-backing")[la chaîne, ses étages et `commit`]).
        `vm2` est vidée, mais QEMU 8.2 la réécrit : elle pèse 256 Kio, non 196.], "chaine-commit"),
    ([La même chaîne : `qemu-img rebase -b base.qcow2` sur `vm2`, sans passer par `vm1`. Que copie qemu-img dans `vm2`,
      et que lit `vm2` ensuite ? Puis `rebase` sur aucune base.],
      [Sur `base`, il copie la grappe 1 (`bb`) dans `vm2` : `base` fournit `aa` à la place, et `vm2` doit lire le même
        contenu qu’avant ; ce qu’elle lit n’a pas changé. Sur aucune base, il copie dans `vm2` toutes les
        grappes qu’elle lisait dans `base` : elle devient une image autonome, qui occupe sa taille pleine. `rebase`
        change de base sans changer ce que lit l’image (#diapo(pdf, "qcow2-backing")[la chaîne, ses étages et `rebase`]).],
      "rebase"),
  )
]
