#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Premiers pas dans le shell ».
#
# Il exécute preparer.sh, puis les scripts de corrige/, ceux-là mêmes que
# l'énoncé affiche, dans un conteneur neuf, sous un compte ordinaire (ada) :
# un corrigé qui ne fonctionne plus fait échouer le harnais.
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
#                (dates et heures neutralisées), et vérifie l'état obtenu.
#   --alpine     les mêmes corrigés et les mêmes vérifications d'état dans une
#                image Alpine 3.22 qui a les paquets de la VM du navigateur
#                (commun/terminal/construire-vm.sh) ; les écarts de sortie avec
#                Debian sont affichés, sans compter comme échecs. Construire
#                l'image demande le réseau (dépôts Alpine).
#   --regenerer  avec --up : réécrit corrige/etape-N.sortie à partir de ce
#                passage (après une modification voulue d'un corrigé).
#   --keep       garde le conteneur (tptest-shell-premiers-pas) pour examen.
#
# Ce que --up vérifie, en plus des sorties :
#   preparer.sh  il crée l'arborescence attendue, avec les droits attendus ; un
#                second lancement est refusé et ne touche à rien ;
#   étapes 1 à 6 elles ne modifient rien au dossier ;
#   étape 6      les réponses données dans le corrigé (première erreur à 00:24:10,
#                deuxième à 00:48:20) sont celles du journal ;
#   étape 7      l'arborescence finale est exactement celle demandée ;
#   étape 8      le contenu de liste.txt, erreurs.txt, dernieres-erreurs.txt et
#                notes/a-faire.txt.
#
# Le harnais ne crée et ne supprime que le conteneur tptest-shell-premiers-pas
# et, avec --alpine, l'image tptest-shell-premiers-pas-alpine. Prérequis : bash, shellcheck ;
# pour --up et --alpine, Docker (l'image debian:13-slim, ou le réseau pour la
# télécharger). Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le
# README.md du dépôt) fait passer apk par lui pour --alpine.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
etapes=(1 2 3 4 5 6 7 8)
conteneur="tptest-shell-premiers-pas"
image_alpine="tptest-shell-premiers-pas-alpine"

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

# Les dates de ls -l (« Sep  1 08:00 », « Nov 25  2026 ») changent d'un passage
# à l'autre : on les neutralise avant de comparer. Les fins de ligne du terminal
# (\r) et les tabulations de ls disparaissent.
normaliser() {
  tr -d '\r' | expand -t 8 \
    | sed -E 's/[A-Z][a-z]{2} [ 1-3][0-9] ( [0-9]{4}|[0-9]{2}:[0-9]{2})/<date>/g'
}

# ------------------------------------------- dans le conteneur : les vérifications
# --dedans <debian|alpine> [--regenerer] : lancé en root dans le conteneur, le
# TP monté en lecture seule sur /tp (et /sortie inscriptible pour --regenerer).
if [ "${1:-}" = "--dedans" ]; then
  systeme="$2"; regenerer="${3:-}"
  atelier=/home/ada/atelier
  if [ "$systeme" = "alpine" ]; then
    adduser -D -s /bin/bash ada > /dev/null
    # adduser de BusyBox pose le bit setgid sur le dossier personnel (drwxr-sr-x),
    # que ses sous-dossiers hériteraient (chmod 700 le garderait) : on lui donne
    # les droits de Debian 13.
    chmod u=rwx,go=,g-s /home/ada
  else
    useradd -m -s /bin/bash ada
  fi
  # La commande, dans une session de connexion d'ada, et dans un terminal.
  en_ada() { su - ada -c "script -qec '$1' /dev/null"; }

  titre "preparer.sh ($systeme)"
  if en_ada "bash /tp/preparer.sh" > /tmp/preparer.log 2>&1; then ok "preparer.sh crée ~/atelier"
  else ko "preparer.sh"; cat /tmp/preparer.log; fi
  arbre() { (cd "$atelier" && find . -printf '%M %u %p\n' | LC_ALL=C sort); }
  arbre > /tmp/arbre-depart
  attendu_depart="drwxr-xr-x ada .
-rw-r--r-- ada ./.reglages
-rw-r--r-- ada ./journaux/serveur-2025-novembre.log
-rw-r--r-- ada ./journaux/serveur-2026-novembre.log
-rw-r--r-- ada ./notes/a-faire.txt
-rw-r--r-- ada ./notes/idees.txt
-rw-r--r-- ada ./notes/lisezmoi.txt
-rw-r--r-- ada ./pionnieres.csv
-rw-r--r-- ada ./projets/site/index.html
-rw-r--r-- ada ./vieux/brouillon-1.txt
-rw-r--r-- ada ./vieux/brouillon-2.txt
-rwxr-xr-x ada ./projets/scripts/bonjour.sh
drwxr-xr-x ada ./journaux
drwxr-xr-x ada ./notes
drwxr-xr-x ada ./projets
drwxr-xr-x ada ./projets/scripts
drwxr-xr-x ada ./projets/site
drwxr-xr-x ada ./vieux"
  if [ "$(sort /tmp/arbre-depart)" = "$(sort <<< "$attendu_depart")" ]; then ok "arborescence et droits de départ"
  else ko "arborescence de départ inattendue"; diff <(sort <<< "$attendu_depart") <(sort /tmp/arbre-depart) || true; fi
  if [ "$(wc -l < "$atelier/journaux/serveur-2026-novembre.log")" -eq 1500 ] \
    && [ "$(grep -c ERROR "$atelier/journaux/serveur-2026-novembre.log")" -eq 30 ]; then
    ok "le journal de 2026 a 1500 lignes, dont 30 erreurs"
  else ko "le journal de 2026 n'a pas 1500 lignes, dont 30 erreurs"; fi
  if ! en_ada "bash /tp/preparer.sh" > /tmp/preparer-2.log 2>&1 && grep -q 'existe déjà' /tmp/preparer-2.log \
    && [ "$(arbre)" = "$(cat /tmp/arbre-depart)" ]; then
    ok "un second lancement de preparer.sh est refusé, sans rien modifier"
  else ko "un second lancement de preparer.sh n'est pas refusé proprement"; cat /tmp/preparer-2.log; fi

  for n in "${etapes[@]}"; do
    titre "Étape $n : corrige/etape-$n.sh ($systeme)"
    avant="$(arbre)"
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
    apres="$(arbre)"
    case $n in
      1 | 2 | 3 | 4 | 5 | 6)
        if [ "$avant" = "$apres" ]; then ok "étape $n : le dossier n'a pas changé"
        else ko "étape $n : le dossier a changé"; diff <(echo "$avant") <(echo "$apres") || true; fi
        ;;
    esac
    case $n in
      6)
        erreurs="$(grep ERROR "$atelier/journaux/serveur-2026-novembre.log" | head -n 2 | cut -d' ' -f2 | tr '\n' ' ')"
        if [ "$erreurs" = "00:24:10 00:48:20 " ]; then ok "étape 6 : premières erreurs à 00:24:10 et 00:48:20, comme le dit le corrigé"
        else ko "étape 6 : premières erreurs à $erreurs"; fi
        ;;
      7)
        attendu="drwxr-xr-x ada .
-rw-r--r-- ada ./.reglages
-rw-r--r-- ada ./archives/2025/serveur-2025-novembre.log
-rw-r--r-- ada ./journaux/serveur-2026-novembre.log
-rw-r--r-- ada ./notes/a-faire.txt
-rw-r--r-- ada ./notes/idees.txt
-rw-r--r-- ada ./notes/lisezmoi.txt
-rw-r--r-- ada ./pionnieres.csv
-rw-r--r-- ada ./projets/site/index.html
-rwxr-xr-x ada ./projets/scripts/bonjour.sh
drwxr-xr-x ada ./journaux
drwxr-xr-x ada ./notes
drwxr-xr-x ada ./projets
drwxr-xr-x ada ./projets/scripts
drwxr-xr-x ada ./projets/site"
        # Les fichiers et dossiers créés par ada suivent son umask : on ne compare que les noms.
        cree="./archives ./archives/2025 ./archives/notes-sauvegarde ./archives/notes-sauvegarde/a-faire.txt
./archives/notes-sauvegarde/idees.txt ./archives/notes-sauvegarde/lisezmoi.txt ./archives/pionnieres-v1.csv"
        obtenu="$(cd "$atelier" && find . -printf '%p\n' | LC_ALL=C sort)"
        voulu="$( { cut -d' ' -f3 <<< "$attendu"; tr ' ' '\n' <<< "$cree"; } | LC_ALL=C sort)"
        if [ "$obtenu" = "$voulu" ]; then ok "étape 7 : l'arborescence finale est celle demandée"
        else ko "étape 7 : arborescence inattendue"; diff <(echo "$voulu") <(echo "$obtenu") || true; fi
        if cmp -s "$atelier/archives/pionnieres-v1.csv" "$atelier/pionnieres.csv" \
          && diff -r "$atelier/notes" "$atelier/archives/notes-sauvegarde" > /dev/null; then
          ok "étape 7 : la copie et la sauvegarde des notes sont identiques aux originaux"
        else ko "étape 7 : copies différentes des originaux"; fi
        if [ "$(grep -c '' "$atelier/archives/2025/serveur-2025-novembre.log")" -eq 120 ]; then
          ok "étape 7 : le journal de 2025 est déplacé, entier"
        else ko "étape 7 : journal de 2025 incomplet"; fi
        ;;
      8)
        if grep -q ' liste.txt$' "$atelier/liste.txt" && [ "$(wc -l < "$atelier/liste.txt")" -eq 7 ]; then
          ok "étape 8 : liste.txt contient ls -l (7 lignes), y compris liste.txt"
        else ko "étape 8 : liste.txt inattendu"; cat "$atelier/liste.txt" || true; fi
        if [ "$(cat "$atelier/erreurs.txt")" = "ls: cannot access 'absent.txt': No such file or directory" ]; then
          ok "étape 8 : erreurs.txt contient le message d'erreur de ls, seul"
        else ko "étape 8 : erreurs.txt inattendu"; cat "$atelier/erreurs.txt" || true; fi
        if [ "$(tail -n 1 "$atelier/notes/a-faire.txt")" = "- relire les diapos" ] \
          && [ "$(wc -l < "$atelier/notes/a-faire.txt")" -eq 4 ]; then
          ok "étape 8 : a-faire.txt garde ses 3 lignes et gagne la 4e"
        else ko "étape 8 : a-faire.txt inattendu"; fi
        if [ "$(cut -d' ' -f2 "$atelier/dernieres-erreurs.txt" | tr '\n' ' ')" = "11:16:40 11:40:50 12:05:00 " ] \
          && [ "$(grep -vc ERROR "$atelier/dernieres-erreurs.txt")" -eq 0 ]; then
          ok "étape 8 : dernieres-erreurs.txt contient les trois dernières erreurs"
        else ko "étape 8 : dernieres-erreurs.txt inattendu"; cat "$atelier/dernieres-erreurs.txt" || true; fi
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
    -h | --help) sed -n '2,41p' "$0"; exit 0 ;;
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
# avertissements et les erreurs, sans SC2164 (« cd ~/atelier », comme l'étudiant le tape).
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
for paire in "pionnieres.csv:pionnieres.csv" "projets/scripts/bonjour.sh:bonjour.sh"; do
  if cmp -s <(extraire "${paire%%:*}") "$ici/../../cm/exemples/${paire#*:}"; then
    ok "preparer.sh : ${paire%%:*} identique à shell/cm/exemples/${paire#*:}"
  else ko "preparer.sh : ${paire%%:*} diffère de shell/cm/exemples/${paire#*:}"; fi
done

# Chaque corrigé a sa sortie, et l'énoncé affiche l'un et l'autre.
for n in "${etapes[@]}"; do
  for f in "etape-$n.sh" "etape-$n.sortie"; do
    if [ -f "$corrige/$f" ]; then ok "corrige/$f existe"; else ko "corrige/$f manque"; fi
    if grep -qF "\"$f\"" "$ici/premiers-pas.typ"; then ok "l'énoncé affiche corrige/$f"
    else ko "l'énoncé n'affiche pas corrige/$f"; fi
  done
done

if [ "$mode" = "lint" ]; then bilan "--lint"; fi

# ------------------------------------------------------------- dans un conteneur

docker rm -f "$conteneur" > /dev/null 2>&1 || true
journal="$(mktemp "${TMPDIR:-/tmp}/tptest.XXXXXX")"
sortie=""
# shellcheck disable=SC2317  # appelée par trap
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
