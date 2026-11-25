#!/usr/bin/env bash
# Étape 10 — avant le durcissement : autoriser la clé d'ada pour root sur le serveur, par la console.
# À lancer sur votre machine, dans le dossier de compose.yaml. Le labo n'installe aucune clé pour root :
# sans cette étape, root serait refusé avant comme après le durcissement, et la vérification ne prouverait rien.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# La même clé publique qu'ada : root entrera avec la clé de l'étudiant (sshd d'un Debian : prohibit-password).
docker compose exec -T serveur sh -c 'install -d -m 700 /root/.ssh && cp /home/ada/.ssh/authorized_keys /root/.ssh/authorized_keys && ls -l /root/.ssh'
