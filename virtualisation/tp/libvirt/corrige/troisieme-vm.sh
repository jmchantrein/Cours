#!/bin/bash
# Troisième VM, en copie sur écriture : une image de base figée, et pour la
# VM un disque qcow2 qui ne garde que ses différences (backing file).
#   1. la base : une copie du disque de la VM d'origine, éteinte ;
#   2. le disque de la nouvelle VM : un volume qcow2 adossé à la base ;
#   3. la VM : un clone de la définition de la VM d'origine, branché sur ce
#      disque (--preserve-data : virt-clone ne copie rien).
# Après coup, la base ne doit plus jamais être modifiée ni démarrée.
#
# Usage : ./troisieme-vm.sh [VM d'origine] [nom de la VM]
set -euo pipefail

export LIBVIRT_DEFAULT_URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"

vm_origine="${1:-ma-premiere-vm}"
vm_nouvelle="${2:-troisieme-vm}"
volume_base="base-$vm_origine.qcow2"
volume_vm="$vm_nouvelle.qcow2"

# (virsh list --name ne traduit rien, contrairement à virsh domstate.)
vm_eteintes="$(virsh list --name --state-shutoff)"
if ! grep -qxF "$vm_origine" <<< "$vm_eteintes"; then
  echo "$vm_origine n'est pas éteinte, ou n'existe pas : virsh shutdown $vm_origine" >&2
  exit 1
fi

# Premier disque de la VM d'origine (vda) : un chemin, comme dans une VM créée
# par virt-install. La base et le nouveau disque iront dans le pool qui le contient.
disque_origine="$(virsh domblklist "$vm_origine" | awk '$1 == "vda" { print $2 }')"
case "$disque_origine" in
  "") echo "$vm_origine n'a pas de disque vda." >&2; exit 1 ;;
  /*) ;;
  *) echo "Le disque vda de $vm_origine n'est pas un chemin ($disque_origine)." >&2; exit 1 ;;
esac
pool="$(virsh vol-pool "$disque_origine")"

# 1. La base, si elle n'existe pas déjà : copie complète, une seule fois.
if ! virsh vol-key --pool "$pool" "$volume_base" > /dev/null 2>&1; then
  virsh vol-clone "$disque_origine" "$volume_base"
fi

# 2. Le disque de la VM : même taille virtuelle que la base (en octets, lue
#    dans le XML du volume), quelques Kio sur l'hôte. --backing-vol-format
#    évite à QEMU de deviner le format de la base.
capacite="$(virsh vol-dumpxml --pool "$pool" "$volume_base" \
  | sed -n 's:.*<capacity unit=.bytes.>\([0-9]*\)</capacity>.*:\1:p')"
virsh vol-create-as "$pool" "$volume_vm" "$capacite" --format qcow2 \
  --backing-vol "$volume_base" --backing-vol-format qcow2

# 3. La définition : nom, uuid et MAC neufs, disque = le volume adossé.
virt-clone --original "$vm_origine" --name "$vm_nouvelle" --preserve-data \
  --file "$(virsh vol-path --pool "$pool" "$volume_vm")"

# La chaîne, vue par libvirt : l'image sur laquelle s'appuie le disque de la VM
# (élément backingStore du XML du volume).
virsh vol-dumpxml --pool "$pool" "$volume_vm" \
  | sed -n '/<backingStore>/,/<\/backingStore>/{/<path>\|<format /p}'
