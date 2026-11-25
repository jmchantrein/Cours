# Cours

Supports de cours de Jean-Mathieu Chantrein : un dossier par cours, une charte commune.
Le site : <https://jmchantrein.github.io/Cours/>. Ce dépôt contient les sources ; les PDF et les pages web sont
compilés par la CI et publiés sur le site.

| Cours | Diapos | Rendus adaptés | Sources |
|---|---|---|---|
| Fondements de la conteneurisation | [`conteneurisation-projection.pdf`](https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-projection.pdf) | [deutéranopie](https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-deuteranopie.pdf) · [protanopie](https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-protanopie.pdf) · [tritanopie](https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-tritanopie.pdf) · [achromatopsie](https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-achromatopsie.pdf) · [dyslexie](https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-dyslexie.pdf) | [`conteneurisation/`](conteneurisation/) · TP [Conteneuriser WordPress](https://jmchantrein.github.io/Cours/conteneurisation/tp/wordpress/) · artefact [Le cache de build](https://jmchantrein.github.io/Cours/conteneurisation/artefacts/cache-de-build/) |
| Fondements de la virtualisation de machines | [`virtualisation-projection.pdf`](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-projection.pdf) | [deutéranopie](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-deuteranopie.pdf) · [protanopie](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-protanopie.pdf) · [tritanopie](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-tritanopie.pdf) · [achromatopsie](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-achromatopsie.pdf) · [dyslexie](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-dyslexie.pdf) | [`virtualisation/`](virtualisation/) · TP [Découvrir Incus](https://jmchantrein.github.io/Cours/virtualisation/tp/incus/) · artefact [L’héritage des profils](https://jmchantrein.github.io/Cours/virtualisation/artefacts/heritage-des-profils/) |

## Rendus adaptés
Les diapos de chaque cours sont compilées en plusieurs rendus, à partir des mêmes sources ; la charte commune
(`commun/charte.typ`) applique la variante choisie à la compilation. Le rendu de projection sert en cours ;
les autres se téléchargent, pour lire les diapos dans le rendu qui convient à sa vision ou à sa lecture.

| Variante | Fichier | Pour qui, quoi |
|---|---|---|
| projection | `<cours>-projection.pdf` | La projection en cours, pour la vision typique. |
| deuteranopie | `<cours>-deuteranopie.pdf` | Daltonisme rouge-vert, la forme la plus fréquente : le vert devient bleu-vert, bien distinct de l’orange et du bleu. |
| protanopie | `<cours>-protanopie.pdf` | Daltonisme rouge-vert (insensibilité au rouge) : même palette que la deutéranopie. |
| tritanopie | `<cours>-tritanopie.pdf` | Confusion bleu-vert et jaune-violet : le vert devient violet. |
| achromatopsie | `<cours>-achromatopsie.pdf` | Vision sans couleur : les couleurs se distinguent par leur clarté. |
| dyslexie | `<cours>-dyslexie.pdf` | Lettres, mots et lignes plus espacés ; pas de capitales forcées ni d’italique. |

Les palettes sont vérifiées par simulation de chaque type de vision, et chaque rôle pédagogique porte aussi
un pictogramme (voir [`commun/README.md`](commun/README.md)). Chaque variante s’ouvre sur une page « Légende »
qui relie ses couleurs à celles de la projection.

## Organisation
Un dossier par cours, et dans chaque cours un dossier par nature de support. Les pages web renvoient les unes
aux autres : un TP vers la diapo qui porte la notion et vers l’artefact qui la fait manipuler.

- `<cours>/cm/` : le cours magistral. `<cours>.typ` contient les diapos, en [Typst](https://typst.app) avec
  [Touying](https://github.com/touying-typ/touying) ; les PDF `<cours>-<variante>.pdf` sont compilés par la CI.
  Un exercice fait et corrigé en séance reste dans les diapos.
- `<cours>/tp/<tp>/` : une séance de travaux pratiques. `<tp>.typ` contient l’énoncé, compilé par la CI en page
  web `index.html` ; `corrige/` contient les corrigés, fichiers réels que l’énoncé affiche à la demande ;
  `tester.sh` les construit et les vérifie.
- `<cours>/artefacts/<nom>/` : un artefact, petit logiciel interactif qui fait manipuler un concept.
  `<nom>.typ` le présente, `<nom>.js` et `<nom>.css` le font vivre ; la CI en tire une page web `index.html`.
- `commun/` : la charte partagée (rôles, palettes, thème des diapos, thème des pages web) et les polices
  IBM Plex ; voir [`commun/README.md`](commun/README.md).
- `index.typ` : la page d’accueil du site, compilée en `index.html`.

## Compiler
Typst 0.15 ou plus récent, depuis la racine du dépôt (Touying se télécharge seul à la première compilation).
Les diapos :

    typst compile --root . --font-path commun/fonts virtualisation/cm/virtualisation.typ build/virtualisation.pdf
    typst watch   --root . --font-path commun/fonts virtualisation/cm/virtualisation.typ build/virtualisation.pdf

Pour une variante : ajouter `--input variante=<variante>` (par exemple `--input variante=dyslexie`).

Une page web (TP, accueil) : l’export HTML de Typst est encore expérimental, d’où `--features html` ;
la version de Typst est fixée dans la CI.

    typst compile --root . --font-path commun/fonts --features html --format html conteneurisation/tp/wordpress/wordpress.typ build/wordpress.html

`--root .` autorise l’import de `commun/`. Les fichiers générés ne sont pas versionnés : git ignore `build/`,
les PDF de `<cours>/cm/` et les `index.html`. Pour suivre les liens d’une page web à l’autre, compilez-la à sa
place, à côté de sa source (`…/wordpress/index.html`).

Sur GitHub, l’action `.github/workflows/compilation-cours.yml` recompile les supports à chaque push sur `main`
touchant les sources ou la charte, et les publie sur le site, sans rien commiter.
L’action `.github/workflows/test-corriges.yml` lance, dans un job par TP, le `tester.sh` de chaque TP dont les corrigés
ont changé ; un harnais règle son job par des directives de son en-tête : `ci-delai: <minutes>` (90 par défaut) et
`ci-prerequis: incus` (installe et initialise Incus). L’action `.github/workflows/verification-artefacts.yml`
confronte l’artefact « L’héritage des profils » à un vrai Incus (`verifier-incus.js`).

Ajouter un cours : créer `<cours>/cm/<cours>.typ` qui importe `../../commun/theme-cours.typ`.
Ajouter un TP : créer `<cours>/tp/<tp>/<tp>.typ` qui importe `../../../commun/theme-tp.typ`, avec ses corrigés
dans `corrige/` et, s’ils s’exécutent, un `tester.sh`.

## Site
Le site est le dépôt, complété des supports compilés : l’action de compilation dépose l’ensemble sur
<https://jmchantrein.github.io/Cours/> par GitHub Pages (source « GitHub Actions »).
`index.html` mène aux diapos, aux TP et aux artefacts. Chaque page web embarque les variantes de rendu, que le lecteur
choisit dans la page.

## Signaler une erreur, proposer une amélioration
Ces supports peuvent contenir des erreurs. Signalez-les par une
[issue](https://github.com/jmchantrein/Cours/issues), ou proposez directement une correction ou une amélioration
par une pull request. Les propositions rédigées par une IA, ou avec son aide, sont acceptées elles aussi.

## Licences
Contenus sous CC BY-NC-SA 4.0 (voir [`LICENSE.md`](LICENSE.md)). Les polices IBM Plex de `commun/fonts/`
restent sous SIL Open Font License 1.1 (voir `commun/fonts/OFL-IBM-Plex.txt`).
