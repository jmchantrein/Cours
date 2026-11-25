#!/bin/sh
# Étape 4 — publier le port 80 de la VM : sur une VM, Incus n'accepte le
# périphérique proxy qu'en mode NAT (une règle de pare-feu de l'hôte).
set -eu

# Le NAT exige une adresse fixe sur la carte réseau de la VM : on fige celle
# qu'elle a déjà reçue. eth0 vient du profil default ; override le recopie dans
# la configuration de la VM, avec la clé en plus.
adresse="$(incus list vm1 -c 4 -f csv | cut -d ' ' -f 1)"
incus config device override vm1 eth0 ipv4.address="$adresse"

# En mode NAT, l'adresse d'écoute est une adresse précise de l'hôte (0.0.0.0
# est refusé) : ici, celle que l'hôte utilise pour sortir sur son réseau.
hote="$(ip -4 route get 1.1.1.1 | sed -n 's/.* src \([0-9.]*\).*/\1/p')"

# Le port 8080 est pris par le conteneur : la VM reçoit le 8081.
incus config device add vm1 web proxy nat=true listen="tcp:$hote:8081" connect="tcp:$adresse:80"
incus config device show vm1

echo "Site : http://$hote:8081/"
