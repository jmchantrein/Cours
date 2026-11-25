#!/usr/bin/env bash
# Étape 7 : liens physiques et liens symboliques. Le premier nombre de
# ls -li est le numéro d'inode : il change d'une machine à l'autre.

cd ~/fichiers
ln documents/rapport.txt rapport-dur.txt
ln -s documents/rapport.txt rapport-lien.txt
ls -li documents/rapport.txt rapport-dur.txt rapport-lien.txt
# 1. Un lien physique est un second nom du même fichier
echo "Ajouté par le lien physique." >> rapport-dur.txt
cat documents/rapport.txt
# 2. Le nom d'origine change : le lien symbolique pointe dans le vide
mv documents/rapport.txt documents/rapport-2026.txt
cat rapport-dur.txt
cat rapport-lien.txt
ls -l rapport-lien.txt
# 3. Le réparer : -f remplace le lien existant
ln -sf documents/rapport-2026.txt rapport-lien.txt
cat rapport-lien.txt
# 4. Pas de lien physique vers un répertoire
ln documents documents-dur
