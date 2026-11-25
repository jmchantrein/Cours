# Licences des composants du terminal

Le site publie avec les pages des logiciels tiers, que `preparer.sh` et `compagnon/construire.sh` téléchargent ou
construisent (`vendor/`, `compagnon/dist/`, jamais versionnés). Chacun reste sous **sa propre licence** : la
licence CC BY-NC-SA 4.0 des contenus du dépôt ne s’applique pas à eux, et sa clause « pas d’utilisation
commerciale » non plus. Leur réunion sur un même site est un simple agrégat (GPLv2 §2, GPLv3 §5).

| Composant | Fichiers publiés | Licence | Avis publié | Sources |
|---|---|---|---|---|
| v86 0.5.462 | `vendor/libv86.js`, `vendor/v86.wasm` | BSD-2-Clause | `vendor/LICENSE-v86.txt` | <https://github.com/copy/v86> (paquet npm `v86@0.5.462`, révision `5f9a90f`) |
| SeaBIOS, SeaVGABIOS (BIOS de v86) | `vendor/seabios.bin`, `vendor/vgabios.bin` | LGPL-3.0 | ce fichier | <https://github.com/copy/v86/tree/5f9a90f/bios> ; amont : <https://www.seabios.org/> |
| xterm.js 6.0.0 et `@xterm/addon-fit` 0.11.0 | `vendor/xterm.js`, `vendor/xterm.css`, `vendor/addon-fit.js` | MIT | `vendor/LICENSE-xterm.txt`, `vendor/LICENSE-addon-fit.txt` | <https://github.com/xtermjs/xterm.js> |
| Image de la VM : Alpine Linux 3.22 (x86) | `vendor/vm/bzImage` (noyau `linux-virt`), `vendor/vm/initrd.gz` | noyau GPL-2.0 ; paquets sous GPL-2.0, GPL-3.0, LGPL, MIT, BSD, ISC… | `vendor/vm/paquets.txt` : chaque paquet, sa version exacte et sa licence | voir ci-dessous |
| Go 1.24.7 (bibliothèque standard et exécution, liées statiquement) | compilés dans `compagnon/dist/iadmin-terminal-*` | BSD-3-Clause | `compagnon/dist/LICENCES-modules.txt` | <https://go.dev/dl/> (archive `go1.24.7.src.tar.gz`), <https://github.com/golang/go> |
| Modules Go du compagnon : `github.com/creack/pty` 1.1.24, `github.com/coder/websocket` 1.8.14 | compilés dans `compagnon/dist/iadmin-terminal-*` | MIT ; ISC | `compagnon/dist/LICENCES-modules.txt` | <https://github.com/creack/pty>, <https://github.com/coder/websocket> |

## Sources de l’image de la VM
L’image est construite par `construire-vm.sh` à partir de l’image Docker `alpine:3.22.8` (condensé fixé dans
`dependances.txt`) et des paquets binaires Alpine listés dans `vendor/vm/paquets.txt`. Les sources
correspondantes sont celles de la distribution :
- recettes de construction (APKBUILD, correctifs) de chaque paquet : <https://gitlab.alpinelinux.org/alpine/aports>,
  branche `3.22-stable` ; chaque APKBUILD donne l’adresse et la somme de l’archive source amont ;
- noyau : paquet `linux-virt` (version dans `paquets.txt`), recette `main/linux-lts` des aports, sur les sources de
  <https://kernel.org> ;
- archives sources amont de chaque paquet, telles que les APKBUILD les nomment, copiées par Alpine sur
  <https://distfiles.alpinelinux.org/distfiles/v3.22/> ;
- BusyBox (GPL-2.0), musl (MIT), Bash, GNU coreutils, sed, gawk, findutils, tar, diffutils, grep, less (GPL-3.0) et
  Git (GPL-2.0) sont donc dans cette liste, sans copie sur ce site : l’engagement est de maintenir `paquets.txt`
  à jour avec chaque image publiée, de sorte qu’une version exacte retrouve toujours ses sources.

Seuls `vm/init`, `vm/profil.sh` et `vm/telecharger`, écrits pour ce dépôt, sont ajoutés à l’image, avec les fichiers de
départ des TP en mode `vm` (`preparer.sh`, `dojo/` : contenus du dépôt, sous sa licence CC BY-NC-SA 4.0). Parmi les
paquets, `procps-ng` (GPL-2.0 et LGPL-2.1), `bats` (MIT), `mandoc` (ISC) et les pages de manuel `*-doc` suivent leurs licences,
indiquées dans `paquets.txt`.

## Le compagnon
Le code du compagnon (`compagnon/`) est écrit pour ce dépôt. **Il n’a pas de licence logicielle propre** (le dépôt
`site`, d’où vient son protocole, n’en avait pas non plus) : il suit donc, par défaut, la licence du dépôt,
CC BY-NC-SA 4.0, mal adaptée à du code. Choisir une licence (MIT, par exemple) est une décision de l’auteur ; elle
s’écrirait dans l’en-tête de `compagnon/main.go` et dans ce fichier.
Les exécutables publiés embarquent Go et deux modules (lignes ci-dessus) ; leurs avis sont dans
`compagnon/dist/LICENCES-modules.txt`, publié à côté d’eux.
