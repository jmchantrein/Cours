#!/bin/bash
# Deuxième VM, copie complète de la première, par virt-clone : il donne au
# clone un nom, un uuid et une adresse MAC neufs, et copie chaque disque dans
# un nouveau volume du même pool. C'est ce qu'on ferait à la main en
# modifiant la sortie de virsh dumpxml, sans risque d'oubli.
#
# Usage : ./deuxieme-vm.sh [VM d'origine] [nom du clone]
set -euo pipefail

export LIBVIRT_DEFAULT_URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"

vm_origine="${1:-ma-premiere-vm}"
vm_clone="${2:-deuxieme-vm}"

# Un disque copié pendant que la VM écrit dessus est incohérent :
# virt-clone refuse une VM en marche, on le vérifie avant lui.
# (virsh list --name ne traduit rien, contrairement à virsh domstate.)
vm_eteintes="$(virsh list --name --state-shutoff)"
if ! grep -qxF "$vm_origine" <<< "$vm_eteintes"; then
  echo "$vm_origine n'est pas éteinte, ou n'existe pas : virsh shutdown $vm_origine" >&2
  exit 1
fi

# --auto-clone : nom du nouveau volume tiré du nom du clone.
virt-clone --original "$vm_origine" --name "$vm_clone" --auto-clone

# Ce qui change d'une VM à l'autre.
for vm in "$vm_origine" "$vm_clone"; do
  echo "== $vm"
  virsh domuuid "$vm"
  virsh domiflist "$vm"
  virsh domblklist "$vm"
done
