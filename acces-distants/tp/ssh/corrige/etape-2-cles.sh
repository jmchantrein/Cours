#!/usr/bin/env bash
# Étape 2 — générer la paire de clés. À lancer sur le poste, en tant qu'ada.
# Sans clavier, la phrase de passe vient de la variable PHRASE (-N) ; au clavier,
# « ssh-keygen -t ed25519 » la demande deux fois.
set -euo pipefail
: "${PHRASE:?PHRASE : la phrase de passe de la clé}"
ssh-keygen -t ed25519 -N "$PHRASE" -f ~/.ssh/id_ed25519
ls -l ~/.ssh
# La clé privée est chiffrée : sans la phrase, ssh-keygen ne peut pas en tirer la clé publique.
if ssh-keygen -y -P "" -f ~/.ssh/id_ed25519 > /dev/null 2>&1; then
  echo "La clé privée n'est pas protégée par une phrase de passe." >&2
  exit 1
fi
echo "Clé privée chiffrée par la phrase de passe."
