#!/usr/bin/env bash
# Étape 3 — première connexion au bastion, empreinte vérifiée. À lancer sur le poste, en tant qu'ada.
# Argument : l'empreinte lue sur la console du bastion, par exemple SHA256:fWJx…CKE
#   docker compose exec bastion ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
# Au clavier, « ssh -p 2222 ada@bastion » affiche l'empreinte et attend « yes ». Sans clavier, on
# récupère la clé d'hôte, on compare son empreinte, et on ne l'ajoute à known_hosts que si elle concorde.
set -euo pipefail
attendue="${1:?usage : $0 SHA256:… (empreinte lue sur la console du bastion)}"
: "${MOTDEPASSE:?MOTDEPASSE : le mot de passe du compte ada}"
cle="$(mktemp)"
trap 'rm -f "$cle"' EXIT
ssh-keyscan -H -p 2222 -t ed25519 bastion > "$cle" 2> /dev/null
recue="$(ssh-keygen -lf "$cle" | awk '{ print $2 }')"
echo "empreinte reçue   : $recue"
echo "empreinte attendue : $attendue"
if [ "$recue" != "$attendue" ]; then
  echo "Les empreintes diffèrent : ne pas se connecter." >&2
  exit 1
fi
mkdir -p ~/.ssh
cat "$cle" >> ~/.ssh/known_hosts
# Connexion par mot de passe : SSH_ASKPASS répond à la place du clavier.
repondre="$(mktemp)"
trap 'rm -f "$cle" "$repondre"' EXIT
# shellcheck disable=SC2016 # $MOTDEPASSE est lu par le programme écrit, pas ici
printf '#!/bin/sh\necho "$MOTDEPASSE"\n' > "$repondre"
chmod 700 "$repondre"
SSH_ASKPASS="$repondre" SSH_ASKPASS_REQUIRE=force \
  ssh -p 2222 -o StrictHostKeyChecking=yes -o PreferredAuthentications=password ada@bastion hostname < /dev/null
