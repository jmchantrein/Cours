#!/bin/sh
# Étape 6 — la base et WordPress dans deux instances, qui se joignent par
# leur nom ; les données de la base sur un volume.
set -eu

# db.sh et les fichiers de configuration sont cherchés à côté du script.
cd "$(dirname "$0")"

# Un volume du pool de stockage « default » : il existe hors de toute instance.
incus storage volume create default donnees

# L'instance db, avec le volume.
./db.sh

# L'instance web : le paquet wordpress, sans serveur de base de données.
incus launch images:debian/13 web
timeout 120 sh -c 'until incus exec web -- getent hosts deb.debian.org > /dev/null 2>&1; do sleep 2; done'
incus exec web -- apt-get update
incus exec web --env DEBIAN_FRONTEND=noninteractive -- apt-get install -y wordpress

# Les fichiers de l'étape 2, à une ligne près : l'adresse de la base, db.incus.
incus file push --uid 0 --gid 33 --mode 0640 config-default.php web/etc/wordpress/config-default.php
incus file push wordpress.conf web/etc/apache2/sites-available/wordpress.conf
incus exec web -- a2dissite 000-default
incus exec web -- a2ensite wordpress
incus exec web -- systemctl reload apache2

# Le serveur de noms du pont connaît chaque instance : <nom>.incus.
incus exec web -- getent hosts db.incus

adresse="$(incus list web -c 4 -f csv | cut -d ' ' -f 1)"
echo "Site : http://$adresse/"
