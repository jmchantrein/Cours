#!/usr/bin/env bash
# Étape 6 — ~/.ssh/config. À lancer sur le poste, en tant qu'ada, une fois le fichier écrit
# (corrigé : le fichier config de ce dossier, copié en ~/.ssh/config).
set -euo pipefail
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
chmod 600 ~/.ssh/config
# Ce que ssh retient de l'entrée bastion, sans se connecter.
ssh -G bastion | grep -E '^(hostname|user|port) '
# L'alias suffit : ni -p 2222, ni ada@.
ssh -o BatchMode=yes bastion hostname
