#!/bin/bash
# Étape 7 : la même ligne modifiée par chacun ; le pull d'Ada s'arrête sur un conflit, qu'elle résout.
cd ~/collab/grace || exit 1
sed -i 's/^# Site du club$/# Site du club de lecture/' README.md
git commit -am "Titre précisé"
git push
cd ~/collab/ada || exit 1
sed -i 's/^# Site du club$/# Site du club de code/' README.md
git commit -am "Titre complété"
git push
# conflit attendu : la première ligne de README.md a changé des deux côtés
git pull --no-rebase --no-edit
git status --short
cat README.md
# on édite README.md (avec Vim…) : un seul titre, sans marqueurs ; ici, printf réécrit le fichier
printf '%s\n' '# Site des clubs de lecture et de code' '' 'Responsable : Ada.' 'Contact : grace@example.org' > README.md
cat README.md
git add README.md
git commit --no-edit
git push
git log --oneline --graph -4
cd ~/collab/grace || exit 1
git pull
