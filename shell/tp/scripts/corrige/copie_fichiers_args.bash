#!/bin/bash
# copie_fichiers.bash, non interactif : la source et la destination arrivent en arguments.
# Usage : copie_fichiers_args.bash SOURCE DESTINATION
# Codes de retour : 0 succès, 1 source absente, 2 création impossible, 3 copie impossible,
# 4 mauvais nombre d’arguments.
set -euo pipefail

# Vérifier le nombre d’arguments avant de lire $1 et $2 : avec set -u, un argument absent arrêterait
# le script sur « unbound variable », sans message d’usage.
if [ "$#" -ne 2 ]; then
    echo "Usage : $0 SOURCE DESTINATION" >&2
    exit 4
fi
source=$1
destination=$2
# Vérifier si le répertoire source existe
if [ -d "$source" ]; then
    # Vérifier si le répertoire destination existe, sinon le créer
    if [ ! -d "$destination" ]; then
        echo "Le répertoire destination n’existe pas. Création de $destination."
        mkdir -p "$destination" || { echo "Erreur lors de la création du répertoire destination." >&2; exit 2; }
    fi
    # Copier les fichiers
    cp -r "$source"/* "$destination"/ || { echo "Erreur lors de la copie des fichiers." >&2; exit 3; }
    # Message de confirmation
    echo "Les fichiers ont été copiés de $source vers $destination."
else
    echo "Le répertoire source $source n’existe pas." >&2
    exit 1  # Code de retour 1 si le répertoire source n’existe pas
fi
exit 0  # Code de retour 0 pour un succès
