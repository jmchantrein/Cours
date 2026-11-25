#!/usr/bin/env bash
# Harnais des corrigés du TP Ansible, séance 1 « Inventaire et commandes ad hoc ».
#
# Usage : ./tester.sh [--lint | --up] [--keep]
#   --lint  (défaut) validations, sans démarrer le labo : bash -n et shellcheck des scripts,
#           docker compose config et docker build --check du labo, puis, dans l’image du
#           nœud de contrôle (construite pour l’occasion) : ansible-lint et l’inventaire
#           résolu par ansible-inventory --graph.
#   --up    --lint, puis le labo démarré (projet Compose tptest-ansible-inventaire) :
#           câblage SSH par corrige/cabler-ssh.sh (deux fois : il est rejouable),
#           ansible.cfg lu, ping de tous les nœuds et d’un groupe, les motifs de l’étape 5,
#           les facts de l’étape 6, le module file en deux passages (CHANGED puis SUCCESS).
#   --keep  laisse le labo en marche et les fichiers temporaires (pour examiner un échec).
#
# Prérequis : bash, Docker avec Compose v2, shellcheck. La construction de l’image du nœud
# de contrôle a besoin du réseau (dépôts Debian, PyPI), --up aussi (dépôts Debian).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
seance="inventaire"
# shellcheck source=SCRIPTDIR/../harnais.sh
. "$ici/../harnais.sh"

titre "Séance 1 : validations"
lint_scripts "$ici/tester.sh" "$ici/corrige/cabler-ssh.sh"
verifier "shellcheck harnais.sh" env LC_ALL=C.UTF-8 shellcheck "$ici/../harnais.sh"
lint_labo
copier "$ici/corrige" ansible.cfg inventory
construire control-node || bilan

graphe_attendu='@all:
  |--@ungrouped:
  |--@mon_groupe:
  |  |--managed-node-1
  |  |--managed-node-2
  |--@web_server:
  |  |--managed-node-1'
verifier "ansible-inventory --graph : l’inventaire de l’étape 4" \
  test "$(dans_controle ansible-inventory --graph 2> /dev/null)" = "$graphe_attendu"
# shellcheck disable=SC2119 # sans contre-exemple à exclure
lint_projet

if [ "$mode" = "up" ]; then
  titre "Séance 1 : le labo"
  if ! { construire && monter_labo; }; then bilan; fi
  # Étape 1 : sans clé, le nœud refuse le nœud de contrôle.
  verifier "étape 1 : sans câblage, ssh managed-node-1 échoue" \
    sh -c '! docker compose exec -T control-node ssh -o BatchMode=yes managed-node-1 true 2> /dev/null'
  cabler || bilan
  verifier "étape 2 : cabler-ssh.sh se rejoue sans erreur" silencieux_sauf_echec sh -c "cd '$labo' && '$cabler_ssh'"

  ctl ansible --version > "$travail/version.log" 2>&1 || true
  contient "étape 3 : ansible --version lit /etc/ansible/ansible.cfg" version "config file = /etc/ansible/ansible.cfg"

  ctl ansible all -m ansible.builtin.ping > "$travail/ping-all.log" 2>&1 || true
  verifier "étape 4 : ansible all -m ansible.builtin.ping : deux SUCCESS" \
    test "$(grep -c '| SUCCESS =>' "$travail/ping-all.log")" -eq 2
  contient "étape 4 : interpréteur découvert sur les nœuds : python3.13" ping-all '"discovered_interpreter_python": "/usr/bin/python3.13"'
  ctl ansible mon_groupe -m ansible.builtin.ping > "$travail/ping-groupe.log" 2>&1 || true
  verifier "étape 4 : ansible mon_groupe -m ansible.builtin.ping : deux SUCCESS" \
    test "$(grep -c '| SUCCESS =>' "$travail/ping-groupe.log")" -eq 2

  hotes() { ctl ansible "$1" --list-hosts 2> /dev/null | sed -n 's/^    //p' | sort | tr '\n' ' '; }
  for cas in "web_server=managed-node-1 " "all:!web_server=managed-node-2 " \
    "mon_groupe:&web_server=managed-node-1 " "managed-node-*=managed-node-1 managed-node-2 " "inconnu="; do
    verifier "étape 5 : motif ${cas%%=*} → ${cas#*=}" test "$(hotes "${cas%%=*}")" = "${cas#*=}"
  done

  ctl ansible managed-node-1 -m ansible.builtin.setup -a "filter=ansible_distribution*" > "$travail/setup.log" 2>&1 || true
  contient "étape 6 : ansible_distribution vaut Debian" setup '"ansible_distribution": "Debian"'
  contient "étape 6 : ansible_distribution_major_version vaut 13" setup '"ansible_distribution_major_version": "13"'
  ctl env ANSIBLE_CALLBACK_RESULT_FORMAT=yaml ansible managed-node-1 -m ansible.builtin.setup \
    -a "filter=ansible_distribution" > "$travail/setup-yaml.log" 2>&1 || true
  contient "étape 6 : la même réponse en YAML" setup-yaml "ansible_distribution: Debian"

  ctl ansible all -m ansible.builtin.file -a "path=/srv/tp state=directory mode=0755" > "$travail/file-1.log" 2>&1 || true
  ctl ansible all -m ansible.builtin.file -a "path=/srv/tp state=directory mode=0755" > "$travail/file-2.log" 2>&1 || true
  verifier "étape 6 : file, premier passage : CHANGED sur les deux nœuds" \
    test "$(grep -c '| CHANGED =>' "$travail/file-1.log")" -eq 2
  verifier "étape 6 : file, second passage : SUCCESS, \"changed\": false sur les deux nœuds" \
    test "$(grep -c '| SUCCESS =>' "$travail/file-2.log")" -eq 2
  ctl ansible all -a "ls -ld /srv/tp" > "$travail/command.log" 2>&1 || true
  verifier "étape 6 : le module command répond CHANGED, même pour lire" \
    test "$(grep -c '| CHANGED | rc=0 >>' "$travail/command.log")" -eq 2
fi

bilan
