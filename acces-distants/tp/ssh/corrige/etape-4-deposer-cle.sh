#!/usr/bin/env bash
# Étape 4 — déposer la clé publique sur le bastion. À lancer sur le poste, en tant qu'ada.
# Sans clavier, SSH_ASKPASS donne le mot de passe (MOTDEPASSE), puis la phrase de passe (PHRASE).
set -euo pipefail
: "${PHRASE:?PHRASE : la phrase de passe de la clé}" "${MOTDEPASSE:?MOTDEPASSE : le mot de passe du compte ada}"
repondre="$(mktemp)"
trap 'rm -f "$repondre"' EXIT
cat > "$repondre" <<'FIN'
#!/bin/sh
case "$1" in *passphrase*) echo "$PHRASE" ;; *) echo "$MOTDEPASSE" ;; esac
FIN
chmod 700 "$repondre"
export SSH_ASKPASS="$repondre" SSH_ASKPASS_REQUIRE=force
ssh-copy-id -p 2222 ada@bastion < /dev/null
# Connexion par clé : ssh ne demande plus le mot de passe, mais la phrase de passe de la clé.
ssh -p 2222 -o PreferredAuthentications=publickey ada@bastion 'hostname; ls -l ~/.ssh' < /dev/null
