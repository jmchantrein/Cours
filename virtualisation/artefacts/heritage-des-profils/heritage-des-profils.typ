// Artefact « L’héritage des profils » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     virtualisation/artefacts/heritage-des-profils/heritage-des-profils.typ virtualisation/artefacts/heritage-des-profils/index.html
// L’état de départ est l’exemple des diapos « Profils : une configuration réutilisable » et « Héritage des
// profils : deux régimes » : profils default et moyen, instance v2 lancée avec --config limits.cpu=4.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/virtualisation-projection.pdf"
#let tp = "../../tp/incus/"

#show: page-web.with(
  titre: [L’héritage des profils],
  surtitre: [Fondements de la virtualisation de machines · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux : celle de la diapo.
  sous-titre: [Ordre : les profils, dans l’ordre donné, puis l’instance. Clés : le dernier qui définit la clé
    l’emporte. Périphériques : à nom égal, le dernier remplace l’autre en entier.
    #diapo(pdf, "incus-profils")[Héritage des profils]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP Incus, étape 5 : profils et cloud-init], tp + "#etape-5"),
  ),
)

#artefact(read("heritage-des-profils.js"), style: read("heritage-des-profils.css"))[
  #experiences(
    ([Le profil `moyen` dit `limits.cpu=2`, l’instance `v2` dit `4`. Combien de processeurs pour `v2` ? Et si un
        troisième profil, `petit`, s’en mêle ?],
      [4 : l’instance passe après tous ses profils, quel que soit leur ordre. Entre profils, le dernier de la
        liste qui définit la clé l’emporte, clé par clé : `incus profile add` ajoute en fin de liste,
        `incus profile assign` redonne toute la liste. Et `incus config unset` ne supprime pas la limite : la
        valeur d’un profil réapparaît.], "cles"),
    ([Le profil `moyen` sert à `v2` et à `v3`. Vous le modifiez : quelles instances changent ?],
      [Toutes celles qui l’utilisent, aussitôt, sans les recréer : elles ne copient pas le profil, elles le lisent.
        Seule exception, une clé que l’instance définit elle-même : `v2` garde ses 4 processeurs.
        #diapo(pdf, "incus-profils-commandes")[Profils : une configuration réutilisable]], "profil-partage"),
    ([Le `root` de `moyen` répète `path=/` et `pool=default`, que `default` donne déjà. Peut-il ne porter que
        `size=20GiB` ?],
      [Non. Les périphériques ne fusionnent pas clé par clé : à nom égal, le dernier remplace l’autre en entier,
        entre profils comme entre l’instance et ses profils.
        #diapo(pdf, "incus-profils")[Héritage des profils]], "peripherique-entier"),
    ([À quoi sert `incus config device override` ?],
      [À modifier un périphérique hérité sans rien perdre : la commande le copie en entier dans l’instance, puis y
        pose les clés données. En une fois : `incus config device override v2 root size=30GiB`. Le revers : la
        copie ne suit plus le profil. Le TP fixe ainsi l’adresse d’une VM
        (#link(tp + "#etape-4")[TP, étape 4]).], "override"),
    ([Le profil `default` donne `eth0` à toutes ses instances. Comment le retirer à `v3` seule ?],
      [Pas avec `incus config device remove` : `eth0` n’appartient pas à l’instance. On lui ajoute un périphérique
        du même nom, de type `none` : il remplace en entier celui du profil et ne crée rien. C’est la règle du
        remplacement entier, employée exprès ; `v2` garde son `eth0`.], "none"),
  )
]
