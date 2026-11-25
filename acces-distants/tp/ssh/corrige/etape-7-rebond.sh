#!/usr/bin/env bash
# Étape 7 — joindre le serveur par le bastion. À lancer sur le poste, en tant qu'ada.
# Argument : l'empreinte lue sur la console du serveur, par exemple SHA256:…
#   docker compose exec serveur ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
set -euo pipefail
attendue="${1:?usage : $0 SHA256:… (empreinte lue sur la console du serveur)}"
: "${MOTDEPASSE:?MOTDEPASSE : le mot de passe du compte ada}"
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
# Depuis le poste, le serveur n'existe pas : son nom ne se résout que sur le réseau privé.
if getent hosts serveur > /dev/null; then echo "Le poste voit le serveur : le labo est mal câblé." >&2; exit 1; fi
echo "Le poste ne résout pas « serveur »."
# Clé d'hôte du serveur, lue à travers le bastion, puis comparée à celle de la console.
cle="$(mktemp)"
repondre="$(mktemp)"
trap 'rm -f "$cle" "$repondre"' EXIT
ssh bastion ssh-keyscan -H -t ed25519 serveur > "$cle" 2> /dev/null
recue="$(ssh-keygen -lf "$cle" | awk '{ print $2 }')"
echo "empreinte reçue   : $recue"
echo "empreinte attendue : $attendue"
[ "$recue" = "$attendue" ] || { echo "Les empreintes diffèrent : ne pas se connecter." >&2; exit 1; }
cat "$cle" >> ~/.ssh/known_hosts
# Dépôt de la clé sur le serveur : l'entrée serveur de ~/.ssh/config porte ProxyJump bastion.
# shellcheck disable=SC2016 # $MOTDEPASSE est lu par le programme écrit, pas ici
printf '#!/bin/sh\necho "$MOTDEPASSE"\n' > "$repondre"
chmod 700 "$repondre"
SSH_ASKPASS="$repondre" SSH_ASKPASS_REQUIRE=force ssh-copy-id serveur < /dev/null
ssh -o BatchMode=yes serveur hostname
# Le serveur voit venir la connexion du bastion (son adresse sur le réseau privé).
ssh -o BatchMode=yes serveur 'echo $SSH_CONNECTION'
