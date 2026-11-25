#!/bin/sh
# Étape 4 — un conteneur système : la commande de l'étape 1, sans --vm.
set -eu

incus launch images:debian/13 ct1

# incus exec répond tout de suite dans un conteneur : seul le réseau se fait
# attendre, deux minutes au plus.
timeout 120 sh -c 'until incus exec ct1 -- getent hosts deb.debian.org > /dev/null 2>&1; do sleep 2; done'

# Un serveur web, pour avoir des processus à observer et un port à publier.
incus exec ct1 -- apt-get update
incus exec ct1 --env DEBIAN_FRONTEND=noninteractive -- apt-get install -y apache2

incus list
