#!/bin/bash
# Étape 5 : lire l'historique, et y trouver ses propres identifiants de commit.
cd ~/mon_projet || exit 1
git log
git log --oneline
# le premier commit : la dernière ligne
git log --oneline | tail -n 1
git log --oneline | wc -l
