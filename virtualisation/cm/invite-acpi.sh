#!/usr/bin/env bash
# Construit un invité minimal qui obéit à « virsh shutdown » : un noyau Alpine Linux (flavor virt) et un
# initramfs d'une quinzaine de lignes, où acpid (celui de BusyBox) écoute le bouton d'alimentation ACPI
# et éteint la machine. Il sert à rejouer, sans installer de système, les sorties de la diapositive
# « Éteindre, débrancher, effacer » (voir rejouer-libvirt.sh) ; aucun disque n'est nécessaire.
# Usage : ./invite-acpi.sh [dossier]      (défaut : /var/lib/libvirt/invite-acpi)
# Produit dans le dossier : vmlinuz-virt et initrd.gz ; libvirt-qemu doit pouvoir traverser le dossier.
# Prérequis : curl, cpio, gzip, squashfs-tools (unsquashfs) ; accès à dl-cdn.alpinelinux.org.
set -euo pipefail

version="3.24.4"                       # Alpine ; branche v3.24
depot="https://dl-cdn.alpinelinux.org/alpine/v${version%.*}/releases/x86_64"
destination="${1:-/var/lib/libvirt/invite-acpi}"
travail="$(mktemp -d)"
trap 'rm -rf -- "$travail"' EXIT

mkdir -p "$destination"
cd "$travail"
curl -fsSL -O "$depot/alpine-netboot-$version-x86_64.tar.gz" -O "$depot/alpine-minirootfs-$version-x86_64.tar.gz"
mkdir netboot racine
tar -xzf "alpine-netboot-$version-x86_64.tar.gz" -C netboot
tar -xzf "alpine-minirootfs-$version-x86_64.tar.gz" -C racine

# Les pilotes du bouton d'alimentation (button, evdev) sont des modules : on les prend dans modloop.
unsquashfs -q -d modules netboot/boot/modloop-virt > /dev/null
find modules -name button.ko -path '*drivers/acpi*' -exec cp {} racine/ \;
find modules -name evdev.ko -exec cp {} racine/ \;

# acpid (BusyBox) exécute /etc/acpi/PWRF/00000080 quand le bouton est pressé.
mkdir -p racine/etc/acpi/PWRF
cat > racine/etc/acpi/PWRF/00000080 << 'EOF'
#!/bin/sh
echo "bouton d'alimentation : arrêt"
poweroff -f
EOF
cat > racine/init << 'EOF'
#!/bin/busybox sh
mkdir -p /proc /sys /dev
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
insmod /evdev.ko
insmod /button.ko
echo "invité prêt : acpid écoute le bouton d'alimentation"
exec acpid -f -d
EOF
chmod +x racine/init racine/etc/acpi/PWRF/00000080

(cd racine && find . | cpio -o -H newc --quiet | gzip -1) > "$destination/initrd.gz"
cp netboot/boot/vmlinuz-virt "$destination/vmlinuz-virt"
chmod -R a+rX "$destination"
echo "Noyau et initramfs dans $destination (Alpine $version)"
