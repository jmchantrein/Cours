#!/usr/bin/env bash
# Harnais de test des corrigés du TP « SSH : clés, bastion, tunnel, durcissement ».
#
# Il exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé affiche : un
# corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--keep]
#   --lint   (défaut) sans rien construire : shellcheck et bash -n des scripts,
#            docker compose config, docker build --check, et, si ssh et sshd
#            sont installés sur l'hôte, ssh -G sur config et sshd -t sur le
#            fichier de durcissement.
#   --up     monte le labo (projet Compose « tptest-ssh »), rejoue les étapes 1
#            à 10 dans l'ordre de l'énoncé, vérifie, puis supprime le labo.
#   --keep   ne supprime pas le labo en fin de test (pour examiner un échec).
#
# Ce que --up vérifie :
#   2   la clé privée est chiffrée par la phrase de passe ;
#   3   known_hosts contient la clé d'hôte que montre la console du bastion ;
#   4   la clé publique est dans authorized_keys du bastion, droits 600 ;
#   5   l'agent détient la clé : connexion par clé réussie sans rien saisir ;
#   6   ssh -G retient port 2222 et utilisateur ada ; « ssh bastion » répond ;
#   7   le poste ne voit pas le serveur ; le rebond par le bastion aboutit, et
#       le serveur voit venir la connexion de l'adresse privée du bastion ;
#   8   le fichier copié par scp et le site synchronisé par rsync sont sur le
#       serveur, à jour ;
#   9   le port 8080 redirigé du poste répond par la page de supervision ;
#   10  avant : mot de passe et root (par clé) acceptés ; après : mot de passe
#       refusé, root refusé, clé acceptée, et la session ouverte avant le
#       rechargement de sshd est toujours vivante.
#
# Ressources : seulement le projet Compose « tptest-ssh » (conteneurs, réseaux,
# images tptest-ssh-*) et, derrière un proxy, l'image tptest-ssh-debian.
#
# Derrière un proxy HTTPS qui réécrit TLS (facultatif, absent en CI) :
#   TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://127.0.0.1:port ./tester.sh --up
# Le harnais construit alors une image de base debian:13-slim qui passe par ce
# proxy, et la substitue à debian:13-slim (contexte nommé), sans toucher aux
# fichiers du corrigé.
#
# Prérequis : bash, Docker avec Compose v2 et Buildx ; shellcheck pour --lint.
# --up a besoin du réseau (deb.debian.org, Docker Hub).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"

mode="lint"; garder=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,38p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

command -v docker > /dev/null || { echo "docker est introuvable dans le PATH." >&2; exit 1; }
docker compose version > /dev/null 2>&1 || { echo "Le plugin Compose v2 (docker compose) est requis." >&2; exit 1; }

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
indente() { sed 's/^/       /'; }

bilan() {
  printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec ========\n' "$mode" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then
    printf '  - %s\n' "${echecs[@]}"
    exit 1
  fi
  exit 0
}

# ------------------------------------------------------------------ validation

titre "Lint"
for s in "$corrige"/*.sh "$corrige"/machine/demarrer.sh; do
  nom="${s#"$corrige"/}"
  if [ ! -x "$s" ]; then ko "$nom n'est pas exécutable (chmod +x)"; continue; fi
  if ! bash -n "$s"; then ko "syntaxe $nom"; continue; fi
  if command -v shellcheck > /dev/null; then
    if LC_ALL=C.UTF-8 shellcheck "$s"; then ok "shellcheck $nom"; else ko "shellcheck $nom"; fi
  else
    ok "bash -n $nom (shellcheck absent : non analysé)"
  fi
done

if docker compose -f "$corrige/compose.yaml" config --quiet; then ok "docker compose config compose.yaml"
else ko "docker compose config compose.yaml"; fi

if docker build --help 2> /dev/null | grep -q -- '--check'; then
  if sortie="$(docker build --check "$corrige/machine" 2>&1)"; then ok "docker build --check machine/Dockerfile"
  else ko "docker build --check machine/Dockerfile"; tail -n 20 <<< "$sortie"; fi
else
  echo "       (docker build --check indisponible : machine/Dockerfile non vérifié)"
fi

# Le client lit-il config ? ssh -G analyse sans se connecter.
if command -v ssh > /dev/null; then
  if sortie="$(ssh -F "$corrige/config" -G serveur 2>&1)" && grep -qx 'proxyjump bastion' <<< "$sortie" \
    && ssh -F "$corrige/config" -G bastion | grep -qx 'port 2222'; then
    ok "ssh -G -F config : bastion sur le port 2222, serveur par ProxyJump bastion"
  else
    ko "ssh -G -F config"; echo "$sortie" | head -n 5
  fi
else
  echo "       (ssh absent de l'hôte : config sera vérifié par --up)"
fi

# sshd accepte-t-il le fichier de durcissement ? Une configuration minimale qui l'inclut.
sshd_hote="$(command -v sshd || ls /usr/sbin/sshd 2> /dev/null || true)"
if [ -n "$sshd_hote" ] && command -v ssh-keygen > /dev/null; then
  essai="$(mktemp -d "${TMPDIR:-/tmp}/tptest-ssh.XXXXXX")"
  ssh-keygen -q -t ed25519 -N "" -f "$essai/cle_hote"
  printf 'Include %s\nHostKey %s\nPasswordAuthentication yes\n' "$corrige/10-durcissement.conf" "$essai/cle_hote" > "$essai/sshd_config"
  if sortie="$("$sshd_hote" -T -f "$essai/sshd_config" -C user=ada,host=poste,addr=127.0.0.1 2>&1)" \
    && grep -qx 'passwordauthentication no' <<< "$sortie" && grep -qx 'permitrootlogin no' <<< "$sortie"; then
    ok "sshd -T sur 10-durcissement.conf : mot de passe et root refusés, même avant une autre ligne"
  elif grep -q 'privilege separation directory' <<< "$sortie"; then
    echo "       (sshd -T exige /run/sshd, absent de l'hôte : 10-durcissement.conf sera vérifié par --up)"
  else
    ko "sshd -T sur 10-durcissement.conf"; head -n 5 <<< "$sortie"
  fi
  rm -rf -- "$essai"
else
  echo "       (sshd absent de l'hôte : 10-durcissement.conf sera vérifié par --up)"
fi

[ "$mode" = "up" ] || bilan

# ---------------------------------------------------------------------- labo

export COMPOSE_PROJECT_NAME="tptest-ssh"
export COMPOSE_FILE="$corrige/compose.yaml"
travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest-ssh.XXXXXX")"

nettoyer() {
  docker compose down --volumes --remove-orphans --rmi local > /dev/null 2>&1 || true
}
en_sortie() {
  if [ -z "$garder" ]; then
    nettoyer
    docker image rm tptest-ssh-debian > /dev/null 2>&1 || true
    rm -rf -- "$travail"
  else
    echo "--keep : labo « tptest-ssh » conservé (docker compose -p tptest-ssh down --rmi local pour le supprimer)"
  fi
}
trap en_sortie EXIT
nettoyer

# Proxy facultatif : une base debian:13-slim qui passe par le proxy, substituée par un contexte nommé.
if [ -n "${TPTEST_CA:-}" ]; then
  : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
  mkdir -p "$travail/base"
  cp "$TPTEST_CA" "$travail/base/ca.crt"
  cat > "$travail/base/Dockerfile" <<EOF
FROM debian:13-slim
COPY ca.crt /usr/local/share/ca-certificates/proxy.crt
RUN sed -i 's,http://,https://,g' /etc/apt/sources.list.d/debian.sources \\
 && printf 'Acquire::https::Proxy "%s";\nAcquire::https::CAInfo "/usr/local/share/ca-certificates/proxy.crt";\n' "$HTTPS_PROXY" > /etc/apt/apt.conf.d/99proxy
EOF
  docker build -q -t tptest-ssh-debian "$travail/base" > /dev/null
  cat > "$travail/proxy.yaml" <<'EOF'
x-proxy: &proxy
  build:
    network: host
    additional_contexts:
      "debian:13-slim": "docker-image://tptest-ssh-debian"
services:
  poste: *proxy
  bastion: *proxy
  serveur: *proxy
EOF
  COMPOSE_FILE="$COMPOSE_FILE:$travail/proxy.yaml"
  echo "       (proxy : $HTTPS_PROXY, base tptest-ssh-debian)"
fi

PHRASE="tptest phrase $RANDOM$RANDOM"
MOTDEPASSE="motdepasse"   # celui du Dockerfile, mot de passe d'exercice

# Un script du corrigé, exécuté sur le poste en tant qu'ada ; sa sortie va dans le journal.
poste_script() { # $1 script  $2… arguments
  local s="$1"; shift
  # Copié puis exécuté, et non lu sur l'entrée standard : ssh lirait la suite du script.
  docker compose cp "$corrige/$s" "poste:/tmp/$s" > /dev/null 2>&1
  docker compose exec -T -u ada -e "PHRASE=$PHRASE" -e "MOTDEPASSE=$MOTDEPASSE" poste \
    bash "/tmp/$s" "$@" < /dev/null > "$travail/$s.log" 2>&1
}
journal() { tail -n 25 "$travail/$1.log" | indente; }
etape() { # $1 script  $2… arguments : rejoue, compte rendu
  if poste_script "$@"; then ok "$1"; return 0; fi
  ko "$1"; journal "$1"; return 1
}
# Commandes de vérification, sur le poste (ada) ou sur une machine (root, sa console).
poste() { docker compose exec -T -u ada -e SSH_AUTH_SOCK=/home/ada/.ssh/agent.sock poste bash -c "$1" < /dev/null; }
console() { local m="$1"; shift; docker compose exec -T "$m" "$@" < /dev/null; }
# ssh par mot de passe seulement, le mot de passe donné par SSH_ASKPASS.
par_mot_de_passe() { # $1 destination (alias de ~/.ssh/config ou ada@bastion…)
  poste "printf '#!/bin/sh\necho $MOTDEPASSE\n' > /tmp/tptest-askpass && chmod 700 /tmp/tptest-askpass
    SSH_ASKPASS=/tmp/tptest-askpass SSH_ASKPASS_REQUIRE=force ssh -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no $1 hostname < /dev/null"
}

titre "Étape 1 — le labo"
if (cd "$corrige" && ./etape-1-labo.sh) > "$travail/etape-1.log" 2>&1; then ok "etape-1-labo.sh"
else ko "etape-1-labo.sh"; journal etape-1; bilan; fi
pret=""
for _ in $(seq 1 30); do
  if docker compose logs bastion serveur 2> /dev/null | grep -c 'Server listening on 0.0.0.0' | grep -qx 2; then pret=1; break; fi
  sleep 1
done
if [ -n "$pret" ]; then ok "sshd écoute sur le bastion (2222) et le serveur (22)"
else ko "sshd ne démarre pas"; docker compose logs | tail -n 20 | indente; bilan; fi

titre "Étape 2 — la paire de clés"
if etape etape-2-cles.sh; then
  if [ "$(poste "ssh-keygen -y -P '$PHRASE' -f ~/.ssh/id_ed25519 | cut -d ' ' -f 1,2")" = "$(poste "cut -d ' ' -f 1,2 ~/.ssh/id_ed25519.pub")" ]; then
    ok "la phrase de passe ouvre la clé privée, qui correspond à id_ed25519.pub"
  else ko "clé privée et clé publique ne concordent pas"; fi
fi

titre "Étape 3 — l'empreinte du bastion"
empreinte_bastion="$(console bastion ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{ print $2 }')"
echo "       console du bastion : $empreinte_bastion"
if etape etape-3-empreinte.sh "$empreinte_bastion"; then
  if poste "ssh-keygen -lF '[bastion]:2222' | grep -q '$empreinte_bastion'"; then
    ok "known_hosts : la clé d'hôte du bastion, celle de sa console"
  else ko "known_hosts ne contient pas la clé du bastion"; fi
fi
# Une empreinte fausse doit arrêter le script avant toute connexion.
if poste_script etape-3-empreinte.sh "SHA256:fausse"; then ko "etape-3-empreinte.sh accepte une empreinte fausse"
else ok "etape-3-empreinte.sh refuse une empreinte fausse"; fi

titre "Étape 4 — déposer la clé"
if etape etape-4-deposer-cle.sh; then
  cle_pub="$(poste 'cat ~/.ssh/id_ed25519.pub')"
  if console bastion grep -qxF "$cle_pub" /home/ada/.ssh/authorized_keys \
    && [ "$(console bastion stat -c %a /home/ada/.ssh/authorized_keys)" = 600 ]; then
    ok "authorized_keys du bastion : la clé d'ada, droits 600"
  else ko "authorized_keys du bastion"; fi
fi

titre "Étape 5 — l'agent"
if etape etape-5-agent.sh; then
  if [ "$(poste 'ssh -o BatchMode=yes -p 2222 ada@bastion hostname')" = bastion ]; then
    ok "connexion par clé réussie, sans rien saisir (agent)"
  else ko "connexion par clé au bastion"; fi
fi

titre "Étape 6 — ~/.ssh/config"
docker compose cp "$corrige/config" poste:/home/ada/.ssh/config > /dev/null
console poste chown ada:ada /home/ada/.ssh/config
if etape etape-6-config.sh; then
  g="$(poste 'ssh -G bastion' 2> /dev/null)"
  if grep -qx 'port 2222' <<< "$g" && grep -qx 'user ada' <<< "$g"; then ok "ssh -G bastion : port 2222, utilisateur ada"
  else ko "ssh -G bastion"; fi
fi

titre "Étape 7 — rebond par le bastion"
empreinte_serveur="$(console serveur ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{ print $2 }')"
echo "       console du serveur : $empreinte_serveur"
if etape etape-7-rebond.sh "$empreinte_serveur"; then
  if [ "$(poste 'ssh -o BatchMode=yes serveur hostname')" = serveur ]; then ok "rebond : ssh serveur répond « serveur »"
  else ko "rebond par le bastion"; fi
  ip_bastion="$(console serveur getent hosts bastion | awk '{ print $1 }' || true)"
  vu="$(poste "ssh -o BatchMode=yes serveur 'echo \$SSH_CONNECTION'" | awk '{ print $1 }' || true)"
  if [ -n "$vu" ] && [ "$vu" = "$ip_bastion" ]; then ok "le serveur voit venir la connexion du bastion ($vu)"
  else ko "SSH_CONNECTION du serveur : $vu, bastion : $ip_bastion"; fi
  if poste 'ls ~/.ssh' > /dev/null && [ "$(console bastion ls /home/ada/.ssh)" = authorized_keys ]; then
    ok "sur le bastion, ~/.ssh ne contient que authorized_keys"
  else ko "le bastion détient d'autres fichiers ssh"; fi
fi

titre "Étape 8 — scp et rsync"
if etape etape-8-copier.sh; then
  if [ "$(console serveur cat /tmp/rapport.txt)" = "Rapport du poste d'Ada" ]; then ok "scp : rapport.txt est sur le serveur"
  else ko "scp : rapport.txt absent ou différent"; fi
  if [ "$(console serveur cat /home/ada/site/index.html)" = "accueil, version 2" ] \
    && console serveur test -f /home/ada/site/contact.html; then ok "rsync : site/ est à jour sur le serveur"
  else ko "rsync : site/ incomplet sur le serveur"; fi
  # La liste des fichiers envoyés au second passage : du second « sending… » à la ligne vide.
  second="$(awk '/^sending incremental file list$/ { n++; next } n == 2 && /^$/ { exit } n == 2' "$travail/etape-8-copier.sh.log")"
  if [ "$second" = "index.html" ]; then
    ok "rsync, second passage : seul index.html est reparti"
  else ko "rsync, second passage"; journal etape-8-copier.sh; fi
fi

titre "Étape 9 — redirection locale"
if etape etape-9-tunnel.sh; then
  if [ "$(poste 'curl -sS --max-time 5 localhost:8080')" = "Supervision : tout va bien" ]; then
    ok "le port 8080 du poste répond : la supervision du serveur"
  else ko "le port 8080 du poste ne répond pas"; fi
  if console poste sh -c 'curl -sS --max-time 3 serveur:8000' > /dev/null 2>&1; then ko "la supervision est joignable sans tunnel"
  else ok "sans tunnel, la supervision reste injoignable depuis le poste"; fi
fi

titre "Étape 10 — durcir sshd"
# Avant : root entre par clé une fois la clé d'ada autorisée pour lui (prohibit-password, réglage de Debian), ada par mot de passe.
if (cd "$corrige" && ./etape-10-root.sh) > "$travail/etape-10-root.log" 2>&1; then ok "etape-10-root.sh"
else ko "etape-10-root.sh"; journal etape-10-root; fi
if [ "$(par_mot_de_passe serveur 2> /dev/null)" = serveur ]; then ok "avant : mot de passe accepté"
else ko "avant : le mot de passe devrait être accepté"; fi
if [ "$(poste 'ssh -o BatchMode=yes root@serveur hostname' 2> /dev/null)" = serveur ]; then ok "avant : root entre par clé"
else ko "avant : root devrait entrer par clé"; fi
# La session de secours, ouverte avant le rechargement.
docker compose exec -d -u ada -e SSH_AUTH_SOCK=/home/ada/.ssh/agent.sock poste \
  ssh -o BatchMode=yes serveur 'echo $$ > /tmp/tptest-secours; sleep 120'
sleep 3
secours="$(console serveur cat /tmp/tptest-secours 2> /dev/null || true)"
if (cd "$corrige" && ./etape-10-durcir.sh) > "$travail/etape-10-durcir.log" 2>&1; then ok "etape-10-durcir.sh"
else ko "etape-10-durcir.sh"; journal etape-10-durcir; fi
sleep 1
if etape etape-10-verifier.sh; then :; fi
if [ "$(par_mot_de_passe serveur 2>&1)" != serveur ]; then ok "après : mot de passe refusé"
else ko "après : mot de passe encore accepté"; fi
if [ "$(poste 'ssh -o BatchMode=yes root@serveur hostname' 2> /dev/null)" != serveur ]; then ok "après : root refusé"
else ko "après : root entre encore"; fi
if [ "$(poste 'ssh -o BatchMode=yes serveur hostname')" = serveur ]; then ok "après : connexion par clé acceptée"
else ko "après : connexion par clé refusée"; fi
if [ -n "$secours" ] && console serveur kill -0 "$secours" 2> /dev/null; then
  ok "la session ouverte avant le rechargement est toujours vivante"
else ko "la session de secours n'a pas survécu au rechargement"; fi
if [ "$(par_mot_de_passe "-p 2222 ada@bastion" 2> /dev/null)" = bastion ]; then ok "le bastion, non durci, accepte encore le mot de passe"
else ko "le bastion devrait accepter encore le mot de passe"; fi

bilan
