#!/bin/bash
# awk, exercice 1 : les champs.
# Domaine, puis nom, des trois premières pionnières (sans l'en-tête).
awk -F';' 'NR > 1 && NR <= 4 { print $3 ": " $1 }' pionnieres.csv
# $NF est le dernier champ, quel que soit leur nombre.
awk -F';' 'NR == 2 { print NF " champs, le dernier : " $NF }' pionnieres.csv
# Contrôle du fichier : chaque ligne a-t-elle 4 champs ? Une seule valeur doit sortir.
awk -F';' '{ print NF }' pionnieres.csv | sort -u
