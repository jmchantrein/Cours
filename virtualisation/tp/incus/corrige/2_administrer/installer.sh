#!/bin/sh
# Étape 2 — administrer la VM comme une machine : WordPress par les paquets de
# Debian, comme sur un serveur. Chaque commande passe par incus exec ; dans un
# shell ouvert par « incus exec vm1 -- bash », ce sont les mêmes, sans préfixe.
set -eu

# Les deux fichiers de configuration sont cherchés à côté du script.
cd "$(dirname "$0")"

# La VM doit répondre et avoir le réseau : son agent, puis la résolution de noms.
# On attend deux minutes au plus.
timeout 120 sh -c 'until incus exec vm1 -- getent hosts deb.debian.org > /dev/null 2>&1; do sleep 2; done'

# Le paquet wordpress amène Apache, PHP et un client de base de données ; le
# serveur MariaDB est à demander.
incus exec vm1 -- apt-get update
incus exec vm1 --env DEBIAN_FRONTEND=noninteractive -- apt-get install -y wordpress mariadb-server

# La base et son utilisateur. Dans la VM, root se connecte à MariaDB par le
# socket local, sans mot de passe.
incus exec vm1 -- mariadb -e "CREATE DATABASE wordpress"
incus exec vm1 -- mariadb -e "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'tempo'"
incus exec vm1 -- mariadb -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost'"

# La configuration : deux fichiers poussés de l'hôte vers la VM. Celui de
# WordPress contient le mot de passe de la base : root le possède, seul le
# groupe www-data (33) le lit.
incus file push --uid 0 --gid 33 --mode 0640 config-default.php vm1/etc/wordpress/config-default.php
incus file push wordpress.conf vm1/etc/apache2/sites-available/wordpress.conf

# Le site de WordPress remplace le site par défaut d'Apache.
incus exec vm1 -- a2dissite 000-default
incus exec vm1 -- a2ensite wordpress
incus exec vm1 -- systemctl reload apache2

# L'adresse de la VM sur le pont : l'hôte la joint directement.
adresse="$(incus list vm1 -c 4 -f csv | cut -d ' ' -f 1)"
echo "Site : http://$adresse/"
