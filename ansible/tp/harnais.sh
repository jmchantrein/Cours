# shellcheck shell=bash
# Fonctions communes aux harnais des trois séances du TP Ansible (inventaire, playbooks,
# roles), chargées par <séance>/tester.sh après qu’il a fixé « seance » et « ici ».
#
# Le harnais monte le labo du cours (ansible/cm/labo, la seule source du labo) sous le projet
# Compose « tptest-ansible-<séance> », avec pour /etc/ansible un dossier temporaire où il
# copie les corrigés. Il ne crée et ne supprime que ces ressources : conteneurs, réseau et
# images du projet, dossier temporaire.
#
# Proxy HTTPS qui réécrit TLS (facultatif, absent en CI) : convention du dépôt (README.md),
#   TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./tester.sh --up
# Le harnais construit alors, par ansible/cm/labo/proxy.sh, une base debian:13-slim qui passe
# par ce proxy et la substitue à debian:13-slim, sans toucher aux fichiers du labo. Sans
# TPTEST_CA, il ignore HTTPS_PROXY et se comporte comme en CI.

: "${ici:?ici : dossier de la séance}" "${seance:?seance : nom de la séance}"
mode="lint"; garder=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

manque() { echo "$1 est introuvable : $2" >&2; exit 1; }
command -v docker > /dev/null || manque docker "installez Docker."
docker info > /dev/null 2>&1 || manque "Le démon Docker" "docker info ne répond pas."
docker compose version > /dev/null 2>&1 || manque "Le plugin Compose v2" "installez docker compose."
command -v shellcheck > /dev/null || manque shellcheck "installez le paquet shellcheck."

labo="$(cd "$ici/../../cm/labo" && pwd)"
cabler_ssh="$(cd "$ici/../inventaire/corrige" && pwd)/cabler-ssh.sh"
projet="$(mktemp -d "${TMPDIR:-/tmp}/tptest-ansible-projet.XXXXXX")"
travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest-ansible-journaux.XXXXXX")"
export COMPOSE_FILE="$labo/compose.yaml" COMPOSE_PROJECT_NAME="tptest-ansible-$seance" ANSIBLE_PROJET="$projet"
# shellcheck source=/dev/null
. "$labo/proxy.sh"

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
verifier() { # $1 libellé, puis la commande
  local libelle="$1"; shift
  if "$@"; then ok "$libelle"; else ko "$libelle"; fi
}
bilan() {
  printf '\n======== Bilan %s (--%s) : %s vérifications réussies, %s en échec ========\n' \
    "$seance" "$mode" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then printf '  - %s\n' "${echecs[@]}"; exit 1; fi
}

# ------------------------------------------------------------------- nettoyage

silencieux() { "$@" > /dev/null 2>&1 || true; }
image_construite=""
nettoyer() {
  if [ -n "$garder" ]; then
    echo "--keep : projet Compose $COMPOSE_PROJECT_NAME conservé ; /etc/ansible = $projet ; journaux : $travail"
    return 0
  fi
  # Les fichiers écrits par les conteneurs appartiennent à root : un conteneur les efface.
  if [ -n "$image_construite" ]; then
    silencieux docker compose run --rm --no-deps -T control-node find /etc/ansible -mindepth 1 -delete
  fi
  silencieux docker compose down --volumes --remove-orphans --rmi local -t 1
  silencieux docker image rm "$COMPOSE_PROJECT_NAME-base"
  rm -rf -- "${projet:?}" "${travail:?}"
}
trap nettoyer EXIT
labo_proxy "$COMPOSE_PROJECT_NAME" "$travail"

# ------------------------------------------------------------- outils du labo

ctl() { docker compose exec -T control-node "$@"; }
noeud() { local n="$1"; shift; docker compose exec -T "$n" "$@"; }

copier() { # $1 dossier source, puis chemins relatifs à copier dans le projet
  local src="$1"; shift
  for chemin in "$@"; do
    mkdir -p "$projet/$(dirname "$chemin")"
    cp -R "$src/$chemin" "$projet/$chemin"
  done
}

construire() { # services à construire (aucun : tous)
  if docker compose build "$@" > "$travail/build.log" 2>&1; then
    image_construite="1"; ok "construction du labo (${*:-tous les services})"
  else
    ko "construction du labo (${*:-tous les services})"; tail -n 30 "$travail/build.log"; return 1
  fi
}

# Une commande dans le nœud de contrôle, dans /etc/ansible, sans démarrer le labo.
dans_controle() { docker compose run --rm --no-deps -T control-node "$@"; }

monter_labo() {
  if ! docker compose up -d > "$travail/up.log" 2>&1; then
    ko "docker compose up"; tail -n 20 "$travail/up.log"; return 1
  fi
  ok "docker compose up : control-node, managed-node-1, managed-node-2"
  for _ in $(seq 1 30); do
    [ "$(ctl ssh-keyscan -T 2 managed-node-1 managed-node-2 2> /dev/null | grep -c ssh-ed25519)" -eq 2 ] && return 0
    sleep 1
  done
  ko "les serveurs SSH des nœuds ne répondent pas"; return 1
}

cabler() { # le corrigé de l’étape 2 de la séance « inventaire »
  local sortie
  if sortie="$(cd "$labo" && "$cabler_ssh" 2>&1)" \
    && [ "$sortie" = "$(printf 'managed-node-1\nmanaged-node-2')" ]; then
    ok "cabler-ssh.sh : ssh managed-node-1 et managed-node-2 répondent par leur nom"
  else
    ko "cabler-ssh.sh"; printf '%s\n' "$sortie" | tail -n 20; return 1
  fi
}

# ----------------------------------------------------------------- validations

lint_scripts() { # scripts bash : syntaxe, droit d’exécution, shellcheck
  local s nom
  for s in "$@"; do
    nom="${s#"$ici"/}"
    if ! bash -n "$s"; then ko "syntaxe $nom"; continue; fi
    if [ ! -x "$s" ]; then ko "$nom n’est pas exécutable (chmod +x)"; continue; fi
    if LC_ALL=C.UTF-8 shellcheck -x "$s"; then ok "shellcheck $nom"; else ko "shellcheck $nom"; fi
  done
}

lint_labo() {
  verifier "docker compose config (labo)" docker compose config --quiet
  if docker build --help 2> /dev/null | grep -q -- '--check'; then
    local f
    for f in Dockerfile.control Dockerfile.node; do
      verifier "docker build --check $f" silencieux_sauf_echec docker build --check -f "$labo/$f" "$labo"
    done
  fi
}
silencieux_sauf_echec() { local s; if s="$("$@" 2>&1)"; then return 0; fi; printf '%s\n' "$s" | tail -n 20; return 1; }

# ansible-playbook --syntax-check sur chaque playbook nommé.
syntaxe() {
  local pb
  for pb in "$@"; do
    verifier "ansible-playbook --syntax-check $pb" silencieux_sauf_echec dans_controle ansible-playbook --syntax-check "$pb"
  done
}

# ansible-lint sur tout le projet, sauf les contre-exemples nommés.
lint_projet() {
  local exclus=() f
  for f in "$@"; do exclus+=(--exclude "$f"); done
  if dans_controle ansible-lint --offline "${exclus[@]}" > "$travail/lint.log" 2>&1; then
    ok "ansible-lint du projet${*:+ (sauf $*)}"
  else
    ko "ansible-lint du projet"; tail -n 30 "$travail/lint.log"
  fi
}

# Un contre-exemple : ansible-lint doit le refuser, avec exactement ces règles.
lint_refuse() { # $1 fichier, puis les règles attendues
  local f="$1"; shift
  local sortie trouvees attendues
  if sortie="$(dans_controle ansible-lint --offline "$f" 2>&1)"; then
    ko "ansible-lint accepte $f, qui doit être refusé"; return 0
  fi
  trouvees="$(sed -n 's/^\([a-z-]*\): .*/\1/p' <<< "$sortie" | grep -v '^WARNING$' | sort -u | tr '\n' ' ')"
  attendues="$(printf '%s\n' "$@" | sort -u | tr '\n' ' ')"
  if [ "$trouvees" = "$attendues" ]; then ok "ansible-lint refuse $f : $*"
  else ko "ansible-lint sur $f : règles « $trouvees», attendues « $attendues»"; fi
}

# --------------------------------------------------------------- vérifications

# Joue un playbook ; la sortie va dans $travail/<journal>.log.
# Son code de retour est gardé dans « rc », pour passage.
jouer() { # $1 journal, puis les arguments d’ansible-playbook
  local journal="$1"; shift
  rc=0; ctl ansible-playbook "$@" > "$travail/$journal.log" 2>&1 || rc=$?
}
journal() { cat "$travail/$1.log"; }

# Le bilan PLAY RECAP d’un hôte : « ok=N changed=N unreachable=N failed=N ».
recap() { # $1 journal, $2 hôte
  sed -n "s/^$2 *: \(ok=[0-9]*\) *\(changed=[0-9]*\) *\(unreachable=[0-9]*\) *\(failed=[0-9]*\).*/\1 \2 \3 \4/p" "$travail/$1.log"
}

# Le dernier passage joué (code de retour « rc ») : pour chaque hôte, « ok=… changed=… » attendus.
passage() { # $1 libellé, $2 journal, puis paires hôte=ok,changed
  local libelle="$1" j="$2"; shift 2
  local h attendu obtenu tout=""
  for h in "$@"; do
    attendu="ok=${h#*=}"; attendu="${attendu/,/ changed=} unreachable=0 failed=0"
    obtenu="$(recap "$j" "${h%%=*}")"
    tout+=" ${h%%=*}: $obtenu ;"
    if [ "$rc" -ne 0 ] || [ "$obtenu" != "$attendu" ]; then
      ko "$libelle :$tout attendu ${h%%=*}: $attendu (code $rc)"; tail -n 25 "$travail/$j.log"; return 0
    fi
  done
  ok "$libelle :${tout%;}"
}

# Le même bilan sur les deux nœuds gérés.
passages() { passage "$1" "$2" "managed-node-1=$3" "managed-node-2=$3"; }

contient() { # $1 libellé, $2 journal, $3 texte attendu (fixe)
  if grep -qF -- "$3" "$travail/$2.log"; then ok "$1"; else ko "$1 : « $3 » absent de la sortie"; tail -n 25 "$travail/$2.log"; fi
}
