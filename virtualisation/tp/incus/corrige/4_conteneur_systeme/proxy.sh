#!/bin/sh
# Étape 4 — publier le port 80 du conteneur sur le port 8080 de l'hôte.
set -eu

# Un périphérique « proxy », nommé web : l'hôte écoute sur son port 8080 et
# relaie chaque connexion vers le port 80 du conteneur.
incus config device add ct1 web proxy listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:80
incus config device show ct1

echo "Site : http://localhost:8080/"
