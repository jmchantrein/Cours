#!/usr/bin/env bash
# Étape 6 : afficher un fichier, son début, sa fin, son nombre de lignes.

cd ~/atelier
cat notes/a-faire.txt
cat pionnieres.csv
head -n 3 pionnieres.csv
tail -n 2 pionnieres.csv
wc -l pionnieres.csv
wc -l journaux/serveur-2026-novembre.log
head -n 2 journaux/serveur-2026-novembre.log
tail -n 1 journaux/serveur-2026-novembre.log
# less journaux/serveur-2026-novembre.log, puis /ERROR : la première erreur
# est à 00:24:10 ; n passe à la suivante (00:48:20) ; q pour quitter
