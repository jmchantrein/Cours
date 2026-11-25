#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Git en local ».
#
# Il exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé affiche, dans
# l'ordre des étapes, et vérifie l'état du dépôt après chacun : un corrigé qui
# ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up | --releve] [--keep]
#   --lint    (défaut) sans rien exécuter : bash -n et shellcheck des scripts,
#             droits d'exécution, une commande par ligne (pas de suite de ligne
#             par « \ », pas de document en ligne « << »).
#   --up      --lint, puis les treize scripts, dans un dossier temporaire, et
#             les états attendus après chacun.
#   --releve  rejoue les scripts dans un pseudo-terminal et imprime chaque
#             commande suivie de sa sortie réelle, comme dans un terminal : ce
#             sont les sorties que l'énoncé montre (aucune vérification).
#   --keep    ne supprime pas le dossier temporaire (pour examiner un échec).
#
# Ce que --up vérifie, étape par étape (git status --porcelain, git log
# --format, contenu des fichiers, branches) :
#   1   identité dans la configuration globale ; dépôt mon_projet, branche
#       main, sans commit ;
#   2-4 nombre de commits et leurs messages ; fichiers suivis ; le commit
#       refusé de l'étape 3 n'a rien enregistré ; répertoire de travail propre ;
#   5   l'historique n'a pas changé ; la dernière ligne de git log --oneline
#       est le premier commit ;
#   6   .gitignore suivi, acces.log et secrets/ ignorés et non suivis ;
#   7   branche contact en avance d'un commit sur main ; contact.html absent
#       du disque sur main ;
#   8   avance rapide (pas de commit de fusion pour contact), puis un commit
#       de fusion à deux parents ; seules restent les branches main ;
#   9   commit de fusion après conflit, sans marqueur, titre résolu ;
#   10a rien n'a changé dans le dépôt ni dans les fichiers ;
#   10b deux commits de plus ; l'arbre du revert est celui d'avant le bandeau ;
#   10c la branche revient au même commit ; trois commits « Brouillon » dans
#       le reflog ; le paragraphe a disparu du fichier ;
#   10d le reset mène au premier commit, puis HEAD@{1} rend tout l'historique.
#
# Le harnais ne touche ni à votre configuration Git ni à vos dépôts : HOME
# factice (le dossier temporaire tptest-git-local.*), /etc/gitconfig ignoré,
# identité factice (celle du corrigé de l'étape 1), dates de commit fixées. Il
# refuse de tourner si ce dossier temporaire se trouve dans un dépôt Git, et
# n'exécute aucune commande git ailleurs que dans ce dossier.
#
# Prérequis : bash, shellcheck ; pour --up, git ≥ 2.28 (git init -b) ; pour
# --releve, en plus script (util-linux).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
etapes=(01-identite-depot 02-premier-commit 03-index 04-diff 05-log 06-gitignore 07-branche 08-fusion
  09-conflit 10a-restore 10b-revert 10c-reset-modes 10d-reset-reflog)

mode="lint"; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --releve) mode="releve" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,46p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian ou Ubuntu qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}

# --------------------------------------------------- environnement de Git isolé

# Un dossier est-il dans un dépôt Git ? Lecture du disque seulement, sans git.
dans_un_depot() {
  local d="$1"
  while :; do
    if [ -e "$d/.git" ] || { [ -f "$d/HEAD" ] && [ -d "$d/objects" ] && [ -d "$d/refs" ]; }; then return 0; fi
    [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}
preparer() { # $1 dossier de travail, vide
  travail="$1"
  if dans_un_depot "$travail"; then
    echo "Le dossier de travail $travail est dans un dépôt Git : le harnais refuse d'y lancer git." >&2
    echo "Donnez-lui un dossier temporaire hors de tout dépôt : TMPDIR=/tmp $0 --$mode" >&2
    rmdir -- "$travail" 2> /dev/null || true
    exit 1
  fi
  mkdir -p "$travail/home"
  # Aucune variable de l'appelant ne doit diriger git vers un autre dépôt ou une autre configuration.
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
    GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_PARAMETERS GIT_NAMESPACE \
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL
  export HOME="$travail/home" XDG_CONFIG_HOME="$travail/home/.config"
  # git ne remonte pas au-dessus du dossier de travail pour chercher un dépôt.
  export GIT_CEILING_DIRECTORIES="$travail"
  export GIT_CONFIG_NOSYSTEM=1 LC_ALL=C GIT_PAGER=cat PAGER=cat GIT_EDITOR=true GIT_TERMINAL_PROMPT=0
  # Pas de couleurs : elles ne changent pas le texte.
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=never
  # Dates fixées : mêmes contenus, mêmes identifiants d'une exécution à l'autre.
  export GIT_AUTHOR_DATE="2026-11-25T10:00:00+01:00" GIT_COMMITTER_DATE="2026-11-25T10:00:00+01:00"
  cd "$HOME"
}

# ------------------------------------------------------------- --releve

# Rejoue un script ligne à ligne : « $ commande », puis sa sortie. Les commentaires
# d'en-tête sont omis, les autres imprimés tels quels, comme dans l'énoncé.
rejouer() { # $1 script, puis ses arguments, que les lignes rejouées lisent dans "$@"
  local fichier="$1" entete=1 ligne
  shift
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    if [ "$entete" = 1 ]; then
      case "$ligne" in '#'*) continue ;; esac
      entete=0
    fi
    case "$ligne" in
      '') continue ;;
      '#'*) printf '%s\n' "$ligne"; continue ;;
    esac
    printf '$ %s\n' "$ligne"
    eval "$ligne" < /dev/null 2>&1
  done < "$fichier"
}
if [ "$mode" = "releve" ]; then
  exiger git git
  exiger script util-linux
  if [ -z "${TPTEST_TTY:-}" ]; then
    # git n'affiche pas la même chose dans un terminal (décorations de git log, colonnes de ls) :
    # le relevé se fait dans un pseudo-terminal, dont on ne garde que ce qui reste affiché.
    TPTEST_TTY=1 script -qec "bash $(printf '%q' "$0") --releve" /dev/null \
      | sed -e 's/\r$//' -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/.*\r//'
    exit "${PIPESTATUS[0]}"
  fi
  # Un chemin fixe, pour des sorties identiques d'un relevé à l'autre.
  base="${TMPDIR:-/tmp}/tptest-git-local-releve"
  rm -rf -- "$base"
  preparer "$base"
  printf '# %s\n' "$(git --version)"
  for e in "${etapes[@]}"; do
    printf '\n######## corrige/%s.sh\n' "$e"
    ( cd "$HOME" && rejouer "$corrige/$e.sh" ) || true
  done
  rm -rf -- "$base"
  exit 0
fi

# ---------------------------------------------------------------- comptes rendus

exiger bash bash
exiger shellcheck shellcheck
reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
# egal description obtenu attendu
egal() {
  if [ "$2" = "$3" ]; then ok "$1"
  else ko "$1 : obtenu « ${2//$'\n'/ ⏎ } », attendu « ${3//$'\n'/ ⏎ } »"; fi
}
bilan() {
  printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec ========\n' "$mode" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then printf '  - %s\n' "${echecs[@]}"; exit 1; fi
  exit 0
}

# ---------------------------------------------------------------------- --lint

titre "Lint : scripts de corrige/ et harnais"
for e in "${etapes[@]}"; do
  [ -f "$corrige/$e.sh" ] || ko "corrige/$e.sh : fichier absent"
done
for script in "$corrige"/*.sh "$0"; do
  nom="${script#"$ici"/}"
  if bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  # Messages de shellcheck en UTF-8 : une locale C le fait échouer sur les accents.
  if LC_ALL=C.UTF-8 shellcheck "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  [ "$script" = "$0" ] && continue
  if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
  # L'énoncé montre ces commandes une par ligne, à copier ou à cliquer dans le terminal de la page.
  if grep -qE '\\$|<<' "$script"; then ko "$nom : une commande s'étend sur plusieurs lignes"
  else ok "$nom : une commande par ligne"; fi
done
[ "$mode" = "lint" ] && bilan

# ------------------------------------------------------------------------ --up

exiger git git
version="$(git --version | awk '{ print $3 }')"
if ! printf '%s\n' 2.28 "$version" | sort -V -c 2> /dev/null; then
  echo "git $version : il faut git ≥ 2.28, pour git init -b." >&2; exit 1
fi
preparer "$(mktemp -d "${TMPDIR:-/tmp}/tptest-git-local.XXXXXX")"
# shellcheck disable=SC2317,SC2329 # appelée par trap
en_sortie() {
  if [ -z "$garder" ]; then rm -rf -- "$travail"
  else echo "--keep : dossier conservé, $travail"; fi
}
trap en_sortie EXIT

depot="$HOME/mon_projet"
g() { git -C "$depot" "$@"; }
journal="$travail/journal"; mkdir -p "$journal"
lancer() { # $1 étape : exécute le corrigé depuis HOME ; sa sortie va dans le journal
  titre "Étape ${1%%-*} — corrige/$1.sh"
  local code=0
  ( cd "$HOME" && bash "$corrige/$1.sh" ) > "$journal/$1.txt" 2>&1 || code=$?
  printf '       (code de sortie %s ; sortie : %s lignes)\n' "$code" "$(wc -l < "$journal/$1.txt")"
}
# (grep lit le journal directement : grep -q derrière un tube ferait échouer cat, et le tube, sous pipefail.)
sortie() { cat "$journal/$1.txt"; }
nb_commits() { g rev-list --count HEAD 2> /dev/null || echo 0; }
sujets() { g log --format=%s; }
propre() { egal "$1 : git status --porcelain est vide" "$(g status --porcelain)" ""; }
branches() { g branch --format='%(refname:short)' | sort | paste -sd ' '; }
parents() { g rev-list --parents -n 1 "${1:-HEAD}" | awk '{ print NF - 1 }'; }
afficher_si_echec() { # $1 étape : la sortie du corrigé, pour comprendre un échec
  local avant="$2"
  if [ "${#echecs[@]}" -gt "$avant" ]; then sed 's/^/       │ /' "$journal/$1.txt"; fi
}

e=01-identite-depot; n=${#echecs[@]}; lancer "$e"
egal "$e : user.name global" "$(git config --global user.name)" "Ada Lovelace"
egal "$e : user.email global" "$(git config --global user.email)" "ada@example.org"
if [ -d "$depot/.git" ]; then ok "$e : ~/mon_projet/.git existe"; else ko "$e : ~/mon_projet/.git est absent"; fi
egal "$e : branche courante" "$(g symbolic-ref HEAD 2>&1)" "refs/heads/main"
egal "$e : aucun commit" "$(nb_commits)" "0"
afficher_si_echec "$e" "$n"

e=02-premier-commit; n=${#echecs[@]}; lancer "$e"
egal "$e : un commit" "$(nb_commits)" "1"
egal "$e : son message" "$(sujets)" "Ajout de la page d'accueil"
egal "$e : son auteur" "$(g log -1 --format='%an <%ae>')" "Ada Lovelace <ada@example.org>"
egal "$e : fichiers suivis" "$(g ls-files)" "index.html"
egal "$e : index.html" "$(cat "$depot/index.html")" "<h1>Bienvenue sur mon site</h1>"
egal "$e : premier git status --short" "$(sortie "$e" | sed -n 1p)" "?? index.html"
egal "$e : second git status --short" "$(sortie "$e" | sed -n 2p)" "A  index.html"
propre "$e"
afficher_si_echec "$e" "$n"

e=03-index; n=${#echecs[@]}; lancer "$e"
egal "$e : deux commits (le commit sans git add n'a rien enregistré)" "$(nb_commits)" "2"
egal "$e : messages" "$(sujets)" "Ajout d'un paragraphe"$'\n'"Ajout de la page d'accueil"
egal "$e : git status --short avant git add" "$(sortie "$e" | sed -n 1p)" " M index.html"
if grep -q '^no changes added to commit' "$journal/$e.txt"; then ok "$e : git commit sans git add est refusé"
else ko "$e : git commit sans git add n'a pas été refusé"; fi
egal "$e : git status --short après git add" "$(sortie "$e" | grep -x 'M  index.html')" "M  index.html"
egal "$e : index.html" "$(g show HEAD:index.html)" "<h1>Bienvenue sur mon site</h1>"$'\n'"<p>Ceci est un paragraphe.</p>"
propre "$e"
afficher_si_echec "$e" "$n"

e=04-diff; n=${#echecs[@]}; lancer "$e"
egal "$e : trois commits" "$(nb_commits)" "3"
egal "$e : dernier message" "$(g log -1 --format=%s)" "Lien vers la page contact"
egal "$e : git diff puis git diff --staged montrent la ligne ajoutée" \
  "$(sortie "$e" | grep -c '^+<p><a href="contact.html">Contact</a></p>$')" "2"
egal "$e : le commit ne touche que index.html" "$(g diff --name-only HEAD~1 HEAD)" "index.html"
propre "$e"
afficher_si_echec "$e" "$n"

e=05-log; n=${#echecs[@]}; avant="$(g rev-parse HEAD)"; lancer "$e"
egal "$e : l'historique n'a pas changé" "$(g rev-parse HEAD)" "$avant"
premier="$(g rev-list --max-parents=0 HEAD)"
egal "$e : dernière ligne de git log --oneline = premier commit" \
  "$(sortie "$e" | grep -E '^[0-9a-f]{7} Ajout de la page' | tail -n 1)" "$(g log -1 --format='%h %s' "$premier")"
egal "$e : git log --oneline | wc -l" "$(sortie "$e" | tail -n 1 | tr -d ' ')" "3"
afficher_si_echec "$e" "$n"

e=06-gitignore; n=${#echecs[@]}; lancer "$e"
egal "$e : quatre commits" "$(nb_commits)" "4"
egal "$e : fichiers suivis" "$(g ls-files | paste -sd ' ')" ".gitignore index.html"
if g check-ignore -q acces.log && g check-ignore -q secrets/bdd.txt; then ok "$e : acces.log et secrets/bdd.txt ignorés"
else ko "$e : acces.log ou secrets/bdd.txt n'est pas ignoré"; fi
if [ -f "$depot/acces.log" ] && [ -f "$depot/secrets/bdd.txt" ]; then ok "$e : les fichiers ignorés restent sur le disque"
else ko "$e : un fichier ignoré a disparu du disque"; fi
egal "$e : git status --short après .gitignore" "$(sortie "$e" | grep -x '?? .*' | paste -sd ' ')" "?? acces.log ?? secrets/ ?? .gitignore"
propre "$e"
afficher_si_echec "$e" "$n"

e=07-branche; n=${#echecs[@]}; avant="$(g rev-parse HEAD)"; lancer "$e"
egal "$e : branches" "$(branches)" "contact main"
egal "$e : branche courante" "$(g symbolic-ref --short HEAD)" "main"
egal "$e : main n'a pas bougé" "$(g rev-parse main)" "$avant"
egal "$e : contact a un commit de plus que main" "$(g rev-parse contact~1)" "$avant"
egal "$e : contact.html dans le commit de contact" "$(g show contact:contact.html)" "<p>Écrire à ada@example.org</p>"
if [ -e "$depot/contact.html" ]; then ko "$e : contact.html est encore sur le disque, sur main"
else ok "$e : sur main, contact.html n'est plus sur le disque"; fi
propre "$e"
afficher_si_echec "$e" "$n"

e=08-fusion; n=${#echecs[@]}; lancer "$e"
egal "$e : branches" "$(branches)" "main"
if grep -qx 'Fast-forward' "$journal/$e.txt"; then ok "$e : git merge contact par avance rapide"
else ko "$e : git merge contact n'a pas fait d'avance rapide"; fi
egal "$e : commits de fusion" "$(g log --merges --format=%s)" "Fusion de la branche style"
egal "$e : le commit de fusion a deux parents" "$(parents HEAD)" "2"
egal "$e : premier parent" "$(g log -1 --format=%s HEAD^1)" "Délai de réponse"
egal "$e : second parent" "$(g log -1 --format=%s HEAD^2)" "Ajout d'une feuille de style"
egal "$e : style.css" "$(cat "$depot/style.css")" "h1 { color: navy; }"
egal "$e : contact.html" "$(cat "$depot/contact.html")" "<p>Écrire à ada@example.org</p>"$'\n'"<p>Réponse sous 48 h.</p>"
propre "$e"
afficher_si_echec "$e" "$n"

e=09-conflit; n=${#echecs[@]}; lancer "$e"
if grep -q '^CONFLICT (content): Merge conflict in index.html' "$journal/$e.txt"; then ok "$e : git merge titre signale le conflit"
else ko "$e : git merge titre n'a pas signalé de conflit"; fi
if grep -qx '<<<<<<< HEAD' "$journal/$e.txt"; then ok "$e : cat index.html montre les marqueurs"
else ko "$e : cat index.html ne montre pas les marqueurs de conflit"; fi
egal "$e : branches" "$(branches)" "main"
egal "$e : dernier commit" "$(g log -1 --format=%s)" "Merge branch 'titre'"
egal "$e : deux parents" "$(parents HEAD)" "2"
egal "$e : parents (messages)" "$(g log -1 --format=%s HEAD^1) / $(g log -1 --format=%s HEAD^2)" "Titre collectif / Titre personnel"
egal "$e : titre résolu" "$(head -n 1 "$depot/index.html")" "<h1>Bienvenue chez Ada et ses amis</h1>"
if grep -qE '^(<<<<<<<|=======|>>>>>>>)' "$depot/index.html"; then ko "$e : il reste un marqueur de conflit"
else ok "$e : aucun marqueur de conflit"; fi
egal "$e : index.html, trois lignes" "$(wc -l < "$depot/index.html" | tr -d ' ')" "3"
propre "$e"
afficher_si_echec "$e" "$n"

e=10a-restore; n=${#echecs[@]}; avant="$(g rev-parse HEAD)"; contenu="$(cat "$depot/index.html")"; lancer "$e"
egal "$e : aucun commit de plus" "$(g rev-parse HEAD)" "$avant"
egal "$e : index.html revenu à sa version enregistrée" "$(cat "$depot/index.html")" "$contenu"
egal "$e : git status --short, dans l'ordre" "$(sortie "$e" | grep -E '^( M|M ) index.html$' | sed 's/ /_/g' | paste -sd ' ')" \
  "_M_index.html M__index.html _M_index.html"
propre "$e"
afficher_si_echec "$e" "$n"

e=10b-revert; n=${#echecs[@]}; avant="$(g rev-parse HEAD)"; lancer "$e"
egal "$e : deux commits de plus" "$(g rev-parse HEAD~2)" "$avant"
egal "$e : messages" "$(g log -2 --format=%s)" "Revert \"Bandeau de promotion\""$'\n'"Bandeau de promotion"
egal "$e : l'arbre du revert est celui d'avant le bandeau" "$(g rev-parse 'HEAD^{tree}')" "$(g rev-parse "$avant^{tree}")"
if grep -q Promotion "$depot/index.html"; then ko "$e : le bandeau est encore dans index.html"
else ok "$e : le bandeau a disparu de index.html"; fi
if g show HEAD~1:index.html | grep -q Promotion; then ok "$e : le commit du bandeau reste dans l'historique"
else ko "$e : le commit du bandeau ne contient pas le bandeau"; fi
propre "$e"
afficher_si_echec "$e" "$n"

e=10c-reset-modes; n=${#echecs[@]}; avant="$(g rev-parse HEAD)"; lancer "$e"
egal "$e : la branche revient au même commit" "$(g rev-parse HEAD)" "$avant"
egal "$e : trois commits « Brouillon » dans le reflog" "$(g reflog --format=%gs | grep -cx 'commit: Brouillon')" "3"
egal "$e : trois reset dans le reflog" "$(g reflog --format=%gs | grep -cx 'reset: moving to HEAD~1')" "3"
egal "$e : git status --short après --soft puis --mixed" "$(sortie "$e" | grep -E '^( M|M ) contact.html$' | sed 's/ /_/g' | paste -sd ' ')" \
  "M__contact.html _M_contact.html"
egal "$e : tail -n 1 contact.html après --hard" "$(sortie "$e" | tail -n 1)" "<p>Réponse sous 48 h.</p>"
propre "$e"
afficher_si_echec "$e" "$n"

e=10d-reset-reflog; n=${#echecs[@]}; avant="$(g rev-parse HEAD)"; total="$(nb_commits)"; lancer "$e"
if grep -qxF "HEAD is now at $(g log -1 --format='%h %s' "$premier")" "$journal/$e.txt"; then
  ok "$e : git reset --hard mène au premier commit"
else
  ko "$e : git reset --hard n'a pas mené au premier commit"
fi
if grep -qx '?? acces.log' "$journal/$e.txt"; then ok "$e : sur le premier commit, sans .gitignore, acces.log redevient visible"
else ko "$e : git status --short ne montre pas acces.log sur le premier commit"; fi
egal "$e : HEAD@{1} rend la position d'avant" "$(g rev-parse HEAD)" "$avant"
egal "$e : tout l'historique est revenu" "$(nb_commits)" "$total"
egal "$e : git log --oneline | wc -l, avant puis après" "$(sortie "$e" | grep -xE ' *[0-9]+' | tr -d ' ' | paste -sd ' ')" "$total $total"
propre "$e"
afficher_si_echec "$e" "$n"

titre "Ensemble du dépôt"
egal "auteurs des commits" "$(g log --format='%an <%ae>' | sort -u)" "Ada Lovelace <ada@example.org>"
egal "dates des commits (fixées par le harnais)" "$(g log --format=%ad --date=iso-strict | sort -u)" "2026-11-25T10:00:00+01:00"
egal "nombre de commits à la fin" "$(nb_commits)" "13"

bilan
