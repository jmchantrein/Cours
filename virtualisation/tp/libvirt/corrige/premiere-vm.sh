#!/bin/bash
# Première VM, en ligne de commande, sur la connexion qemu:///system.
# Prérequis : verifier-hote.sh réussit ; l'image netinst de Debian est
# téléchargée et vérifiée (signature, puis empreinte : voir les diapos).
# L'installateur s'ouvre dans virt-viewer : n'installez PAS d'environnement
# de bureau, installez le serveur SSH.
#
# Usage : ./premiere-vm.sh [nom de la VM] [chemin de l'image ISO]
set -euo pipefail

# Sans cette variable, virsh et virt-install d'un compte ordinaire parlent à
# qemu:///session, qui n'a ni le réseau default ni le pool default.
export LIBVIRT_DEFAULT_URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"

nom_vm="${1:-ma-premiere-vm}"
image_iso="${2:-$HOME/iso-debian/debian-13.7.0-amd64-netinst.iso}"

[ -f "$image_iso" ] || { echo "Image ISO introuvable : $image_iso" >&2; exit 1; }

# --memory 2048       2 Gio de mémoire vive (en Mio)
# --vcpus 2           deux processeurs virtuels
# --disk size=10      un volume qcow2 de 10 Gio, créé dans le pool default
#                     (/var/lib/libvirt/images/), sur le bus virtio
# --osinfo detect=on  reconnaît Debian dans l'ISO et adapte le matériel virtuel
# --network ...       branche la VM sur le réseau libvirt default (NAT)
# --cdrom ...         démarre l'installateur depuis l'image
# Micrologiciel : BIOS, le choix par défaut de virt-install pour Debian ;
# il permet les instantanés internes de l'étape 6 (l'UEFI les refuse).
virt-install \
  --name "$nom_vm" \
  --memory 2048 \
  --vcpus 2 \
  --disk size=10 \
  --osinfo detect=on \
  --network network=default \
  --cdrom "$image_iso"
