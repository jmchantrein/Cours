#!/bin/bash
# Étape 8 : avant de pousser, Ada rejoue son commit au-dessus de celui de Grace : un historique linéaire.
cd ~/collab/grace || exit 1
echo 'Réunion le jeudi, à 18 h.' > agenda.md
git commit -am "Heure des réunions"
git push
cd ~/collab/ada || exit 1
echo 'Fermé les jours fériés.' >> horaires.md
git commit -am "Jours fériés"
git push
git pull --rebase
git log --oneline --graph -3
git push
cd ~/collab/grace || exit 1
git pull
git log --oneline --graph -3
