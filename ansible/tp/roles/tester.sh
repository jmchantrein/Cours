#!/usr/bin/env bash
# Harnais des corrigés du TP Ansible, séance 3 « Un rôle : nginx_hello_world ».
#
# Usage : ./tester.sh [--lint | --up] [--keep]
#   --lint  (défaut) validations, sans démarrer le labo : docker compose config et
#           docker build --check du labo, puis, dans l’image du nœud de contrôle (construite
#           pour l’occasion) : ansible-playbook --syntax-check de chaque playbook, ansible-lint
#           de site-web.yml (rôle compris), ansible-galaxy role init et l’arborescence du rôle.
#   --up    --lint, puis le labo démarré (projet Compose tptest-ansible-roles), avec l’inventaire
#           et ansible.cfg de la séance 1 : le rôle joué deux fois (le handler au premier
#           passage seulement, la page servie sur le port 8080), le port surchargé par
#           group_vars (80) puis par -e (8081) avec le handler à chaque changement, le fichier
#           signé par ansible_managed, puis site-local.yml sur le nœud de contrôle.
#   --keep  laisse le labo en marche et les fichiers temporaires (pour examiner un échec).
#
# Prérequis : bash, Docker avec Compose v2, shellcheck. La construction des images a
# besoin du réseau (dépôts Debian, PyPI).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
seance="roles"
# shellcheck source=SCRIPTDIR/../harnais.sh
. "$ici/../harnais.sh"

# Le message de ansible_managed (group_vars/all.yaml), tel que l’étape 7 le déclare.
signature="$(sed -n 's/^ansible_managed: "\(.*\)"$/\1/p' "$ici/corrige/group_vars/all.yaml")"
# L’arborescence du rôle, telle que la montre la diapo « Rôles ».
arbre_attendu='roles/nginx_hello_world
├── defaults
│   └── main.yml
├── files
│   └── index.html
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── tasks
│   └── main.yml
└── templates
    └── etc_nginx_sites_available_default.j2

7 directories, 6 files'

titre "Séance 3 : validations"
lint_scripts "$ici/tester.sh"
copier "$ici/../inventaire/corrige" ansible.cfg inventory
copier "$ici/corrige" roles site-web.yml site-local.yml
# Les contre-exemples que la séance 2 laisse dans le dossier de l’étudiant : ansible-lint, sans argument, les refuserait.
copier "$ici/../playbooks/corrige" write_hello_world_naif.yaml install-common-software-latest.yaml
construire control-node || bilan
syntaxe site-web.yml site-local.yml
lint_playbook site-web.yml
refuse() { ! "$@" > /dev/null 2>&1; }
verifier "ansible-lint sans argument refuse les contre-exemples de la séance 2 (d’où « site-web.yml » à l’étape 5)" \
  refuse dans_controle ansible-lint --offline
verifier "signature de ansible_managed lue dans group_vars/all.yaml" test -n "$signature"
verifier "ansible-galaxy role init : defaults files handlers meta tasks templates tests vars, README.md" \
  test "$(dans_controle sh -c 'cd /tmp && ansible-galaxy role init --init-path /tmp/essai nginx_hello_world > /dev/null \
    && cd essai/nginx_hello_world && ls -A | tr "\n" " "' 2> /dev/null)" = "README.md defaults files handlers meta tasks templates tests vars "
# tree indente avec des espaces insécables : comparés comme des espaces.
verifier "tree : l’arborescence du rôle (diapo « Rôles »)" \
  test "$(dans_controle tree roles/nginx_hello_world 2> /dev/null | sed 's/\xc2\xa0/ /g')" = "$arbre_attendu"

if [ "$mode" = "up" ]; then
  titre "Séance 3 : le labo"
  if ! { construire && monter_labo; }; then bilan; fi
  cabler || bilan

  page() { ctl curl -s --max-time 5 "http://managed-node-1:$1/" || true; }
  # Nginx tient son port : la ligne « listen » du fichier déployé.
  port_ecoute() { noeud managed-node-1 sed -n 's/^ *listen \([0-9]*\) default_server;$/\1/p' /etc/nginx/sites-available/default; }

  # Étape 5 : le rôle, avec le port par défaut (8080)
  jouer s1 site-web.yml; passage "étape 5 : site-web.yml, premier passage" s1 managed-node-1=6,5
  contient "étape 5 : le handler redémarre nginx au premier passage" s1 "RUNNING HANDLER [nginx_hello_world : Redémarrer nginx]"
  jouer s2 site-web.yml; passage "étape 5 : site-web.yml, second passage" s2 managed-node-1=5,0
  verifier "étape 5 : aucun handler au second passage" test "$(grep -c 'RUNNING HANDLER' "$travail/s2.log")" -eq 0
  verifier "étape 5 : le play ne vise que web_server (managed-node-2 absent)" test "$(grep -c managed-node-2 "$travail/s1.log")" -eq 0
  verifier "étape 5 : curl managed-node-1:8080 : Hello world !" test "$(page 8080)" = "<h1>Hello world !</h1>"
  verifier "étape 5 : nginx écoute sur 8080, managed-node-2 n’a pas nginx" \
    test "$(port_ecoute)" = 8080 -a "$(noeud managed-node-2 sh -c 'command -v nginx || echo aucun')" = aucun
  verifier "étape 5 : la page tient de files/ : propriétaire www-data, droits 644" \
    test "$(noeud managed-node-1 stat -c '%U:%G %a' /var/www/html/index.html)" = "www-data:www-data 644"
  verifier "étape 5 : première ligne du fichier déployé : « # Ansible managed » (valeur par défaut)" \
    test "$(noeud managed-node-1 head -1 /etc/nginx/sites-available/default)" = "# Ansible managed"

  # Étape 6 : surcharger le port
  copier "$ici/corrige" group_vars/web_server.yaml
  jouer s3 site-web.yml; passage "étape 6 : group_vars/web_server.yaml (80) bat defaults/ (8080)" s3 managed-node-1=6,2
  contient "étape 6 : le handler redémarre nginx" s3 "RUNNING HANDLER [nginx_hello_world : Redémarrer nginx]"
  verifier "étape 6 : curl managed-node-1:80 : Hello world !" test "$(page 80)" = "<h1>Hello world !</h1>"
  verifier "étape 6 : nginx n’écoute plus sur 8080" test -z "$(page 8080)"
  jouer s4 site-web.yml -e nginx_hello_world_port=8081
  passage "étape 6 : -e (8081) bat group_vars (80)" s4 managed-node-1=6,2
  verifier "étape 6 : curl managed-node-1:8081 : Hello world !" test "$(page 8081)" = "<h1>Hello world !</h1>"
  jouer s5 site-web.yml; passage "étape 6 : sans -e, retour au port 80" s5 managed-node-1=6,2
  verifier "étape 6 : le port 80 sert de nouveau la page" test "$(page 80)" = "<h1>Hello world !</h1>"

  # Étape 7 : le fichier signé
  copier "$ici/corrige" group_vars/all.yaml
  jouer s6 site-web.yml; passage "étape 7 : ansible_managed personnalisé : le gabarit change, le handler tire" s6 managed-node-1=6,2
  verifier "étape 7 : première ligne du fichier déployé = ansible_managed de group_vars/all.yaml" \
    test "$(noeud managed-node-1 head -1 /etc/nginx/sites-available/default)" = "# $signature"
  jouer s7 site-web.yml; passage "étape 7 : second passage" s7 managed-node-1=5,0

  # Étape 8 : le nœud de contrôle se configure lui-même (localhost, sans SSH)
  jouer l1 site-local.yml; passage "étape 8 : site-local.yml, premier passage" l1 localhost=1,1
  jouer l2 site-local.yml; passage "étape 8 : site-local.yml, second passage" l2 localhost=1,0
  verifier "étape 8 : /root/.bashrc : le bloc, un seul, avec ses trois lignes" \
    test "$(ctl sh -c "grep -c 'raccourcis du TP Ansible' /root/.bashrc; grep -c -E '^(cd /etc/ansible|alias ap=|alias al=)' /root/.bashrc")" = "$(printf '2\n3')"
  verifier "étape 8 : un shell de root s’ouvre dans /etc/ansible, l’alias ap existe" \
    test "$(ctl bash -ic 'pwd; type ap' 2> /dev/null | tr '\n' ' ')" = "/etc/ansible ap is aliased to \`ansible-playbook' "
fi

bilan
