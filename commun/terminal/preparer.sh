#!/usr/bin/env bash
# preparer.sh — dépendances tierces du terminal des pages web, rangées dans commun/terminal/vendor/ (ignoré
# par git, publié par la CI avec le site). Chaque fichier est fixé en version et en SHA-256 dans
# dependances.txt ; une somme inattendue arrête tout.
#
# Usage : commun/terminal/preparer.sh        xterm.js, v86 et les BIOS
#         commun/terminal/preparer.sh --vm   la même chose, plus l'image de la VM (construire-vm.sh, Docker)
# Une image déjà rangée dans vendor/vm/ (bzImage, initrd.gz, version) est reprise dans le manifeste.
set -euo pipefail

ICI=$(cd "$(dirname "$0")" && pwd)
VENDOR="$ICI/vendor"
case "${1:-}" in
  "") vm=false ;;
  --vm) vm=true ;;
  *) echo "usage : preparer.sh [--vm]" >&2; exit 2 ;;
esac

travail=$(mktemp -d)
trap 'rm -rf "$travail"' EXIT
mkdir -p "$VENDOR/vm"

# Téléchargement, puis vérification de la somme avant tout usage.
while read -r nom somme adresse; do
  case "$nom" in ''|'#'*|alpine) continue ;; esac
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --output "$travail/$nom" "$adresse"
  printf '%s  %s\n' "$somme" "$travail/$nom" | sha256sum --check --quiet \
    || { echo "preparer.sh : somme SHA-256 inattendue pour $nom ($adresse)" >&2; exit 1; }
done < "$ICI/dependances.txt"

# extraire <archive npm> <fichier dans l'archive> <destination dans vendor/>
extraire() { tar -xzOf "$travail/$1" "package/$2" > "$VENDOR/$3"; }
extraire xterm-6.0.0.tgz lib/xterm.js xterm.js
extraire xterm-6.0.0.tgz css/xterm.css xterm.css
extraire xterm-6.0.0.tgz LICENSE LICENSE-xterm.txt
extraire addon-fit-0.11.0.tgz lib/addon-fit.js addon-fit.js
extraire addon-fit-0.11.0.tgz LICENSE LICENSE-addon-fit.txt
extraire v86-0.5.462.tgz build/libv86.js libv86.js
extraire v86-0.5.462.tgz build/v86.wasm v86.wasm
extraire v86-0.5.462.tgz LICENSE LICENSE-v86.txt
cp "$travail/seabios.bin" "$travail/vgabios.bin" "$VENDOR/"

if $vm; then "$ICI/construire-vm.sh" "$VENDOR/vm"; fi

# Manifeste de la VM : la page y lit les fichiers à charger et la version, qui nomme son cache. La version
# porte une somme de tous les fichiers : une nouvelle image ou un nouveau v86 changent de cache.
fichiers=(libv86.js v86.wasm seabios.bin vgabios.bin vm/bzImage vm/initrd.gz)
if [[ -f "$VENDOR/vm/bzImage" && -f "$VENDOR/vm/initrd.gz" && -f "$VENDOR/vm/version" ]]; then
  somme=$(cd "$VENDOR" && sha256sum "${fichiers[@]}" | sha256sum | cut -c1-12)
  {
    printf '{\n  "version": "%s-%s",\n  "memoire_mo": 512,\n  "fichiers": {\n' "$(cat "$VENDOR/vm/version")" "$somme"
    for i in "${!fichiers[@]}"; do
      f=${fichiers[$i]}
      printf '    "%s": %s' "$f" "$(stat -c %s "$VENDOR/$f")"
      if (( i < ${#fichiers[@]} - 1 )); then printf ',\n'; else printf '\n'; fi
    done
    printf '  }\n}\n'
  } > "$VENDOR/vm/manifeste.json"
else
  rm -f "$VENDOR/vm/manifeste.json"
fi

printf 'Terminal prêt : %s dans %s\n' "$(du -sh "$VENDOR" | cut -f1)" "$VENDOR"
