// Artefact « Le cache de build » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     conteneurisation/artefacts/cache-de-build/cache-de-build.typ conteneurisation/artefacts/cache-de-build/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/conteneurisation-projection.pdf"

#show: page-web.with(
  titre: [Le cache de build],
  surtitre: [Fondements de la conteneurisation · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Clé d’une étape = clé de l’étape précédente + instruction + contenu des fichiers copiés. Clé connue
    du cache : couche réutilisée (`CACHED`). #diapo(pdf, "cache-buildkit")[Le cache de BuildKit]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : conteneuriser WordPress], "../../tp/wordpress/"),
  ),
)

#artefact(read("cache-de-build.js"), style: read("cache-de-build.css"))[
  #experiences(
    ([Deux builds de suite, sans rien changer : que coûte le second ?],
      [Rien : les trois clés sont dans le cache, tout est `CACHED`. Le cadre du cache marque ses couches
        « réutilisée ».], "deux-builds"),
    ([Seul le contenu de `index.php` change. Pourquoi l’installation des paquets est-elle rejouée ?],
      [Le contenu du fichier entre dans la clé du `COPY` ; et la clé du parent entre dans celle de chaque étape
        suivante, dont les 38 secondes d’installation. Le cache reçoit trois couches « créée » ; les anciennes
        passent « en réserve ».], "code-modifie"),
    ([`COPY index.php` passe sous le `RUN`. Que coûte alors une modification du code ?],
      [Deux dixièmes de seconde, le temps des deux copies : la clé de l’installation ne dépend plus du code.
        C’est la règle « instructions stables d’abord » :
        #diapo(pdf, "dockerfile-bonnes-pratiques")[Dockerfile : bonnes pratiques].], "stables-dabord"),
    ([`index.php` retrouve un contenu déjà construit. Le build est-il rejoué ?],
      [Non : le cache garde une couche par clé, pas seulement la dernière. Les couches « en réserve »
        redeviennent « réutilisée ».], "contenu-deja-construit"),
    ([Les dépôts Debian ont reçu des mises à jour de sécurité. Votre `RUN apt-get update` est-il rejoué ?],
      [Non : l’instruction n’a pas changé, sa clé non plus ; le cache ignore ce que la commande irait chercher
        sur le réseau. Pour reconstruire sans le cache : `docker image build --no-cache --pull`.], "depots-a-jour"),
  )
]
