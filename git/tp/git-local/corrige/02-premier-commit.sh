#!/bin/bash
# Étape 2 : un premier fichier, ajouté à l'index, puis enregistré dans un commit.
cd ~/mon_projet || exit 1
echo '<h1>Bienvenue sur mon site</h1>' > index.html
git status --short
git add index.html
git status --short
git commit -m "Ajout de la page d'accueil"
git status
