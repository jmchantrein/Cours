#!/usr/bin/env bash
# Harnais de test des corrigés du dojo Vim.
#
# Chaque kata du dojo a un fichier de départ et un résultat attendu
# (dojo/<kata>/depart.* et attendu.*) ; son corrigé est une suite de touches
# (corrige/<kata>.touches). Le harnais rejoue chaque suite dans Vim, sur une
# copie du fichier de départ, et compare le fichier obtenu au résultat attendu
# par diff : un corrigé qui ne mène plus au résultat fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up | --local]
#   --lint   (défaut) sans rien exécuter : bash -n et shellcheck ; chaque kata a
#            un départ, un attendu de même extension et un corrigé ; un corrigé
#            n'emploie que les touches nommées connues et se termine par :wq.
#   --up     le --local ci-dessous, dans un conteneur debian:13-slim où le
#            harnais installe vim et yamllint : la version de Vim est celle de
#            Debian 13.
#   --local  --lint, puis le rejeu, avec le Vim de cet hôte. Chaque suite est
#            rejouée trois fois : sans configuration (vim -u NONE), avec la
#            configuration par défaut de Vim (-u DEFAULTS, celle d'un compte sans
#            ~/.vimrc) et avec le ~/.vimrc du cours. Les YAML du dojo passent
#            yamllint : les modifications laissent un YAML valide.
#
# Format d'un corrigé (.touches) : les touches telles qu'on les tape ; une ligne
# qui commence par « " » est un commentaire ; les fins de ligne ne comptent pas
# (Entrée s'écrit <CR>) ; touches nommées : <Esc>, <CR>, <C-v>, <C-r>.
#
# Le harnais travaille dans un dossier temporaire et ne modifie aucun fichier
# du TP. --up crée un seul conteneur, tptest-vim, supprimé en sortie.
#
# Prérequis : --lint : bash, shellcheck. --local : en plus vim (version
# complète, pas vim-tiny ni le vi de BusyBox), timeout, yamllint. --up : bash, le
# programme shellcheck, Docker et l'accès aux dépôts Debian.
# Derrière un mandataire HTTPS (variable HTTPS_PROXY, et SSL_CERT_FILE pour son
# autorité de certification), --up fait passer apt par lui, en HTTPS.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
dojo="$ici/dojo"
# Vim lit et écrit les fichiers en UTF-8 (kata 6 : « à », « è »).
export LC_ALL=C.UTF-8

mode="lint"
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --local) mode="local" ;;
    -h | --help) sed -n '2,35p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian ou Ubuntu qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}

# ------------------------------------------------------------------ --up : Debian 13

if [ "$mode" = "up" ]; then
  exiger docker docker.io
  docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
  reseau=(); apt_https=""
  if [ -n "${HTTPS_PROXY:-}" ]; then
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY"); apt_https="1"
    if [ -n "${SSL_CERT_FILE:-}" ] && [ -f "$SSL_CERT_FILE" ]; then
      reseau+=(--volume "$SSL_CERT_FILE:/run/ca-hote.crt:ro")
    fi
  fi
  docker container rm -f tptest-vim > /dev/null 2>&1 || true
  echo "Conteneur debian:13-slim : installation de vim, yamllint et shellcheck…"
  # Le TP est monté en lecture seule : le harnais n'écrit que dans /tmp.
  exec docker container run --rm --name tptest-vim "${reseau[@]}" \
    --env "APT_HTTPS=$apt_https" --volume "$ici:/tp:ro" debian:13-slim bash -euc '
      if [ -n "$APT_HTTPS" ]; then
        sed -i "s|http://deb.debian.org|https://deb.debian.org|g" /etc/apt/sources.list.d/debian.sources
        { echo "Acquire::https::Proxy \"$HTTPS_PROXY\";"
          [ ! -f /run/ca-hote.crt ] || echo "Acquire::https::CAInfo \"/run/ca-hote.crt\";"; } > /etc/apt/apt.conf.d/99mandataire
      fi
      apt-get update -qq > /dev/null
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        vim yamllint shellcheck > /dev/null
      echo "Debian $(cat /etc/debian_version) · $(dpkg-query -W -f="vim \${Version}" vim)"
      exec bash /tp/tester.sh --local'
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

# touches FICHIER : la suite de touches d'un corrigé, sans commentaires ni fins
# de ligne, les touches nommées remplacées par leur caractère.
touches() {
  local t
  t="$(grep -v '^"' "$1" | tr -d '\n')"
  t="${t//<Esc>/$'\e'}"; t="${t//<CR>/$'\r'}"; t="${t//<C-v>/$'\x16'}"; t="${t//<C-r>/$'\x12'}"
  printf '%s' "$t"
}

# ------------------------------------------------------------------------- lint

exiger bash bash
exiger shellcheck shellcheck

titre "Lint : le harnais"
if bash -n "$ici/tester.sh"; then ok "tester.sh : syntaxe bash"; else ko "tester.sh : syntaxe bash"; fi
if shellcheck "$ici/tester.sh"; then ok "tester.sh : shellcheck"; else ko "tester.sh : shellcheck"; fi

titre "Lint : katas et corrigés"
katas=()
for dossier in "$dojo"/*/; do
  kata="$(basename "$dossier")"; katas+=("$kata")
  departs=("$dossier"depart.*); attendus=("$dossier"attendu.*)
  if [ "${#departs[@]}" -eq 1 ] && [ -f "${departs[0]}" ] && [ "${#attendus[@]}" -eq 1 ] && [ -f "${attendus[0]}" ] \
    && [ "${departs[0]##*.}" = "${attendus[0]##*.}" ]; then
    ok "$kata : un fichier de départ et un résultat attendu, de même extension"
  else
    ko "$kata : il faut un depart.<ext> et un attendu.<ext>"; continue
  fi
  if cmp -s "${departs[0]}" "${attendus[0]}"; then ko "$kata : départ et attendu sont identiques"
  else ok "$kata : départ et attendu diffèrent"; fi
  fichier="$corrige/$kata.touches"
  if [ ! -f "$fichier" ]; then ko "$kata : corrigé absent (corrige/$kata.touches)"; continue; fi
  inconnues="$(grep -v '^"' "$fichier" | grep -o '<[^>]*>' | grep -vxE '<(Esc|CR|C-v|C-r)>' || true)"
  if [ -z "$inconnues" ]; then ok "$kata : le corrigé n'emploie que des touches nommées connues"
  else ko "$kata : touches nommées inconnues : $(tr '\n' ' ' <<< "$inconnues")"; fi
  if grep -v '^"' "$fichier" | grep -q '[[:space:]]$'; then ko "$kata : une ligne du corrigé finit par une espace, invisible"
  else ok "$kata : aucune espace en fin de ligne"; fi
  if [[ "$(touches "$fichier")" == *$':wq\r' ]]; then ok "$kata : le corrigé se termine par :wq<CR>"
  else ko "$kata : le corrigé doit se terminer par :wq<CR>"; fi
done
for fichier in "$corrige"/*.touches; do
  kata="$(basename "$fichier" .touches)"
  [ -d "$dojo/$kata" ] || ko "corrige/$kata.touches : aucun kata dojo/$kata"
done

[ "$mode" = "lint" ] && bilan

# ----------------------------------------------------------------------- rejeu

exiger vim vim
exiger timeout coreutils
exiger yamllint yamllint
if ! vim --version | grep -q '+eval'; then
  echo "Ce vim est une version réduite (vim-tiny ?) : installez le paquet vim." >&2; exit 1
fi

travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
trap 'rm -rf -- "$travail"' EXIT
# Le ~/.vimrc du cours (diapo « Configurer Vim »).
printf '%s\n' '" les commentaires commencent par un guillemet' 'set number' 'set autoindent' \
  'set tabstop=4' 'syntax on' 'filetype plugin indent on' > "$travail/vimrc-du-cours"

titre "Rejeu : $(vim --version | head -1)"
for kata in "${katas[@]}"; do
  depart=("$dojo/$kata"/depart.*); attendu=("$dojo/$kata"/attendu.*)
  extension="${depart[0]##*.}"
  touches "$corrige/$kata.touches" > "$travail/$kata.touches"
  for configuration in NONE DEFAULTS "$travail/vimrc-du-cours"; do
    libelle="vim -u ${configuration##*/}"
    copie="$travail/$kata/kata.$extension"
    rm -rf "${copie%/*}"; mkdir -p "${copie%/*}"; cp "${depart[0]}" "$copie"
    # Sans terminal, Vim lit ses touches dans le fichier (-s) puis, après :wq, s'arrête ;
    # </dev/null et timeout l'arrêtent aussi quand une suite ne se termine pas.
    if (cd "${copie%/*}" && timeout 20 vim -u "$configuration" -N -i NONE -n -s "$travail/$kata.touches" \
      "kata.$extension" < /dev/null > /dev/null 2>&1); then :; else
      ko "$kata ($libelle) : Vim ne s'est pas terminé normalement"; continue
    fi
    if diff -u "${attendu[0]}" "$copie" > "$travail/diff"; then ok "$kata ($libelle) : le résultat est celui attendu"
    else ko "$kata ($libelle) : le résultat diffère de l'attendu"; sed 's/^/       /' "$travail/diff"; fi
  done
done

titre "Les YAML du dojo restent valides"
for f in "$dojo"/*/*.yaml; do
  if yamllint "$f" > /dev/null; then ok "${f#"$ici"/} : yamllint"
  else ko "${f#"$ici"/} : yamllint"; yamllint "$f" || true; fi
done

bilan
