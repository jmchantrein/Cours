#!/usr/bin/env bash
# Étape 3 : chmod en notation octale ; stat -c '%a %A %n' affiche les deux notations.

cd ~/fichiers
stat -c '%a %A %n' pionnieres.csv scripts/sauvegarde.sh documents/notes
# rw- r-- --- : 4+2, 4, 0
chmod 640 pionnieres.csv
# rwx r-x --- : 4+2+1, 4+1, 0
chmod 750 scripts/sauvegarde.sh
# rwx --- --- : 7, 0, 0
chmod 700 documents/notes
stat -c '%a %A %n' pionnieres.csv scripts/sauvegarde.sh documents/notes
