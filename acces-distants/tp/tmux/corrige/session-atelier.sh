#!/usr/bin/env bash
# session-atelier.sh : la session de travail « atelier », construite une fois, retrouvée ensuite.
#   fenêtre edition      : l'éditeur à gauche, un shell à droite
#   fenêtre surveillance : top
# Si la session existe déjà, le script s'y rattache sans rien reconstruire.
# Lancé hors d'un terminal (depuis un autre script, par cron), il crée la session sans s'y attacher.
#
# Usage : ./session-atelier.sh [nom de la session]
set -euo pipefail

session=${1:-atelier}

# « = » : le nom exact. Sans lui, has-session accepte un début de nom (« atel » trouverait « atelier »).
if ! tmux has-session -t "=$session" 2> /dev/null; then
  # -d : sans s'attacher. -P -F : afficher l'identifiant du panneau créé (%0, %1…), qui ne dépend ni de
  # base-index ni de pane-base-index, contrairement aux numéros.
  gauche=$(tmux new-session -d -s "$session" -n edition -c "$HOME" -P -F '#{pane_id}')
  tmux split-window -h -t "$gauche" -c "$HOME"
  # send-keys tape la commande dans le shell du panneau : quand on quitte l'éditeur, le shell reste.
  tmux send-keys -t "$gauche" "${EDITOR:-vi} notes.txt" Enter
  # Une commande donnée à new-window remplace le shell : la fenêtre se ferme quand top s'arrête.
  tmux new-window -d -t "=$session:" -n surveillance top
  tmux select-pane -t "$gauche"
fi

# Pas de terminal : la session est prête, on s'arrête là.
[ -t 0 ] && [ -t 1 ] || exit 0
if [ -n "${TMUX:-}" ]; then
  # Déjà dans tmux : y ouvrir la session plutôt que d'imbriquer un client dans un panneau.
  exec tmux switch-client -t "=$session"
fi
exec tmux attach-session -t "=$session"
