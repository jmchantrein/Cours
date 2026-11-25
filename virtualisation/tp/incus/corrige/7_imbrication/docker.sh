#!/bin/sh
# Étape 7 — Docker dans une VM Incus : un poste pour le TP « Conteneuriser
# WordPress », isolé de l'hôte par un noyau à part.
set -eu

# 2 processeurs, 2 Gio de mémoire, un disque de 20 Gio : -d root,size=…
# reprend le disque du profil default et change sa taille.
incus launch images:debian/13 docker --vm \
  --config limits.cpu=2 --config limits.memory=2GiB \
  --device root,size=20GiB

until incus exec docker -- getent hosts deb.debian.org > /dev/null 2>&1; do sleep 2; done

# Les paquets du cours de conteneurisation.
incus exec docker -- apt-get update
incus exec docker --env DEBIAN_FRONTEND=noninteractive -- apt-get install -y docker.io docker-compose

# Un conteneur applicatif, dans la VM.
incus exec docker -- docker container run --rm hello-world

# Pour y travailler : incus exec docker -- bash
