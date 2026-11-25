#!/bin/bash
# Étape 6 : des fichiers que Git ne doit pas suivre, déclarés dans un .gitignore versionné.
cd ~/mon_projet || exit 1
touch acces.log
mkdir -p secrets
echo "mot-de-passe" > secrets/bdd.txt
git status --short
printf '%s\n' '# journaux' '*.log' '# jamais de secret dans le dépôt' 'secrets/' > .gitignore
git status --short
git check-ignore -v acces.log secrets/bdd.txt
git add .gitignore
git commit -m "Fichiers à ignorer"
