#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Décrire des livres en YAML et en JSON ».
#
# Il valide et exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé
# affiche : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up | --local]
#   --lint   (défaut) sans rien construire ni exécuter : bash -n et shellcheck
#            des scripts, yamllint --strict des YAML, syntaxe des JSON (jq).
#   --up     le --local ci-dessous, dans un conteneur debian:13-slim où le
#            harnais installe les paquets de l'énoncé (yamllint, yq, jq) :
#            les versions sont celles de Debian 13.
#   --local  --lint, puis les vérifications d'exécution, avec les outils de
#            cet hôte (un Debian 13 où l'énoncé a été suivi, par exemple).
#
# Ce que --local (et donc --up) vérifie :
#   yq                est la version Python (celle du paquet yq de Debian) ;
#   livres.json       contient les mêmes données que livres.yaml, lu par PyYAML
#                     comme par yq, et yq -S rend le même fichier que jq -S ;
#   livres-fautif     (fichiers/) yamllint le refuse, sur la tabulation, puis,
#                     tabulation corrigée, sur l'indentation ; livres-repare.yaml
#                     passe yamllint --strict ;
#   pieges.yaml       (fichiers/) les lectures annoncées par l'énoncé : PyYAML
#                     et yq lisent les valeurs différemment ; dans
#                     pieges-corrige.yaml, ils lisent les mêmes chaînes ;
#   livres-ancres     contient une ancre, des alias et une clé de fusion ; résolu
#                     par yq comme par PyYAML, il donne les livres de livres.yaml,
#                     l'auteur devenu un objet ; naissance est un entier ;
#   requetes.sh       rejoué sur une copie : sa sortie est celle de l'énoncé, le
#                     fichier réécrit reste du YAML et seul le titre a changé ;
#                     yq -i sans -y est refusé et laisse le fichier intact.
#
# Fichiers exclus du --lint, parce qu'ils échouent exprès (l'étudiant les
# corrige) : fichiers/livres-fautif.yaml, fichiers/pieges.yaml.
#
# Le harnais travaille dans un dossier temporaire et ne modifie aucun fichier
# du TP. --up crée un seul conteneur, tptest-yaml-json, supprimé en sortie.
#
# Prérequis : --lint : bash, shellcheck, jq, yamllint. --local : en plus yq
# (version Python) et python3 avec PyYAML. --up : bash, shellcheck, Docker et
# l'accès aux dépôts Debian.
# Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le README.md du dépôt)
# fait passer apt par HTTPS_PROXY, en HTTPS, avec cette autorité.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
fichiers="$ici/fichiers"
exclus=("$fichiers/livres-fautif.yaml" "$fichiers/pieges.yaml")
# Messages des outils en anglais : le harnais les compare.
export LC_ALL=C.UTF-8

mode="lint"
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --local) mode="local" ;;
    -h | --help) sed -n '2,43p' "$0"; exit 0 ;;
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
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY" --volume "$TPTEST_CA:/run/ca-hote.crt:ro"); apt_https="1"
  fi
  docker container rm -f tptest-yaml-json > /dev/null 2>&1 || true
  echo "Conteneur debian:13-slim : installation de yamllint, yq, jq et shellcheck…"
  # Le TP est monté en lecture seule : le harnais n'écrit que dans /tmp.
  exec docker container run --rm --name tptest-yaml-json "${reseau[@]}" \
    --env "APT_HTTPS=$apt_https" --volume "$ici:/tp:ro" debian:13-slim bash -euc '
      if [ -n "$APT_HTTPS" ]; then
        sed -i "s|http://deb.debian.org|https://deb.debian.org|g" /etc/apt/sources.list.d/debian.sources
        printf "Acquire::https::Proxy \"%s\";\nAcquire::https::CAInfo \"/run/ca-hote.crt\";\n" "$HTTPS_PROXY" > /etc/apt/apt.conf.d/99mandataire
      fi
      apt-get update -qq > /dev/null
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        yamllint yq jq shellcheck > /dev/null
      echo "Debian $(cat /etc/debian_version) · $(yq --version) · $(jq --version) · $(yamllint --version)"
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
nom() { printf '%s' "${1#"$ici"/}"; }
exclu() { local e; for e in "${exclus[@]}"; do [ "$1" = "$e" ] && return 0; done; return 1; }

# ------------------------------------------------------------------------- lint

exiger bash bash
exiger shellcheck shellcheck
exiger jq jq
exiger yamllint yamllint

titre "Lint : scripts, YAML et JSON"
for script in "$corrige"/*.sh "$ici/tester.sh"; do
  if bash -n "$script"; then ok "$(nom "$script") : syntaxe bash"; else ko "$(nom "$script") : syntaxe bash"; fi
  if shellcheck "$script"; then ok "$(nom "$script") : shellcheck"; else ko "$(nom "$script") : shellcheck"; fi
done
for f in "$corrige"/*.yaml "$fichiers"/*.yaml; do
  if exclu "$f"; then echo "--     $(nom "$f") : exclu du lint (échoue exprès)"; continue; fi
  if yamllint --strict "$f"; then ok "$(nom "$f") : yamllint --strict"; else ko "$(nom "$f") : yamllint --strict"; fi
done
for f in "$corrige"/*.json; do
  if jq empty "$f"; then ok "$(nom "$f") : JSON valide"; else ko "$(nom "$f") : JSON invalide"; fi
done

[ "$mode" = "lint" ] && bilan

# -------------------------------------------------------------------- exécution

exiger yq yq
exiger python3 python3
python3 -c 'import yaml' 2> /dev/null || { echo "Le module yaml de python3 est introuvable : installez le paquet python3-yaml." >&2; exit 1; }

travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
trap 'rm -rf -- "$travail"' EXIT
# py_json FICHIER : le YAML lu par PyYAML, écrit en JSON aux clés triées.
py_json() { python3 -c 'import sys, json, yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1])), sort_keys=True, separators=(",", ":"), ensure_ascii=False))' "$1"; }
# compare LIBELLÉ OBTENU ATTENDU
compare() {
  if [ "$2" = "$3" ]; then ok "$1"
  else ko "$1"; printf '       obtenu  : %s\n       attendu : %s\n' "$2" "$3"; fi
}

titre "yq"
if yq --help 2>&1 | grep -q 'jq filter'; then ok "yq est la version Python, qui passe le JSON à jq ($(yq --version))"
else ko "yq n'est pas la version Python : les commandes de l'énoncé visent le paquet yq de Debian"; fi

titre "Étape 4 : livres.json et livres.yaml, les mêmes données"
compare "PyYAML : livres.yaml et livres.json donnent le même arbre" \
  "$(py_json "$corrige/livres.yaml")" "$(jq -cS . "$corrige/livres.json")"
jq -S . "$corrige/livres.json" > "$travail/a.json"
yq -S . "$corrige/livres.yaml" > "$travail/b.json"
if cmp -s "$travail/a.json" "$travail/b.json"; then ok "jq -S . livres.json et yq -S . livres.yaml : fichiers identiques (cmp)"
else ko "jq -S . livres.json et yq -S . livres.yaml diffèrent"; diff "$travail/a.json" "$travail/b.json" || true; fi
compare "livre.yaml : le titre est une chaîne, l'année un nombre" \
  "$(yq -c '[.titre, .annee_publication] | map(type)' "$corrige/livre.yaml")" '["string","number"]'

titre "Étape 3 : livres-fautif.yaml, puis livres-repare.yaml"
fautif="$fichiers/livres-fautif.yaml"
verdict() { yamllint "$1" 2>&1 | grep -o 'error .*' | head -1 || true; }
compare "yamllint refuse livres-fautif.yaml : la tabulation de la ligne 8" "$(verdict "$fautif")" \
  "error    syntax error: found character '\\t' that cannot start any token (syntax)"
if yamllint "$fautif" > /dev/null 2>&1; then ko "yamllint accepte livres-fautif.yaml"; else ok "yamllint livres-fautif.yaml : code de retour non nul"; fi
sed 's/^\t- politique/      - politique/' "$fautif" > "$travail/sans-tabulation.yaml"
compare "tabulation corrigée : yamllint bute sur l'indentation de la ligne 11" "$(verdict "$travail/sans-tabulation.yaml")" \
  "error    syntax error: mapping values are not allowed here (syntax)"
compare "livres-repare.yaml : les deux premiers livres de livres.yaml, sans les mots-clés manquants" \
  "$(py_json "$corrige/livres-repare.yaml")" \
  "$(py_json "$corrige/livres.yaml" | jq -cS '.livres |= .[0:2] | .livres[1] |= del(.mots_cles)')"

titre "Étape 5 : pieges.yaml, deux analyseurs"
pieges="$fichiers/pieges.yaml"
compare "yq lit pieges.yaml" "$(yq -c . "$pieges")" \
  '{"titre":1984,"traductions":["fr","de","no"],"disponible":"yes","cote":83,"duree_lecture":"7:30","publication":"1949-06-08"}'
compare "PyYAML lit pieges.yaml" \
  "$(python3 -c 'import sys, yaml; print(yaml.safe_load(sys.stdin))' < "$pieges")" \
  "{'titre': 1984, 'traductions': ['fr', 'de', False], 'disponible': True, 'cote': 83, 'duree_lecture': 450, 'publication': datetime.date(1949, 6, 8)}"
compare "yamllint pieges.yaml : deux avertissements truthy (no, yes)" \
  "$(yamllint "$pieges" | grep -c '(truthy)' || true)" "2"
corrige_p="$corrige/pieges-corrige.yaml"
compare "pieges-corrige.yaml : PyYAML et yq lisent les mêmes valeurs" \
  "$(py_json "$corrige_p")" "$(yq -cS . "$corrige_p")"
compare "pieges-corrige.yaml : les valeurs voulues" "$(yq -cS . "$corrige_p")" \
  '{"cote":"0123","disponible":true,"duree_lecture":"7:30","publication":"1949-06-08","titre":"1984","traductions":["fr","de","no"]}'

titre "Étape 6 : livres-ancres.yaml"
ancres="$corrige/livres-ancres.yaml"
for marque in '&auteur_defaut' '\*auteur_defaut' '<<: \*auteur_defaut' '!!int'; do
  if grep -q -- "$marque" "$ancres"; then ok "livres-ancres.yaml emploie ${marque//\\/}"
  else ko "livres-ancres.yaml n'emploie pas ${marque//\\/}"; fi
done
attendu_ancres="$(py_json "$corrige/livres.yaml" | jq -cS '
  {"George Orwell": 1903, "Aldous Huxley": 1894} as $naissance
  | .livres | map(.auteur |= {nom: ., naissance: $naissance[.], nationalite: "britannique"})')"
compare "yq résout les alias et la fusion : les livres de livres.yaml, auteur détaillé" \
  "$(yq -cS '.livres' "$ancres")" "$attendu_ancres"
compare "PyYAML résout de même" "$(py_json "$ancres" | jq -cS '.livres')" "$attendu_ancres"
compare "naissance est un entier pour PyYAML" \
  "$(python3 -c 'import sys, yaml; print(sorted({type(l["auteur"]["naissance"]).__name__ for l in yaml.safe_load(open(sys.argv[1]))["livres"]}))' "$ancres")" \
  "['int']"

titre "Étape 7 : requetes.sh, rejoué sur une copie"
cp "$corrige/livres.yaml" "$corrige/livres.json" "$travail/"
avant="$(py_json "$travail/livres.yaml")"
if sortie="$(cd "$travail" && bash "$corrige/requetes.sh" 2>&1)"; then ok "requetes.sh : code de retour 0"
else ko "requetes.sh : code de retour non nul"; fi
compare "requetes.sh : la sortie annoncée" "$sortie" "$(printf '%s\n' 'Le meilleur des mondes' \
  'Le meilleur des mondes' 'Les portes de la perception' 'Le meilleur des mondes' 'Les portes de la perception')"
compare "livres.yaml réécrit : seul le titre de 1984 a changé" \
  "$(py_json "$travail/livres.yaml")" "$(jq -cS '.livres[0].titre = "2024"' <<< "$avant")"
if yamllint "$travail/livres.yaml" > /dev/null; then ok "livres.yaml réécrit : yamllint ne trouve pas d'erreur"
else ko "livres.yaml réécrit : yamllint trouve une erreur"; fi
if grep -q '^#' "$travail/livres.yaml"; then ko "livres.yaml réécrit : le commentaire est resté"
else ok "livres.yaml réécrit par yq -yi : le commentaire et --- ont disparu, comme l'annonce l'énoncé"; fi
cp "$corrige/livres.yaml" "$travail/refus.yaml"
if yq -i '.livres[0].titre = "2024"' "$travail/refus.yaml" 2> "$travail/refus.log"; then ko "yq -i sans -y est accepté"
else ok "yq -i sans -y est refusé : $(cat "$travail/refus.log")"; fi
if cmp -s "$corrige/livres.yaml" "$travail/refus.yaml"; then ok "… et le fichier est intact"
else ko "yq -i sans -y a modifié le fichier"; fi

bilan
