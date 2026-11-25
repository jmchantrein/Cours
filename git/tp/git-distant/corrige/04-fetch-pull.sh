#!/bin/bash
# Étape 4 : Grace publie un commit ; Ada le voit après git fetch, puis l'intègre par git pull.
cd ~/collab/grace || exit 1
echo 'Contact : grace@example.org' >> README.md
git commit -am "Adresse de contact"
git push
cd ~/collab/ada || exit 1
# git status ne parle pas au dépôt central : il ne sait rien encore
git status
git fetch
git status
git log --oneline --all
git pull
git log --oneline
