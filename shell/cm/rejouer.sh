#!/usr/bin/env bash
# Rejoue les commandes montrées dans les diapos du cours « Shell » et relève les versions.
# Usage : ./rejouer.sh > sorties-shell.txt 2>&1
# Environnement de référence : Debian 13. Hors d’un Debian 13, le script se relance tout seul dans un conteneur
# debian:13-slim (Docker requis), y installe shellcheck, bats et cron, et joue les sessions en utilisateur ordinaire
# (ada, du groupe etudiants). Sur un Debian 13, il tourne tel quel : bash 5.2, GNU sed 4.9, mawk 1.3.4 (l’awk par
# défaut), paquets shellcheck et bats (sinon, les sessions qui les emploient le signalent) ; la session cron n’est
# jouée que si un service cron tourne.
# REJOUER_NOM (facultatif) : préfixe du nom du conteneur (défaut : rejeu-shell).
# Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le README.md du dépôt) : facultatif, absent en CI.
#   TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./rejouer.sh > sorties-shell.txt 2>&1
# Chaque session part d’une copie neuve de exemples/ dans ~/atelier, et se joue dans un vrai Bash
# interactif : avant chaque commande, ce Bash affiche « $ » et la commande, puis l’exécute ; la
# transcription est celle d’un terminal (seul `ls` diffère : hors terminal, un nom par ligne).
# Les messages sont en anglais : locale C.UTF-8, comme dans un conteneur debian:13.
set -u
umask 022

# ---- Debian 13 par défaut : sinon, relance dans un conteneur debian:13-slim ----
# shellcheck source=/dev/null
debian13() { ( . /etc/os-release 2>/dev/null && [ "${ID:-}" = debian ] && [ "${VERSION_ID:-}" = 13 ] ); }
if [ -z "${REJOUER_CONTENEUR:-}" ] && ! debian13; then
  ici=$(cd "$(dirname "$0")" && pwd)
  command -v docker > /dev/null || { echo "Docker est nécessaire hors d’un Debian 13." >&2; exit 1; }
  reseau=(); apt_https=""
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY" --volume "$TPTEST_CA:/run/ca-hote.crt:ro"); apt_https="1"
  fi
  # Le cours est monté en lecture seule : les sessions n’écrivent que dans le dossier personnel d’ada.
  exec docker container run --rm --name "${REJOUER_NOM:-rejeu-shell}-$$" "${reseau[@]}" \
    --env "APT_HTTPS=$apt_https" --volume "$ici:/cm:ro" debian:13-slim bash -euc '
      if [ -n "$APT_HTTPS" ]; then
        sed -i "s|http://deb.debian.org|https://deb.debian.org|g" /etc/apt/sources.list.d/debian.sources
        printf "Acquire::https::Proxy \"%s\";\nAcquire::https::CAInfo \"/run/ca-hote.crt\";\n" "$HTTPS_PROXY" > /etc/apt/apt.conf.d/99mandataire
      fi
      apt-get update -qq > /dev/null
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends shellcheck bats cron > /dev/null
      groupadd etudiants
      useradd --create-home --shell /bin/bash --groups etudiants ada
      cron
      exec setpriv --reuid=ada --regid=ada --init-groups env -i PATH="$PATH" HOME=/home/ada USER=ada LOGNAME=ada \
        REJOUER_CONTENEUR=1 REJOUER_CRON=1 bash /cm/rejouer.sh'
fi

export LANG=C.UTF-8 LC_ALL=C.UTF-8
EXEMPLES=$(cd "$(dirname "$0")/exemples" && pwd)
ATELIER="$HOME/atelier"

# Une commande commence par une ligne non indentée ; done, fi, else, elif, esac et } la continuent.
# Chaque commande est précédée d’un printf qui la recopie, puis passée telle quelle au Bash interactif ;
# le code de retour de la commande précédente est sauvé avant le printf, puis rétabli : `echo $?` reste juste.
# shellcheck disable=SC2016  # $__code est développé par le Bash qui rejoue, pas ici
recopier() {
  local ligne bloc="" echo="__code=\$?"$'\n'
  while IFS= read -r ligne; do
    if [[ -n $bloc && ! $ligne =~ ^([[:space:]]|done|fi|else|elif|esac|\}) ]]; then
      printf '%s(exit $__code)\n%s' "$echo" "$bloc"; bloc="" echo="__code=\$?"$'\n'
    fi
    local q=${ligne//\'/\'\\\'\'}
    if [[ -z $bloc ]]; then echo+="builtin printf '%s\\n' '\$ $q'"$'\n'
    else echo+="builtin printf '%s\\n' '$q'"$'\n'; fi
    bloc+="$ligne"$'\n'
  done
  [[ -n $bloc ]] && printf '%s(exit $__code)\n%s' "$echo" "$bloc"
}

# Copie neuve des exemples, puis transcription des commandes lues sur l’entrée standard.
# Le second argument, facultatif, est un préambule que le Bash interactif exécute sans l’afficher.
session() {
  printf '\n######## %s\n' "$1"
  rm -rf "$ATELIER" "$HOME/demo" /tmp/chantier
  mkdir -p "$ATELIER"
  cp -p "$EXEMPLES"/* "$ATELIER"/
  cd "$ATELIER" || exit 1
  { printf "PS1=''; PS2=''\n"; printf '%s\n' "${2:-}"; recopier; } \
    | bash --norc --noediting -i 2>&1 \
    | sed -e '/cannot set terminal process group/d' -e '/no job control in this shell/d' \
          -e 's/^bash-[0-9.]*\$ //' -e '/^exit$/d' \
          -e 's/.*\x1b\[1G//' -e 's/\x1b\[[0-9;]*[A-Za-z]//g'
}

# shellcheck source=/dev/null
echo "# $(date -I) · $(uname -srm) · $(. /etc/os-release && echo "$PRETTY_NAME")"
session "Versions" <<'EOF'
bash --version | head -1
sed --version | head -1
awk -W version 2>&1 | head -1
readlink -f "$(command -v awk)"
shellcheck --version | sed -n 2p
bats --version
EOF

# ---------- Ouverture ----------
session "Le fil rouge : existence, puis contenu" <<'EOF'
ls pionnieres.csv
cat pionnieres.csv
EOF

session "Lire une commande" <<'EOF'
wc -l pionnieres.csv
head -n 3 pionnieres.csv
head --lines=3 pionnieres.csv
ls -l --human-readable pionnieres.csv
type cd
type wc
cat pionnieres.csv
EOF

session "Décoder ls -l" <<'EOF'
mkdir -p ~/demo && cd ~/demo
cp -p ~/atelier/pionnieres.csv ~/atelier/sauvegarde.sh .
mkdir scripts
chgrp etudiants sauvegarde.sh && chmod 750 sauvegarde.sh
ls -l
chmod 640 pionnieres.csv
ls -l pionnieres.csv
EOF

# ---------- Flux, redirections, tubes ----------
session "Deux flux de sortie" <<'EOF'
ls pionnieres.csv absent.txt
ls pionnieres.csv absent.txt > sortie.txt
cat sortie.txt
ls pionnieres.csv absent.txt 2> erreurs.txt
cat erreurs.txt
EOF

session "Fusionner, ajouter, lire" <<'EOF'
ls pionnieres.csv absent.txt > tout.txt 2>&1
cat tout.txt
date -I >> tout.txt
wc -l tout.txt
wc -l < pionnieres.csv
EOF

session "Ajouter, écraser, lire" <<'EOF'
ls pionnieres.csv > sortie.txt
ls sauvegarde.sh >> sortie.txt
cat sortie.txt
ls sauvegarde.sh > sortie.txt
cat sortie.txt
wc -l pionnieres.csv
wc -l < pionnieres.csv
EOF

session "Ordre des redirections" <<'EOF'
ls pionnieres.csv absent.txt > sortie.txt 2>&1
cat sortie.txt
ls pionnieres.csv absent.txt 2>&1 > sortie.txt
cat sortie.txt
EOF

session "> tronque avant l’exécution" <<'EOF'
cp pionnieres.csv copie.csv
wc -c copie.csv
sort copie.csv > copie.csv
wc -c copie.csv
cp pionnieres.csv copie.csv
sort -o copie.csv copie.csv
wc -c copie.csv
cat copie.csv
EOF

session "Tubes" <<'EOF'
cut -d';' -f3 pionnieres.csv
cut -d';' -f3 pionnieres.csv | sort
cut -d';' -f3 pionnieres.csv | sort | uniq -c
cut -d';' -f3 pionnieres.csv | sort | uniq -c | sort -rn
ls -l | grep csv > resultats.txt
cat resultats.txt
EOF

session "Codes de retour, && et ||" <<'EOF'
ls absent.txt
echo $?
grep -q Hopper pionnieres.csv
echo $?
grep -q Hopper pionnieres.csv && echo "trouvée"
grep -q Turing pionnieres.csv
echo $?
grep -q Turing pionnieres.csv || echo "absent du fichier"
grep -q Hopper pionnieres.csv || echo "absent du fichier"
grep -q Turing pionnieres.csv && echo "trouvée"
EOF

session "Exercice pipeline" <<'EOF'
cut -d';' -f3 pionnieres.csv | tail -n +2 | sort -u
cut -d';' -f3 pionnieres.csv | tail -n +2 | sort -u | wc -l
tail -n +2 pionnieres.csv | sort -t';' -k2 -rn | head -n 3
EOF

# ---------- Variables, tests, boucles ----------
session "Variables" <<'EOF'
nom='Ada'
echo "Bonjour $nom"
nom = Ada
echo "$HOME $USER"
echo "$PATH"
EOF

session "Tests" <<'EOF'
bash exemple_tests.bash
type [
[ -f pionnieres.csv ] && echo "fichier ordinaire"
[ -d pionnieres.csv ] || echo "pas un répertoire"
annee=1843
[ "$annee" -lt 1900 ] && echo "XIXe siècle"
[ "$annee" -lt 1900 -a -f pionnieres.csv ] && echo "les deux"
[[ $annee -lt 1900 && -f pionnieres.csv ]] && echo "les deux"
[[ $annee =~ ^[0-9]+$ ]] && echo "un nombre"
[-f pionnieres.csv]
EOF

session "Boucles" <<'EOF'
for fichier in *.csv *.conf; do echo "Fichier : $fichier"; done
mkdir rapports && cd rapports
touch "mon rapport.txt" notes.txt
for f in $(ls *.txt); do echo "[$f]"; done
for f in *.txt; do echo "[$f]"; done
cd ..
compteur=1
while [ "$compteur" -le 3 ]; do
    echo "Itération $compteur"
    compteur=$((compteur + 1))
done
echo {1..5}
echo $((7 * 6)) $((7 / 2)) $((7 % 2))
EOF

session "Exercice boucles" <<'EOF'
for i in {1..5}; do touch "sauvegarde-$i.txt"; done
echo sauvegarde-*
n=5; while [ "$n" -ge 1 ]; do echo "$n"; n=$((n - 1)); done
for f in *.csv *.conf; do echo "$f : $(wc -l < "$f") lignes"; done
EOF

# ---------- Guillemets et expansions ----------
session "Les étapes de l’expansion" <<'EOF'
mkdir labo && cd labo
touch ada.txt grace.txt hedy.txt
nom="Grace     Hopper"
printf '[%s]\n' ~ {1..2} $nom "$nom" *.txt "*.txt" $((6 * 7)) "$(echo ok)"
EOF

session "Découpage en mots et glob" <<'EOF'
mkdir labo && cd labo
hommage="Grace     Hopper"
echo $hommage
echo "$hommage"
touch ada.txt grace.txt hedy.txt
motif="*.txt"
echo $motif
echo "$motif"
EOF

session "Guillemets dans les erreurs classiques" <<'EOF'
dossier="Mon dossier important"
mkdir "$dossier"
cd $dossier
cd "$dossier" && pwd
nom=
[ $nom = "Etudiant" ] && echo "Bonjour, $nom"
[ "$nom" = "Etudiant" ] || echo "test exécuté, réponse : non"
EOF

session "Simples, doubles, ANSI-C" <<'EOF'
p="Ada Lovelace"
echo "$p" '$p' "'$p'" '"$p"'
echo "\$p vaut $p, prix : 100$"
echo 'a\tb' "a\tb"
echo $'a\tb'
echo $'aujourd\'hui'
echo "$(echo *.csv)" '$(echo *.csv)'
EOF

session "Guillemets : quelles expansions ont lieu" <<'EOF'
mkdir labo && cd labo
touch ada.txt grace.txt
p="Ada Lovelace"
printf '[%s]\n' ~ "~" '~'
printf '[%s]\n' {a,b} "{a,b}" '{a,b}'
printf '[%s]\n' $p "$p" '$p'
printf '[%s]\n' $(echo un deux) "$(echo un deux)" '$(echo un deux)'
printf '[%s]\n' $((6*7)) "$((6*7))" '$((6*7))'
printf '[%s]\n' *.txt "*.txt" '*.txt'
EOF

session "Accolades autour du nom" <<'EOF'
fichier="rapport"
ext="txt"
echo "$fichierext"
echo "${fichier}.${ext}"
chemin="/usr/local/bin"
echo "$chemin_backup"
echo "${chemin}_backup"
EOF

session "Exercice expansions" <<'EOF'
mkdir labo && cd labo
touch ada.txt grace.txt hedy.txt
p="Ada Lovelace"
printf '[%s]\n' $p
printf '[%s]\n' "$p"
printf '[%s]\n' '$p'
printf '[%s]\n' *.txt "*.txt"
printf '[%s]\n' "$(echo *.txt)"
printf '[%s]\n' {ada,hedy}.txt
EOF

# ---------- Scripts ----------
session "Un script exécutable" <<'EOF'
chmod -x bonjour.sh
./bonjour.sh
chmod u+x bonjour.sh
./bonjour.sh
echo $?
./retour.sh
echo $?
EOF

session "Arguments" <<'EOF'
./exemple_argument.bash arg1 arg2
./tous_les_arguments.bash "Grace Hopper" Ada
EOF

session "Saisie" <<'EOF'
./exemple_saisie.bash <<< "Ada"
EOF

session "Sauvegarde" <<'EOF'
mkdir donnees && cp pionnieres.csv donnees/
./sauvegarde.sh donnees
ls sauvegarde_*
tar -tzf sauvegarde_*.tar.gz
EOF

# cron : le service tourne en root dans le conteneur ; la session n’a de sens que s’il tourne.
if [ -n "${REJOUER_CRON:-}" ]; then
  session "cron" <<'EOF'
crontab -l
bin=$HOME/bin; mkdir -p "$bin"; cd "$HOME"
printf '%s\n' '#!/bin/sh' 'pwd; echo "SHELL=$SHELL"; echo "PATH=$PATH"; echo "HOME=$HOME"; echo "LOGNAME=$LOGNAME"' > "$bin/env-cron.sh"
chmod +x "$bin/env-cron.sh"
jour_mois=$(( $(date +%-d) % 28 + 1 )); jour_semaine=$(date +%w)
printf '%s\n' \
  "* * * * * $bin/env-cron.sh > $HOME/env-cron.txt 2>&1" \
  "* * * * * ada /bin/echo bonjour > $HOME/piege-login.txt 2>&1" \
  "* * $jour_mois * $jour_semaine /bin/echo ou-logique > $HOME/ou.txt 2>&1" \
  "* * $jour_mois * * /bin/echo jour-seul > $HOME/jour-seul.txt 2>&1" | crontab -
crontab -l | cut -c1-40
sleep $((70 - $(date +%-S)))
cat env-cron.txt piege-login.txt ou.txt
ls jour-seul.txt
EOF
else
  printf '\n######## cron\nNon rejoué : aucun service cron (REJOUER_CRON absent).\n'
fi

session "set -e" <<'EOF'
./nettoyage.sh
echo $?
./nettoyage-e.sh
echo $?
EOF

session "set -u et pipefail" <<'EOF'
./faute-de-frappe.sh
echo $?
false | true
echo $?
set -o pipefail
false | true
echo $?
EOF

session "Les limites de set -e" <<'EOF'
bash -c 'set -e; false && true; echo "toujours là"'
bash -c 'set -e; if false; then :; fi; echo "toujours là"'
bash -c 'set -e; false; echo "jamais affiché"'
echo $?
EOF

session "bash -x" <<'EOF'
bash -x ./exemple_argument.bash "Grace Hopper"
EOF

session "ShellCheck" <<'EOF'
shellcheck a-relire.sh
EOF

session "Fonctions et main" <<'EOF'
./exemple_main_function.bash
EOF

session "source ou ./" <<'EOF'
./bibliotheque.sh
saluer Ada
source bibliotheque.sh
saluer Ada
type saluer
EOF

# Bats n’écrit le format « pretty » (celui d’un terminal, avec ✓) que sur un terminal : on le demande
# par un préambule masqué, et le filtre de session reconstitue l’écran final (retour en colonne 1, effacements).
session "Bats" 'export TERM=xterm; bats() { command bats --formatter pretty "$@"; }' <<'EOF'
bats exemple_test_unit.bats
mkdir donnees && cp pionnieres.csv donnees/
bats liste_fichiers.bats
EOF

session "Exercice scripts" <<'EOF'
mkdir donnees && cp pionnieres.csv services.conf donnees/
./liste_fichiers.bash <<< donnees
echo $?
./liste_fichiers.bash <<< /nulle/part
echo $?
printf '%s\n' donnees copie > reponses.txt
./copie_fichiers.bash < reponses.txt
echo $?
ls copie
EOF

# ---------- Portée de local ----------
session "Portée dynamique" <<'EOF'
./portee-locale.bash
./portee-readonly.bash
EOF

session "Sous-shell et nouveau processus" <<'EOF'
./portee-sous-shell.bash
./export-processus.bash
EOF

session "Exercice local" <<'EOF'
./devinette.bash
sed 's/local total=10/total=10/' devinette.bash > devinette-globale.bash
bash devinette-globale.bash
EOF

# ---------- sed ----------
session "sed : le cycle" <<'EOF'
sed '' lignes.txt
sed -n '2p' lignes.txt
sed 'p' lignes.txt
EOF

session "sed : substitution" <<'EOF'
sed 's/Alan Turing/Ada Lovelace/g' turing.txt
cat turing.txt
echo "Alan Turing et Alan Kay" | sed 's/Alan/Ada/'
echo "Alan Turing et Alan Kay" | sed 's/Alan/Ada/g'
echo "/usr/local/bin" | sed 's/\/usr\/local/\/opt/'
echo "/usr/local/bin" | sed 's,/usr/local,/opt,'
EOF

session "sed : supprimer, insérer, adresser" <<'EOF'
sed '2d' lignes.txt
sed '2i Nouveau texte ajouté avant la ligne 2' lignes.txt
sed '1a Texte ajouté après la ligne 1' lignes.txt
sed '1d' pionnieres.csv | head -n 2
sed '/langages/d' pionnieres.csv
sed -n '2,3p' pionnieres.csv
EOF

session "sed -i" <<'EOF'
sed -i.bak 's/autostart = yes/autostart = no/' services.conf
grep autostart services.conf
echo services.conf*
diff services.conf.bak services.conf
EOF

session "sed : expressions régulières" <<'EOF'
sed -E 's/[0-9]{3}/###/g' identifiants.txt
sed 's/[0-9]\{3\}/###/g' identifiants.txt
sed 's/[0-9]{3}/###/g' identifiants.txt
EOF

session "sed : groupes de capture" <<'EOF'
cat autrices.txt
sed 's/Nom : \(.*\) \(.*\)/Prénom : \2, Nom : \1/g' autrices.txt
sed -E 's/^([^ ;]+) ([^;]+);/\2 \1;/' pionnieres.csv | head -n 3
EOF

session "Exercice sed" <<'EOF'
sed 's/materiel/matériel/; s/reseau/réseau/' pionnieres.csv | tail -n 3
sed '1d' pionnieres.csv | wc -l
cp services.conf services.copie
sed -i 's/^port = 0$/port = disabled/' services.copie
grep -n port services.copie
printf '#PasswordAuthentication yes\n' > sshd_config.copie
cat sshd_config.copie
sed -E 's,^#?(PasswordAuthentication) .*,\1 no,' sshd_config.copie
EOF

# ---------- awk ----------
session "awk : champs" <<'EOF'
cat personnes.txt
awk '{ print $1, $2 }' personnes.txt
awk '{ print NR ": " $0 " (" NF " champs)" }' personnes.txt
awk -F';' 'NR > 1 { print $1, $2 }' pionnieres.csv | head -n 3
EOF

session "awk : nombre ou chaîne" <<'EOF'
awk '$2 < "30" { print $1, $2 }' personnes.txt
echo "Dan 100 M" >> personnes.txt
awk '$2 < "30" { print $1, $2 }' personnes.txt
awk '$2 < 30 { print $1, $2 }' personnes.txt
EOF

session "awk : calculs et END" <<'EOF'
cat produits.txt
awk '{ print $1, $2 * $3 }' produits.txt
awk '{ somme += $2 } END { print "Total : ", somme }' produits.txt
awk '{ somme += $2 } END { print "Total :", somme }' produits.txt
awk -F';' 'BEGIN { print "Avant la première ligne" } END { print NR " lignes lues" }' pionnieres.csv
EOF

session "awk : tableaux associatifs" <<'EOF'
awk -F';' 'NR > 1 { n[$3]++ } END { for (d in n) print d, n[d] }' pionnieres.csv
awk -F';' 'NR > 1 { n[$3]++ } END { for (d in n) print d, n[d] }' pionnieres.csv | sort
EOF

session "awk : expressions régulières" <<'EOF'
awk '$0 ~ /@example.fr/ { print $0 }' emails.txt
awk '$1 ~ /@example\.fr$/ { print $2 }' emails.txt
awk -F';' '$4 ~ /premier/ { print $1 }' pionnieres.csv
EOF

session "Exercice awk" <<'EOF'
awk -F';' 'NR > 1 && $2 < 1970 { print $1, $2 }' pionnieres.csv
awk -F';' 'NR > 1 { somme += $2 } END { print "Total :", somme }' pionnieres.csv
awk -F';' 'NR > 1 { if ($2 > max) { max = $2; nom = $1 } } END { print nom, max }' pionnieres.csv
awk -F';' -v OFS='\t' 'NR > 1 { print $1, $3 }' pionnieres.csv | head -n 3
awk -F';' '$4 ~ /premier/ { n++ } END { print n }' pionnieres.csv
EOF

# ---------- Annexe : mémo des guillemets ----------
session "Mémo" <<'EOF'
mkdir labo && cd labo
touch ada.txt grace.txt hedy.txt
p="Ada Lovelace"
printf '[%s]\n' "${p}" '${p}' "'${p}'" '"${p}"'
printf '[%s]\n' ${p}
printf '[%s]\n' *.txt
printf '[%s]\n' "*.txt" "\${p}" "100$" '\n' "\n"
printf '%s' $'\n\t' | od -c | head -1
printf '[%s]\n' $'\'' "$(echo hi)" '$(echo hi)'
EOF
