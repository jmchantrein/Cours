#!/bin/bash
# Étape 5 : Ada publie une branche ; Grace la récupère et la relit ; Ada la fusionne dans main.
cd ~/collab/ada || exit 1
git switch -c horaires
echo 'Ouvert le lundi, de 9 h à 17 h.' > horaires.md
git add horaires.md
git commit -m "Horaires d'ouverture"
git push -u origin horaires
cd ~/collab/grace || exit 1
git fetch
git branch -a
# une branche locale horaires, qui suit origin/horaires
git switch horaires
cat horaires.md
git switch main
cd ~/collab/ada || exit 1
git switch main
git merge horaires
git push
cd ~/collab/grace || exit 1
git pull
git log --oneline -3
