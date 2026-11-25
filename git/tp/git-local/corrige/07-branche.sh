#!/bin/bash
# Étape 7 : une branche contact, un commit dessus, puis retour sur main.
cd ~/mon_projet || exit 1
git switch -c contact
echo '<p>Écrire à ada@example.org</p>' > contact.html
git add contact.html
git commit -m "Ajout de la page contact"
git branch
git log --oneline --graph --all
git switch main
ls
