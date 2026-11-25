// Artefact « L’héritage des profils » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     virtualisation/artefacts/heritage-des-profils/heritage-des-profils.typ virtualisation/artefacts/heritage-des-profils/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/virtualisation-projection.pdf"
#let tp = "../../tp/incus/"

#show: page-web.with(
  titre: [L’héritage des profils],
  surtitre: [Fondements de la virtualisation de machines · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Configuration étendue = chaque profil, dans l’ordre, puis l’instance. Clé : la dernière définition
    l’emporte. Périphérique : à nom égal, le dernier remplace l’autre en entier.
    #diapo(pdf, "incus-profils")[Les profils d’Incus]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP Incus, étape 5 : profils et cloud-init], tp + "#etape-5"),
  ),
)

#artefact(read("heritage-des-profils.js"), style: read("heritage-des-profils.css"))[
  #experiences(
    ([Les profils `wordpress` et `petit` définissent tous deux `limits.memory`. Laquelle des deux valeurs `wp-ct`
        reçoit-elle ?],
      [Celle du dernier profil de sa liste qui définit la clé. `incus profile add` ajoute en fin de liste ;
        `incus profile assign` redonne toute la liste. Le choix se fait clé par clé : `limits.cpu`, que `petit`
        ne définit pas, vient toujours de `wordpress`. De même, deux profils qui définissent
        `cloud-init.user-data` ne s’additionnent pas (#link(tp + "#etape-5")[TP, étape 5]).], "deux-profils"),
    ([`wp-ct` définit elle-même `limits.memory`. L’ordre de ses profils compte-t-il encore pour cette clé ?],
      [Non : l’instance est appliquée après tous ses profils. Et `incus config unset` ne supprime pas la limite :
        dès que l’instance ne définit plus la clé, la valeur d’un profil réapparaît.], "instance-dabord"),
    ([Le profil `wordpress` sert à `wp-vm` et à `wp-ct`. Vous le modifiez : quelles instances changent ?],
      [Toutes celles qui l’utilisent, aussitôt, sans les recréer : elles ne copient pas le profil, elles le lisent.
        Seule exception, une clé que l’instance définit elle-même : `wp-ct` garde ses `2GiB`.
        #diapo(pdf, "incus-profils")[Les profils d’Incus]], "profil-partage"),
    ([Pour fixer l’adresse de `wp-vm`, vous lui ajoutez un périphérique `eth0` qui ne porte que `ipv4.address`.
        Que deviennent `network` et `name`, que le profil `default` donnait à `eth0` ?],
      [Ils sont perdus. Les périphériques ne fusionnent pas clé par clé : à nom égal, celui de l’instance remplace
        en entier celui du profil. Il faut y recopier chaque clé : Incus refuse une carte réseau sans
        `network`.], "peripherique-entier"),
    ([À quoi sert `incus config device override` ?],
      [À modifier un périphérique hérité sans rien perdre : la commande le copie en entier dans l’instance, puis y
        pose les clés données. En une fois : `incus config device override wp-vm eth0 ipv4.address=10.0.0.10`.
        Le revers : la copie ne suit plus le profil.
        #diapo(pdf, "incus-reseau")[Le périphérique `proxy` d’une VM]], "override"),
    ([Le profil `default` donne `eth0` à toutes ses instances. Comment le retirer à `wp-ct` seule ?],
      [Pas avec `incus config device remove` : `eth0` n’appartient pas à l’instance. On lui ajoute un périphérique
        du même nom, de type `none` : il remplace en entier celui du profil et ne crée rien. C’est la règle du
        remplacement entier, employée exprès ; `wp-vm` garde son `eth0`.], "none"),
  )
]
