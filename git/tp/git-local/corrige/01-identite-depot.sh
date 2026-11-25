#!/bin/bash
# Étape 1 : se présenter à Git, puis créer le dépôt ~/mon_projet, sur la branche main.
# Remplacez le nom et l'adresse par les vôtres : ils figureront dans chaque commit.
git --version
git config --global user.name "Ada Lovelace"
git config --global user.email ada@example.org
git config --global --list
cd ~ || exit 1
mkdir mon_projet
cd mon_projet || exit 1
git init -b main
ls -A
git status
