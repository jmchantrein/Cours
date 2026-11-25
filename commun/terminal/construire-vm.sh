#!/usr/bin/env bash
# construire-vm.sh — construit l'image de la VM du terminal : Alpine Linux x86 (32 bits, pour v86), sans réseau,
# démarrée en noyau + initramfs. Appelé par preparer.sh --vm ; demande Docker (un hôte x86_64 exécute
# l'image linux/386 sans émulation).
#
# Usage : commun/terminal/construire-vm.sh <dossier de sortie>
# Produit : bzImage (noyau), initrd.gz (tout le système), paquets.txt (paquets, versions et licences), version.
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
  nano vim git jq tmux tar ncurses-terminfo-base
)

command -v docker >/dev/null || { echo "construire-vm.sh : Docker est requis" >&2; exit 1; }

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
  --volume "$ICI/vm:/cours:ro" --volume "$SORTIE:/sortie" "$image" sh -euc '
    apk add --no-cache --no-scripts "$@"
    install -m 0755 /cours/init /init
    install -m 0644 /cours/profil.sh /etc/profile.d/cours.sh
    printf "127.0.0.1 localhost cours\n" > /etc/hosts
    : > /etc/resolv.conf
    cp /boot/vmlinuz-virt /sortie/bzImage
    apk list --installed 2>/dev/null | sort > /sortie/paquets.txt
    rm -rf /boot /lib/modules /usr/lib/modules /var/cache/apk/*
    cd /
    find . \( -path ./proc -o -path ./sys -o -path ./dev -o -path ./tmp -o -path ./run \) -prune -print \
      -o \( -path ./sortie -o -path ./cours -o -path ./.dockerenv \) -prune \
      -o -print | cpio -o -H newc 2>/dev/null | gzip -9 > /sortie/initrd.gz
    chown "$0" /sortie/bzImage /sortie/initrd.gz /sortie/paquets.txt
  ' "$(id -u):$(id -g)" "${paquets[@]}"

printf '%s\n' "$version" > "$SORTIE/version"
printf 'Image %s : noyau %s, initramfs %s\n' "$version" \
  "$(du -h "$SORTIE/bzImage" | cut -f1)" "$(du -h "$SORTIE/initrd.gz" | cut -f1)"
