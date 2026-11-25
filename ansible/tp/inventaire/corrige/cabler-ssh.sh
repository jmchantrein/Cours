#!/bin/bash
# Câble SSH du nœud de contrôle vers les deux nœuds gérés du labo, depuis l’hôte : les
# commandes de l’étape 2, passées par docker compose exec. Une paire de clés ed25519 sur
# control-node (gardée si elle existe), la clé publique dans authorized_keys de chaque nœud,
# leurs empreintes dans known_hosts. Rejouable : à relancer après chaque docker compose down.
# À lancer depuis le dossier du labo (ansible/cm/labo), avec ANSIBLE_PROJET exporté comme à
# l’étape 1 (et COMPOSE_PROJECT_NAME, si l’on a nommé le projet Compose).
set -euo pipefail

noeuds=(managed-node-1 managed-node-2)
ctl() { docker compose exec -T control-node "$@"; }

ctl sh -c 'test -f /root/.ssh/id_ed25519 || ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -q'
cle="$(ctl cat /root/.ssh/id_ed25519.pub)"

for noeud in "${noeuds[@]}"; do
  docker compose exec -T "$noeud" sh -c 'mkdir -p /root/.ssh && chmod 700 /root/.ssh
    cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' <<< "$cle"
done

# En vrai, comparez ces empreintes à celles que l’administrateur du nœud vous donne.
ctl sh -c 'ssh-keyscan -t ed25519 "$@" > /root/.ssh/known_hosts 2> /dev/null' sh "${noeuds[@]}"

for noeud in "${noeuds[@]}"; do
  ctl ssh "$noeud" hostname
done
