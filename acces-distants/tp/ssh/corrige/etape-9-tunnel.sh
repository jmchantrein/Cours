#!/usr/bin/env bash
# Étape 9 — redirection de port locale. À lancer sur le poste, en tant qu'ada.
# La supervision du serveur n'écoute que sur 127.0.0.1:8000, du serveur.
set -euo pipefail
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
ssh serveur 'ss -ltn | grep ":8000 "'
# Rien n'écoute encore sur le port 8080 du poste.
if curl -sS localhost:8080; then echo "Le port 8080 du poste est déjà pris." >&2; exit 1; fi
# -f : en arrière-plan, une fois connecté ; -N : aucune commande, seulement le tunnel ;
# ExitOnForwardFailure : échouer si le port local ne peut pas être ouvert.
ssh -f -N -o ExitOnForwardFailure=yes -L 8080:localhost:8000 serveur
curl -sS localhost:8080
