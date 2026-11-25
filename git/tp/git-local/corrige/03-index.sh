#!/bin/bash
# Étape 3 : un fichier déjà suivi et modifié n'entre dans un commit qu'après git add.
cd ~/mon_projet || exit 1
echo '<p>Ceci est un paragraphe.</p>' >> index.html
git status --short
# sans git add, l'index n'a pas changé : git commit refuse, rien n'est enregistré
git commit -m "Ajout d'un paragraphe"
git add index.html
git status --short
git commit -m "Ajout d'un paragraphe"
