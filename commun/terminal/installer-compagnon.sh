#!/bin/sh
# installer-compagnon.sh — installe le compagnon du terminal des cours (iadmin-terminal) dans ~/.local/bin,
# sur l'ordinateur où s'ouvre le navigateur. Demande Python 3 et curl (ou wget) ; n'installe rien d'autre.
# Porté de site/public/terminal/install-iadmin-terminal.sh.
#
#   curl -fLO https://jmchantrein.github.io/Cours/commun/terminal/installer-compagnon.sh
#   less installer-compagnon.sh        # lire avant d'exécuter
#   sh installer-compagnon.sh
set -eu

SOURCE="${COURS_TERMINAL_SOURCE:-https://jmchantrein.github.io/Cours/commun/terminal}/iadmin-terminal.py"
DOSSIER="${COURS_TERMINAL_DOSSIER:-$HOME/.local/bin}"
CIBLE="$DOSSIER/iadmin-terminal"

command -v python3 >/dev/null 2>&1 || { echo "Python 3 est requis : sudo apt install python3" >&2; exit 1; }
printf 'Source : %s\nDestination : %s\n' "$SOURCE" "$CIBLE"
mkdir -p "$DOSSIER"
# Téléchargement dans un fichier temporaire : un transfert interrompu ne remplace jamais une installation
# qui fonctionne. HTTPS est imposé : ce fichier est du code qui s'exécutera avec vos droits.
temporaire="$(mktemp)"
trap 'rm -f "$temporaire"' EXIT HUP INT TERM
if command -v curl >/dev/null 2>&1; then
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --output "$temporaire" "$SOURCE"
elif command -v wget >/dev/null 2>&1; then
  wget --quiet --https-only --output-document="$temporaire" "$SOURCE"
else
  echo "curl ou wget est requis : sudo apt install curl" >&2
  exit 1
fi
# La compilation détecte un fichier tronqué avant qu'il n'arrive dans le PATH.
python3 -c 'import sys; compile(open(sys.argv[1], "rb").read(), sys.argv[1], "exec")' "$temporaire"
install -m 0755 "$temporaire" "$CIBLE"
printf 'Installé : %s\n' "$CIBLE"
case ":$PATH:" in
  *":$DOSSIER:"*) ;;
  *) printf 'Ajoutez %s à votre PATH, ou lancez %s directement.\n' "$DOSSIER" "$CIBLE" ;;
esac
printf 'Lancer : iadmin-terminal local     Désinstaller : rm %s\n' "$CIBLE"
