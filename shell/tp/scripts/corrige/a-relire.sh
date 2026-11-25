#!/bin/bash
# a-relire.sh, relu par ShellCheck : cherche rapport.txt dans le dossier donné en argument.
dossier=$1
# Un motif (glob) plutôt que $(ls …) : chaque chemin reste un seul mot, espaces compris (SC2045).
for chemin in "$dossier"/*; do
    fichier=$(basename "$chemin")
    # Des guillemets autour de chaque variable : ni découpage, ni chemins (SC2086).
    if [ "$fichier" = "rapport.txt" ]; then
        echo "Trouvé : $fichier"
    fi
done
