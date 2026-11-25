#!/bin/bash
# sed, exercice 2 : choisir les lignes par leur numéro, puis par un motif.
# Les lignes 2 à 4 seulement : -n coupe l'affichage automatique, p affiche la plage.
sed -n '2,4p' pionnieres.csv
# services.conf sans ses commentaires ni ses lignes vides : ^ début de ligne, $ fin de ligne.
sed '/^#/d; /^$/d' services.conf
