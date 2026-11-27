#!/usr/bin/env bash
# Rejoue les commandes du diaporama « Le terminal, le shell, la commande » (intro.typ) et relève les versions.
# Usage : ./rejouer-intro.sh > sorties-intro.txt 2>&1
# Les commandes sont jouées comme dans la VM du terminal des pages web : Alpine 3.22.8 (l’image de base de
# commun/terminal/construire-vm.sh), Bash, GNU coreutils, mandoc et les pages de manuel de coreutils et de Bash,
# machine « cours », compte ordinaire ada, invite « ada@cours:~$ ». Le script se relance tout seul dans un conteneur
# (Docker requis, réseau pour apk). Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le README.md du dépôt) :
#   TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./rejouer-intro.sh > sorties-intro.txt 2>&1
# REJOUER_NOM (facultatif) : préfixe du nom du conteneur (défaut : rejeu-intro).
set -u
umask 022

if [ -z "${REJOUER_CONTENEUR:-}" ]; then
  ici=$(cd "$(dirname "$0")" && pwd)
  command -v docker > /dev/null || { echo "Docker est nécessaire." >&2; exit 1; }
  reseau=(); apk_ca=""
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY" --volume "$TPTEST_CA:/run/ca-hote.crt:ro"); apk_ca="1"
  fi
  exec docker container run --rm --hostname cours --name "${REJOUER_NOM:-rejeu-intro}-$$" "${reseau[@]}" \
    --env "APK_CA=$apk_ca" --volume "$ici:/opt/cm:ro" alpine:3.22.8 sh -euc '
      if [ -n "$APK_CA" ]; then cat /run/ca-hote.crt >> /etc/ssl/certs/ca-certificates.crt; fi
      apk add --no-cache -q bash coreutils mandoc coreutils-doc bash-doc > /dev/null
      adduser -D -s /bin/bash ada
      exec su ada -s /bin/bash -c "env -i PATH=\"$PATH\" HOME=/home/ada USER=ada LOGNAME=ada REJOUER_CONTENEUR=1 bash /opt/cm/rejouer-intro.sh"'
fi

export LANG=C.UTF-8 LC_ALL=C.UTF-8
cd "$HOME" || exit 1

# Comme rejouer.sh : chaque commande est recopiée (« $ commande »), puis passée au Bash interactif.
# shellcheck disable=SC2016  # $__code est développé par le Bash qui rejoue, pas ici
recopier() {
  local ligne bloc="" echo="__code=\$?"$'\n'
  while IFS= read -r ligne; do
    if [[ -n $bloc ]]; then printf '%s(exit $__code)\n%s' "$echo" "$bloc"; bloc="" echo="__code=\$?"$'\n'; fi
    local q=${ligne//\'/\'\\\'\'}
    echo+="builtin printf '%s\\n' '\$ $q'"$'\n'
    bloc+="$ligne"$'\n'
  done
  [[ -n $bloc ]] && printf '%s(exit $__code)\n%s' "$echo" "$bloc"
}
session() {
  printf '\n######## %s\n' "$1"
  { printf "PS1=''; PS2=''; export COLUMNS=80\n"; recopier; } \
    | bash --norc --noediting -i 2>&1 \
    | sed -e '/cannot set terminal process group/d' -e '/no job control in this shell/d' \
          -e 's/^bash-[0-9.]*\$ //' -e '/^exit$/d'
}

# shellcheck source=/dev/null
echo "# $(date -u -I) · $(uname -srm) · Alpine $(cat /etc/alpine-release)"
session "Versions" <<'EOF'
bash --version | head -1
date --version | head -1
EOF

printf '\n######## Invite de la VM (PS1 de commun/terminal/vm/profil.sh)\n'
# shellcheck disable=SC2016
bash --norc -c 'PS1="\u@\h:\w\\$ "; printf "%s\n" "${PS1@P}"'

session "Une fenêtre de terminal ; de la frappe au résultat" <<'EOF'
whoami
EOF

session "Lire une ligne de commande" <<'EOF'
date -u +%H:%M
EOF

session "Une option peut prendre un argument" <<'EOF'
date -d 1906-12-09 +%A
date --date=1906-12-09 +%A
EOF

session "Les guillemets : un texte, un seul argument" <<'EOF'
echo Grace     Hopper
echo "Grace     Hopper"
EOF

session "Se documenter" <<'EOF'
type cd
type whoami
help -d cd
whoami --help
EOF

printf '\n######## man date (premieres lignes de l ecran, 80 colonnes, sans le gras)\n'
MANWIDTH=80 MANPAGER=cat man date 2>&1 | sed 's/.\x08//g' | head -n 16

session "Exercice" <<'EOF'
echo Ada     Lovelace
echo "Ada     Lovelace"
date -d 1815-12-10 +%A
type echo
EOF
