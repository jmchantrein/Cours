#!/bin/bash
# Étape 8 : une fusion par avance rapide (contact), puis un commit de fusion (style).
cd ~/mon_projet || exit 1
git merge contact
git branch -d contact
git switch -c style
echo 'h1 { color: navy; }' > style.css
git add style.css
git commit -m "Ajout d'une feuille de style"
git switch main
echo '<p>Réponse sous 48 h.</p>' >> contact.html
git commit -am "Délai de réponse"
git log --oneline --graph --all
git merge style -m "Fusion de la branche style"
git log --oneline --graph
git branch -d style
