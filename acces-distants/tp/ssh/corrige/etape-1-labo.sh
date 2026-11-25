#!/usr/bin/env bash
# Étape 1 — monter le labo. À lancer sur votre machine, dans le dossier de compose.yaml.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Construit l'image des trois machines, puis les démarre en arrière-plan.
docker compose up -d --build
docker compose ps --format 'table {{.Service}}\t{{.Status}}'
# Le journal de sshd : chaque machine annonce ses clés d'hôte, puis son port.
docker compose logs bastion serveur
