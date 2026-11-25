#!/usr/bin/env bash
# Étape 5 — confier la clé à l'agent. À lancer sur le poste, en tant qu'ada.
# -a fixe l'adresse de l'agent : tout terminal du poste le retrouve par SSH_AUTH_SOCK.
set -euo pipefail
: "${PHRASE:?PHRASE : la phrase de passe de la clé}"
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
# ssh-add -l répond 2 quand aucun agent n'écoute : on le démarre.
if ssh-add -l > /dev/null 2>&1 || [ $? -ne 2 ]; then
  echo "Un agent écoute déjà sur $SSH_AUTH_SOCK."
else
  eval "$(ssh-agent -a "$SSH_AUTH_SOCK")"
fi
grep -qx 'export SSH_AUTH_SOCK=~/.ssh/agent.sock' ~/.bashrc \
  || echo 'export SSH_AUTH_SOCK=~/.ssh/agent.sock' >> ~/.bashrc
# Sans clavier, SSH_ASKPASS donne la phrase de passe ; timeout, car ssh-add redemande sans fin une phrase fausse.
repondre="$(mktemp)"
trap 'rm -f "$repondre"' EXIT
# shellcheck disable=SC2016 # $PHRASE est lu par le programme écrit, pas ici
printf '#!/bin/sh\necho "$PHRASE"\n' > "$repondre"
chmod 700 "$repondre"
SSH_ASKPASS="$repondre" SSH_ASKPASS_REQUIRE=force timeout 20 ssh-add < /dev/null
ssh-add -l
# BatchMode : ssh ne demande rien ; il réussit, car l'agent signe à la place de la clé chiffrée.
ssh -o BatchMode=yes -p 2222 ada@bastion hostname
