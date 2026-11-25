#!/bin/bash
dossier=$1
for fichier in $(ls $dossier); do
    if [ $fichier = "rapport.txt" ]; then
        echo "Trouvé : $fichier"
    fi
done
