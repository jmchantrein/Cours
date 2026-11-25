#!/usr/bin/env bash
# Rejoue, dans l'ordre du cours, chaque commande montrée dans git/cm/git.typ, et imprime sa sortie réelle.
# Usage : ./rejouer.sh > sorties-git.txt 2>&1
# Environnement de référence : Debian 13 (Git 2.47.3). Hors d'un Debian 13, le script se relance tout seul dans un
# conteneur debian:13-slim (Docker requis) où il installe git ; sur un Debian 13, il tourne tel quel.
# Prérequis : bash, Git ≥ 2.28 (git init -b), script (util-linux) ; aucun droit particulier.
# Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le README.md du dépôt) : facultatif, absent en CI.
#   TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./rejouer.sh > sorties-git.txt 2>&1
# Tout se passe dans un dossier jetable ($BASE, /tmp/git-cours par défaut), vidé au départ :
# la configuration de l'utilisateur (~/.gitconfig, /etc/gitconfig) n'est pas lue.
# Identité et date sont fixées : les identifiants de commit sont ceux des diapos. Pour les retrouver chez vous,
# exportez les mêmes variables (voir l'annexe « Rejouer le cours à l'identique »).
set -u
# ---- Debian 13 par défaut : sinon, relance dans un conteneur debian:13-slim ----
# shellcheck source=/dev/null
debian13() { ( . /etc/os-release 2>/dev/null && [ "${ID:-}" = debian ] && [ "${VERSION_ID:-}" = 13 ] ); }
if [ -z "${REJOUER_CONTENEUR:-}" ] && ! debian13; then
  ici=$(cd "$(dirname "$0")" && pwd)
  command -v docker > /dev/null || { echo "Docker est nécessaire hors d'un Debian 13." >&2; exit 1; }
  reseau=(); apt_https=""
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY" --volume "$TPTEST_CA:/run/ca-hote.crt:ro"); apt_https="1"
  fi
  # Le cours est monté en lecture seule ; le relevé s'écrit dans /tmp du conteneur.
  exec docker container run --rm --name "rejeu-git-$$" "${reseau[@]}" \
    --env "APT_HTTPS=$apt_https" --volume "$ici:/cm:ro" debian:13-slim bash -euc '
      if [ -n "$APT_HTTPS" ]; then
        sed -i "s|http://deb.debian.org|https://deb.debian.org|g" /etc/apt/sources.list.d/debian.sources
        printf "Acquire::https::Proxy \"%s\";\nAcquire::https::CAInfo \"/run/ca-hote.crt\";\n" "$HTTPS_PROXY" > /etc/apt/apt.conf.d/99mandataire
      fi
      apt-get update -qq > /dev/null
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends git > /dev/null
      useradd --create-home --shell /bin/bash ada
      exec setpriv --reuid=ada --regid=ada --init-groups env -i PATH="$PATH" HOME=/home/ada USER=ada LOGNAME=ada \
        REJOUER_CONTENEUR=1 bash /cm/rejouer.sh'
fi
# Git n'affiche pas la même chose selon que sa sortie est un terminal ou non (décorations de git log,
# progression de push et clone) : le script se relance dans un pseudo-terminal (script, de util-linux) et
# n'imprime que ce qui reste affiché à l'écran.
if [ -z "${REJOUER_TTY:-}" ]; then
  REJOUER_TTY=1 script -qec "$0" /dev/null | sed -e 's/\r$//' -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/.*\r//'
  exit "${PIPESTATUS[0]}"
fi
BASE=${BASE:-/tmp/git-cours}
case "$BASE" in /tmp/*) ;; *) echo "BASE doit être sous /tmp" >&2; exit 1 ;; esac
rm -rf "$BASE"; mkdir -p "$BASE/ada"
export HOME="$BASE/ada" GIT_CONFIG_NOSYSTEM=1 LC_ALL=C GIT_PAGER=cat
# pas de couleurs dans le relevé (elles ne changent pas le texte)
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=never
export GIT_AUTHOR_DATE="2026-11-25T10:00:00+01:00" GIT_COMMITTER_DATE="2026-11-25T10:00:00+01:00"
run() { printf '\n$ %s\n' "$1"; eval "$1" 2>&1; }
titre() { printf '\n\n######## %s\n' "$1"; }
cd "$HOME" || exit 1
echo "# $(date -I) · $(uname -srm) · $BASE"

titre "Se présenter à Git"
run 'git --version'
run 'git config --global user.name "Ada Lovelace"'
run 'git config --global user.email ada@example.org'
run 'git config --global --list'

titre "Premier dépôt"
run 'mkdir mon_projet'
run 'cd mon_projet'
run 'git init -b main'
run 'ls -A'
run 'git status'

titre "Premier commit"
run "echo '<h1>Bienvenue sur mon site</h1>' > index.html"
run 'git status --short'
run 'git add index.html'
run 'git status --short'
run "git commit -m \"Ajout de la page d'accueil\""

titre "Second commit, diff"
run "echo '<p>Ceci est un paragraphe.</p>' >> index.html"
run 'git status --short'
run 'git diff'
run 'git add index.html'
run 'git status --short'
run 'git diff --staged'
run "git commit -m \"Ajout d'un paragraphe\""
run 'git log'
run 'git log --oneline'

titre "Objets"
run 'git cat-file -t HEAD'
run 'git cat-file -p HEAD'
run 'git cat-file -p "HEAD^{tree}"'
run 'git cat-file -p "HEAD:index.html"'
run 'git hash-object index.html'

titre "Pointeurs"
run 'cat .git/HEAD'
run 'cat .git/refs/heads/main'
run 'git rev-parse HEAD~1'

titre "Branche contact, avance rapide"
run 'git switch -c contact'
run 'cat .git/HEAD'
run "echo '<p>Écrire à ada@example.org</p>' > contact.html"
run 'git add contact.html'
run "git commit -m \"Ajout de la page contact\""
run 'git branch'
run 'git log --oneline --graph --all'
run 'git switch main'
run 'git merge contact'
run 'git log --oneline --graph --all'
run 'git branch -d contact'

titre "Commit de fusion"
run 'git switch -c style'
run "echo 'h1 { color: navy; }' > style.css"
run 'git add style.css'
run "git commit -m \"Ajout d'une feuille de style\""
run 'git switch main'
run "echo '<p>Réponse sous 48 h.</p>' >> contact.html"
run 'git commit -am "Délai de réponse"'
run 'git log --oneline --graph --all'
run "git merge style -m \"Fusion de la branche style\""
run 'git log --oneline --graph'
run 'git log --oneline --graph -4'
run 'git cat-file -p HEAD'
run 'git cat-file -p HEAD | grep parent'
run 'git branch -d style'

titre "Conflit"
run 'git switch -c titre'
run "sed -i 's/sur mon site/chez Ada/' index.html"
run 'git commit -am "Titre personnel"'
run 'git switch main'
run "sed -i 's/sur mon site/sur notre site/' index.html"
run 'git commit -am "Titre collectif"'
run 'git merge titre'
run 'git status'
run 'cat index.html'
run "printf '%s\n' '<h1>Bienvenue chez Ada et ses amis</h1>' '<p>Ceci est un paragraphe.</p>' > index.html"
run 'cat index.html'
run 'git add index.html'
run 'git status --short'
run 'git commit --no-edit'
run 'git log --oneline --graph'
run 'git branch -d titre'

titre "Rebasage"
run 'git switch -c faq'
run "echo '<h2>Questions fréquentes</h2>' > faq.html"
run 'git add faq.html'
run 'git commit -m "Ajout de la FAQ"'
run "echo '<p>Rien à signaler.</p>' > faq.html"
run 'git commit -am "Première réponse"'
run 'git switch main'
run "echo '<p>Bureau 101.</p>' >> contact.html"
run 'git commit -am "Adresse du bureau"'
run 'git log --oneline --graph --all'
run 'git log --oneline --graph --all -4'
run 'git switch faq'
run 'git rebase main'
run 'git log --oneline --graph --all -4'
run 'git switch main'
run 'git merge faq'
run 'git branch -d faq'

titre "Dépôt distant : un dépôt nu en local tient lieu de serveur"
run 'cd ~'
run 'git init --bare -b main depot-central.git'
run 'cd mon_projet'
run 'git remote add origin ~/depot-central.git'
run 'git remote -v'
run 'git push -u origin main'
run 'git status'
run 'git log --oneline -3'

titre "Grace clone le dépôt et pousse un commit"
run 'cd ~'
run 'git clone depot-central.git grace'
run 'cd grace'
run 'git config user.name "Grace Hopper"'
run 'git config user.email grace@example.org'
run 'git branch -a'
run "echo 'Site de démonstration du cours Git.' > README"
run 'git add README'
run 'git commit -m "Ajout du README"'
run 'git push'

titre "Ada : push refusé, fetch, pull"
run 'cd ~/mon_projet'
run "echo '<p>Ouvert le lundi.</p>' >> contact.html"
run 'git commit -am "Jour d'"'"'ouverture"'
run 'git push'
run 'git fetch'
run 'git status'
run 'git log --oneline --graph --all -4'
run 'git pull'
run 'git pull --rebase'
run 'git log --oneline --graph -3'
run 'git push'

titre "Grace se met à jour"
run 'cd ~/grace'
run 'git pull'
run 'git log --oneline -3'

titre "Annuler : restore"
run 'cd ~/mon_projet'
run "echo '<p>une erreur' >> index.html"
run 'git status --short'
run 'git restore index.html'
run 'git status --short'
run "echo '<p>une erreur' >> index.html"
run 'git add index.html'
run 'git status --short'
run 'git restore --staged index.html'
run 'git status --short'
run 'git restore index.html'
run 'git status --short'

titre "Annuler : revert"
run "echo '<p>Promotion : -50 % ce jour</p>' >> index.html"
run 'git commit -am "Bandeau de promotion"'
run 'git push'
run 'git revert --no-edit HEAD'
run 'git log --oneline -3'
run 'git show --stat --format=%s HEAD'
run 'git push'

titre "reset : trois modes"
run "echo '<p>Brouillon</p>' >> contact.html"
run 'git commit -am "Brouillon"'
run 'git log --oneline -2'
run 'git reset --soft HEAD~1'
run 'git status --short'
run 'git log --oneline -1'
run 'git commit -m "Brouillon"'
run 'git reset HEAD~1'
run 'git status --short'
run 'git commit -am "Brouillon"'
run 'git reset --hard HEAD~1'
run 'git status --short'
run 'tail -1 contact.html'

titre "reflog"
run 'git reflog -4'
run 'git reset --hard HEAD@{1}'
run 'tail -1 contact.html'
run 'git reset --hard HEAD~1'

titre "Branche poussée pour une demande de fusion"
run 'cd ~/mon_projet'
run 'git switch -c horaires'
run "echo '<p>De 9 h à 17 h.</p>' >> contact.html"
run 'git commit -am "Horaires d'"'"'ouverture"'
run 'git push -u origin horaires'
run 'git switch main'

titre ".gitignore"
run 'touch acces.log'
run 'mkdir -p secrets'
run 'echo "mot-de-passe" > secrets/bdd.txt'
run 'git status --short'
run "printf '%s\n' '# journaux' '*.log' '# jamais de secret dans le dépôt' 'secrets/' > .gitignore"
run 'cat .gitignore'
run 'git status --short'
run 'git check-ignore -v acces.log secrets/bdd.txt'
run 'git add .gitignore'
run 'git commit -m "Fichiers à ignorer"'

titre "Exercice 1 : un dépôt pour un script d'administration"
run 'cd ~'
run 'mkdir admin'
run 'cd admin'
run 'git init -b main'
run "printf '%s\n' '#!/bin/sh' 'tar -cf /tmp/etc.tar /etc' > sauvegarde.sh"
run 'git add sauvegarde.sh'
run 'git status --short'
run 'git commit -m "Script de sauvegarde"'
run "echo 'echo Sauvegarde terminée' >> sauvegarde.sh"
run 'git status --short'
run 'git add sauvegarde.sh'
run 'git commit -m "Message de fin"'
run 'git log --oneline'

titre "Exercice 2 : branche, conflit"
run 'git switch -c compression'
run "sed -i 's|tar -cf /tmp/etc.tar|tar -czf /tmp/etc.tar.gz|' sauvegarde.sh"
run 'git commit -am "Archive compressée"'
run 'git switch main'
run "sed -i 's|/tmp/etc.tar|/srv/etc.tar|' sauvegarde.sh"
run 'git commit -am "Archive dans /srv"'
run 'git log --oneline --graph --all'
run 'git merge compression'
run 'git status --short'
run 'cat sauvegarde.sh'
run "sed -i -e '/^<<<<<<<\|^=======\|^>>>>>>>/d' -e '/tar -cf \/srv/d' -e 's|/tmp/etc.tar.gz|/srv/etc.tar.gz|' sauvegarde.sh"
run 'cat sauvegarde.sh'
run 'git add sauvegarde.sh'
run 'git commit --no-edit'
run 'git log --oneline --graph'
run 'git branch -d compression'

titre "Exercice 3 : annuler"
run "echo 'tar -cf /tmp/home.tar /hoem' >> sauvegarde.sh"
run 'git diff'
run 'git restore sauvegarde.sh'
run 'git status --short'
run "echo 'logger Sauvegarde faite' >> sauvegarde.sh"
run 'git commit -am "Journalisation"'
run 'git revert --no-edit HEAD'
run 'tail -1 sauvegarde.sh'
run 'git log --oneline -3'
run 'git reset --hard HEAD~2'
run 'git log --oneline -2'
run 'git reflog -4'

titre "Annexe : sans -b main ni init.defaultBranch"
run 'cd ~'
run 'git init sans-config'
run 'rm -rf sans-config'
