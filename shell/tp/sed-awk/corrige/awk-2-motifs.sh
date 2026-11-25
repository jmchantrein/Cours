#!/bin/bash
# awk, exercice 2 : les motifs.
# Égalité de chaînes ; sans action, awk affiche la ligne entière.
awk -F';' '$3 == "langages"' pionnieres.csv
# Comparaisons de nombres : les contributions de 1950 à 1979, année d'abord.
awk -F';' 'NR > 1 && $2 >= 1950 && $2 < 1980 { print $2, $1 }' pionnieres.csv
