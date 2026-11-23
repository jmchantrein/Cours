// Page d’accueil du site des cours — compilée en index.html par la CI.
//   typst compile --root . --font-path commun/fonts --features html --format html index.typ build/index.html

#import "commun/theme-tp.typ": *

#show: page-web.with(
  titre: [Cours],
  sous-titre: [Supports de cours de Jean-Mathieu Chantrein : diapositives, travaux pratiques, artefacts],
  racine: "",
  sommaire: false,
  liens: (([Sources], "https://github.com/jmchantrein/Cours"),),
)

// Les diapos d’un cours : le rendu de projection, puis les rendus adaptés.
#let diapos(cours) = {
  let pdf(v) = cours + "/cm/" + cours + "-" + v + ".pdf"
  [#link(pdf("projection"))[Diapositives] (rendus adaptés : #variantes.filter(v => v != "projection").map(v => link(pdf(v), v)).join([, ]))]
}

= Fondements de la conteneurisation
- #diapos("conteneurisation")
- Travaux pratiques : #link("conteneurisation/tp/wordpress/")[Conteneuriser WordPress]
- Artefact : #link("conteneurisation/artefacts/cache-de-build/")[Le cache de build]

= Fondements de la virtualisation de machines
- #diapos("virtualisation")

#note(role: "notion")[Chaque page web propose, en haut à droite, les mêmes rendus adaptés que les diapositives :
  palettes pour les daltonismes et l’achromatopsie, mise en page pour la dyslexie.]
