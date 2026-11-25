#!/usr/bin/env bash
# Étape 5 : lire l'aide. man et less sont interactifs (q pour quitter) : ils
# n'ont pas leur place dans un script ; les options trouvées, si.

cd ~/atelier
# man ls, puis /size et n : l'option -S trie par taille ; -r inverse l'ordre ;
# -h écrit les tailles en Kio, Mio (avec -l)
ls -lS journaux
ls -lSr journaux
ls -lh journaux
type cd
type wc
