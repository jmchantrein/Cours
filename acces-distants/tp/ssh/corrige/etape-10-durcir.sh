#!/usr/bin/env bash
# Étape 10 — durcir sshd sur le serveur, par la console. À lancer sur votre machine, dans le
# dossier de compose.yaml et de 10-durcissement.conf. Avant : la connexion par clé fonctionne,
# et une session ssh reste ouverte sur le serveur dans un autre terminal.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
serveur() { docker compose exec -T serveur "$@"; }
# La configuration effective avant le changement.
serveur sh -c "sshd -T | grep -E '^(passwordauthentication|permitrootlogin) '"
serveur ls /etc/ssh/sshd_config.d/
# Un fichier à soi, lu avant 50-cloud-init.conf : sa valeur l'emporte.
docker compose cp 10-durcissement.conf serveur:/etc/ssh/sshd_config.d/10-durcissement.conf
serveur chmod 644 /etc/ssh/sshd_config.d/10-durcissement.conf
# -t : vérifier la syntaxe avant de recharger ; une erreur ici, et l'on ne recharge pas.
serveur sshd -t
serveur sh -c "sshd -T | grep -E '^(passwordauthentication|permitrootlogin|kbdinteractiveauthentication) '"
# Recharger : sur un vrai serveur, systemctl reload ssh ; dans le labo, sans systemd, le signal HUP.
serveur pkill -HUP -x sshd
