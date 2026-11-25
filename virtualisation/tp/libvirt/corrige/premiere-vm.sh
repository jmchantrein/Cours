#!/bin/bash
# Première VM, en ligne de commande, sur la connexion qemu:///system.
# Prérequis : verifier-hote.sh réussit ; le paquet acl (setfacl) ; l'image netinst de
# Debian téléchargée et vérifiée (signature, puis empreinte : voir les diapos).
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

# Sur qemu:///system, QEMU ne tourne pas sous votre compte mais sous libvirt-qemu.
# Or Debian 13 crée votre dossier personnel en mode 0700 : libvirt-qemu ne peut pas
# le traverser, et l'installateur ne démarre pas (« Permission denied »).
# Une ACL lui accorde le seul droit de traverser (x, sans lire ni lister) ; le fichier
# lui-même est géré par libvirt. Le pool default, lui, est déjà lisible (/var/lib/libvirt/images).
setfacl -m u:libvirt-qemu:x "$HOME" "$(dirname "$image_iso")"

# --memory 2048       2 Gio de mémoire vive (en Mio)
# --vcpus 2           deux processeurs virtuels
# --disk size=10      un volume qcow2 de 10 Gio, créé dans le pool default
#                     (/var/lib/libvirt/images/), sur le bus virtio
# --osinfo debian13   adapte le matériel virtuel à Debian 13 (disque et carte virtio) ;
#                     detect=on ne reconnaît pas l'ISO 13.x avec osinfo-db 0.20250606
#                     (Debian 13, Ubuntu 24.04) et retombe sur generic (IDE, e1000)
# --network ...       branche la VM sur le réseau libvirt default (NAT)
# --cdrom ...         démarre l'installateur depuis l'image
# Micrologiciel : BIOS, le choix par défaut de virt-install pour Debian ;
# il permet les instantanés internes de l'étape 7 (l'UEFI les refuse).
virt-install \
  --name "$nom_vm" \
  --memory 2048 \
  --vcpus 2 \
  --disk size=10 \
  --osinfo debian13 \
  --network network=default \
  --cdrom "$image_iso"
