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
- Laisse la CI produire les fichiers versionnés : `<cours>/cm/<cours>-<variante>.pdf`, les `index.html` des TP,
  des artefacts et de l’accueil.
- Pour créer ou réviser des diapos, applique les règles de structure de `structurer-diapos-cours`.
- Écris un énoncé de TP en Typst avec `commun/theme-tp.typ` ; après une modification, compile la page en HTML
  dans `build/` et ouvre-la dans un navigateur.
- Écris chaque corrigé de TP comme un fichier réel sous `corrige/`, affiché par `fichier(…)` dans un bloc `corrige`.
- Aligne un TP sur son cours : mêmes commandes, même vocabulaire ; renvoie aux diapos par `diapo(…)`.
- Après une modification de corrigés, lance `<cours>/tp/<tp>/tester.sh --lint`, et `--up` quand Docker a accès au réseau.
- Écris un artefact sans dépendance externe : une page Typst, un script, un style qui emploie les variables CSS de la charte.
- Fais reposer un artefact sur le modèle énoncé dans le cours, et relie-le à la diapo et au TP concernés.
- Après une modification d’artefact, déroule ses expériences dans un navigateur et vérifie les résultats annoncés dans ses réponses.
