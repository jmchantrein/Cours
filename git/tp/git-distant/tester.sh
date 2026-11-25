#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Git à plusieurs, sans forge ».
#
# Il exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé affiche, dans
# l'ordre des étapes, et vérifie après chacun l'état du dépôt nu et des deux
# clones : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up | --releve] [--keep]
#   --lint    (défaut) sans rien exécuter : bash -n et shellcheck des scripts,
#             droits d'exécution, une commande par ligne (pas de suite de ligne
#             par « \ », pas de document en ligne « << »).
#   --up      --lint, puis les neuf scripts, dans un dossier temporaire, et
#             les états attendus après chacun.
#   --releve  rejoue les scripts dans un pseudo-terminal et imprime chaque
#             commande suivie de sa sortie réelle, comme dans un terminal : ce
#             sont les sorties que l'énoncé montre (aucune vérification).
#   --keep    ne supprime pas le dossier temporaire (pour examiner un échec).
#
# Ce que --up vérifie, étape par étape (git status --porcelain, git log
# --format, git rev-parse des branches des trois dépôts, contenu des fichiers) :
#   1  depot-central.git est un dépôt nu, branche main, sans commit ;
#   2  ada : un commit, auteur Ada, main suit origin/main, publié ;
#   3  grace : même main que le dépôt central, identité propre au clone ;
#   4  git status d'Ada ignore le commit de Grace avant git fetch, puis le
#      signale ; git pull par avance rapide ; trois dépôts alignés ;
#   5  branche horaires publiée, suivie par Grace, fusionnée dans main ;
#   6  push refusé, pull refusé sans choix, puis commit de fusion à deux
#      parents, publié ; trois dépôts alignés ;
#   7  conflit sur README.md, résolu sans marqueur, publié ;
#   8  push refusé, puis pull --rebase : aucun commit de fusion de plus, le
#      commit d'Ada a pour parent celui de Grace ; trois dépôts alignés ;
#   9  branches main et presentation publiées sur la « forge » (ici, un
#      second dépôt nu, forge.git, dont le chemin tient lieu d'adresse).
#
# Le harnais ne touche ni à votre configuration Git ni à vos dépôts : HOME
# factice (le dossier temporaire tptest-git-distant.*), /etc/gitconfig ignoré,
# identités factices (celles des corrigés), dates de commit fixées, aucun
# réseau. Il refuse de tourner si ce dossier temporaire se trouve dans un dépôt
# Git, et n'exécute aucune commande git ailleurs que dans ce dossier.
#
# Prérequis : bash, shellcheck ; pour --up, git ≥ 2.28 (git init -b) ; pour
# --releve, en plus script (util-linux).

set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
etapes=(01-depot-nu 02-ada-clone 03-grace-clone 04-fetch-pull 05-branche-poussee 06-divergence 07-conflit
  08-rebasage 09-forge)

mode="lint"; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --releve) mode="releve" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,42p' "$0"; exit 0 ;;
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
  base="${TMPDIR:-/tmp}/tptest-git-distant-releve"
  rm -rf -- "$base"
  preparer "$base"
  printf '# %s\n' "$(git --version)"
  for e in "${etapes[@]}"; do
    printf '\n######## corrige/%s.sh\n' "$e"
    # L'étape 9 publie sur une « forge » : ici, un second dépôt nu.
    if [ "$e" = 09-forge ]; then git init -q --bare -b main "$HOME/forge.git"; fi
    ( cd "$HOME" && rejouer "$corrige/$e.sh" "$HOME/forge.git" ) || true
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
preparer "$(mktemp -d "${TMPDIR:-/tmp}/tptest-git-distant.XXXXXX")"
# shellcheck disable=SC2317 # appelée par trap
en_sortie() {
  if [ -z "$garder" ]; then rm -rf -- "$travail"
  else echo "--keep : dossier conservé, $travail"; fi
}
trap en_sortie EXIT

collab="$HOME/collab"
central="$collab/depot-central.git"
ga() { git -C "$collab/ada" "$@"; }
gg() { git -C "$collab/grace" "$@"; }
gc() { git -C "$central" "$@"; }
journal="$travail/journal"; mkdir -p "$journal"
lancer() { # $1 étape, puis ses arguments : exécute le corrigé depuis HOME ; sa sortie va dans le journal
  titre "Étape ${1%%-*} — corrige/$1.sh"
  local code=0
  ( cd "$HOME" && bash "$corrige/$1.sh" "${@:2}" ) > "$journal/$1.txt" 2>&1 || code=$?
  printf '       (code de sortie %s ; sortie : %s lignes)\n' "$code" "$(wc -l < "$journal/$1.txt")"
}
# grep lit le journal lui-même : grep -q derrière un tube ferait échouer cat, et le tube, sous pipefail.
contient() { # $1 étape  $2 description  $3 motif (grep -E) attendu dans la sortie du corrigé
  if grep -qE -- "$3" "$journal/$1.txt"; then ok "$1 : $2"; else ko "$1 : $2 (« $3 » absent de la sortie)"; fi
}
parents() { "$1" rev-list --parents -n 1 "${2:-HEAD}" | awk '{ print NF - 1 }'; }
propres() { # $1 étape : les deux clones sur main, propres
  egal "$1 : ada sur main, git status --porcelain vide" "$(ga symbolic-ref --short HEAD) [$(ga status --porcelain)]" "main []"
  egal "$1 : grace sur main, git status --porcelain vide" "$(gg symbolic-ref --short HEAD) [$(gg status --porcelain)]" "main []"
}
alignes() { # $1 étape : main identique dans les trois dépôts
  local c; c="$(gc rev-parse main)"
  egal "$1 : main d'ada = main du dépôt central" "$(ga rev-parse main)" "$c"
  egal "$1 : main de grace = main du dépôt central" "$(gg rev-parse main)" "$c"
}
afficher_si_echec() { # $1 étape : la sortie du corrigé, pour comprendre un échec
  if [ "${#echecs[@]}" -gt "$2" ]; then sed 's/^/       │ /' "$journal/$1.txt"; fi
}

e=01-depot-nu; n=${#echecs[@]}; lancer "$e"
egal "$e : dépôt nu" "$(gc rev-parse --is-bare-repository 2>&1)" "true"
egal "$e : sa branche par défaut" "$(gc symbolic-ref HEAD 2>&1)" "refs/heads/main"
egal "$e : aucune branche encore" "$(gc for-each-ref --format='%(refname)' refs/heads)" ""
if [ -d "$central/objects" ] && [ ! -e "$central/.git" ]; then ok "$e : pas de répertoire de travail, les fichiers de Git à la racine"
else ko "$e : depot-central.git n'a pas la forme d'un dépôt nu"; fi
afficher_si_echec "$e" "$n"

e=02-ada-clone; n=${#echecs[@]}; lancer "$e"
contient "$e" "git clone prévient que le dépôt est vide" "cloned an empty repository"
egal "$e : un commit sur le dépôt central" "$(gc rev-list --count main 2>&1)" "1"
egal "$e : son auteur" "$(gc log -1 --format='%an <%ae>' main)" "Ada Lovelace <ada@example.org>"
egal "$e : identité locale au clone, rien dans la configuration globale" \
  "$(ga config --local user.name) / $(git config --global user.name || echo aucune)" "Ada Lovelace / aucune"
egal "$e : main suit origin/main" "$(ga rev-parse --abbrev-ref 'main@{upstream}')" "origin/main"
egal "$e : README.md" "$(cat "$collab/ada/README.md")" "# Site du club"$'\n\n'"Responsable : Ada."
egal "$e : ada, git status --porcelain vide" "$(ga status --porcelain)" ""
afficher_si_echec "$e" "$n"

e=03-grace-clone; n=${#echecs[@]}; lancer "$e"
egal "$e : main de grace = main du dépôt central" "$(gg rev-parse main)" "$(gc rev-parse main)"
egal "$e : identité de grace" "$(gg config --local user.name) <$(gg config --local user.email)>" "Grace Hopper <grace@example.org>"
contient "$e" "git branch -a montre origin/main" "^  remotes/origin/main$"
afficher_si_echec "$e" "$n"

e=04-fetch-pull; n=${#echecs[@]}; lancer "$e"
egal "$e : deux commits sur le dépôt central" "$(gc rev-list --count main)" "2"
egal "$e : le dernier, de Grace" "$(gc log -1 --format=%an main)" "Grace Hopper"
contient "$e" "avant git fetch, git status d'Ada se croit à jour" "^Your branch is up to date with 'origin/main'"
contient "$e" "après git fetch, git status voit le retard" "^Your branch is behind 'origin/main' by 1 commit"
contient "$e" "git pull par avance rapide" "^Fast-forward$"
alignes "$e"; propres "$e"
afficher_si_echec "$e" "$n"

e=05-branche-poussee; n=${#echecs[@]}; lancer "$e"
egal "$e : branches du dépôt central" "$(gc for-each-ref --format='%(refname:short)' refs/heads | paste -sd ' ')" "horaires main"
egal "$e : horaires de grace suit origin/horaires" "$(gg rev-parse --abbrev-ref 'horaires@{upstream}')" "origin/horaires"
contient "$e" "Grace lit le fichier de la branche" "^Ouvert le lundi, de 9 h à 17 h\.$"
egal "$e : horaires fusionnée dans main par avance rapide" "$(gc rev-parse main)" "$(gc rev-parse horaires)"
alignes "$e"; propres "$e"
afficher_si_echec "$e" "$n"

e=06-divergence; n=${#echecs[@]}; avant="$(gc rev-parse main)"; lancer "$e"
contient "$e" "le premier push d'Ada est refusé" '! \[rejected\] +main -> main \(fetch first\)'
contient "$e" "git status voit la divergence" "have diverged"
contient "$e" "git pull sans choix est refusé" "^fatal: Need to specify how to reconcile divergent branches"
egal "$e : commit de fusion sur le dépôt central" "$(parents gc main)" "2"
egal "$e : ses parents" "$(gc log -1 --format=%an main^1) / $(gc log -1 --format=%an main^2)" "Ada Lovelace / Grace Hopper"
if gc merge-base --is-ancestor "$avant" main; then ok "$e : rien de perdu : l'ancien main est un ancêtre"
else ko "$e : l'ancien main n'est plus dans l'historique"; fi
egal "$e : agenda.md et horaires.md dans main" "$(gc show main:agenda.md) / $(gc show main:horaires.md | tail -n 1)" "Réunion le jeudi. / Fermé le dimanche."
alignes "$e"; propres "$e"
afficher_si_echec "$e" "$n"

e=07-conflit; n=${#echecs[@]}; lancer "$e"
contient "$e" "le push d'Ada est refusé" '! \[rejected\] +main -> main \(fetch first\)'
contient "$e" "git pull s'arrête sur un conflit" '^CONFLICT \(content\): Merge conflict in README.md'
contient "$e" "git status --short : UU" "^UU README.md$"
contient "$e" "cat README.md montre les marqueurs" "^<<<<<<< HEAD$"
egal "$e : commit de fusion à deux parents" "$(parents gc main)" "2"
egal "$e : README.md résolu" "$(gc show main:README.md)" "# Site des clubs de lecture et de code"$'\n\n'"Responsable : Ada."$'\n'"Contact : grace@example.org"
alignes "$e"; propres "$e"
afficher_si_echec "$e" "$n"

e=08-rebasage; n=${#echecs[@]}; fusions="$(gc rev-list --merges --count main)"; lancer "$e"
contient "$e" "le premier push d'Ada est refusé" '! \[rejected\] +main -> main \(fetch first\)'
contient "$e" "git pull --rebase rejoue le commit d'Ada" 'Successfully rebased and updated refs/heads/main\.$'
egal "$e : aucun commit de fusion de plus" "$(gc rev-list --merges --count main)" "$fusions"
egal "$e : les deux derniers commits" "$(gc log -2 --format='%an : %s' main)" "Ada Lovelace : Jours fériés"$'\n'"Grace Hopper : Heure des réunions"
egal "$e : un seul parent" "$(parents gc main)" "1"
alignes "$e"; propres "$e"
afficher_si_echec "$e" "$n"

e=09-forge; n=${#echecs[@]}; forge="$travail/forge.git"; git init -q --bare -b main "$forge"; lancer "$e" "$forge"
egal "$e : main publiée sur la forge" "$(git -C "$forge" rev-parse main 2>&1)" "$(gc rev-parse main)"
egal "$e : presentation publiée sur la forge" "$(git -C "$forge" log -1 --format=%s presentation 2>&1)" "Présentation du club"
egal "$e : presentation part de main" "$(git -C "$forge" rev-parse presentation~1 2>&1)" "$(gc rev-parse main)"
egal "$e : presentation suit forge/presentation" "$(ga rev-parse --abbrev-ref 'presentation@{upstream}' 2>&1)" "forge/presentation"
egal "$e : le dépôt central n'a pas reçu presentation" "$(gc for-each-ref --format='%(refname:short)' refs/heads | paste -sd ' ')" "horaires main"
egal "$e : main suit toujours origin/main" "$(ga rev-parse --abbrev-ref 'main@{upstream}' 2>&1)" "origin/main"
egal "$e : ada revenue sur main, propre" "$(ga symbolic-ref --short HEAD) [$(ga status --porcelain)]" "main []"
afficher_si_echec "$e" "$n"

titre "Ensemble"
egal "auteurs des commits" "$(gc log --format='%an <%ae>' main | sort -u | paste -sd ' ')" \
  "Ada Lovelace <ada@example.org> Grace Hopper <grace@example.org>"
egal "dates des commits (fixées par le harnais)" "$(gc log --format=%ad --date=iso-strict main | sort -u)" "2026-11-25T10:00:00+01:00"

bilan
