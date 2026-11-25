#!/usr/bin/env bash
# Étape 2 : chmod en notation symbolique.

cd ~/fichiers
# 1. Sans le droit x, le script ne se lance pas
./scripts/bonjour.sh
chmod u+x scripts/bonjour.sh
ls -l scripts/bonjour.sh
./scripts/bonjour.sh
# 2. Le groupe peut écrire le rapport, les autres ne peuvent plus le lire
chmod g+w,o-r documents/rapport.txt
ls -l documents/rapport.txt
# 3. Le journal en lecture seule pour tout le monde, propriétaire compris
chmod a=r journaux/serveur.log
ls -l journaux/serveur.log
echo "une ligne de plus" >> journaux/serveur.log
chmod u+w journaux/serveur.log
ls -l journaux/serveur.log
