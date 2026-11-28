#!/usr/bin/env bash
# construire-site.sh — construit le site d'un arbre du dépôt, à sa place : terminal des pages web, diapos (PDF),
# pages web (index.html : TP, pages de cours, artefacts, accueil). C'est ce que lance la CI (.github/workflows/compilation-cours.yml), et ce qui compile
# tout le site en local.
#
# Usage : commun/construire-site.sh [dossier]     (dossier : racine d'un arbre du dépôt ; défaut : le dépôt de ce script)
# Variables facultatives :
#   APERCU_BRANCHE   nom de la branche : les pages web portent la bannière « Aperçu de la branche … » ;
#   COURS_VARIANTES  variantes des diapos à compiler, séparées par des espaces (défaut : les six).
# Une étape n'a lieu que si l'arbre la demande : sans commun/terminal/, pas de terminal à construire. Le script
# peut donc construire un arbre plus ancien que lui (la production, pendant un aperçu de branche).
# Prérequis : typst 0.15 ; pour le terminal, Docker, Go, Node, Python 3.
set -euo pipefail

arbre=$(cd "${1:-$(dirname "$0")/..}" && pwd)
cd "$arbre"
variantes=${COURS_VARIANTES:-projection deuteranopie protanopie tritanopie achromatopsie dyslexie}
entrees=()
[ -z "${APERCU_BRANCHE:-}" ] || entrees=(--input "apercu=$APERCU_BRANCHE")

# Terminal des pages web : xterm.js, v86 et ses BIOS (sommes dans dependances.txt), l'image Alpine de la VM
# (Docker), démarrée une fois dans Node pour vérifier ses outils ; puis les exécutables statiques de host-shell-access
# (Linux, amd64 et arm64), SHA256SUMS, et le test du protocole.
if [ -f commun/terminal/preparer.sh ]; then
  echo "::group::Terminal, VM dans le navigateur"
  commun/terminal/preparer.sh --vm
  node commun/terminal/tester-vm.mjs
  echo "::endgroup::"
  echo "::group::Terminal, host-shell-access"
  commun/terminal/host-shell-access/construire.sh
  python3 -I commun/terminal/host-shell-access/tester.py
  echo "::endgroup::"
fi

# Diapos : chaque diaporama de <cours>/cm/ (<cours>.typ, et un par module : arbo.typ…) donne un PDF par variante,
# <nom>-<variante>.pdf. Ce que les diaporamas importent se range dans un sous-dossier (cm/partage/…).
for src in */cm/*.typ; do
  [ -f "$src" ] || continue
  for variante in $variantes; do
    pdf="${src%.typ}-$variante.pdf"
    echo "::group::$pdf"
    typst compile --root . --font-path commun/fonts --input variante="$variante" "$src" "$pdf"
    echo "::endgroup::"
  done
done

# Pages web : TP, pages de cours, artefacts, accueil, page de host-shell-access, chacune en index.html à côté de sa source.
web() { typst compile --root . --font-path commun/fonts --features html --format html "${entrees[@]}" "${@:3}" "$1" "$2"; }
for src in */tp/*/*.typ */pages/*/*.typ */artefacts/*/*.typ; do
  [ -f "$src" ] || continue
  dossier=$(dirname "$src")
  [ "$src" = "$dossier/$(basename "$dossier").typ" ] || continue
  echo "::group::$dossier/index.html"
  web "$src" "$dossier/index.html"
  echo "::endgroup::"
done
# Page d'un cours (<cours>/index.typ, lue dans son progression.yaml) : la liste des supports présents, pour ne
# poser aucun lien mort.
for src in */index.typ; do
  cours=${src%%/*}
  # Un cours a son index de progression : un autre <dossier>/index.typ (l'accueil d'un aperçu copié dans
  # apercu/) n'est pas une page de cours.
  [ -f "$cours/progression.yaml" ] || continue
  existants=""
  for support in "$cours"/cm/*.typ "$cours"/pages/*/ "$cours"/tp/*/ "$cours"/artefacts/*/; do
    [ -e "$support" ] && existants+="${support#"$cours"/} "
  done
  echo "::group::$cours/index.html"
  web "$src" "$cours/index.html" --input existants="$existants"
  echo "::endgroup::"
done
web index.typ index.html
if [ -f commun/terminal/host-shell-access/host-shell-access.typ ]; then web commun/terminal/host-shell-access/host-shell-access.typ commun/terminal/host-shell-access/index.html; fi
