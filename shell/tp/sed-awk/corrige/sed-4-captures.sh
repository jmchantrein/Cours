#!/bin/bash
# sed, exercice 4 : « Lovelace Ada;1843;… » devient « Ada Lovelace (1843) ».
# \1 le nom, \2 le prénom, \3 l'année ; 1d retire l'en-tête avant la substitution.
sed -E '1d; s/^([^ ;]+) ([^;]+);([0-9]{4});.*/\2 \1 (\3)/' pionnieres.csv
