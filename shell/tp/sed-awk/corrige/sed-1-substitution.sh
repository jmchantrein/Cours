#!/bin/bash
# sed, exercice 1 : remplacer le séparateur « ; » par « | », pour lire le fichier en colonnes.
# Sans drapeau, s ne remplace que la première occurrence de chaque ligne ; g les remplace toutes.
sed 's/;/ | /' pionnieres.csv | head -n 3
sed 's/;/ | /g' pionnieres.csv | head -n 3
