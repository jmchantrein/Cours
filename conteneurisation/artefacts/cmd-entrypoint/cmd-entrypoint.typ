// Artefact « CMD × ENTRYPOINT » — page web compilée par Typst (voir commun/README.md, « Artefacts »).
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     conteneurisation/artefacts/cmd-entrypoint/cmd-entrypoint.typ conteneurisation/artefacts/cmd-entrypoint/index.html

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/conteneurisation-projection.pdf"

#show: page-web.with(
  titre: [CMD × ENTRYPOINT],
  surtitre: [Fondements de la conteneurisation · artefact],
  // La règle que l’artefact fait manipuler, toujours sous les yeux.
  sous-titre: [Le conteneur exécute `ENTRYPOINT` puis `CMD`, mis bout à bout. Les arguments de `run` remplacent `CMD` ;
    `--entrypoint` remplace `ENTRYPOINT` et efface `CMD` ; la forme shell passe par `/bin/sh -c`.
    #diapo(pdf, "cmd-entrypoint")[CMD × ENTRYPOINT : la commande lancée]],
  sommaire: false,
  atelier: true,
  liens: (
    ([Diapos du cours], pdf),
    ([TP : conteneuriser WordPress], "../../tp/wordpress/"),
  ),
)

#artefact(read("cmd-entrypoint.js"), style: read("cmd-entrypoint.css"))[
  #experiences(
    ([`ENTRYPOINT ["e1", "e2"]` et `CMD ["c1", "c2"]`. Que reçoit `e1` sans argument, puis avec `x y` ?],
      [Sans argument : `e1 e2 c1 c2` ; avec `x y` : `e1 e2 x y`. Les arguments de `run` remplacent `CMD`, jamais
        `ENTRYPOINT` (#diapo(pdf, "cmd-entrypoint")[le tableau]).], "arguments-de-run"),
    ([`ENTRYPOINT` en forme shell : `x y` est-il pris en compte ? Qui porte le PID 1 ?],
      [Non : `sh` les reçoit comme `$0` et `$1`, et `e1 e2` ne les emploie pas. `sh` est PID 1 et ne relaie pas
        `SIGTERM` : l’arrêt attend 10 s (#diapo(pdf, "forme-exec")[l’arrêt]).], "forme-shell"),
    ([`CMD` en forme shell derrière un `ENTRYPOINT` en forme exec : que devient-il ? Et sans `ENTRYPOINT` ?],
      [Trois paramètres de plus : `e1 e2 /bin/sh -c "c1 c2"`, `e1` est PID 1. Sans `ENTRYPOINT`, il lance
        `/bin/sh -c "c1 c2"` : `sh` est PID 1.], "cmd-en-forme-shell"),
    ([Ni `ENTRYPOINT` ni `CMD` dans le Dockerfile : que lance un conteneur de `debian:13` ? Et avec un `ENTRYPOINT` ?],
      [`bash`, le `CMD` hérité de `debian:13`. Un `ENTRYPOINT` déclaré remet ce `CMD` hérité à vide
        (`Config.Cmd` vaut `null`) : `bash` ne s’ajoute pas. Une base sans commande : _no command specified_.], "cmd-herite"),
    ([`--entrypoint e3` avec un `CMD` dans l’image : que devient le `CMD` ? Et avec `x y` ?],
      [`--entrypoint` remplace `ENTRYPOINT` et efface `CMD` : `e3` seul. Avec `x y` : `e3 x y`.], "option-entrypoint"),
  )
]
