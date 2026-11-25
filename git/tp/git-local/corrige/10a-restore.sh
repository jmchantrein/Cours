#!/bin/bash
# Étape 10 a : défaire une modification qui n'est pas encore enregistrée, puis un git add.
cd ~/mon_projet || exit 1
echo '<p>une erreur' >> index.html
git status --short
git diff
git restore index.html
git status --short
echo '<p>une erreur' >> index.html
git add index.html
git status --short
git restore --staged index.html
git status --short
git restore index.html
git status --short
