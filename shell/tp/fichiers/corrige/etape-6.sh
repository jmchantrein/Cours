#!/usr/bin/env bash
# Étape 6 : propriétaires et groupes. Remplacez etudiants par l'un de vos
# groupes, que id -Gn affiche.

cd ~/fichiers
id -un
id -Gn
ls -l /etc/passwd /etc/shadow
cat /etc/shadow
chown root pionnieres.csv
chgrp etudiants pionnieres.csv
ls -l pionnieres.csv
chgrp root pionnieres.csv
cp /etc/passwd copie-passwd
ls -l copie-passwd
