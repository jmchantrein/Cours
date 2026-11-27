#!/usr/bin/env bash
# preparer.sh — pose les fichiers du dojo Vim dans ~/dojo (état de départ du TP « Dojo Vim »).
#
# Usage : bash preparer.sh [dossier]      (par défaut : ~/dojo)
#
# Le dossier ne doit pas exister : le script refuse d'écraser quoi que ce soit.
# À côté du dossier dojo/ du dépôt (la VM du terminal de la page l'embarque), il le copie ; seul, il l'extrait de
# l'archive du dépôt des cours.
set -eu

dossier=${1:-"$HOME/dojo"}
if [ -e "$dossier" ]; then
  echo "$dossier existe déjà : rien n'est modifié." >&2
  exit 1
fi
ici=$(cd "$(dirname "$0")" && pwd)
if [ -d "$ici/dojo" ]; then
  cp -R "$ici/dojo" "$dossier"
else
  mkdir -p "$dossier"
  curl -fsSL https://github.com/jmchantrein/Cours/archive/refs/heads/main.tar.gz \
    | tar -xz -C "$dossier" --strip-components=5 Cours-main/edition-formats/tp/vim/dojo
fi
echo "Dojo prêt : $dossier"
