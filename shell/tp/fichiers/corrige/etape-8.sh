#!/usr/bin/env bash
# Étape 8 : jokers et find. find rend les noms dans l'ordre où le disque les
# range : sort les remet dans l'ordre alphabétique.

cd ~/fichiers
# 1. Le joker : le shell remplace *.txt par les noms du répertoire courant
ls *.txt
ls documents/notes/reunion-*
# 2. find descend dans les sous-répertoires ; les guillemets protègent le motif du shell
find . -name '*.txt' | sort
find . -type d | sort
find . -type f -size +10k
find . -empty | sort
find . -type l
# 3. Les fichiers modifiés depuis moins d'un jour (-mtime -1)
find . -type f -mtime -1 | sort
# 4. Agir sur ce qu'on trouve : rendre exécutables tous les scripts
find scripts -name '*.sh' -exec chmod u+x {} +
ls -l scripts
# 5. Ailleurs que chez soi : les répertoires interdits donnent des erreurs, qu'on écarte
find /etc -name 'host*' 2> /dev/null | sort
