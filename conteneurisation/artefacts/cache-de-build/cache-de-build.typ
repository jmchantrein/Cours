// Artefact « Le cache de build » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     conteneurisation/artefacts/cache-de-build/cache-de-build.typ build/cache-de-build.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/conteneurisation-projection.pdf"

#show: page-web.with(
  titre: [Le cache de build],
  surtitre: [Fondements de la conteneurisation · artefact],
  sous-titre: [Modifiez un Dockerfile ou un fichier, reconstruisez, et regardez quelles étapes sont rejouées],
  sommaire: false,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : conteneuriser WordPress], "../../tp/wordpress/"),
  ),
)

#bloc(role: "retenir")[La règle][
  Chaque étape d’un build a une *clé* : l’empreinte de la clé de l’étape précédente, de l’instruction, et du
  contenu des fichiers copiés. Si le cache de build connaît cette clé, la couche est réutilisée (`CACHED`) ;
  sinon l’étape est exécutée, et toutes les suivantes avec elle, puisque leur parent a changé. Le cours :
  #diapo(pdf, "cache-buildkit")[Le cache de BuildKit : la clé de chaque étape].
]

#artefact(read("cache-de-build.js"), style: read("cache-de-build.css"))

#note(role: "precaution")[C’est une simulation : les durées sont fictives et les clés sont des empreintes
  simplifiées. Les instructions, elles, se modifient librement, et les flèches les déplacent.]

= À essayer

+ Construisez deux fois de suite. Que coûte le second build ?
+ Modifiez le contenu de `index.php`, puis reconstruisez. Quelles étapes sont rejouées, et pourquoi
  l’installation des paquets l’est-elle aussi ?
+ Descendez l’instruction `COPY index.php` sous le `RUN`, reconstruisez, puis modifiez de nouveau `index.php`.
  Que coûte maintenant une modification du code ?
+ Remettez dans `index.php` un contenu que vous avez déjà construit. Le build est-il rejoué ?
+ Les dépôts Debian ont reçu des mises à jour de sécurité depuis votre dernier build. Votre `RUN apt-get update`
  est-il rejoué ? Comment l’obtenir ?

#corrige(titre: [Réponses])[
  + Rien : toutes les clés sont connues, tout est `CACHED`.
  + Le `COPY`, parce que le contenu du fichier entre dans sa clé ; puis tout ce qui suit, dont les 38 secondes
    d’installation, parce que la clé du parent entre dans la clé de chaque étape.
  + Deux dixièmes de seconde, le temps des deux copies : l’installation des paquets précède désormais le code, sa clé n’en dépend plus.
    C’est la règle « instructions stables d’abord » :
    #diapo(pdf, "dockerfile-bonnes-pratiques")[Dockerfile : bonnes pratiques].
  + Non : le cache garde une couche par clé, pas seulement la dernière. Un contenu déjà construit retrouve sa clé.
  + Non : l’instruction n’a pas changé, sa clé non plus ; le cache ignore ce que la commande irait chercher sur
    le réseau. Pour reconstruire sans le cache : `docker image build --no-cache --pull`.
]
