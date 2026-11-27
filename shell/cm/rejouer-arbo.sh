#!/usr/bin/env bash
# Rejoue les commandes du diaporama « Se repérer dans l’arborescence » (arbo.typ) et relève les versions.
# Usage : ./rejouer-arbo.sh > sorties-arbo.txt 2>&1
# Hors d’un Debian 13, le script se relance tout seul dans un conteneur debian:13-slim (Docker requis), sans réseau,
# y crée le compte ordinaire ada, prépare ~/atelier avec shell/tp/premiers-pas/preparer.sh (l’arborescence du TP et
# de la VM du terminal), puis joue les sessions en ada, chacune dans un Bash interactif qui part du répertoire
# personnel : avant chaque commande, « $ » et la commande, puis sa sortie.
# ls est joué comme dans un terminal de 80 colonnes (noms en colonnes) : ls -C, COLUMNS=80, sans le montrer.
# REJOUER_NOM (facultatif) : préfixe du nom du conteneur (défaut : rejeu-arbo).
set -u
umask 022

# shellcheck source=/dev/null
debian13() { ( . /etc/os-release 2>/dev/null && [ "${ID:-}" = debian ] && [ "${VERSION_ID:-}" = 13 ] ); }
if [ -z "${REJOUER_CONTENEUR:-}" ] && ! debian13; then
  shell=$(cd "$(dirname "$0")/.." && pwd)
  command -v docker > /dev/null || { echo "Docker est nécessaire hors d’un Debian 13." >&2; exit 1; }
  # Le dossier shell/ est monté en lecture seule (sous /opt, pour que ls / montre la racine d’un Debian) : les sessions n’écrivent que chez ada.
  exec docker container run --rm --network none --name "${REJOUER_NOM:-rejeu-arbo}-$$" \
    --volume "$shell:/opt/shell:ro" debian:13-slim bash -euc '
      useradd --create-home --shell /bin/bash ada
      exec setpriv --reuid=ada --regid=ada --init-groups env -i PATH="$PATH" HOME=/home/ada USER=ada LOGNAME=ada \
        REJOUER_CONTENEUR=1 bash /opt/shell/cm/rejouer-arbo.sh'
fi

export LANG=C.UTF-8 LC_ALL=C.UTF-8
PREPARER=$(cd "$(dirname "$0")/../tp/premiers-pas" && pwd)/preparer.sh

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

# ~/atelier neuf, puis la session, dans un Bash interactif qui part de ~.
session() {
  printf '\n######## %s\n' "$1"
  rm -rf "$HOME/atelier"
  bash "$PREPARER" > /dev/null
  cd "$HOME" || exit 1
  { printf "PS1=''; PS2=''; export COLUMNS=80; alias ls='ls -C'\n"; recopier; } \
    | bash --norc --noediting -i 2>&1 \
    | sed -e '/cannot set terminal process group/d' -e '/no job control in this shell/d' \
          -e 's/^bash-[0-9.]*\$ //' -e '/^exit$/d'
}

# shellcheck source=/dev/null
echo "# $(date -I) · $(uname -srm) · $(. /etc/os-release && echo "$PRETTY_NAME")"
session "Versions" <<'EOF'
bash --version | head -1
ls --version | head -1
EOF

session "La racine" <<'EOF'
ls /
EOF

session "Où suis-je ? Que contient ce répertoire ?" <<'EOF'
pwd
ls
ls atelier
ls -a atelier
EOF

session "Changer de répertoire" <<'EOF'
cd atelier
pwd
cd notes
pwd
ls
EOF

session "Chemin relatif, chemin absolu" <<'EOF'
cd atelier/notes
cd ../projets/site
pwd
cd /home/ada/atelier/notes
cd /home/ada/atelier/projets/site
pwd
EOF

session ". et .." <<'EOF'
cd atelier/projets/site
ls -a
ls ..
ls ../../journaux
cd ~/atelier
ls notes/../projets/./site
EOF

session "~, cd seul, cd -" <<'EOF'
echo ~
cd ~/atelier/notes
cd /tmp
pwd
cd -
cd
pwd
EOF

session "Exercice" <<'EOF'
cd ~/atelier/notes
cd ../projets/scripts
pwd
ls
cd ../..
pwd
ls ./vieux
cd -
EOF

session "Ouverture : ls -a notes" <<'EOF'
cd ~/atelier
ls -a notes
EOF
