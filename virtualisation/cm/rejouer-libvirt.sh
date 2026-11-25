#!/usr/bin/env bash
# Rejoue les commandes des diapositives « Administrer avec libvirt » et relève les versions,
# pour recopier dans les diapositives des sorties réelles, avec les noms du fil rouge.
# Usage : sudo ./rejouer-libvirt.sh > sorties-libvirt.txt
#
# La VM ma-premiere-vm est créée sans système (disque vide) : elle démarre, mais aucun invité
# n'écoute « virsh shutdown ». Avec /dev/kvm, le domaine est de type kvm ; sans, de type qemu (TCG).
# Le script refuse de tourner si un des objets qu'il crée existe déjà, et les efface tous en fin.
set -u
export LIBVIRT_DEFAULT_URI=qemu:///system
export LC_ALL=C
corrige="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tp/libvirt/corrige" && pwd)"
run() { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1; }

vms=(ma-premiere-vm deuxieme-vm troisieme-vm)
for vm in "${vms[@]}"; do
  if virsh dominfo "$vm" > /dev/null 2>&1; then echo "La VM $vm existe déjà : rien n'est fait." >&2; exit 1; fi
done
if virsh net-info labo > /dev/null 2>&1; then echo "Le réseau labo existe déjà : rien n'est fait." >&2; exit 1; fi
type_virt=qemu
[ -w /dev/kvm ] && type_virt=kvm

nettoyer() {
  for vm in "${vms[@]}"; do
    virsh destroy "$vm" > /dev/null 2>&1
    virsh undefine "$vm" --snapshots-metadata --remove-all-storage > /dev/null 2>&1
  done
  virsh vol-delete --pool default base-ma-premiere-vm.qcow2 > /dev/null 2>&1
  virsh net-destroy labo > /dev/null 2>&1
  virsh net-undefine labo > /dev/null 2>&1
}
trap nettoyer EXIT

echo "# $(date -I) · $(uname -srm) · domaine de type $type_virt"
run 'virsh version'
run 'virt-install --version'
run 'qemu-img --version | head -1'

# Connexions
run 'env -u LIBVIRT_DEFAULT_URI virsh uri'
run 'virsh uri'

# Réseau default, pool default
run 'virsh net-list --all'
run 'virsh net-dumpxml default'
run 'ip addr show virbr0'
run 'virsh pool-list --all'

# Création (sans ISO : --import d'un disque vide), cycle de vie
run "virt-install --name ma-premiere-vm --memory 2048 --vcpus 2 --disk size=10 --osinfo debian12 \
  --network network=default --import --virt-type $type_virt --noautoconsole --graphics vnc"
run 'virsh pool-list'
run 'virsh vol-list default'
run 'virsh list --all'
run 'virsh dumpxml ma-premiere-vm | head -12'
run 'virsh dominfo ma-premiere-vm'
run 'virsh shutdown ma-premiere-vm; sleep 10; virsh domstate ma-premiere-vm'
run 'virsh destroy ma-premiere-vm'
run 'virsh list --all'

# Instantanés
run 'virsh start ma-premiere-vm'
run 'virsh snapshot-create-as ma-premiere-vm avant-tp --description "état sain"'
run 'virsh snapshot-list ma-premiere-vm'
run 'virsh destroy ma-premiere-vm'
run 'virsh snapshot-revert ma-premiere-vm avant-tp'
run 'virsh domstate ma-premiere-vm'
run 'virsh destroy ma-premiere-vm'
run 'virsh undefine ma-premiere-vm'

# Clones : copie complète, puis copie sur écriture
run "$corrige/deuxieme-vm.sh ma-premiere-vm deuxieme-vm"
run "$corrige/troisieme-vm.sh ma-premiere-vm troisieme-vm"
run 'virsh vol-list default'
run 'qemu-img info --backing-chain /var/lib/libvirt/images/troisieme-vm.qcow2'
run 'ls -sh /var/lib/libvirt/images/ma-premiere-vm.qcow2 /var/lib/libvirt/images/base-ma-premiere-vm.qcow2 /var/lib/libvirt/images/troisieme-vm.qcow2'
run 'virsh undefine troisieme-vm --remove-all-storage'
run 'virsh vol-list default'

# Réseau isolé
run "virsh net-define $corrige/labo.xml"
run 'virsh net-start labo'
run 'virsh net-list --all'
run 'virsh attach-interface deuxieme-vm network labo --model virtio --config'
run 'virsh domiflist deuxieme-vm'

# Effacer
run 'virsh undefine deuxieme-vm --remove-all-storage'
run 'virsh undefine ma-premiere-vm --snapshots-metadata --remove-all-storage'
