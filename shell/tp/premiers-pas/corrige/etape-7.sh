#!/usr/bin/env bash
# Étape 7 : créer, copier, déplacer, supprimer.

cd ~/atelier
mkdir -p archives/2025
cp pionnieres.csv archives/pionnieres-copie.csv
mv archives/pionnieres-copie.csv archives/pionnieres-v1.csv
mv journaux/serveur-2025-novembre.log archives/2025/
cp -r notes archives/notes-sauvegarde
touch notes/brouillon.txt
ls notes
rm notes/brouillon.txt
mkdir essai
rmdir essai
rmdir vieux
ls vieux
rm -r vieux
ls
ls archives archives/2025
