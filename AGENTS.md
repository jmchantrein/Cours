# Consignes pour les agents

La charte graphique est dans [`commun/README.md`](commun/README.md) (rôles, pictogrammes, schémas, variantes) ;
la structure pédagogique des diapos dans [`.claude/skills/structurer-diapos-cours/SKILL.md`](.claude/skills/structurer-diapos-cours/SKILL.md) ;
l’organisation et la compilation dans [`README.md`](README.md).

- Range chaque support selon sa nature : diapos dans `<cours>/cm/`, séance de TP dans `<cours>/tp/<tp>/`,
  artefact interactif dans `<cours>/artefacts/<nom>/`.
- Dans un cours, déclare des rôles : `bloc(role: …)`, `note`, `encadre`, `corrige` + `reponse`, `cadre(niveau: …)`.
- Prends les couleurs dans la charte (`c.*`, `roles.*`) ; écris toute couleur nouvelle dans `commun/charte.typ`.
- Choisis le rôle d’après le sens du bloc, selon le tableau de `commun/README.md`.
- Pour un besoin visuel nouveau, ajoute un rôle ou un composant à la charte, avec sa couleur dans chaque palette.
- Après une modification de diapos, compile chaque variante dans `build/` et vérifie qu’elle a le nombre de pages
  de la projection, plus une (la légende).
- Versionne les sources seulement : les PDF et les `index.html` sont compilés par la CI et publiés sur le site ;
  git les ignore.
- Pour créer ou réviser des diapos, applique les règles de structure de `structurer-diapos-cours`.
- Écris un énoncé de TP en Typst avec `commun/theme-tp.typ` ; après une modification, compile la page en HTML
  dans `build/` et ouvre-la dans un navigateur.
- Écris chaque corrigé de TP comme un fichier réel sous `corrige/`, affiché par `fichier(…)` dans un bloc `corrige`.
- Aligne un TP sur son cours : mêmes commandes, même vocabulaire ; renvoie aux diapos par `diapo(…)`.
- Déclare les paquets `apt` qu’un harnais demande à son hôte dans `paquets-apt.txt`, à côté de lui ; la CI les installe.
- Un harnais ne tient compte d’un proxy qui réécrit TLS que par `TPTEST_CA=/chemin/ca.crt` (avec `HTTPS_PROXY`).
- Après une modification de corrigés, lance `<cours>/tp/<tp>/tester.sh --lint`, et `--up` quand Docker a accès au réseau.
- Écris un artefact sans dépendance externe : une page Typst, un script, un style qui emploie les variables CSS de la charte.
- Déclare le terminal d’une page par `page-web(terminal: …)` : `("compagnon",)` pour Docker ou libvirt, `("vm", "compagnon")`
  pour un TP shell. Ses dépendances tierces sont fixées en version et en SHA-256 (`commun/terminal/dependances.txt`,
  `go.sum`), téléchargées par la CI et servies par le site : ni CDN, ni fichier tiers dans git.
- Après une modification du terminal, lance `commun/terminal/tester-vm.mjs`, `compagnon/tester.py` et
  `tester-navigateur.js` (voir `commun/README.md`).
- Fais reposer un artefact sur le modèle énoncé dans le cours, et relie-le à la diapo et au TP concernés.
- Après une modification d’artefact, déroule ses expériences dans un navigateur et vérifie les résultats annoncés dans ses réponses.
- Fais tenir un artefact dans la fenêtre sans défilement de la page : vérifie de 1280 × 650 à 1920 × 950 px,
  chaque réponse ouverte, que rien n’est rogné.
- Donne à chaque expérience d’un artefact une recette jouable, et vérifie qu’elle aboutit au résultat de sa réponse.
- Vérifie chaque commande d’une recette : continuer, pause au milieu d’une étape, reprise, revenir (y compris
  pendant une étape), enchaînement sans pause, reprise en main à la fin.
- Calcule chaque explication d’un artefact à partir du résultat de la simulation ; pour un cas que le simulateur
  ne sait pas traiter, affiche « Limitation du simulateur : … ».
- Confronte un simulateur à l’outil réel avant de le publier, et après toute modification de son modèle
  (`verifier-buildkit.js` pour le cache de build).
