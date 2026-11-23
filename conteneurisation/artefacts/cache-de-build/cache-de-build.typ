// Artefact « Le cache de build » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     conteneurisation/artefacts/cache-de-build/cache-de-build.typ conteneurisation/artefacts/cache-de-build/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/conteneurisation-projection.pdf"

#show: page-web.with(
  titre: [Le cache de build],
  surtitre: [Fondements de la conteneurisation · artefact],
  sous-titre: [Modifiez le Dockerfile ou un fichier, reconstruisez : le cache épargne-t-il l’attente ?],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : conteneuriser WordPress], "../../tp/wordpress/"),
  ),
)

#artefact(read("cache-de-build.js"), style: read("cache-de-build.css"))[
  #bloc(role: "retenir")[La règle][
    *Clé* d’une étape = clé de l’étape précédente + instruction + contenu des fichiers copiés. Clé connue du
    cache : couche réutilisée (`CACHED`). Sinon l’étape est rejouée, et toutes les suivantes avec elle.
    #diapo(pdf, "cache-buildkit")[Le cache de BuildKit].
  ]

  #experiences(
    ([Construisez deux fois de suite. Que coûte le second build ?],
      [Rien : les trois clés sont dans le cache, tout est `CACHED`. Le cadre du cache marque ses couches
        « réutilisée ».]),
    ([Modifiez le contenu de `index.php`, puis reconstruisez. Pourquoi l’installation des paquets est-elle
      rejouée ?],
      [Le contenu du fichier entre dans la clé du `COPY` ; et la clé du parent entre dans celle de chaque étape
        suivante, dont les 38 secondes d’installation. Le cache reçoit trois couches « créée » ; les anciennes
        passent « en réserve ».]),
    ([Descendez `COPY index.php` sous le `RUN`, reconstruisez, puis modifiez de nouveau `index.php`. Que coûte
      maintenant une modification du code ?],
      [Deux dixièmes de seconde, le temps des deux copies : la clé de l’installation ne dépend plus du code.
        C’est la règle « instructions stables d’abord » :
        #diapo(pdf, "dockerfile-bonnes-pratiques")[Dockerfile : bonnes pratiques].]),
    ([Remettez dans `index.php` un contenu déjà construit. Le build est-il rejoué ?],
      [Non : le cache garde une couche par clé, pas seulement la dernière. Les couches « en réserve »
        redeviennent « réutilisée ».]),
    ([Les dépôts Debian ont reçu des mises à jour de sécurité depuis votre dernier build. Votre
      `RUN apt-get update` est-il rejoué ?],
      [Non : l’instruction n’a pas changé, sa clé non plus ; le cache ignore ce que la commande irait chercher
        sur le réseau. Pour reconstruire sans le cache : `docker image build --no-cache --pull`.]),
  )
]
