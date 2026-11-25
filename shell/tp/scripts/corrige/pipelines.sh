#!/bin/bash
# Étape 2 : trois pipelines sur donnees/pionnieres.csv, à lancer depuis ~/tp-scripts.

# 1) Nombre de pionnières par domaine, du domaine le plus fréquent au moins fréquent
tail -n +2 donnees/pionnieres.csv | cut -d';' -f3 | sort | uniq -c | sort -rn

# 2) La contribution la plus ancienne : tri numérique sur l'année (colonne 2 seulement)
tail -n +2 donnees/pionnieres.csv | sort -t';' -k2,2n | head -n 1

# 3) La colonne 1 de deux fichiers, dont un absent : sortie dans noms.txt, erreurs dans erreurs.txt
cut -d';' -f1 donnees/pionnieres.csv donnees/absent.csv > noms.txt 2> erreurs.txt
echo "code de retour de cut : $?"
wc -l < noms.txt
cat erreurs.txt
