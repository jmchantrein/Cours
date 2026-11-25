#!/bin/bash
# Demander à l’utilisateurice le répertoire source
echo "Entrez le répertoire source :"
read -r source
# Demander à l’utilisateurice le répertoire destination
echo "Entrez le répertoire destination :"
read -r destination
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
