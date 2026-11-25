#!/bin/bash
# Étape 2 : Ada clone le dépôt central, encore vide, y enregistre un premier commit et le publie.
cd ~/collab || exit 1
git clone depot-central.git ada
cd ada || exit 1
# sans --global : l'identité de ce dépôt seulement
git config user.name "Ada Lovelace"
git config user.email ada@example.org
printf '%s\n' '# Site du club' '' 'Responsable : Ada.' > README.md
git add README.md
git commit -m "Ajout du README"
git push -u origin main
git status
