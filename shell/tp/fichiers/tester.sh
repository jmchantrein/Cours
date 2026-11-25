#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Droits, liens, recherche et archives ».
#
# Il exécute preparer.sh, puis les scripts de corrige/, ceux-là mêmes que
# l'énoncé affiche, dans un conteneur neuf, sous un compte ordinaire (ada,
# membre du groupe etudiants) : un corrigé qui ne fonctionne plus fait échouer
# le harnais.
#
# Usage : ./tester.sh [--lint | --up | --alpine] [--regenerer] [--keep]
#   --lint       (défaut) sans rien lancer : bash -n et shellcheck des scripts,
#                droits d'exécution, fichiers de départ identiques à ceux du
#                cours (shell/cm/exemples/), chaque corrigé affiché par l'énoncé.
#   --up         --lint, puis dans un conteneur debian:13-slim neuf : le compte
#                ada ouvre une session (umask de Debian : 0002), lance
#                preparer.sh, puis chaque corrigé dans un terminal (script(1),
#                80 colonnes, locale C.UTF-8). Le harnais compare la sortie de
#                chaque corrigé à corrige/etape-N.sortie, que l'énoncé affiche
#                (dates, heures et numéros d'inode neutralisés), et vérifie
#                l'état obtenu.
#   --alpine     les mêmes corrigés et les mêmes vérifications d'état dans une
#                image Alpine 3.22 qui a les paquets de la VM du navigateur
#                (commun/terminal/construire-vm.sh) ; les écarts de sortie avec
#                Debian sont affichés, sans compter comme échecs. Construire
#                l'image demande le réseau (dépôts Alpine).
#   --regenerer  avec --up : réécrit corrige/etape-N.sortie à partir de ce
#                passage (après une modification voulue d'un corrigé).
#   --keep       garde le conteneur (tptest-shell-fichiers) pour examen.
#
# Ce que --up vérifie, en plus des sorties : les droits de départ, et qu'un
# second lancement de preparer.sh est refusé ; puis, étape par étape, les
# droits obtenus (2, 3, 4, 8), le umask appliqué (5), le groupe changé et la
# copie qui appartient à ada (6), le même inode pour les deux noms et la cible
# du lien symbolique (7), le contenu des archives, l'extraction identique à
# l'original et la restauration du dossier supprimé (9).
#
# Le harnais ne crée et ne supprime que le conteneur tptest-shell-fichiers et,
# avec --alpine, l'image tptest-shell-fichiers-alpine. Prérequis : bash, shellcheck ;
# pour --up et --alpine, Docker (l'image debian:13-slim, ou le réseau pour la
# télécharger). Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le
# README.md du dépôt) fait passer apk par lui pour --alpine.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
etapes=(1 2 3 4 5 6 7 8 9)
conteneur="tptest-shell-fichiers"
image_alpine="tptest-shell-fichiers-alpine"

# ------------------------------------------------- dans le conteneur : rejouer
# source tester.sh --rejouer <script>, dans un Bash interactif : affiche chaque commande précédée de « $ », puis
# l'exécute, comme dans un terminal. Les lignes de commentaire sont recopiées ;
# l'en-tête du script (jusqu'à la première ligne vide) est sauté.
if [ "${1:-}" = "--rejouer" ]; then
  # Comme dans un terminal : une commande qui échoue n'arrête pas la suite.
  set +euo pipefail
  export LANG=C.UTF-8 LC_ALL=C.UTF-8
  stty cols 80 2> /dev/null || true
  __entete=1
  while IFS= read -r __ligne <&3; do
    if [ "$__entete" = 1 ]; then [ -n "$__ligne" ] || __entete=0; continue; fi
    case $__ligne in
      '') continue ;;
      '#'*) printf '%s\n' "$__ligne"; continue ;;
    esac
    printf '$ %s\n' "$__ligne"
    eval "$__ligne" 2>&1
  done 3< "$2"
  exit 0
fi

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
bilan() { # $1 mode
  printf '\n======== Bilan (%s) : %s vérifications réussies, %s en échec ========\n' "$1" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then printf '  - %s\n' "${echecs[@]}"; exit 1; fi
  exit 0
}

# Les dates de ls -l (« Sep  1 08:00 », « Nov 25  2026 »), la date du nom de
# la sauvegarde et les numéros d'inode de ls -li changent d'un passage à
# l'autre : on les neutralise avant de comparer. Les fins de ligne du terminal
# (\r) et les tabulations de ls disparaissent.
normaliser() {
  tr -d '\r' | expand -t 8 \
    | sed -E -e 's/[A-Z][a-z]{2} [ 1-3][0-9] ( [0-9]{4}|[0-9]{2}:[0-9]{2})/<date>/g' \
      -e 's/sauvegarde_[0-9]{8}/sauvegarde_<date>/g' -e 's/^ *[0-9]+ ([-dl][-rwxst]{9} )/<inode> \1/'
}

# ------------------------------------------- dans le conteneur : les vérifications
# --dedans <debian|alpine> [--regenerer] : lancé en root dans le conteneur, le
# TP monté en lecture seule sur /tp (et /sortie inscriptible pour --regenerer).
if [ "${1:-}" = "--dedans" ]; then
  systeme="$2"; regenerer="${3:-}"
  d=/home/ada/fichiers
  if [ "$systeme" = "alpine" ]; then
    adduser -D -s /bin/bash ada > /dev/null
    # adduser de BusyBox pose le bit setgid sur le dossier personnel (drwxr-sr-x),
    # que ses sous-dossiers hériteraient (chmod 700 le garderait) : on lui donne
    # les droits de Debian 13.
    chmod u=rwx,go=,g-s /home/ada
    addgroup etudiants > /dev/null
    addgroup ada etudiants > /dev/null
  else
    useradd -m -s /bin/bash ada
    groupadd etudiants
    usermod -aG etudiants ada
  fi
  # La commande, dans une session de connexion d'ada, et dans un terminal.
  en_ada() { su - ada -c "script -qec '$1' /dev/null"; }
  mode_de() { stat -c '%a' "$d/$1"; }
  verifier_mode() { # $1 étape  $2 chemin  $3 mode octal attendu
    local m; m="$(mode_de "$2" 2> /dev/null || echo absent)"
    if [ "$m" = "$3" ]; then ok "étape $1 : $2 a le mode $3"; else ko "étape $1 : $2 a le mode $m, $3 attendu"; fi
  }

  titre "preparer.sh ($systeme)"
  if en_ada "bash /tp/preparer.sh" > /tmp/preparer.log 2>&1; then ok "preparer.sh crée ~/fichiers"
  else ko "preparer.sh"; cat /tmp/preparer.log; fi
  arbre() { (cd "$d" && find . -printf '%M %u %g %p\n' | LC_ALL=C sort); }
  arbre > /tmp/arbre-depart
  attendu_depart="drwxr-xr-x ada ada .
drwxr-xr-x ada ada ./coffre
-rw-r--r-- ada ada ./coffre/secret.txt
drwxr-xr-x ada ada ./documents
drwxr-xr-x ada ada ./documents/brouillons
-rw-r--r-- ada ada ./documents/brouillons/vide.txt
drwxr-xr-x ada ada ./documents/notes
-rw-r--r-- ada ada ./documents/notes/reunion-2026-11-18.txt
-rw-r--r-- ada ada ./documents/notes/reunion-2026-11-25.txt
-rw-r--r-- ada ada ./documents/rapport.txt
drwxr-xr-x ada ada ./journaux
-rw-r--r-- ada ada ./journaux/serveur.log
-rw-r--r-- ada ada ./pionnieres.csv
drwxr-xr-x ada ada ./scripts
-rw-r--r-- ada ada ./scripts/bonjour.sh
-rw-r--r-- ada ada ./scripts/sauvegarde.sh"
  if [ "$(cat /tmp/arbre-depart)" = "$(LC_ALL=C sort <<< "$attendu_depart")" ]; then ok "arborescence et droits de départ"
  else ko "arborescence de départ inattendue"; diff <(LC_ALL=C sort <<< "$attendu_depart") /tmp/arbre-depart || true; fi
  if [ "$(wc -l < "$d/journaux/serveur.log")" -eq 1500 ]; then ok "le journal a 1500 lignes"
  else ko "le journal n'a pas 1500 lignes"; fi
  if ! en_ada "bash /tp/preparer.sh" > /tmp/preparer-2.log 2>&1 && grep -q 'existe déjà' /tmp/preparer-2.log \
    && [ "$(arbre)" = "$(cat /tmp/arbre-depart)" ]; then
    ok "un second lancement de preparer.sh est refusé, sans rien modifier"
  else ko "un second lancement de preparer.sh n'est pas refusé proprement"; cat /tmp/preparer-2.log; fi
  umask_ada="$(su - ada -c umask)"

  for n in "${etapes[@]}"; do
    titre "Étape $n : corrige/etape-$n.sh ($systeme)"
    avant="$(arbre)"
    if [ "$n" = 9 ]; then (cd "$d" && find documents -printf '%M %p\n' | LC_ALL=C sort) > /tmp/documents-avant; fi
    # Un Bash interactif, comme au terminal : ses messages d'erreur commencent par « bash: ».
    if en_ada "bash --norc --noprofile -i -c \"source /tp/tester.sh --rejouer /tp/corrige/etape-$n.sh\"" \
      > "/tmp/etape-$n.brut" 2>&1; then
      ok "etape-$n.sh s'exécute"
    else ko "etape-$n.sh"; fi
    tr -d '\r' < "/tmp/etape-$n.brut" | expand -t 8 > "/tmp/etape-$n.sortie"
    if [ -n "$regenerer" ]; then cp "/tmp/etape-$n.sortie" "/sortie/etape-$n.sortie"; fi
    if [ "$(normaliser < "/tp/corrige/etape-$n.sortie")" = "$(normaliser < "/tmp/etape-$n.sortie")" ]; then
      ok "sortie identique à corrige/etape-$n.sortie"
    elif [ "$systeme" = "alpine" ]; then
      echo "ÉCART  sortie différente de Debian (information, pas un échec) :"
      diff <(normaliser < "/tp/corrige/etape-$n.sortie") <(normaliser < "/tmp/etape-$n.sortie") | sed 's/^/       /' || true
    else
      ko "sortie différente de corrige/etape-$n.sortie"
      diff <(normaliser < "/tp/corrige/etape-$n.sortie") <(normaliser < "/tmp/etape-$n.sortie") | sed 's/^/       /' || true
    fi
    case $n in
      1)
        if [ "$avant" = "$(arbre)" ]; then ok "étape 1 : le dossier n'a pas changé"
        else ko "étape 1 : le dossier a changé"; fi
        ;;
      2)
        verifier_mode 2 scripts/bonjour.sh 744
        verifier_mode 2 documents/rapport.txt 660
        verifier_mode 2 journaux/serveur.log 644
        if [ "$(wc -l < "$d/journaux/serveur.log")" -eq 1500 ]; then ok "étape 2 : l'écriture dans le journal en lecture seule a été refusée"
        else ko "étape 2 : le journal en lecture seule a été modifié"; fi
        ;;
      3)
        verifier_mode 3 pionnieres.csv 640
        verifier_mode 3 scripts/sauvegarde.sh 750
        verifier_mode 3 documents/notes 700
        ;;
      4)
        verifier_mode 4 coffre 755
        if [ ! -e "$d/coffre/nouveau.txt" ] && [ "$(wc -l < "$d/coffre/secret.txt")" -eq 2 ]; then
          ok "étape 4 : sans w sur coffre, ni création ni suppression ; secret.txt modifié quand même"
        else ko "étape 4 : contenu de coffre inattendu"; ls -l "$d/coffre"; fi
        # Ce que l'énoncé dit de l'alias « ls --color=auto » : sous Debian, dans un terminal (TERM réglé) avec le
        # .bashrc par défaut, ls d'un dossier sans x ajoute une erreur ; la VM Alpine n'a pas l'alias.
        chmod u=rw "$d/coffre"
        alias_ls="$(su - ada -c "TERM=xterm script -qec 'bash -i -c \"ls fichiers/coffre\"' /dev/null" 2>&1 | tr -d '\r' || true)"
        chmod 755 "$d/coffre"
        if [ "$systeme" = "debian" ]; then
          if [ "$alias_ls" = "ls: cannot access 'fichiers/coffre/secret.txt': Permission denied
secret.txt" ]; then ok "étape 4 : sous Debian, ls (alias --color=auto) ajoute l'erreur « cannot access » avant secret.txt"
          else ko "étape 4 : ls sans x sous Debian : $alias_ls"; fi
        elif [ "$alias_ls" = "secret.txt" ]; then ok "étape 4 : sans l'alias, ls n'affiche que secret.txt"
        else ko "étape 4 : ls sans x sans alias : $alias_ls"; fi
        ;;
      5)
        attendu_fichier="$(printf '%o' $((8#666 & ~8#$umask_ada)))"
        attendu_dossier="$(printf '%o' $((8#777 & ~8#$umask_ada)))"
        verifier_mode "5 (umask $umask_ada)" public.txt "$attendu_fichier"
        verifier_mode "5 (umask $umask_ada)" public "$attendu_dossier"
        verifier_mode "5 (umask 077)" prive.txt 600
        verifier_mode "5 (umask 077)" prive 700
        ;;
      6)
        if [ "$(stat -c '%U %G' "$d/pionnieres.csv")" = "ada etudiants" ]; then ok "étape 6 : pionnieres.csv appartient à ada, groupe etudiants"
        else ko "étape 6 : pionnieres.csv : $(stat -c '%U %G' "$d/pionnieres.csv")"; fi
        if [ "$(stat -c '%U' "$d/copie-passwd")" = "ada" ] && cmp -s /etc/passwd "$d/copie-passwd"; then
          ok "étape 6 : la copie de /etc/passwd appartient à ada"
        else ko "étape 6 : copie-passwd inattendue"; fi
        ;;
      7)
        if [ "$d/rapport-dur.txt" -ef "$d/documents/rapport-2026.txt" ] && [ "$(stat -c '%h' "$d/rapport-dur.txt")" = 2 ]; then
          ok "étape 7 : rapport-dur.txt et documents/rapport-2026.txt sont le même inode, compté deux fois"
        else ko "étape 7 : rapport-dur.txt n'est pas un lien physique de documents/rapport-2026.txt"; fi
        if [ -L "$d/rapport-lien.txt" ] && [ "$(readlink "$d/rapport-lien.txt")" = "documents/rapport-2026.txt" ] \
          && [ -f "$d/rapport-lien.txt" ]; then
          ok "étape 7 : rapport-lien.txt est un lien symbolique réparé vers documents/rapport-2026.txt"
        else ko "étape 7 : rapport-lien.txt inattendu"; fi
        if [ -e "$d/documents-dur" ]; then ko "étape 7 : documents-dur existe"; else ok "étape 7 : pas de lien physique vers un répertoire"; fi
        if [ "$(tail -n 1 "$d/rapport-dur.txt")" = "Ajouté par le lien physique." ]; then ok "étape 7 : l'ajout par un nom se lit par l'autre"
        else ko "étape 7 : rapport-dur.txt sans l'ajout"; fi
        ;;
      8)
        verifier_mode 8 scripts/bonjour.sh 744
        verifier_mode 8 scripts/sauvegarde.sh 750
        ;;
      9)
        if [ "$(tar -tzf "$d/journaux.tar.gz" | LC_ALL=C sort | tr '\n' ' ')" = "journaux/ journaux/serveur.log " ] \
          && [ "$(tar -tf "$d/journaux.tar" | LC_ALL=C sort | tr '\n' ' ')" = "journaux/ journaux/serveur.log " ]; then
          ok "étape 9 : journaux.tar et journaux.tar.gz contiennent journaux/ et journaux/serveur.log"
        else ko "étape 9 : contenu des archives des journaux inattendu"; fi
        if [ "$(stat -c '%s' "$d/journaux.tar.gz")" -lt $(($(stat -c '%s' "$d/journaux.tar") / 4)) ]; then
          ok "étape 9 : l'archive compressée fait moins du quart de l'archive"
        else ko "étape 9 : la compression gagne moins que prévu"; fi
        if cmp -s "$d/journaux/serveur.log" "$d/restauration/journaux/serveur.log"; then ok "étape 9 : l'extraction est identique à l'original"
        else ko "étape 9 : extraction différente de l'original"; fi
        if [ -f "$d/journaux/serveur.log" ] && gzip -dc "$d/journaux/serveur.log.gz" | cmp -s - "$d/journaux/serveur.log"; then
          ok "étape 9 : gzip -k garde l'original, serveur.log.gz le restitue"
        else ko "étape 9 : serveur.log.gz inattendu"; fi
        sauvegarde="$d/sauvegarde_$(date +%Y%m%d).tar.gz"
        if [ -f "$sauvegarde" ]; then ok "étape 9 : sauvegarde.sh a créé ${sauvegarde#"$d"/}"
        else ko "étape 9 : pas de sauvegarde du jour"; ls "$d"; fi
        # tar extrait sous le umask d'ada (sans -p) : on compare les noms, puis le mode de notes (700).
        if [ "$( (cd "$d" && find documents | LC_ALL=C sort) )" = "$(cut -d' ' -f2 /tmp/documents-avant | LC_ALL=C sort)" ]; then
          ok "étape 9 : documents restauré, avec tous ses noms"
        else ko "étape 9 : documents restauré diffère"; diff <(cut -d' ' -f2 /tmp/documents-avant | LC_ALL=C sort) <(cd "$d" && find documents | LC_ALL=C sort) || true; fi
        verifier_mode 9 documents/notes 700
        ;;
    esac
  done
  bilan "dans le conteneur $systeme"
fi

# ------------------------------------------------------------------- options

mode="lint"; regenerer=""; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --alpine) mode="alpine" ;;
    --regenerer) regenerer="--regenerer" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done
if [ -n "$regenerer" ] && [ "$mode" != "up" ]; then echo "--regenerer va avec --up." >&2; exit 2; fi

exiger() { # $1 commande  $2 paquet Debian ou Ubuntu qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}
exiger bash bash
exiger shellcheck shellcheck
if [ "$mode" != "lint" ]; then
  exiger docker docker.io
  docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
fi

# ------------------------------------------------------------------ validation

titre "Lint : preparer.sh, corrige/ et tester.sh"
# Les corrigés sont des suites de commandes tapées au terminal : ShellCheck n'y relève que les
# avertissements et les erreurs, sans SC2164 (« cd ~/fichiers », comme l'étudiant le tape).
export LC_ALL=C.UTF-8
for script in "$ici/preparer.sh" "$corrige"/*.sh "$ici/tester.sh"; do
  nom="${script#"$ici"/}"
  regles=()
  case $script in "$corrige"/*) regles=(--severity=warning --exclude=SC2164) ;; esac
  if bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  if shellcheck "${regles[@]}" "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
done

# Les fichiers de départ repris du cours doivent rester identiques à ceux des diapos.
extraire() { # $1 nom du fichier créé par preparer.sh : le contenu de son document en ligne
  sed -n "\\|^cat > $1 << 'FIN'\$|,/^FIN\$/p" "$ici/preparer.sh" | sed '1d;$d'
}
for paire in "pionnieres.csv:pionnieres.csv" "scripts/bonjour.sh:bonjour.sh" "scripts/sauvegarde.sh:sauvegarde.sh"; do
  if cmp -s <(extraire "${paire%%:*}") "$ici/../../cm/exemples/${paire#*:}"; then
    ok "preparer.sh : ${paire%%:*} identique à shell/cm/exemples/${paire#*:}"
  else ko "preparer.sh : ${paire%%:*} diffère de shell/cm/exemples/${paire#*:}"; fi
done

# Chaque corrigé a sa sortie, et l'énoncé affiche l'un et l'autre.
for n in "${etapes[@]}"; do
  for f in "etape-$n.sh" "etape-$n.sortie"; do
    if [ -f "$corrige/$f" ]; then ok "corrige/$f existe"; else ko "corrige/$f manque"; fi
    if grep -qF "\"$f\"" "$ici/fichiers.typ"; then ok "l'énoncé affiche corrige/$f"
    else ko "l'énoncé n'affiche pas corrige/$f"; fi
  done
done

if [ "$mode" = "lint" ]; then bilan "--lint"; fi

# ------------------------------------------------------------- dans un conteneur

docker rm -f "$conteneur" > /dev/null 2>&1 || true
journal="$(mktemp "${TMPDIR:-/tmp}/tptest.XXXXXX")"
sortie=""
# shellcheck disable=SC2317,SC2329  # appelée par trap
en_sortie() {
  rm -f -- "$journal"
  [ -z "$sortie" ] || rm -rf -- "$sortie"
  if [ -z "$garder" ]; then docker rm -f "$conteneur" > /dev/null 2>&1 || true
  else echo "--keep : conteneur $conteneur conservé (docker start -ai $conteneur ; docker rm -f $conteneur)."; fi
}
trap en_sortie EXIT

options=(--name "$conteneur" -v "$ici:/tp:ro")
if [ "$mode" = "up" ]; then
  image="debian:13-slim"; systeme="debian"
  if [ -n "$regenerer" ]; then
    sortie="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"; chmod 777 "$sortie"
    options+=(-v "$sortie:/sortie")
  fi
else
  image="$image_alpine"; systeme="alpine"
  titre "Image $image_alpine : Alpine 3.22 et les paquets de la VM du navigateur"
  # Les paquets de commun/terminal/construire-vm.sh, et util-linux-misc pour script(1).
  reseau=()
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY"
      --volume "$TPTEST_CA:/run/ca-hote.crt:ro" --env SSL_CERT_FILE=/run/ca-hote.crt)
  fi
  docker rm -f "$conteneur-image" > /dev/null 2>&1 || true
  if docker run --name "$conteneur-image" "${reseau[@]}" alpine:3.22 apk add --no-cache \
    bash bash-completion coreutils findutils grep sed gawk diffutils less file tree util-linux-misc > "$journal" 2>&1 \
    && docker commit "$conteneur-image" "$image_alpine" > /dev/null; then
    ok "image $image_alpine construite"
  else
    ko "construction de l'image $image_alpine"; tail -n 20 "$journal"
  fi
  docker rm -f "$conteneur-image" > /dev/null 2>&1 || true
fi

set +e
docker run "${options[@]}" "$image" bash /tp/tester.sh --dedans "$systeme" $regenerer 2>&1 | tee "$journal"
set -e
reussis=$((reussis + $(grep -c '^OK ' "$journal" || true)))
while IFS= read -r ligne; do echecs+=("${ligne#ÉCHEC  }"); done < <(grep '^ÉCHEC ' "$journal" || true)
if ! grep -q '^======== Bilan' "$journal"; then ko "le conteneur s'est arrêté avant son bilan"; fi
if [ -n "$regenerer" ]; then
  cp "$sortie"/etape-*.sortie "$corrige"/
  echo "--regenerer : corrige/etape-N.sortie réécrits à partir de ce passage."
fi
bilan "--$mode"
