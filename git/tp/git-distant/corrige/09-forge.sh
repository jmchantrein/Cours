#!/bin/bash
# Étape 9 (facultative) : publier sur une forge une branche, pour y ouvrir une demande de fusion.
# Usage : ./09-forge.sh <adresse du dépôt vide créé sur la forge>
#   par exemple git@codeberg.org:ada/site-du-club.git (SSH) ou https://codeberg.org/ada/site-du-club.git
adresse="${1:?usage : $0 <adresse du dépôt créé sur la forge>}"
cd ~/collab/ada || exit 1
git remote add forge "$adresse"
git remote -v
git push forge main
git switch -c presentation
echo 'Le club se réunit pour lire, coder et partager.' >> README.md
git commit -am "Présentation du club"
git push -u forge presentation
git switch main
# puis, dans l'interface web de la forge : ouvrir une demande de fusion de presentation vers main
