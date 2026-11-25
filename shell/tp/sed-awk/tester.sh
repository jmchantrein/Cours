#!/usr/bin/env bash
# Harnais de test des corrigés du TP « sed et awk : exercices progressifs ».
#
# Il vérifie et exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé
# affiche : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--keep] [--attendus]
#   --lint      (défaut) sans rien exécuter : bash -n et shellcheck des scripts,
#               droits d'exécution, une sortie attendue par exercice, données
#               identiques au fil rouge du cours (cm/exemples/).
#   --up        --lint, puis, dans un conteneur debian:13-slim, chaque exercice
#               rejoué dans un atelier neuf sous mawk (l'awk par défaut de
#               Debian) puis sous gawk, sa sortie comparée à attendu/<exercice>.txt ;
#               puis le durcissement de sshd_config validé par sshd lui-même.
#   --keep      ne supprime pas le conteneur en fin de test.
#   --attendus  avec --up : réécrit attendu/ d'après les sorties sous mawk
#               (après une modification voulue d'un exercice ; relire le diff).
#
# Ce que --up vérifie :
#   chaque exercice   sortie identique à l'attendu sous mawk, et sous gawk ;
#                     une différence entre les deux est signalée nommément ;
#   BusyBox           les mêmes exercices sous les sed et awk de BusyBox, ceux de
#                     la VM Alpine du navigateur avant l'ajout de sed et gawk :
#                     les différences sont affichées (INFO), sans faire échouer ;
#   sshd_config       l'extrait de donnees/ reprend, dans l'ordre, des lignes du
#                     fichier installé par openssh-server ; une fois durci par
#                     sshd-2-durcir.sh, l'extrait et le fichier complet passent
#                     « sshd -t » et « sshd -T » lit passwordauthentication no et
#                     permitrootlogin no ; un fichier de sshd_config.d qui dit
#                     yes l'emporte (la première valeur lue gagne), un fichier
#                     00-… lu avant lui l'emporte sur lui.
#
# Ressources : un conteneur « tptest-shell-sed-awk-<pid> », supprimé en fin de
# test ; le dossier du TP y est monté en lecture seule.
#
# Prérequis de --lint : bash, shellcheck. De --up : Docker, et l'accès aux dépôts
# Debian (le conteneur installe gawk, busybox, openssh-server).
# Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le README.md du dépôt)
# fait passer le conteneur par HTTPS_PROXY ; apt passe en HTTPS avec cette autorité.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
exemples="$ici/../../cm/exemples"
export LC_ALL=C.UTF-8

# Les exercices, dans l'ordre de l'énoncé : les trois sshd-* travaillent sur le même fichier, l'un après l'autre.
exercices=(sed-1-substitution sed-2-adresses sed-3-plages sed-4-captures sed-5-en-place
  awk-1-champs awk-2-motifs awk-3-begin-end awk-4-tableaux awk-5-sections
  sshd-1-directives sshd-2-durcir sshd-3-verifier)

mode="lint"; garder=""; attendus=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --keep) garder="1" ;;
    --attendus) attendus="1" ;;
    -h | --help) sed -n '2,41p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian ou Ubuntu qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}
exiger bash bash
exiger shellcheck shellcheck
if [ "$mode" = "up" ]; then
  exiger docker docker.io
  docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
fi

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=(); infos=0
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
info() { printf 'INFO   %s\n' "$*"; infos=$((infos + 1)); }
titre() { printf '\n======== %s ========\n' "$*"; }
bilan() {
  printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec' "$mode" "$reussis" "${#echecs[@]}"
  [ "$mode" = "lint" ] || printf ', %s différences BusyBox signalées' "$infos"
  printf ' ========\n'
  [ "${#echecs[@]}" -eq 0 ] || { printf '  - %s\n' "${echecs[@]}"; exit 1; }
  exit 0
}

# ------------------------------------------------------------------------ lint

titre "Lint : scripts de corrige/"
for script in "$corrige"/*.sh "$0"; do
  nom="${script#"$ici"/}"
  if bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  if shellcheck "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  if [ "$script" != "$0" ]; then
    if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
  fi
done

titre "Lint : exercices, sorties attendues, données"
for e in "${exercices[@]}"; do
  [ -f "$corrige/$e.sh" ] || ko "corrige/$e.sh : absent"
  if [ -s "$corrige/attendu/$e.txt" ]; then ok "corrige/attendu/$e.txt : présent"
  else ko "corrige/attendu/$e.txt : absent ou vide"; fi
done
for script in "$corrige"/*.sh; do
  e="$(basename "$script" .sh)"
  [[ " ${exercices[*]} " == *" $e "* ]] || ko "corrige/$e.sh : absent de la liste « exercices » du harnais"
done
for donnee in pionnieres.csv services.conf; do
  if cmp -s "$corrige/donnees/$donnee" "$exemples/$donnee"; then ok "corrige/donnees/$donnee : identique au fil rouge du cours"
  else ko "corrige/donnees/$donnee : diffère de shell/cm/exemples/$donnee"; fi
done

[ "$mode" = "lint" ] && bilan

# ------------------------------------------------------------------------- up

journal="$(mktemp "${TMPDIR:-/tmp}/tptest.XXXXXX")"
conteneur="tptest-shell-sed-awk-$$"
# shellcheck disable=SC2317  # appelée par trap, en sortie
en_sortie() {
  rm -f -- "$journal"
  if [ -z "$garder" ]; then docker container rm -f "$conteneur" > /dev/null 2>&1 || true; fi
}
trap en_sortie EXIT

reseau=(); apt_options=""
if [ -n "${TPTEST_CA:-}" ]; then
  : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
  reseau+=(--network host --env "https_proxy=$HTTPS_PROXY" --volume "$TPTEST_CA:/run/ca-hote.crt:ro")
  apt_options="-o Acquire::https::CAInfo=/run/ca-hote.crt"
fi
sortie_attendus=()
if [ -n "$attendus" ]; then sortie_attendus=(--volume "$corrige/attendu:/attendus-neufs"); fi

# Le script du conteneur écrit des lignes « VERIF ok|ko|info … », relues ici, et « # … » pour les versions.
# shellcheck disable=SC2016,SC1112  # $ développés dans le conteneur ; apostrophes typographiques voulues
script_conteneur='
  set -u
  export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
  if [ -n "$APT_OPTIONS" ]; then
    sed -i "s,http://deb.debian.org,https://deb.debian.org,g" /etc/apt/sources.list.d/debian.sources
  fi
  # Avant toute installation : l’awk par défaut de Debian 13.
  echo "# awk par défaut : $(readlink -f "$(command -v awk)")"
  # shellcheck disable=SC2086
  { apt-get $APT_OPTIONS update -qq \
      && apt-get $APT_OPTIONS install -y -qq --no-install-recommends gawk busybox openssh-server; } > /tmp/apt.log 2>&1 \
    || { echo "VERIF ko installation de gawk, busybox et openssh-server (apt-get)"; tail -n 5 /tmp/apt.log; exit 0; }
  echo "# $(. /etc/os-release && echo "$PRETTY_NAME") ; $(sed --version | head -n 1) ; $(mawk -W version 2>&1 | head -n 1) ;" \
    "$(gawk --version | head -n 1 | cut -d, -f1) ; $(busybox | head -n 1 | cut -d" " -f1-2) ; OpenSSH $(dpkg-query -W -f "\${Version}" openssh-server)"
  echo "# awk après installation de gawk : $(readlink -f "$(command -v awk)") (gawk prend la main : le harnais nomme chaque awk)"

  # Un dossier par implémentation, en tête du PATH : « awk » et « sed » y désignent l’outil voulu.
  mkdir -p /impl/mawk /impl/gawk /impl/busybox
  ln -s /usr/bin/mawk /impl/mawk/awk; ln -s /usr/bin/gawk /impl/gawk/awk
  ln -s /usr/bin/busybox /impl/busybox/awk; ln -s /usr/bin/busybox /impl/busybox/sed
  for impl in mawk gawk busybox; do
    atelier="/ateliers/$impl"; mkdir -p "$atelier"; cp /tp/corrige/donnees/* "$atelier"/
    mkdir -p "/sorties/$impl"
    for e in $EXERCICES; do
      ( cd "$atelier" && PATH="/impl/$impl:$PATH" bash "/tp/corrige/$e.sh" ) > "/sorties/$impl/$e.txt" 2>&1
    done
  done
  for e in $EXERCICES; do
    attendu="/tp/corrige/attendu/$e.txt"
    for impl in mawk gawk; do
      if cmp -s "/sorties/$impl/$e.txt" "$attendu"; then echo "VERIF ok $e : sortie attendue sous $impl"
      else echo "VERIF ko $e : sortie différente de attendu/$e.txt sous $impl"; diff "$attendu" "/sorties/$impl/$e.txt" | sed "s/^/       /"; fi
    done
    if cmp -s "/sorties/mawk/$e.txt" "/sorties/gawk/$e.txt"; then echo "VERIF ok $e : mawk et gawk donnent la même sortie"
    else echo "VERIF ko $e : mawk et gawk diffèrent"; diff "/sorties/mawk/$e.txt" "/sorties/gawk/$e.txt" | sed "s/^/       /"; fi
    if ! cmp -s "/sorties/busybox/$e.txt" "$attendu"; then
      echo "VERIF info $e : BusyBox diffère (sed et awk de BusyBox) :"; diff "$attendu" "/sorties/busybox/$e.txt" | sed "s/^/       /"
    fi
  done
  if [ -d /attendus-neufs ]; then cp /sorties/mawk/*.txt /attendus-neufs/; echo "# attendu/ réécrit d’après mawk"; fi

  # sshd_config : l’extrait reprend des lignes du fichier réel, dans le même ordre.
  reel=/etc/ssh/sshd_config
  if awk "NR == FNR { if (\$0 != \"\") voulu[++n] = \$0; next } i < n && \$0 == voulu[i + 1] { i++ } END { exit i < n }" \
      /tp/corrige/donnees/sshd_config "$reel"; then
    echo "VERIF ok sshd_config : chaque ligne de l’extrait est dans $reel, dans le même ordre"
  else echo "VERIF ko sshd_config : l’extrait ne suit plus $reel"; fi
  mkdir -p /run/sshd; ssh-keygen -A > /dev/null
  mkdir -p /durci/extrait /durci/complet
  cp /tp/corrige/donnees/sshd_config /durci/extrait/; cp "$reel" /durci/complet/sshd_config
  for cas in extrait complet; do
    ( cd "/durci/$cas" && bash /tp/corrige/sshd-2-durcir.sh > /dev/null )
    f="/durci/$cas/sshd_config"
    if sshd -t -f "$f"; then echo "VERIF ok sshd -t accepte le fichier $cas durci"; else echo "VERIF ko sshd -t refuse le fichier $cas durci"; fi
    effectif="$(sshd -T -f "$f" 2>&1)"
    for directive in "passwordauthentication no" "permitrootlogin no"; do
      if grep -qx "$directive" <<< "$effectif"; then echo "VERIF ok sshd -T, fichier $cas durci : $directive"
      else echo "VERIF ko sshd -T, fichier $cas durci : « $directive » attendu, lu : $(grep "^${directive% *} " <<< "$effectif")"; fi
    done
  done
  # La première valeur lue gagne, et Include est en tête du fichier : sshd_config.d a le dernier mot.
  f=/durci/complet/sshd_config
  echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/50-tptest.conf
  if grep -qx "passwordauthentication yes" <<< "$(sshd -T -f "$f")"; then
    echo "VERIF ok sshd -T : un fichier de sshd_config.d qui dit yes l’emporte sur le fichier durci"
  else echo "VERIF ko sshd -T : le fichier de sshd_config.d ne l’emporte pas (l’énoncé est à revoir)"; fi
  echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/00-tptest-durcissement.conf
  if grep -qx "passwordauthentication no" <<< "$(sshd -T -f "$f")"; then
    echo "VERIF ok sshd -T : 00-…conf, lu avant 50-…conf, l’emporte sur lui"
  else echo "VERIF ko sshd -T : 00-…conf ne l’emporte pas sur 50-…conf (l’énoncé est à revoir)"; fi
'
titre "Exercices sous mawk, gawk et BusyBox, puis sshd, dans un conteneur debian:13-slim"
docker container run --name "$conteneur" "${reseau[@]}" --env "APT_OPTIONS=$apt_options" \
  --env "EXERCICES=${exercices[*]}" --volume "$ici:/tp:ro" "${sortie_attendus[@]}" \
  debian:13-slim bash -c "$script_conteneur" > "$journal" 2>&1 || true
while IFS= read -r ligne; do
  case "$ligne" in
    "VERIF ok "*) ok "${ligne#VERIF ok }" ;;
    "VERIF ko "*) ko "${ligne#VERIF ko }" ;;
    "VERIF info "*) info "${ligne#VERIF info }" ;;
    *) printf '%s\n' "$ligne" ;;
  esac
done < "$journal"
[ "$reussis" -gt 0 ] || ko "aucune vérification lue dans le conteneur"
bilan
