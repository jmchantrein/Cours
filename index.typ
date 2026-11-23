// Page d’accueil du site des cours — compilée en index.html par la CI.
//   typst compile --root . --font-path commun/fonts --features html --format html index.typ index.html

#import "commun/theme-tp.typ": *

#show: page-web.with(
  titre: [Cours],
  surtitre: [Cours · LERIA],
  sous-titre: [Diapositives, travaux pratiques et artefacts interactifs],
  auteur: [Jean-Mathieu Chantrein],
  racine: "",
  sommaire: false,
  liens: (([Sources], depot),),
)

// Les diapos d’un cours : le rendu de projection en bouton, les rendus adaptés en liens.
#let pdf(cours, v) = cours + "/cm/" + cours + "-" + v + ".pdf"
#let rendus(cours) = html.elem("p", attrs: (class: "variantes"))[
  Diapositives en rendu adapté :
  #variantes.filter(v => v != "projection").map(v => link(pdf(cours, v), v)).join([, ]).
]

#cartes(
  carte([Fondements de la conteneurisation], illustration: "couches")[
    Du chroot à Docker : images, conteneurs, persistance, sécurité, réseau, Dockerfile, Compose, puis les
    orchestrateurs.
    #actions(
      bouton(principal: true, [Diapositives], pdf("conteneurisation", "projection")),
      bouton([TP : conteneuriser WordPress], "conteneurisation/tp/wordpress/"),
      bouton([Artefact : le cache de build], "conteneurisation/artefacts/cache-de-build/"),
    )
    #rendus("conteneurisation")
  ],
  carte([Fondements de la virtualisation de machines], illustration: "vm")[
    Émulation et virtualisation, assistance matérielle, hyperviseurs, QEMU et KVM, libvirt, avec un mini TP :
    une VM, puis une VM dans la VM.
    #actions(
      bouton(principal: true, [Diapositives], pdf("virtualisation", "projection")),
    )
    #rendus("virtualisation")
  ],
)

#note(role: "notion")[Le menu *Accessibilité*, en haut de chaque page, propose les rendus adaptés des
  diapositives : palettes pour les daltonismes et l’achromatopsie, mise en page pour la dyslexie. Votre choix
  est mémorisé.]
