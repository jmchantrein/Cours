#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Du pipeline au script robuste ».
#
# Il vérifie et exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé
# affiche : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--hote] [--keep]
#   --lint   (défaut) sans rien exécuter : bash -n et shellcheck des scripts et
#            de solutions.bats, droits d'exécution, données identiques au fil
#            rouge du cours (cm/exemples/), sortie attendue présente.
#   --up     --lint, puis les tests Bats (corrige/solutions.bats) et shellcheck
#            dans un conteneur debian:13-slim : bash 5.2, bats 1.11,
#            ShellCheck 0.10, coreutils et locale C.UTF-8 de Debian 13, les
#            versions que l'énoncé suppose.
#   --hote   avec --up : lance Bats sur cette machine plutôt qu'en conteneur
#            (sans Docker ; les messages des outils peuvent alors différer).
#   --keep   ne supprime pas le conteneur en fin de test (pour examiner un échec).
#
# Ce que --up vérifie (un test Bats par ligne, 15 en tout) :
#   pipelines.sh       sa sortie est attendu/pipelines.txt ; noms.txt et
#                      erreurs.txt reçoivent chacun leur flux ;
#   liste_fichiers     la liste, le code 1 et le message sur l'erreur standard,
#                      un nom de répertoire à espace ;
#   copie_fichiers     les codes 0, 1, 2 et 3, chacun provoqué ;
#   a-relire.sh        la version corrigée trouve rapport.txt dans « mes documents » ;
#   copie_fichiers_args.bash et copie_fichiers_robuste.bash : mêmes tests pour
#                      les deux (code 4 d'usage, 0 à 3, entrée standard ignorée).
# Le --lint vérifie aussi que le point de départ de l'étape 5,
# shell/cm/exemples/a-relire.sh, échoue bien à shellcheck (liste explicite
# « attendus_en_echec » ci-dessous) : la démonstration du cours reste fautive.
#
# Ressources : un conteneur « tptest-shell-scripts-<pid> », supprimé en fin de
# test ; le dossier du TP y est monté en lecture seule.
#
# Prérequis de --lint : bash, shellcheck. De --up : Docker et l'accès aux
# dépôts Debian (le conteneur installe bats et shellcheck), ou bats avec --hote.
# Mandataire facultatif : si HTTPS_PROXY est défini, le conteneur passe par lui
# (réseau de l'hôte) ; si TPTEST_CA (ou SSL_CERT_FILE) nomme un fichier, apt
# l'emploie comme autorité de certification et passe en HTTPS.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
exemples="$ici/../../cm/exemples"
export LC_ALL=C.UTF-8

mode="lint"; hote=""; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --hote) hote="1" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian ou Ubuntu qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}
exiger bash bash
exiger shellcheck shellcheck
if [ "$mode" = "up" ]; then
  if [ -n "$hote" ]; then
    exiger bats bats
  else
    exiger docker docker.io
    docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info) ; --hote lance Bats sans Docker." >&2; exit 1; }
  fi
fi

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
bilan() {
  printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec ========\n' "$mode" "$reussis" "${#echecs[@]}"
  [ "${#echecs[@]}" -eq 0 ] || { printf '  - %s\n' "${echecs[@]}"; exit 1; }
  exit 0
}

# ------------------------------------------------------------------------ lint

titre "Lint : scripts de corrige/"
for script in "$corrige"/*.sh "$corrige"/*.bash "$0"; do
  nom="${script#"$ici"/}"
  if bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  if shellcheck "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  if [ "$script" != "$0" ]; then
    if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
  fi
done
# ShellCheck lit les fichiers Bats (shebang bats) ; bash -n ne les comprend pas (@test).
if shellcheck "$corrige/solutions.bats"; then ok "corrige/solutions.bats : shellcheck"; else ko "corrige/solutions.bats : shellcheck"; fi

titre "Lint : points de départ qui doivent échouer"
# Fichiers de démonstration fautifs exprès : exclus des vérifications ci-dessus,
# ils doivent au contraire déclencher les avertissements que l'énoncé fait corriger.
attendus_en_echec=("$exemples/a-relire.sh:SC2045 SC2086")
for entree in "${attendus_en_echec[@]}"; do
  fichier="${entree%%:*}"; codes="${entree#*:}"
  nom="shell/cm/exemples/$(basename "$fichier")"
  if [ ! -f "$fichier" ]; then ko "$nom : introuvable (l'étape 5 part de ce fichier)"; continue; fi
  rapport="$(shellcheck -f gcc "$fichier" || true)"
  for code in $codes; do
    if grep -q "$code" <<< "$rapport"; then ok "$nom : shellcheck signale $code, comme l'énoncé l'annonce"
    else ko "$nom : shellcheck ne signale plus $code (l'énoncé de l'étape 5 est à revoir)"; fi
  done
done

titre "Lint : données et sorties attendues"
for donnee in pionnieres.csv services.conf; do
  if cmp -s "$corrige/donnees/$donnee" "$exemples/$donnee"; then ok "corrige/donnees/$donnee : identique au fil rouge du cours"
  else ko "corrige/donnees/$donnee : diffère de shell/cm/exemples/$donnee"; fi
done
if [ -s "$corrige/attendu/pipelines.txt" ]; then ok "corrige/attendu/pipelines.txt : présent"
else ko "corrige/attendu/pipelines.txt : absent ou vide"; fi

[ "$mode" = "lint" ] && bilan

# ------------------------------------------------------------------------- up

# Compte rendu des tests Bats, lu dans leur sortie TAP (« ok 3 … », « not ok 4 … »).
lire_tap() { # $1 fichier TAP  $2 contexte
  local ligne vus=0
  while IFS= read -r ligne; do
    case "$ligne" in
      "ok "*) ok "bats ($2) : ${ligne#ok [0-9]* }"; vus=$((vus + 1)) ;;
      "not ok "*) ko "bats ($2) : ${ligne#not ok [0-9]* }"; vus=$((vus + 1)) ;;
      "#"*) printf '       %s\n' "$ligne" ;;
    esac
  done < "$1"
  [ "$vus" -gt 0 ] || { ko "bats ($2) : aucun test lu"; sed 's/^/       /' "$1"; }
}

journal="$(mktemp "${TMPDIR:-/tmp}/tptest.XXXXXX")"
conteneur="tptest-shell-scripts-$$"
# shellcheck disable=SC2317  # appelée par trap, en sortie
en_sortie() {
  rm -f -- "$journal"
  if [ -z "$hote" ] && [ -z "$garder" ]; then docker container rm -f "$conteneur" > /dev/null 2>&1 || true; fi
}
trap en_sortie EXIT

if [ -n "$hote" ]; then
  titre "Bats sur cette machine ($(bats --version))"
  bats --tap "$corrige/solutions.bats" > "$journal" 2>&1 || true
  lire_tap "$journal" "hôte"
  bilan
fi

titre "Bats et shellcheck dans un conteneur debian:13-slim"
reseau=(); apt_options=""
if [ -n "${HTTPS_PROXY:-}" ]; then reseau+=(--network host --env "https_proxy=$HTTPS_PROXY"); fi
ca="${TPTEST_CA:-${SSL_CERT_FILE:-}}"
if [ -n "$ca" ] && [ -f "$ca" ]; then
  reseau+=(--volume "$ca:/run/ca-hote.crt:ro")
  apt_options="-o Acquire::https::CAInfo=/run/ca-hote.crt"
fi
# Le script du conteneur : installer les outils, relever leurs versions, lancer shellcheck puis Bats.
# Les lignes « VERIF ok|ko … » et la sortie TAP sont relues ici.
# shellcheck disable=SC2016  # les $ sont développés dans le conteneur
script_conteneur='
  set -u
  export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
  if [ -n "$APT_OPTIONS" ]; then
    sed -i "s,http://deb.debian.org,https://deb.debian.org,g" /etc/apt/sources.list.d/debian.sources
  fi
  # shellcheck disable=SC2086
  { apt-get $APT_OPTIONS update -qq && apt-get $APT_OPTIONS install -y -qq --no-install-recommends bats shellcheck; } > /tmp/apt.log 2>&1 \
    || { echo "VERIF ko installation de bats et shellcheck (apt-get)"; tail -n 5 /tmp/apt.log; exit 0; }
  echo "# $(. /etc/os-release && echo "$PRETTY_NAME") ; $(bash --version | head -n 1)"
  echo "# $(bats --version) ; shellcheck $(shellcheck --version | sed -n "s/^version: //p")"
  for f in /tp/corrige/*.sh /tp/corrige/*.bash /tp/corrige/solutions.bats; do
    if shellcheck "$f"; then echo "VERIF ok shellcheck (Debian 13) : ${f#/tp/}"
    else echo "VERIF ko shellcheck (Debian 13) : ${f#/tp/}"; fi
  done
  bats --tap /tp/corrige/solutions.bats
'
docker container run --name "$conteneur" "${reseau[@]}" --env "APT_OPTIONS=$apt_options" \
  --volume "$ici:/tp:ro" debian:13-slim bash -c "$script_conteneur" > "$journal" 2>&1 || true
while IFS= read -r ligne; do
  case "$ligne" in
    "VERIF ok "*) ok "${ligne#VERIF ok }" ;;
    "VERIF ko "*) ko "${ligne#VERIF ko }" ;;
    "In /tp/"* | *"^--"* | *"SC"[0-9]*) printf '       %s\n' "$ligne" ;;
  esac
done < "$journal"
lire_tap "$journal" "Debian 13"
bilan
