#!/bin/sh
# Démarrage d'une machine du labo : ses clés d'hôte, puis sshd au premier plan.
set -eu
# Les clés d'hôte naissent au premier démarrage : chaque machine a la sienne.
# Elles survivent à « docker compose restart », pas à « docker compose down ».
ssh-keygen -A
mkdir -p /run/sshd
# PORT_SSH : un autre port que 22 (le bastion écoute sur 2222).
if [ -n "${PORT_SSH:-}" ]; then
  echo "Port $PORT_SSH" > /etc/ssh/sshd_config.d/20-port.conf
fi
# SUPERVISION : un service web qui n'écoute qu'en local, sur ce port (le serveur, port 8000).
if [ -n "${SUPERVISION:-}" ]; then
  python3 -m http.server --bind 127.0.0.1 --directory /srv/supervision "$SUPERVISION" > /dev/null 2>&1 &
fi
# -D : au premier plan ; -e : journal sur la sortie d'erreur, lu par « docker compose logs ».
exec /usr/sbin/sshd -D -e
