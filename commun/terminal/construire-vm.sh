#!/usr/bin/env bash
# construire-vm.sh — construit l'image de la VM du terminal : Alpine Linux x86 (32 bits, pour v86), sans réseau,
# démarrée en noyau + initramfs. Appelé par preparer.sh --vm ; demande Docker (un hôte x86_64 exécute
# l'image linux/386 sans émulation).
#
# Usage : commun/terminal/construire-vm.sh <dossier de sortie>
# Produit : bzImage (noyau), initrd.gz (tout le système), paquets.txt (paquets, versions et licences), version.
#
# Fichiers de départ : l'image reprend, de chaque TP dont l'énoncé déclare le mode « vm » (page-web(terminal: …)),
# les fichiers de son dossier hors corrige/, tester.sh, *.typ et index.html (preparer.sh, dojo/…), sous
# /usr/share/cours/Cours-main/<cours>/tp/<tp>/. Aucune copie à maintenir : la source reste le dossier du TP.
# Sans réseau, wget et curl de la VM (vm/telecharger) servent ces fichiers pour les adresses du site des cours et
# de l'archive du dépôt, de sorte que la première étape d'un énoncé se tape telle quelle.
set -euo pipefail

ICI=$(cd "$(dirname "$0")" && pwd)
SORTIE=${1:?usage : construire-vm.sh <dossier de sortie>}
mkdir -p "$SORTIE"
SORTIE=$(cd "$SORTIE" && pwd)

# L'image de base est fixée par son condensé SHA-256, dans dependances.txt.
read -r _ condense reference < <(grep -E '^alpine[[:space:]]' "$ICI/dependances.txt")
image="${reference#docker.io/library/}@sha256:$condense"
version="alpine-${reference##*:}"

# Outils des cours d'initiation (shell, fichiers, édition, git, formats). Le réseau, Docker, SSH et
# Python restent hors de l'image : l'image reste légère, et ces TP passent par le compagnon.
paquets=(
  linux-virt bash bash-completion coreutils findutils grep sed gawk diffutils less file tree
  nano vim git jq tmux tar ncurses-terminfo-base procps-ng bats vim-tutor
  mandoc coreutils-doc bash-doc less-doc grep-doc tmux-doc
)

command -v docker >/dev/null || { echo "construire-vm.sh : Docker est requis" >&2; exit 1; }

# Fichiers de départ des TP en mode « vm », rassemblés comme l'archive du dépôt (Cours-main/<chemin du dépôt>).
depart=$(mktemp -d)
trap 'rm -rf "$depart"' EXIT
for enonce in "$ICI"/../../*/tp/*/*.typ; do
  grep -Eq 'terminal: *\([^)]*"vm"' "$enonce" || continue
  tp=$(dirname "$enonce")
  cible="$depart/Cours-main/${tp#"$ICI"/../../}"
  mkdir -p "$cible"
  tar -C "$tp" --exclude=corrige --exclude=tester.sh --exclude='*.typ' --exclude=index.html -cf - . | tar -C "$cible" -xf -
done

# Un mandataire HTTPS de l'hôte de construction (réseau d'entreprise, bac à sable) sert aussi à apk, avec son
# autorité de certification ; ni l'un ni l'autre n'entre dans l'image (/run reste vide dans l'archive).
reseau=()
if [[ -n "${HTTPS_PROXY:-}" ]]; then reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY"); fi
if [[ -n "${SSL_CERT_FILE:-}" && -f "$SSL_CERT_FILE" ]]; then
  reseau+=(--volume "$SSL_CERT_FILE:/run/ca-hote.crt:ro" --env SSL_CERT_FILE=/run/ca-hote.crt)
fi

# Tout se fait dans le conteneur, en root : les propriétaires des fichiers de l'archive sont justes.
# Le noyau est livré à part à v86 : ni /boot ni les modules n'entrent dans l'initramfs.
docker run --rm --platform linux/386 --name "terminal-vm-$$" "${reseau[@]}" \
  --volume "$ICI/vm:/cours:ro" --volume "$depart:/depart:ro" --volume "$SORTIE:/sortie" "$image" sh -euc '
    apk add --no-cache --no-scripts "$@"
    install -m 0755 /cours/init /init
    install -m 0644 /cours/profil.sh /etc/profile.d/cours.sh
    install -m 0755 /cours/telecharger /usr/local/bin/wget
    ln -s wget /usr/local/bin/curl
    mkdir -p /usr/share/cours
    cp -a /depart/Cours-main /usr/share/cours/
    # Le compte des TP : ordinaire, numéroté et groupé comme sur Debian (ada 1000, etudiants 1001), dossier personnel en 0700.
    adduser -D -s /bin/bash ada
    addgroup etudiants
    addgroup ada etudiants
    chmod u=rwx,go=,g-s /home/ada
    rm -rf /usr/share/info
    # Git de Debian 13 (2.47), la référence des énoncés : dossier branches/ dans un dépôt nu, et pas de refs/remotes/
    # origin/HEAD créé par git fetch (2.48 et suivants).
    mkdir -p /usr/share/git-core/templates/branches
    git config --system fetch.followRemoteHEAD never
    printf "127.0.0.1 localhost cours\n" > /etc/hosts
    : > /etc/resolv.conf
    cp /boot/vmlinuz-virt /sortie/bzImage
    apk list --installed 2>/dev/null | sort > /sortie/paquets.txt
    rm -rf /boot /lib/modules /usr/lib/modules /var/cache/apk/*
    cd /
    find . \( -path ./proc -o -path ./sys -o -path ./dev -o -path ./tmp -o -path ./run \) -prune -print \
      -o \( -path ./sortie -o -path ./cours -o -path ./depart -o -path ./.dockerenv \) -prune \
      -o -print | cpio -o -H newc 2>/dev/null | gzip -9 > /sortie/initrd.gz
    chown "$0" /sortie/bzImage /sortie/initrd.gz /sortie/paquets.txt
  ' "$(id -u):$(id -g)" "${paquets[@]}"

printf '%s\n' "$version" > "$SORTIE/version"
printf 'Image %s : noyau %s, initramfs %s\n' "$version" \
  "$(du -h "$SORTIE/bzImage" | cut -f1)" "$(du -h "$SORTIE/initrd.gz" | cut -f1)"
