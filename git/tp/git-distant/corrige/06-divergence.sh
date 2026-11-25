#!/bin/bash
# Étape 6 : chacun un commit sur main, dans deux fichiers différents ; le push d'Ada est refusé.
cd ~/collab/grace || exit 1
echo 'Réunion le jeudi.' > agenda.md
git add agenda.md
git commit -m "Agenda des réunions"
git push
cd ~/collab/ada || exit 1
echo 'Fermé le dimanche.' >> horaires.md
git commit -am "Fermeture du dimanche"
# refus attendu : le dépôt central a un commit qu'Ada n'a pas
git push
git fetch
git status
git log --oneline --graph --all -4
# refus attendu : Git veut savoir s'il doit fusionner ou rebaser
git pull
git pull --no-rebase --no-edit
git log --oneline --graph -4
git push
cd ~/collab/grace || exit 1
git pull
