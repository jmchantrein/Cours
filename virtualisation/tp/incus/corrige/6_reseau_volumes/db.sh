#!/bin/sh
# Étape 6 — l'instance db : MariaDB, ses données sur le volume « donnees ».
# Lancé une première fois, le script crée la base ; relancé après la
# suppression de l'instance, il la retrouve sur le volume.
set -eu

# ecoute.cnf est cherché à côté du script.
cd "$(dirname "$0")"

incus launch images:debian/13 db

# Le volume est monté sur /var/lib/mysql avant l'installation : MariaDB y
# crée ses fichiers, ou y retrouve ceux d'une instance précédente.
incus storage volume attach default donnees db /var/lib/mysql

until incus exec db -- getent hosts deb.debian.org > /dev/null 2>&1; do sleep 2; done
incus exec db -- apt-get update
incus exec db --env DEBIAN_FRONTEND=noninteractive -- apt-get install -y mariadb-server

# MariaDB n'écoute par défaut que sur 127.0.0.1. Ce fichier est sur le disque
# de l'instance, pas sur le volume : il est à remettre à chaque création.
incus file push ecoute.cnf db/etc/mysql/mariadb.conf.d/99-ecoute.cnf
incus exec db -- systemctl restart mariadb

# La base et son utilisateur, qui se connecte depuis une autre machine ('%').
# IF NOT EXISTS : sur un volume qui contient déjà la base, rien ne change.
incus exec db -- mariadb -e "CREATE DATABASE IF NOT EXISTS wordpress"
incus exec db -- mariadb -e "CREATE USER IF NOT EXISTS 'wordpress'@'%' IDENTIFIED BY 'tempo'"
incus exec db -- mariadb -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%'"
