#!/bin/bash
# Étape 10 c : le même commit défait trois fois, par git reset --soft, --mixed, --hard.
cd ~/mon_projet || exit 1
echo '<p>Brouillon</p>' >> contact.html
git commit -am "Brouillon"
# HEAD~1 : le parent de HEAD
git reset --soft HEAD~1
git status --short
git commit -m "Brouillon"
git reset HEAD~1
git status --short
git commit -am "Brouillon"
git reset --hard HEAD~1
git status --short
tail -n 1 contact.html
