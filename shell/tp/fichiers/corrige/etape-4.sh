#!/usr/bin/env bash
# Étape 4 : les droits d'un répertoire. Sous root, aucune de ces
# interdictions ne s'applique : faites cette étape sous un compte ordinaire.

cd ~/fichiers
# 1. Sans r : on ne peut plus lister, mais on atteint un fichier dont on connaît le nom
chmod u-r coffre
ls coffre
cat coffre/secret.txt
# 2. Sans x : on lit la liste des noms, mais on n'entre plus
chmod u=rw coffre
\ls coffre
cat coffre/secret.txt
cd coffre
# 3. Sans w : on ne crée ni ne supprime plus de nom ; le fichier, lui, reste modifiable
chmod u=rx coffre
touch coffre/nouveau.txt
rm coffre/secret.txt
echo "Nouveau code : 1969." >> coffre/secret.txt
cat coffre/secret.txt
# 4. Les droits d'origine
chmod 755 coffre
ls -ld coffre
