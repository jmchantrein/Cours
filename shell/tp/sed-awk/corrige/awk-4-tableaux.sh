#!/bin/bash
# awk, exercice 4 : un tableau associatif, indexé par la décennie de la contribution.
# int() garde la partie entière : 1969 / 10 = 196,9 → 196 → 1960.
# L'ordre de for (d in n) n'est pas garanti (mawk et gawk diffèrent) : sort -n trie les décennies.
awk -F';' 'NR > 1 { d = int($2 / 10) * 10; n[d]++ } END { for (d in n) print d, n[d] }' pionnieres.csv | sort -n
