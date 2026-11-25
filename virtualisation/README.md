# Cours « Fondements de la virtualisation de machines »

- `cm/` : les diapos, avec les notes de l’orateur, dans `virtualisation.typ`. PDF compilé :
  [`virtualisation-projection.pdf`](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-projection.pdf). `cm/rejouer-tp.sh` rejoue les sorties
  du mini TP sur une machine avec KVM.
- `tp/incus/` : le TP « Découvrir Incus », des machines virtuelles aux conteneurs système. Énoncé dans `incus.typ`,
  publié sur [le site](https://jmchantrein.github.io/Cours/virtualisation/tp/incus/) ;
  corrigés dans `corrige/`, vérifiés par `./tester.sh --up` (Incus, accès au réseau).
- `artefacts/heritage-des-profils/` : l’artefact « L’héritage des profils », simulateur de l’héritage des profils
  d’Incus lié depuis l’étape 5 du TP ; `verifier-incus.js` confronte son modèle à Incus.

Compilation et charte : voir le [README racine](../README.md) et [`../commun/README.md`](../commun/README.md).
