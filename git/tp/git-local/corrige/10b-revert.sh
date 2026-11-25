#!/bin/bash
# Étape 10 b : annuler un commit en ajoutant un commit qui le défait.
cd ~/mon_projet || exit 1
echo '<p>Promotion : -50 % ce jour</p>' >> index.html
git commit -am "Bandeau de promotion"
git log --oneline -1
# git revert prend l'identifiant lu ci-dessus ; HEAD désigne le même commit, le dernier
git revert --no-edit HEAD
git log --oneline -3
cat index.html
