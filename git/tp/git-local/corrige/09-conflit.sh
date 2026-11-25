#!/bin/bash
# Étape 9 : la même ligne modifiée sur deux branches, un conflit, sa résolution.
cd ~/mon_projet || exit 1
git switch -c titre
sed -i 's/sur mon site/chez Ada/' index.html
git commit -am "Titre personnel"
git switch main
sed -i 's/sur mon site/sur notre site/' index.html
git commit -am "Titre collectif"
# conflit attendu : git merge s'arrête, avec un code de sortie non nul
git merge titre
git status
cat index.html
# on édite index.html (avec Vim…) : une seule ligne h1, sans marqueurs ; ici, printf réécrit le fichier
printf '%s\n' '<h1>Bienvenue chez Ada et ses amis</h1>' '<p>Ceci est un paragraphe.</p>' '<p><a href="contact.html">Contact</a></p>' > index.html
git add index.html
git status --short
git commit --no-edit
git log --oneline --graph -4
git branch -d titre
