#!/bin/bash
# Rejoue les commandes des diapos du cours Ansible sur le labo de labo/ :
# construit les trois conteneurs, câble SSH, puis lance chaque commande montrée,
# dans l’ordre des diapos, en affichant sa sortie (à comparer aux diapos).
# Usage : rejouer.sh [--keep]   (--keep laisse le labo en marche)
# Derrière un proxy qui réécrit TLS : CA_PIP=/chemin/vers/ca.crt rejouer.sh
# Les scripts entre apostrophes s’exécutent dans le conteneur : pas d’expansion ici.
# shellcheck disable=SC2016
set -euo pipefail
cd "$(dirname "$0")/labo"

keep="${1:-}"
nettoyer() { [ "$keep" = "--keep" ] || docker compose down -t 1 >/dev/null 2>&1 || true; }
trap nettoyer EXIT

ctl() { docker compose exec -T control-node "$@"; }
titre() { printf '\n===== %s\n' "$*"; }

docker compose down -t 1 >/dev/null 2>&1 || true
docker compose build -q
docker compose up -d

titre "Câblage SSH (fait par le script du labo)"
ctl sh -c "rm -f /root/.ssh/id_ed25519*; ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -q"
cle="$(ctl cat /root/.ssh/id_ed25519.pub)"
for noeud in managed-node-1 managed-node-2; do
  docker compose exec -T "$noeud" sh -c "mkdir -p /root/.ssh && chmod 700 /root/.ssh \
    && printf '%s\n' '$cle' > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
done
ctl sh -c "ssh-keyscan managed-node-1 managed-node-2 > /root/.ssh/known_hosts 2>/dev/null"

titre "Configurer N machines à la main"
ctl bash -c 'for i in 1 2; do for h in managed-node-1 managed-node-2 managed-node-3; do
  ssh "$h" "echo Bienvenue >> /etc/motd"; done; done; ssh managed-node-1 grep -c Bienvenue /etc/motd' || true

titre "Une tâche : un module copié, exécuté, effacé"
ctl ansible managed-node-1 -m ansible.builtin.ping -vvv 2>&1 | grep -E "PUT|SSH: EXEC" | cut -c1-200

titre "Le labo"
ctl ansible --version | head -2
ctl ssh managed-node-1 hostname

titre "L’inventaire, les motifs"
ctl ansible-inventory --graph
for motif in web_server 'all:!web_server' 'mon_groupe:&web_server' inconnu; do
  ctl ansible "$motif" --list-hosts
done

titre "Exercice : quels hôtes ?"
ctl bash -c 'cd exercice && ansible-inventory -i parc.yaml --graph
  for m in ungrouped "prod:!bdd" "web:&nouveaux" "nouveaux:!web:&prod"; do
    echo "== $m"; ansible -i parc.yaml "$m" --list-hosts; done'

titre "Commandes ad hoc"
ctl ansible all -m ansible.builtin.ping
ctl ansible managed-node-1 -m ansible.builtin.setup -a "filter=ansible_distribution*"

titre "Le playbook, où déclarer une variable"
ctl ansible-playbook hello_world.yml

titre "apt : deux passages"
ctl ansible-playbook install-common-software.yaml
ctl ansible-playbook install-common-software.yaml

titre "shell : deux passages (version naïve)"
ctl ansible-playbook write_hello_world_naif.yaml -l managed-node-1
ctl ansible-playbook write_hello_world_naif.yaml -l managed-node-1
ctl ansible managed-node-1 -a "cat /hello /hello_world"

titre "Réparer : creates"
ctl ansible all -m ansible.builtin.file -a "path=/hello state=absent"
ctl ansible all -m ansible.builtin.file -a "path=/hello_world state=absent"
ctl ansible-playbook write_hello_world.yaml
ctl ansible-playbook write_hello_world.yaml

titre "Exercice : prédire changed"
ctl ansible-playbook preparer.yml -l managed-node-1
ctl ansible-playbook preparer.yml -l managed-node-1
docker compose exec -T managed-node-1 sh -c 'echo "Modifié à la main" > /srv/site/index.txt'
ctl ansible-playbook preparer.yml -l managed-node-1 --diff
ctl ansible-playbook preparer.yml -l managed-node-1 --check

titre "Précédence : vars de play, -e"
ctl ansible-playbook precedence.yml
ctl bash -c "ansible-playbook precedence.yml -e 'welcome_msg=\"from -e\"'"

titre "Entre groupes"
for f in hosts.yaml hosts-prio.yaml hosts-enfant.yaml; do
  docker compose exec -T -w /etc/ansible/demo-groupes control-node \
    ansible-inventory -i "$f" --host managed-node-1
done

titre "Exercice : qui gagne ?"
ctl bash -c 'cd exercice && grep -r msg group_vars host_vars | sort
  for h in web1 web2 bdd1 bastion; do echo "== $h"; ansible-inventory -i parc.yaml --host "$h"; done
  ansible-playbook -i parc.yaml qui-gagne.yml'

titre "Rôle, gabarit, handler"
ctl tree roles/nginx_hello_world
ctl ansible-playbook site-web.yml
ctl ansible-playbook site-web.yml
ctl curl -s http://managed-node-1:8080/
ctl ansible web_server -a "head -4 /etc/nginx/sites-available/default"
printf 'nginx_hello_world_port: 80\n' > projet/group_vars/web_server.yaml
ctl ansible-playbook site-web.yml --diff || true
ctl curl -s http://managed-node-1/ || true
rm -f projet/group_vars/web_server.yaml

titre "ansible-lint"
ctl ansible-lint --offline preparer-naif.yml || true
