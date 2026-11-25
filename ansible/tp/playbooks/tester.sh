#!/usr/bin/env bash
# Harnais des corrigés du TP Ansible, séance 2 « Playbooks, variables et gabarits ».
#
# Usage : ./tester.sh [--lint | --up] [--keep]
#   --lint  (défaut) validations, sans démarrer le labo : bash -n et shellcheck des scripts,
#           puis, dans l’image du nœud de contrôle (construite pour l’occasion) :
#           ansible-playbook --syntax-check de chaque playbook, ansible-lint du projet, et
#           le refus par ansible-lint des deux contre-exemples, avec les règles attendues.
#   --up    --lint, puis le labo démarré (projet Compose tptest-ansible-playbooks), avec
#           l’inventaire et ansible.cfg de la séance 1 : chaque playbook joué, ses sorties
#           et l’état des nœuds vérifiés (messages, paquets, fichiers et leurs dates,
#           /etc/motd), le second passage à changed=0 pour les playbooks idempotents, à
#           changed=2 pour la version naïve ; le crochet pre-commit dans un dépôt jetable.
#   --keep  laisse le labo en marche et les fichiers temporaires (pour examiner un échec).
#
# Prérequis : bash, Docker avec Compose v2, shellcheck. La construction des images a
# besoin du réseau (dépôts Debian, PyPI).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
seance="playbooks"
# shellcheck source=SCRIPTDIR/../harnais.sh
. "$ici/../harnais.sh"

# Contre-exemples, refusés exprès par ansible-lint : exclus du lint du projet.
naif="write_hello_world_naif.yaml"
latest="install-common-software-latest.yaml"

titre "Séance 2 : validations"
lint_scripts "$ici/tester.sh" "$ici/corrige/hooks/pre-commit"
copier "$ici/../inventaire/corrige" ansible.cfg inventory
copier "$ici/corrige" group_vars host_vars hooks templates hello_world-1.yml hello_world-2.yml \
  hello_world.yml install-common-software.yaml "$latest" "$naif" write_hello_world.yaml motd.yml
construire control-node || bilan
syntaxe hello_world-1.yml hello_world-2.yml hello_world.yml install-common-software.yaml "$latest" \
  "$naif" write_hello_world.yaml motd.yml
lint_projet "$naif" "$latest"
lint_refuse "$naif" no-changed-when
lint_refuse "$latest" package-latest

if [ "$mode" = "up" ]; then
  titre "Séance 2 : le labo"
  if ! { construire && monter_labo; }; then bilan; fi
  cabler || bilan
  deux="managed-node-1 managed-node-2"
  paires() { local h r=(); for h in $deux; do r+=("$h=$1"); done; printf '%s\n' "${r[@]}"; }

  # Étape 1
  jouer h1 hello_world-1.yml; passage "étape 1 : hello_world-1.yml" h1 $? $(paires 3,0)
  verifier "étape 1 : deux fois « hello world »" test "$(grep -c '"msg": "hello world"' "$travail/h1.log")" -eq 2

  # Étape 2
  jouer h2 hello_world-2.yml; passage "étape 2 : hello_world-2.yml" h2 $? $(paires 3,0)
  verifier "étape 2 : managed-node-1 affiche host_vars, managed-node-2 group_vars" \
    test "$(grep -A1 '^ok: \[managed-node-[12]\] =>' "$travail/h2.log" | sed -n 's/.*"msg": "\(.*\)"/\1/p' | sort | tr '\n' '|')" \
    = "Bonjour le monde from group_vars|Bonjour le monde from host_vars|"
  contient "étape 2 : managed-node-1 → from host_vars" h2 '"msg": "Bonjour le monde from host_vars"'
  jouer h2e hello_world-2.yml -e 'welcome_msg="from -e"'; passage "étape 2 : -e" h2e $? $(paires 3,0)
  verifier "étape 2 : avec -e, les deux nœuds affichent « from -e »" \
    test "$(grep -c '"msg": "from -e"' "$travail/h2e.log")" -eq 2

  # Étape 3
  jouer h3 hello_world.yml; passage "étape 3 : hello_world.yml" h3 $? $(paires 6,0)
  contient "étape 3 : le nom d’hôte, un fact" h3 '"msg": "managed-node-2"'
  verifier "étape 3 : la distribution, par setup et register : Debian ×2" \
    test "$(grep -c '"msg": "Debian"' "$travail/h3.log")" -eq 2

  # Étape 4 : le crochet, dans un dépôt jetable du nœud de contrôle.
  # shellcheck disable=SC2016 # script exécuté dans le conteneur
  crochet='set -e; rm -rf /tmp/depot; mkdir /tmp/depot; cd /tmp/depot; git init -q
    git config user.email tp@exemple.org; git config user.name tp
    cp /etc/ansible/hooks/pre-commit .git/hooks/pre-commit
    cp /etc/ansible/hello_world.yml .; git add hello_world.yml
    git commit -q -m "Premier playbook" && echo ACCEPTE-1
    cp /etc/ansible/write_hello_world_naif.yaml .; git add write_hello_world_naif.yaml
    git commit -q -m naif 2> /dev/null && echo ACCEPTE-2 || echo REFUSE-2
    git reset -q; printf "#!/bin/sh\necho \$1\n" > a.sh; git add a.sh
    git commit -q -m sh > /dev/null 2>&1 && echo ACCEPTE-3 || echo REFUSE-3'
  ctl bash -c "$crochet" > "$travail/crochet.log" 2>&1 || true
  verifier "étape 4 : pre-commit accepte un playbook propre, refuse le naïf et un script fautif" \
    test "$(grep -E '^(ACCEPTE|REFUSE)-' "$travail/crochet.log" | tr '\n' ' ')" = "ACCEPTE-1 REFUSE-2 REFUSE-3 "
  contient "étape 4 : le crochet nomme le fichier refusé" crochet "ansible-lint refuse write_hello_world_naif.yaml"

  # Étape 5
  jouer apt1 install-common-software.yaml; passage "étape 5 : apt, premier passage" apt1 $? $(paires 2,1)
  jouer apt2 install-common-software.yaml; passage "étape 5 : apt, second passage" apt2 $? $(paires 2,0)
  verifier "étape 5 : htop, ncdu et vim installés sur managed-node-2" \
    silencieux_sauf_echec noeud managed-node-2 dpkg -s htop ncdu vim

  # Étape 6
  dates() { ctl ansible managed-node-1 -a "stat -c '%y %n' /hello /world /hello_world" 2> /dev/null | grep ' /'; }
  jouer n1 "$naif"; passage "étape 6 : version naïve, premier passage" n1 $? $(paires 4,3)
  avant="$(dates)"
  jouer n2 "$naif"; passage "étape 6 : version naïve, second passage (shell et command : changed)" n2 $? $(paires 4,2)
  apres="$(dates)"
  verifier "étape 6 : /hello et /world réécrits, /hello_world intact" \
    test "$(diff <(echo "$avant") <(echo "$apres") | sed -n 's/^> .* //p' | tr '\n' ' ')" = "/hello /world "
  verifier "étape 6 : /hello contient une seule ligne « hello »" \
    test "$(noeud managed-node-1 cat /hello)" = "hello"

  # Étape 7
  for f in /hello /world /hello_world; do
    ctl ansible all -m ansible.builtin.file -a "path=$f state=absent" > /dev/null 2>&1 || true
  done
  jouer r1 write_hello_world.yaml; passage "étape 7 : version réparée, premier passage" r1 $? $(paires 5,3)
  jouer r2 write_hello_world.yaml; passage "étape 7 : version réparée, second passage" r2 $? $(paires 4,0)
  contient "étape 7 : command sautée au second passage" r2 "skipping: [managed-node-1]"
  verifier "étape 7 : /world contient « world »" test "$(noeud managed-node-2 cat /world)" = "world"

  # Étape 9
  jouer m1 motd.yml; passage "étape 9 : motd, premier passage" m1 $? $(paires 2,1)
  jouer m2 motd.yml; passage "étape 9 : motd, second passage" m2 $? $(paires 2,0)
  verifier "étape 9 : /etc/motd de managed-node-1" test "$(noeud managed-node-1 head -2 /etc/motd)" = \
    "$(printf 'Bonjour le monde from host_vars\nMachine managed-node-1, sous Debian %s.' \
      "$(noeud managed-node-1 sh -c '. /etc/os-release; cat /etc/debian_version')")"
  jouer m3 motd.yml --check --diff -e 'welcome_msg="Maintenance ce soir"'
  passage "étape 9 : --check --diff annonce le changement" m3 $? $(paires 2,1)
  contient "étape 9 : --diff montre la nouvelle ligne" m3 "+Maintenance ce soir"
  verifier "étape 9 : --check n’a rien modifié" test "$(noeud managed-node-2 head -1 /etc/motd)" = "Bonjour le monde from group_vars"
fi

bilan
