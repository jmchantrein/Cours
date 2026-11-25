#!/usr/bin/env bash
# Étape 8 — copier des fichiers vers le serveur. À lancer sur le poste, en tant qu'ada.
set -euo pipefail
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
cd ~
echo "Rapport du poste d'Ada" > rapport.txt
mkdir -p site
echo accueil > site/index.html
echo contact > site/contact.html
scp rapport.txt serveur:/tmp/
# La barre finale de site/ : « le contenu de site », copié dans site/ sur le serveur.
rsync -av site/ serveur:site/
echo "accueil, version 2" > site/index.html
# Second passage : seul index.html a changé, seul lui part.
rsync -av site/ serveur:site/
ssh serveur 'cat /tmp/rapport.txt; ls site; cat site/index.html'
