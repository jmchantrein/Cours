#!/usr/bin/env bash
# Étape 10 — vérifier le durcissement depuis une nouvelle connexion. À lancer sur le poste, en tant qu'ada.
set -euo pipefail
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
# Sans clé, le serveur refuse et dit ce qu'il accepte encore : « publickey » seulement
# (avant le durcissement : « publickey,password »).
refus="$(ssh -o BatchMode=yes -o PubkeyAuthentication=no serveur hostname 2>&1 | tr -d "\r" || true)"
echo "$refus"
grep -qx 'ada@serveur: Permission denied (publickey).' <<< "$refus" \
  || { echo "Le serveur propose encore une autre méthode que la clé." >&2; exit 1; }
# root est refusé, même avec une clé autorisée.
if ssh -o BatchMode=yes root@serveur hostname; then
  echo "root entre encore sur le serveur." >&2; exit 1
fi
# La clé d'ada passe toujours : l'accès n'est pas coupé.
ssh -o BatchMode=yes serveur hostname
