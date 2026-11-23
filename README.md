# Cours

Supports de cours de Jean-Mathieu Chantrein : un dossier par cours, une charte commune.

| Cours | Diapos | Rendus adaptés | Sources |
|---|---|---|---|
| Fondements de la conteneurisation | [`conteneurisation-projection.pdf`](conteneurisation/cm/conteneurisation-projection.pdf) | [deutéranopie](conteneurisation/cm/conteneurisation-deuteranopie.pdf) · [protanopie](conteneurisation/cm/conteneurisation-protanopie.pdf) · [tritanopie](conteneurisation/cm/conteneurisation-tritanopie.pdf) · [achromatopsie](conteneurisation/cm/conteneurisation-achromatopsie.pdf) · [dyslexie](conteneurisation/cm/conteneurisation-dyslexie.pdf) | [`conteneurisation/`](conteneurisation/) · TP [Conteneuriser WordPress](conteneurisation/tp/wordpress/) · artefact [Le cache de build](conteneurisation/artefacts/cache-de-build/) |
| Fondements de la virtualisation de machines | [`virtualisation-projection.pdf`](virtualisation/cm/virtualisation-projection.pdf) | [deutéranopie](virtualisation/cm/virtualisation-deuteranopie.pdf) · [protanopie](virtualisation/cm/virtualisation-protanopie.pdf) · [tritanopie](virtualisation/cm/virtualisation-tritanopie.pdf) · [achromatopsie](virtualisation/cm/virtualisation-achromatopsie.pdf) · [dyslexie](virtualisation/cm/virtualisation-dyslexie.pdf) | [`virtualisation/`](virtualisation/) |

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

`--root .` autorise l’import de `commun/`. On compile dans `build/` (ignoré par git) : les PDF et les pages
`index.html` versionnés sont produits et commités par la CI, ce qui évite les conflits sur ces fichiers générés.

Sur GitHub, l’action `.github/workflows/compilation-cours.yml` recompile les supports à chaque push sur `main`
touchant les sources ou la charte, puis commite les PDF de chaque variante et les pages web.
L’action `.github/workflows/test-corriges.yml` lance le `tester.sh` de chaque TP.

Ajouter un cours : créer `<cours>/cm/<cours>.typ` qui importe `../../commun/theme-cours.typ`.
Ajouter un TP : créer `<cours>/tp/<tp>/<tp>.typ` qui importe `../../../commun/theme-tp.typ`, avec ses corrigés
dans `corrige/` et, s’ils s’exécutent, un `tester.sh`.

## Site
Le dépôt se publie tel quel avec GitHub Pages (branche `main`, racine ; `.nojekyll` désactive Jekyll) :
`index.html` mène aux diapos, aux TP et aux artefacts. Chaque page web embarque les variantes de rendu, que le lecteur
choisit dans la page.

## Licences
Contenus sous CC BY-NC-SA 4.0 (voir [`LICENSE.md`](LICENSE.md)). Les polices IBM Plex de `commun/fonts/`
restent sous SIL Open Font License 1.1 (voir `commun/fonts/OFL-IBM-Plex.txt`).
