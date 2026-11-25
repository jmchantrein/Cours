# Cours

Supports de cours en Typst : un dossier par cours, avec ses diapos, ses séances de TP et ses artefacts interactifs, tous bâtis sur une charte graphique commune.

## Language

### Supports

**Diapos**: le cours magistral d'un cours, écrit en Typst avec Touying dans `<cours>/cm/` et compilé en PDF. Un exercice fait et corrigé en séance y reste.
_Avoid_: slides, diapositives (en titre ou en code), présentation

**TP**: une séance de travaux pratiques, dans `<cours>/tp/<tp>/` ; son énoncé est une page web compilée depuis Typst.
_Avoid_: travaux pratiques (en toutes lettres dans le code), atelier, lab

**Corrigé**: fichier réel sous `corrige/` que l'énoncé du TP affiche à la demande et que `tester.sh` construit et vérifie.
_Avoid_: solution, correction

**Artefact**: page interactive d'un cours (simulateur + expériences).
_Avoid_: artifact, démo, widget

**Expérience**: question posée dans un artefact, avec sa réponse et, facultativement, une recette que le script sait jouer.
_Avoid_: exercice, scénario

**Recette**: suite d'étapes jouée par un artefact pour mener à la réponse d'une expérience, avec pause et explication après chaque étape.
_Avoid_: script, démo, pas-à-pas

**Charte**: les règles graphiques partagées par tous les supports, dans `commun/charte.typ` (rôles, palettes, couleurs).
_Avoid_: thème (le thème applique la charte, il ne la définit pas), style

**Rôle**: la fonction pédagogique d'un bloc (`notion`, `pratique`, `question`, `reponse`, `retenir`, `precaution`, `avertissement`, `danger`), dont la charte tire couleur et pictogramme.
_Avoid_: type de bloc, couleur du bloc

**Variante**: rendu des mêmes sources adapté à une vision ou à une lecture (projection, deutéranopie, protanopie, tritanopie, achromatopsie, dyslexie), choisi à la compilation.
_Avoid_: version, thème, mode

### Virtualisation et conteneurs

**Hôte**: la machine physique, ou le système qui la pilote, sur laquelle s'exécutent les invités ; en bleu dans les schémas.
_Avoid_: serveur (seul), machine physique, host

**Invité**: VM ou système exécuté sur l'hôte ; en violet dans les schémas.
_Avoid_: client, guest

**Instance**: ce qu'Incus crée et gère, conteneur système ou machine virtuelle ; terme d'Incus.
_Avoid_: un LXC, une machine Incus

**Conteneur système**: conteneur qui fait tourner un système complet avec son init, persistant, administré comme une machine ; réalisé par LXC sous Incus.
_Avoid_: un LXC (jargon Proxmox ; LXC est la technologie, pas l'objet manipulé), conteneur LXC pour désigner l'objet

**Machine virtuelle (VM)**: instance avec son propre noyau, exécutée par QEMU/KVM.
_Avoid_: machine seul quand l'hôte est aussi en jeu

**Conteneur applicatif**: conteneur qui fait tourner un service, éphémère, construit depuis une image (Docker, Podman).
_Avoid_: conteneur seul dans un passage qui parle aussi de conteneurs système
