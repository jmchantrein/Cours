#!/bin/bash
# copie_fichiers.bash, version robuste : arguments, set -euo pipefail, une fonction par tâche, main.
# Usage : copie_fichiers_robuste.bash SOURCE DESTINATION
# Codes de retour : 0 succès, 1 source absente, 2 création impossible, 3 copie impossible,
# 4 mauvais nombre d’arguments.
set -euo pipefail

# Affiche un message sur l’erreur standard, puis termine le script avec le code donné.
erreur() {
    local code=$1
    local message=$2
    echo "$message" >&2
    exit "$code"
}

# Vérifie que le script a reçu exactement deux arguments.
verifier_arguments() {
    if [ "$#" -ne 2 ]; then
        erreur 4 "Usage : $0 SOURCE DESTINATION"
    fi
}

# Crée le répertoire destination s’il n’existe pas encore.
preparer_destination() {
    local destination=$1
    if [ ! -d "$destination" ]; then
        echo "Le répertoire destination n’existe pas. Création de $destination."
        mkdir -p "$destination" || erreur 2 "Erreur lors de la création du répertoire destination."
    fi
}

# Copie le contenu de la source dans la destination.
copier() {
    local source=$1
    local destination=$2
    cp -r "$source"/* "$destination"/ || erreur 3 "Erreur lors de la copie des fichiers."
    echo "Les fichiers ont été copiés de $source vers $destination."
}

# Fonction principale : le déroulé du script se lit ici.
main() {
    verifier_arguments "$@"
    local source=$1
    local destination=$2
    [ -d "$source" ] || erreur 1 "Le répertoire source $source n’existe pas."
    preparer_destination "$destination"
    copier "$source" "$destination"
}

# Appel de la fonction main, avec les arguments du script
main "$@"
