#!/bin/bash
# awk, exercice 3 : BEGIN, END et accumulateurs. L'année moyenne des contributions.
awk -F';' 'BEGIN { print "Contributions :" }
           NR > 1 { somme += $2; n++ }
           END { print n, "pionnières, année moyenne", somme / n }' pionnieres.csv
