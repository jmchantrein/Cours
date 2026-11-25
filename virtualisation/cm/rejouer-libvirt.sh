#!/usr/bin/env bash
# Rejoue les commandes des diapositives « Administrer avec libvirt » et relève les versions,
# pour recopier dans les diapositives des sorties réelles, avec les noms du fil rouge.
# Usage : sudo ./rejouer-libvirt.sh > sorties-libvirt.txt
#
# Le script tourne en root (qemu:///system), mais la diapositive « Deux connexions » montre la sortie
# d'un compte ordinaire (qemu:///session) : il la rejoue sous le compte qui a lancé sudo ($SUDO_USER),
# ou sous celui de COMPTE_ORDINAIRE=nom si la variable est posée. Sans compte ordinaire, il le dit
# et saute cette commande.
#
# La VM ma-premiere-vm est créée sans système (disque vide). Pour que « virsh shutdown » ait un effet,
# elle peut démarrer un invité minimal qui écoute l'ACPI : ./invite-acpi.sh /var/lib/libvirt/invite-acpi,
# puis sudo INVITE_ACPI=/var/lib/libvirt/invite-acpi ./rejouer-libvirt.sh. Sans INVITE_ACPI, aucun invité
# n'écoute : shutdown n'éteint rien, et le script le signale (la sortie de la diapositive est alors « à rejouer »).
# Avec /dev/kvm, le domaine est de type kvm ; sans, de type qemu (TCG).
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
amorce=""   # noyau et initramfs de l'invité ACPI, s'il est fourni
if [ -n "${INVITE_ACPI:-}" ]; then
  amorce="--boot kernel=$INVITE_ACPI/vmlinuz-virt,initrd=$INVITE_ACPI/initrd.gz,cmdline=console=ttyS0"
fi

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
compte="${SUDO_USER:-${COMPTE_ORDINAIRE:-}}"
if [ -n "$compte" ] && [ "$compte" != root ]; then
  printf '\n$ virsh uri   # compte ordinaire %s, LIBVIRT_DEFAULT_URI non définie\n' "$compte"
  runuser -u "$compte" -- env -u LIBVIRT_DEFAULT_URI HOME="$(getent passwd "$compte" | cut -d: -f6)" virsh uri 2>&1
else
  printf '\n# virsh uri sous un compte ordinaire : non rejoué (lancer par sudo depuis ce compte, ou COMPTE_ORDINAIRE=nom)\n'
fi
run 'env -u LIBVIRT_DEFAULT_URI virsh uri   # root'
run 'virsh uri'

# Réseau default, pool default
run 'virsh net-list --all'
run 'virsh net-dumpxml default'
run 'ip addr show virbr0'
run 'virsh pool-list --all'

# Création (sans ISO : --import d'un disque vide), cycle de vie
run "virt-install --name ma-premiere-vm --memory 2048 --vcpus 2 --disk size=10 --osinfo debian12 \
  --network network=default --import --virt-type $type_virt --noautoconsole --graphics vnc $amorce"
run 'virsh pool-list'
run 'virsh vol-list default'
run 'virsh list --all'
run 'virsh dumpxml ma-premiere-vm | head -12'
run 'virsh dominfo ma-premiere-vm'
# shutdown : l'invité reçoit le bouton d'alimentation ACPI. En TCG il lui faut quelques secondes pour démarrer
# avant de l'entendre, et pour s'éteindre ensuite.
[ -n "$amorce" ] && sleep 20
run 'virsh shutdown ma-premiere-vm'
for _ in $(seq 1 60); do
  [ "$(virsh domstate ma-premiere-vm)" = "shut off" ] && break
  sleep 1
done
run 'virsh domstate ma-premiere-vm'
if [ "$(virsh domstate ma-premiere-vm)" = "shut off" ]; then
  # destroy : un second temps, sur la VM relancée (sur une VM arrêtée, destroy répondrait : domain is not running)
  run 'virsh start ma-premiere-vm'
else
  echo "# shutdown n'a rien éteint : aucun invité n'écoute l'ACPI (voir invite-acpi.sh)"
fi
run 'virsh destroy ma-premiere-vm'
run 'virsh domstate ma-premiere-vm'
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
