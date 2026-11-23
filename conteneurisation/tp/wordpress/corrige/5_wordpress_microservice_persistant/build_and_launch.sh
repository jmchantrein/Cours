#!/bin/sh
# Étape 5 — un conteneur par service, reliés par un réseau utilisateur.
# Ce script construit les deux images, puis crée le réseau et lance les deux
# conteneurs. Il peut être relancé : les volumes, donc les données, sont gardés.
set -eu

# Préfixe des noms, vide en usage normal. Le harnais de test (tester.sh) en
# fournit un pour ne toucher à aucune de vos ressources.
PREFIXE="${PREFIXE:-}"
reseau="${PREFIXE}reseau_wordpress"

# Les Dockerfile sont cherchés à côté du script, d'où qu'il soit lancé.
cd "$(dirname "$0")"

docker image build -t "${PREFIXE}image_wordpress" wordpress
docker image build -t "${PREFIXE}image_db" db

# Un nouveau lancement remplace les conteneurs du précédent.
docker container rm -f "${PREFIXE}wordpress" "${PREFIXE}db" > /dev/null 2>&1 || true

# Sur un réseau utilisateur, Docker résout les noms des conteneurs : wordpress
# joint la base par son nom, « db », sans option pour les relier un à un.
docker network inspect "$reseau" > /dev/null 2>&1 || docker network create "$reseau"

# Les deux images tournent sous un utilisateur sans privilège (USER) : aucune
# capability n'est nécessaire, on les retire toutes.
# La base d'abord : wordpress en dépend. Pas d'option -p : elle n'est joignable
# que depuis le réseau des conteneurs, pas depuis l'hôte.
docker container run -d --name "${PREFIXE}db" \
  --network "$reseau" \
  -v "${PREFIXE}data_wordpress:/var/lib/mysql" \
  --cap-drop ALL --security-opt no-new-privileges \
  "${PREFIXE}image_db"

docker container run -d --name "${PREFIXE}wordpress" \
  --network "$reseau" \
  -p 8080:80 \
  -v "${PREFIXE}source_code_wordpress:/var/www/html" \
  --cap-drop ALL --security-opt no-new-privileges \
  "${PREFIXE}image_wordpress"

echo "Site : http://localhost:8080/"
echo "Dans l'assistant d'installation : base « wordpress », identifiant « admin »,"
echo "mot de passe « tempo », adresse de la base « ${PREFIXE}db »."
