#!/bin/bash
# Étape 4 : git diff compare le répertoire de travail à l'index ; git diff --staged, l'index au dernier commit.
cd ~/mon_projet || exit 1
echo '<p><a href="contact.html">Contact</a></p>' >> index.html
git diff
git add index.html
# plus rien entre le répertoire de travail et l'index
git diff
git diff --staged
git commit -m "Lien vers la page contact"
