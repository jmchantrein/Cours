#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Conteneuriser WordPress ».
#
# Il construit, lance et interroge les fichiers de corrige/, ceux-là mêmes que
# l'énoncé affiche : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --build | --up] [--only N] [--no-cache] [--keep]
#   --lint      (défaut) validation sans rien construire : docker build --check,
#               docker compose config, syntaxe et droits des scripts.
#   --build     --lint, puis construction des images des étapes 1 à 6.
#   --up        pour chaque étape : construire, démarrer, attendre, vérifier,
#               nettoyer. WordPress est installé pour de bon à chaque étape.
#   --only N    ne traite que l'étape N (1 à 9).
#   --no-cache  construit sans le cache de build.
#   --keep      ne nettoie pas en fin de test (pour examiner un échec).
#
# Ce que --up vérifie, étape par étape :
#   toutes   le site répond, WordPress joint sa base et s'y installe ;
#   3 à 6    aucun processus du conteneur ne tourne en root (docker container top) ;
#   3 et 4   Apache porte le PID 1 sous www-data, sans capability ;
#   4, 5, 6  le site installé survit à la suppression des conteneurs ;
#   8        les données sont dans les dossiers de $HOME (un HOME temporaire),
#            et la version de WordPress épinglée n'est pas la dernière ;
#   9        avec trois instances, les requêtes atteignent plusieurs conteneurs
#            et une session ouverte sur l'une vaut sur les autres.
#
# Le harnais ne crée et ne supprime que des ressources préfixées « tptest » :
# il ne touche à aucun conteneur, volume, réseau ou image créés en suivant
# l'énoncé. Il a besoin du port 8080 de l'hôte.
#
# Prérequis : bash, curl, Docker avec Compose v2. --build et --up ont besoin du
# réseau (dépôts Debian, wordpress.org, Docker Hub).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
url="http://localhost:8080"

mode="lint"; seule=""; garder=""; sans_cache=()
while [ $# -gt 0 ]; do
  case "$1" in
    --lint) mode="lint" ;;
    --build) mode="build" ;;
    --up) mode="up" ;;
    --only) seule="${2:-}"; shift ;;
    --no-cache) sans_cache=(--no-cache) ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
case "$seule" in "" | [1-9]) ;; *) echo "--only attend un numéro d'étape, de 1 à 9." >&2; exit 2 ;; esac

command -v docker > /dev/null || { echo "docker est introuvable dans le PATH." >&2; exit 1; }
docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
docker compose version > /dev/null 2>&1 || { echo "Le plugin Compose v2 (docker compose) est requis." >&2; exit 1; }
command -v curl > /dev/null || { echo "curl est introuvable dans le PATH." >&2; exit 1; }

# docker build --check n'existe qu'à partir de Buildx 0.15.
check_dispo=""
if docker build --help 2> /dev/null | grep -q -- '--check'; then check_dispo="1"; fi

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
voulue() { [ -z "$seule" ] || [ "$seule" = "$1" ]; }
titre_etape() { printf '\n======== Étape %s — %s ========\n' "$1" "corrige/${2#"$corrige"/}"; }

# ------------------------------------------------------------------- nettoyage
# Chaque fonction ne nomme que des ressources « tptest ». Elles sont appelées
# avant une étape (restes d'un test interrompu), après, et en sortie.

travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
home_etape_8=""

silencieux() { "$@" > /dev/null 2>&1 || true; }

nettoyer_image_unique() { # $1 étape (1 à 4)
  silencieux docker container rm -f -v "tptest-$1"
  silencieux docker volume rm -f "tptest-$1-data" "tptest-$1-source"
  silencieux docker image rm "tptest-image:$1"
}

nettoyer_etape_5() {
  silencieux docker container rm -f -v tptest-5-wordpress tptest-5-db
  silencieux docker network rm tptest-5-reseau_wordpress
  silencieux docker volume rm -f tptest-5-data_wordpress tptest-5-source_code_wordpress
  silencieux docker image rm tptest-5-image_wordpress tptest-5-image_db
}

nettoyer_compose() { # $1 étape (6 à 9)
  silencieux docker compose -p "tptest-$1" down --volumes --remove-orphans
  silencieux docker image rm "tptest-$1-wordpress" "tptest-$1-db"
}

# Les fichiers de l'étape 8 appartiennent aux utilisateurs des conteneurs :
# seul un conteneur (root) peut les supprimer sans sudo.
nettoyer_home_etape_8() {
  [ -n "$home_etape_8" ] && [ -d "$home_etape_8" ] || return 0
  silencieux docker container run --rm -v "$home_etape_8:/tptest-home" --entrypoint sh \
    "$(image_de_compose "$corrige/8_my_final_wordpress/compose.yaml")" \
    -c 'rm -rf /tptest-home/source_code_wordpress /tptest-home/data_wordpress'
  silencieux rmdir "$home_etape_8"
  home_etape_8=""
}

nettoyer_etape() { # $1 étape
  case "$1" in
    1 | 2 | 3 | 4) nettoyer_image_unique "$1" ;;
    5) nettoyer_etape_5 ;;
    8) nettoyer_compose 8; nettoyer_home_etape_8 ;;
    *) nettoyer_compose "$1" ;;
  esac
}

etapes_entamees=()
en_sortie() {
  if [ -z "$garder" ]; then
    for n in "${etapes_entamees[@]}"; do nettoyer_etape "$n"; done
    rm -rf -- "$travail"
  else
    echo "--keep : ressources « tptest » conservées ; journaux dans $travail"
  fi
}
trap en_sortie EXIT

fin_etape() { # $1 étape
  [ -n "$garder" ] || nettoyer_etape "$1"
}

# ------------------------------------------------------------------ validation

# docker build --check sort en erreur au premier avertissement. Certains sont
# voulus : le mot de passe déclaré par ENV (exemple d'école, toutes les images
# qui créent la base) et la forme shell de CMD (étape 1, que l'étape 2 corrige).
verifier_dockerfile() { # $1 dossier  $2… règles tolérées
  local dossier="$1"; shift
  local nom="${dossier#"$corrige"/}/Dockerfile" sortie regle inattendues=""
  if [ -z "$check_dispo" ]; then
    echo "       (docker build --check indisponible : $nom non vérifié)"
    return 0
  fi
  if sortie="$(docker build --check "$dossier" 2>&1)"; then ok "lint $nom"; return 0; fi
  while read -r regle; do
    case " $* " in *" $regle "*) ;; *) inattendues+=" $regle" ;; esac
  done < <(sed -n 's/^WARNING: \([A-Za-z]*\) - .*/\1/p' <<< "$sortie" | sort -u)
  if [ -z "$inattendues" ] && grep -q '^WARNING: ' <<< "$sortie"; then
    ok "lint $nom (avertissements attendus : $*)"
  else
    ko "lint $nom :${inattendues:- erreur}"
    tail -n 30 <<< "$sortie"
  fi
}

verifier_script() { # $1 script sh
  local nom="${1#"$corrige"/}"
  if ! sh -n "$1"; then ko "syntaxe $nom"; return 0; fi
  if [ ! -x "$1" ]; then ko "$nom n'est pas exécutable (chmod +x)"; return 0; fi
  # SC1091 : le fichier chargé (/etc/apache2/envvars) n'existe que dans l'image.
  if command -v shellcheck > /dev/null && ! shellcheck --exclude=SC1091 "$1"; then
    ko "shellcheck $nom"; return 0
  fi
  ok "script $nom"
}

verifier_compose() { # $1 fichier
  local nom="${1#"$corrige"/}"
  if docker compose -f "$1" config --quiet; then ok "compose config $nom"; else ko "compose config $nom"; fi
}

identiques() { # $1 $2 fichiers que l'énoncé dit identiques
  if cmp -s "$1" "$2"; then ok "identiques : ${1#"$corrige"/} et ${2#"$corrige"/}"
  else ko "${1#"$corrige"/} et ${2#"$corrige"/} diffèrent"; fi
}

# ---------------------------------------------------------------- construction

construire() { # $1 tag  $2 dossier
  local journal="$travail/build-${1//[:\/]/_}.log"
  if docker image build "${sans_cache[@]}" -t "$1" "$2" > "$journal" 2>&1; then
    ok "construction ${2#"$corrige"/}"
  else
    ko "construction ${2#"$corrige"/}"
    tail -n 40 "$journal"
    return 1
  fi
}

image_de_compose() { # $1 fichier compose : l'image du service wordpress
  docker compose -f "$1" config --images 2> /dev/null | grep -m 1 '^wordpress:' || echo wordpress
}

# ---------------------------------------------------------------- vérifications

port_libre() { ! (exec 3<> /dev/tcp/127.0.0.1/8080) 2> /dev/null; }

exiger_port_libre() {
  port_libre && return 0
  echo "Le port 8080 de l'hôte est occupé : arrêtez ce qui l'utilise, puis relancez." >&2
  exit 1
}

attendre_http() { # $1 url : une réponse 2xx ou 3xx en moins de deux minutes
  local code
  for _ in $(seq 1 60); do
    code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$1" 2> /dev/null || true)"
    case "$code" in 2?? | 3??) return 0 ;; esac
    sleep 2
  done
  return 1
}

# Liaison WordPress ↔ base, images des étapes 1 à 6 : soumettre l'étape 2 de
# l'assistant (wp-admin/setup-config.php) avec les identifiants du corrigé.
# WordPress se connecte à la base, puis écrit wp-config.php et propose de
# lancer l'installation (lien vers install.php). Si la connexion échoue, il
# affiche une erreur sans ce lien. La base peut mettre quelques secondes à
# démarrer : on réessaie.
wp_configurer() { # $1 url du site  $2 adresse de la base
  local corps
  for _ in $(seq 1 20); do
    corps="$(curl -s -m 30 \
      --data-urlencode "dbname=wordpress" --data-urlencode "uname=admin" \
      --data-urlencode "pwd=tempo" --data-urlencode "dbhost=$2" \
      --data-urlencode "prefix=wp_" --data-urlencode "language=" \
      "$1/wp-admin/setup-config.php?step=2" 2> /dev/null || true)"
    # « <?php » dans la réponse : Apache renvoie le source, PHP ne tourne pas.
    if [[ "$corps" == *"install.php"* && "$corps" != *"<?php"* ]]; then return 0; fi
    sleep 3
  done
  return 1
}

# Installation de WordPress : crée les tables et le compte d'administration.
# Le formulaire (step=1) ne s'affiche que si WordPress joint sa base ; après
# l'installation, la page d'accueil porte le titre choisi, lu dans la base.
wp_installer() { # $1 url du site  $2 titre
  local corps pret=""
  for _ in $(seq 1 40); do
    corps="$(curl -s -m 30 "$1/wp-admin/install.php?step=1" 2> /dev/null || true)"
    if [[ "$corps" == *'name="weblog_title"'* ]]; then pret="1"; break; fi
    sleep 3
  done
  [ -n "$pret" ] || return 1
  curl -s -o /dev/null -m 120 \
    --data-urlencode "weblog_title=$2" --data-urlencode "user_name=tptest" \
    --data-urlencode "admin_password=$mot_de_passe_wp" --data-urlencode "admin_password2=$mot_de_passe_wp" \
    --data-urlencode "pw_weak=on" --data-urlencode "admin_email=tptest@example.org" \
    --data-urlencode "blog_public=0" --data-urlencode "language=" \
    "$1/wp-admin/install.php?step=2" || return 1
  wp_titre_present "$1" "$2"
}
mot_de_passe_wp="tptest-$RANDOM-$RANDOM"

wp_titre_present() { # $1 url du site  $2 titre
  local corps
  for _ in $(seq 1 20); do
    corps="$(curl -sL -m 30 "$1/" 2> /dev/null || true)"
    if [[ "$corps" == *"<title>$2"* ]]; then return 0; fi
    sleep 3
  done
  return 1
}

# Aucun processus root dans le conteneur. docker container top interroge le ps
# de l'hôte : l'UID 0 est root, quel que soit le nom que l'hôte lui donne.
sans_root() { # $1 conteneur
  local uids
  docker container top "$1" -o user,pid,args | sed 's/^/       /'
  uids="$(docker container top "$1" -o uid,pid | awk 'NR > 1 { print $1 }' | sort -u | tr '\n' ' ')"
  [ -n "$uids" ] && ! grep -qw 0 <<< "$uids"
}

# Étapes 3 et 4 : le PID 1 est Apache, sous www-data (UID 33), sans capability
# et sans possibilité d'en regagner ; apache2 ne porte pas de bit setuid.
pid1_apache_sans_pouvoir() { # $1 conteneur
  local etat
  etat="$(docker container exec "$1" sh -c \
    'cat /proc/1/comm; grep -E "^(Uid|CapEff|NoNewPrivs):" /proc/1/status; if test -u /usr/sbin/apache2; then echo setuid; fi' 2>&1 | tr -s '\t\n' '  ')"
  echo "       PID 1 : $etat"
  [[ "$etat" == "apache2 Uid: 33 33 33 33 CapEff: 0000000000000000 NoNewPrivs: 1 " ]]
}

journaux() { # $1… conteneurs : dernières lignes, après un échec
  local c
  for c in "$@"; do
    echo "------ docker container logs $c"
    docker container logs --tail 30 "$c" 2>&1 || true
  done
}

# ------------------------------------------------- étapes 1 à 4 : une seule image

lancer_image_unique() { # $1 étape  $2 durci (0/1)  $3 volumes (0/1)
  local options=(-d --name "tptest-$1" -p 8080:80)
  if [ "$3" = "1" ]; then
    options+=(-v "tptest-$1-data:/var/lib/mysql" -v "tptest-$1-source:/var/www/html")
  fi
  # La commande durcie des corrigés des étapes 3 et 4.
  if [ "$2" = "1" ]; then
    options+=(--cap-drop ALL --cap-add CHOWN --cap-add SETUID --cap-add SETGID
      --security-opt no-new-privileges)
  fi
  docker container run "${options[@]}" "tptest-image:$1" > /dev/null
}

etape_image_unique() { # $1 étape  $2 dossier  $3 chemin du site  $4 durci  $5 volumes  $6… règles tolérées
  local n="$1" dossier="$corrige/$2" site="$url$3" durci="$4" volumes="$5"; shift 5
  local titre="tptest-etape-$n-$RANDOM"
  voulue "$n" || return 0
  titre_etape "$n" "$dossier"
  verifier_dockerfile "$dossier" "$@"
  if [ -f "$dossier/entrypoint.sh" ]; then verifier_script "$dossier/entrypoint.sh"; fi
  [ "$mode" != "lint" ] || return 0

  etapes_entamees+=("$n"); nettoyer_etape "$n"
  construire "tptest-image:$n" "$dossier" || return 0
  if [ "$mode" != "up" ]; then fin_etape "$n"; return 0; fi

  exiger_port_libre
  lancer_image_unique "$n" "$durci" "$volumes"
  if ! attendre_http "$site/"; then
    ko "étape $n : le site ne répond pas ($site/)"; journaux "tptest-$n"; fin_etape "$n"; return 0
  fi
  ok "étape $n : le site répond ($site/)"

  local installe=""
  if ! wp_configurer "$site" localhost; then
    ko "étape $n : WordPress ne joint pas sa base"; journaux "tptest-$n"
  else
    ok "étape $n : WordPress joint sa base (setup-config)"
    if wp_installer "$site" "$titre"; then ok "étape $n : WordPress installé, le site affiche son titre"; installe="1"
    else ko "étape $n : installation de WordPress"; journaux "tptest-$n"; fi
  fi

  if [ "$durci" = "1" ]; then
    if sans_root "tptest-$n"; then ok "étape $n : aucun processus root"
    else ko "étape $n : un processus tourne en root"; fi
    if pid1_apache_sans_pouvoir "tptest-$n"; then ok "étape $n : PID 1 = apache2 sous www-data, sans capability"
    else ko "étape $n : PID 1 inattendu"; fi
  fi

  if [ "$volumes" = "1" ] && [ -n "$installe" ]; then
    docker container rm -f -v "tptest-$n" > /dev/null
    lancer_image_unique "$n" "$durci" "$volumes"
    if attendre_http "$site/" && wp_titre_present "$site" "$titre"; then
      ok "étape $n : le site installé survit à la recréation du conteneur"
    else
      ko "étape $n : données perdues à la recréation du conteneur"; journaux "tptest-$n"
    fi
  fi
  fin_etape "$n"
}

# Arguments : étape, dossier, chemin du site, durci, volumes, règles tolérées.
etape_image_unique 1 1_wordpress_multiservice_dirty /wordpress 0 0 SecretsUsedInArgOrEnv JSONArgsRecommended
etape_image_unique 2 2_wordpress_multiservice_better "" 0 0 SecretsUsedInArgOrEnv
etape_image_unique 3 3_wordpress_multiservice_noroot "" 1 0 SecretsUsedInArgOrEnv
etape_image_unique 4 4_wordpress_multiservice_persistant "" 1 1 SecretsUsedInArgOrEnv
if voulue 4; then
  identiques "$corrige/3_wordpress_multiservice_noroot/entrypoint.sh" "$corrige/4_wordpress_multiservice_persistant/entrypoint.sh"
fi

# --------------------------------------- étape 5 : deux conteneurs lancés par script

if voulue 5; then
  d="$corrige/5_wordpress_microservice_persistant"
  titre="tptest-etape-5-$RANDOM"
  titre_etape 5 "$d"
  verifier_dockerfile "$d/wordpress"
  verifier_dockerfile "$d/db" SecretsUsedInArgOrEnv
  verifier_script "$d/build_and_launch.sh"
  if grep -q -e '--link' "$d/build_and_launch.sh"; then ko "étape 5 : --link ne doit plus apparaître"
  else ok "étape 5 : pas de --link, un réseau utilisateur"; fi

  if [ "$mode" = "build" ]; then
    etapes_entamees+=(5); nettoyer_etape 5
    construire tptest-5-image_wordpress "$d/wordpress" || true
    construire tptest-5-image_db "$d/db" || true
    fin_etape 5
  elif [ "$mode" = "up" ]; then
    etapes_entamees+=(5); nettoyer_etape 5
    exiger_port_libre
    # Le script du corrigé, tel quel : seul le préfixe des noms change.
    if PREFIXE=tptest-5- "$d/build_and_launch.sh" > "$travail/etape-5.log" 2>&1; then
      ok "étape 5 : build_and_launch.sh"
      if attendre_http "$url/"; then ok "étape 5 : le site répond"
      else ko "étape 5 : le site ne répond pas"; journaux tptest-5-wordpress tptest-5-db; fi
      installe=""
      if ! wp_configurer "$url" tptest-5-db; then
        ko "étape 5 : WordPress ne joint pas la base"; journaux tptest-5-wordpress tptest-5-db
      else
        ok "étape 5 : WordPress joint la base par son nom (setup-config)"
        if wp_installer "$url" "$titre"; then ok "étape 5 : WordPress installé, le site affiche son titre"; installe="1"
        else ko "étape 5 : installation de WordPress"; journaux tptest-5-wordpress tptest-5-db; fi
      fi
      for c in tptest-5-wordpress tptest-5-db; do
        if sans_root "$c"; then ok "étape 5 : aucun processus root dans $c"
        else ko "étape 5 : un processus tourne en root dans $c"; fi
      done
      if [ -z "$(docker container port tptest-5-db)" ]; then ok "étape 5 : la base n'est pas publiée sur l'hôte"
      else ko "étape 5 : la base est publiée sur l'hôte"; fi
      # Relancer le script recrée les conteneurs : les volumes gardent le site.
      if [ -z "$installe" ]; then
        :
      elif PREFIXE=tptest-5- "$d/build_and_launch.sh" >> "$travail/etape-5.log" 2>&1 \
        && attendre_http "$url/" && wp_titre_present "$url" "$titre"; then
        ok "étape 5 : le site installé survit à un second lancement du script"
      else
        ko "étape 5 : données perdues au second lancement"; journaux tptest-5-wordpress tptest-5-db
      fi
    else
      ko "étape 5 : build_and_launch.sh"
      tail -n 40 "$travail/etape-5.log"
    fi
    fin_etape 5
  fi
fi

# ------------------------------------------------------ étapes 6 à 9 : Compose

compose() { # $1 étape  $2… arguments de docker compose
  local n="$1"; shift
  docker compose -p "tptest-$n" -f "$fichier_compose" "$@"
}

journaux_compose() { # $1 étape
  echo "------ docker compose logs (étape $1)"
  compose "$1" logs --tail 30 2>&1 || true
}

demarrer_compose() { # $1 étape  $2… arguments de up
  local n="$1"; shift
  if compose "$n" up -d "$@" > "$travail/etape-$n.log" 2>&1; then return 0; fi
  tail -n 40 "$travail/etape-$n.log"
  return 1
}

if voulue 6; then
  d="$corrige/6_wordpress_microservice_compose"
  fichier_compose="$d/compose.yaml"
  titre="tptest-etape-6-$RANDOM"
  titre_etape 6 "$d"
  verifier_compose "$fichier_compose"
  verifier_dockerfile "$d/wordpress"
  verifier_dockerfile "$d/db" SecretsUsedInArgOrEnv
  for f in wordpress/Dockerfile db/Dockerfile; do
    identiques "$corrige/5_wordpress_microservice_persistant/$f" "$d/$f"
  done

  if [ "$mode" = "build" ]; then
    etapes_entamees+=(6); nettoyer_etape 6
    if compose 6 build "${sans_cache[@]}" > "$travail/etape-6.log" 2>&1; then ok "étape 6 : docker compose build"
    else ko "étape 6 : docker compose build"; tail -n 40 "$travail/etape-6.log"; fi
    fin_etape 6
  elif [ "$mode" = "up" ]; then
    etapes_entamees+=(6); nettoyer_etape 6
    exiger_port_libre
    if demarrer_compose 6 --build; then
      ok "étape 6 : docker compose up"
      if attendre_http "$url/"; then ok "étape 6 : le site répond"
      else ko "étape 6 : le site ne répond pas"; journaux_compose 6; fi
      installe=""
      if ! wp_configurer "$url" db; then
        ko "étape 6 : WordPress ne joint pas le service db"; journaux_compose 6
      else
        ok "étape 6 : WordPress joint le service db (setup-config)"
        if wp_installer "$url" "$titre"; then ok "étape 6 : WordPress installé, le site affiche son titre"; installe="1"
        else ko "étape 6 : installation de WordPress"; journaux_compose 6; fi
      fi
      for c in $(compose 6 ps -q); do
        nom="$(docker container inspect -f '{{.Name}}' "$c")"
        if sans_root "$c"; then ok "étape 6 : aucun processus root dans ${nom#/}"
        else ko "étape 6 : un processus tourne en root dans ${nom#/}"; fi
      done
      # down sans -v supprime les conteneurs et le réseau, pas les volumes.
      compose 6 down > /dev/null 2>&1 || true
      if [ -z "$installe" ]; then
        :
      elif demarrer_compose 6 && attendre_http "$url/" && wp_titre_present "$url" "$titre"; then
        ok "étape 6 : le site installé survit à docker compose down"
      else
        ko "étape 6 : données perdues après docker compose down"; journaux_compose 6
      fi
    else
      ko "étape 6 : docker compose up"
    fi
    fin_etape 6
  fi
fi

if voulue 7; then
  d="$corrige/7_wordpress_official_stack"
  fichier_compose="$d/compose.yaml"
  titre="tptest-etape-7-$RANDOM"
  titre_etape 7 "$d"
  verifier_compose "$fichier_compose"
  if [ "$mode" = "up" ]; then
    etapes_entamees+=(7); nettoyer_etape 7
    exiger_port_libre
    if demarrer_compose 7; then
      ok "étape 7 : docker compose up"
      if attendre_http "$url/"; then ok "étape 7 : le site répond"
      else ko "étape 7 : le site ne répond pas"; journaux_compose 7; fi
      if wp_installer "$url" "$titre"; then ok "étape 7 : WordPress joint sa base et s'y installe"
      else ko "étape 7 : installation de WordPress"; journaux_compose 7; fi
    else
      ko "étape 7 : docker compose up"
    fi
    fin_etape 7
  fi
fi

if voulue 8; then
  d="$corrige/8_my_final_wordpress"
  fichier_compose="$d/compose.yaml"
  titre="tptest-etape-8-$RANDOM"
  titre_etape 8 "$d"
  verifier_compose "$fichier_compose"
  if [ "$mode" = "up" ]; then
    etapes_entamees+=(8); nettoyer_etape 8
    exiger_port_libre
    # Un HOME temporaire : le fichier monte $HOME/source_code_wordpress et
    # $HOME/data_wordpress. DOCKER_CONFIG garde la configuration du client.
    home_etape_8="$(mktemp -d "${TMPDIR:-/tmp}/tptest-home.XXXXXX")"
    mkdir -p "$home_etape_8/source_code_wordpress" "$home_etape_8/data_wordpress"
    compose_8() { DOCKER_CONFIG="${DOCKER_CONFIG:-$HOME/.docker}" HOME="$home_etape_8" compose 8 "$@"; }
    if compose_8 up -d > "$travail/etape-8.log" 2>&1; then
      ok "étape 8 : docker compose up"
      if attendre_http "$url/"; then ok "étape 8 : le site répond"
      else ko "étape 8 : le site ne répond pas"; journaux_compose 8; fi
      if wp_installer "$url" "$titre"; then ok "étape 8 : WordPress joint sa base et s'y installe"
      else ko "étape 8 : installation de WordPress"; journaux_compose 8; fi

      if [ -f "$home_etape_8/source_code_wordpress/wp-config.php" ] \
        && [ -n "$(ls -A "$home_etape_8/data_wordpress" 2> /dev/null)" ]; then
        ok "étape 8 : le code et la base sont dans les dossiers de \$HOME"
      else
        ko "étape 8 : dossiers de \$HOME vides"
      fi

      compose_8 down > /dev/null 2>&1 || true
      if compose_8 up -d >> "$travail/etape-8.log" 2>&1 && attendre_http "$url/" && wp_titre_present "$url" "$titre"; then
        ok "étape 8 : le site installé survit à docker compose down"
      else
        ko "étape 8 : données perdues après docker compose down"; journaux_compose 8
      fi

      # L'énoncé fait mettre WordPress à jour : la version épinglée ne doit pas
      # être la dernière. Sans accès à api.wordpress.org, on ne peut pas le dire.
      installee="$(sed -n "s/^\$wp_version = '\(.*\)';/\1/p" "$home_etape_8/source_code_wordpress/wp-includes/version.php" 2> /dev/null || true)"
      derniere="$(curl -s -m 15 https://api.wordpress.org/core/version-check/1.7/ 2> /dev/null \
        | grep -o '"current":"[^"]*"' | head -n 1 | cut -d '"' -f 4 || true)"
      if [ -z "$installee" ]; then
        ko "étape 8 : version de WordPress illisible dans le dossier du code"
      elif [ -z "$derniere" ]; then
        echo "       (WordPress $installee ; api.wordpress.org injoignable : dernière version inconnue)"
      elif [ "$installee" != "$derniere" ]; then
        ok "étape 8 : WordPress $installee installé, $derniere disponible : une mise à jour sera proposée"
      else
        ko "étape 8 : WordPress $installee est la dernière version : épingler une version antérieure"
      fi
    else
      ko "étape 8 : docker compose up"
      tail -n 40 "$travail/etape-8.log"
    fi
    compose_8 down --volumes > /dev/null 2>&1 || true
    fin_etape 8
  fi
fi

if voulue 9; then
  d="$corrige/9_wordpress_scale"
  fichier_compose="$d/compose.yaml"
  titre="tptest-etape-9-$RANDOM"
  titre_etape 9 "$d"
  verifier_compose "$fichier_compose"
  if [ "$mode" = "up" ]; then
    etapes_entamees+=(9); nettoyer_etape 9
    exiger_port_libre
    if demarrer_compose 9 --scale wordpress=3; then
      ok "étape 9 : docker compose up --scale wordpress=3"
      if attendre_http "$url/"; then ok "étape 9 : le site répond à travers le proxy"
      else ko "étape 9 : le site ne répond pas"; journaux_compose 9; fi
      if wp_installer "$url" "$titre"; then ok "étape 9 : WordPress joint sa base et s'y installe"
      else ko "étape 9 : installation de WordPress"; journaux_compose 9; fi

      # Répartition : chaque instance journalise les requêtes qu'elle sert. On
      # envoie des requêtes marquées, puis on compte les instances qui en ont
      # reçu. Une instance n'entre dans la répartition qu'une fois démarrée :
      # on insiste jusqu'à les voir toutes.
      marque="tptest-$RANDOM-$RANDOM"
      touchees=0
      for _ in $(seq 1 15); do
        for _ in $(seq 1 9); do curl -s -o /dev/null -m 10 "$url/readme.html?$marque" || true; done
        touchees=0
        for c in $(compose 9 ps -q wordpress); do
          recues="$(docker container logs "$c" 2>&1 | grep -c -- "$marque" || true)"
          [ "$recues" -eq 0 ] || touchees=$((touchees + 1))
        done
        [ "$touchees" -lt 3 ] || break
        sleep 2
      done
      for c in $(compose 9 ps -q wordpress); do
        printf '       %s : %s requêtes\n' "$(docker container inspect -f '{{.Name}}' "$c")" \
          "$(docker container logs "$c" 2>&1 | grep -c -- "$marque" || true)"
      done
      if [ "$touchees" -ge 2 ]; then ok "étape 9 : les requêtes ont atteint $touchees instances sur 3"
      else ko "étape 9 : les requêtes n'ont atteint que $touchees instance(s)"; fi

      # Session : WordPress ne garde pas de session côté serveur ; il signe ses
      # cookies avec les clés de wp-config.php, que le volume commun partage.
      # Une connexion ouverte par une instance doit donc valoir sur les autres.
      cookies="$travail/cookies-9"
      curl -s -o /dev/null -m 30 -c "$cookies" -b "wordpress_test_cookie=WP%20Cookie%20check" \
        --data-urlencode "log=tptest" --data-urlencode "pwd=$mot_de_passe_wp" \
        --data-urlencode "testcookie=1" --data-urlencode "redirect_to=$url/wp-admin/" \
        "$url/wp-login.php" || true
      acceptees=0
      for _ in $(seq 1 9); do
        code="$(curl -s -o /dev/null -m 30 -b "$cookies" -w '%{http_code}' "$url/wp-admin/profile.php" || true)"
        [ "$code" != "200" ] || acceptees=$((acceptees + 1))
      done
      if [ "$acceptees" -eq 9 ]; then ok "étape 9 : la session ouverte vaut sur toutes les instances (9 requêtes sur 9)"
      else ko "étape 9 : session refusée par certaines instances ($acceptees requêtes sur 9)"; fi
    else
      ko "étape 9 : docker compose up --scale wordpress=3"
    fi
    fin_etape 9
  fi
fi

# ----------------------------------------------------------------------- bilan

printf '\n======== Bilan (%s) : %s vérifications réussies, %s en échec ========\n' "--$mode" "$reussis" "${#echecs[@]}"
if [ "${#echecs[@]}" -gt 0 ]; then
  printf '  - %s\n' "${echecs[@]}"
  exit 1
fi
