# Cours « Fondements de la conteneurisation »

- `cm/` : les diapos, avec les notes de l’orateur, dans `conteneurisation.typ`. PDF compilé :
  [`conteneurisation-projection.pdf`](cm/conteneurisation-projection.pdf).
  `cm/rejouer.sh` rejoue sur un Debian 13 les commandes dont la sortie est marquée « à rejouer » dans les notes
  de l’orateur, et relève les versions : `./rejouer.sh > sorties-conteneurisation.txt 2>&1`.
- `tp/wordpress/` : le TP « Conteneuriser WordPress ». Énoncé dans `wordpress.typ`, compilé en `index.html` ;
  corrigés dans `corrige/`, vérifiés par `./tester.sh --up` (Docker, accès au réseau).

Compilation et charte : voir le [README racine](../README.md) et [`../commun/README.md`](../commun/README.md).
