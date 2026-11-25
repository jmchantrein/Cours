#!/bin/bash
# Cet hôte est-il prêt pour KVM et libvirt ? Quatre contrôles, dans l'ordre
# où ils dépendent les uns des autres :
#   1. le processeur expose la virtualisation matérielle (vmx = Intel VT-x,
#      svm = AMD-V) ;
#   2. le module kvm est chargé : /dev/kvm existe ;
#   3. votre compte peut ouvrir /dev/kvm (groupe kvm) : un simple avertissement,
#      car avec qemu:///system c'est QEMU, lancé par libvirt sous le compte
#      libvirt-qemu, qui ouvre /dev/kvm, pas vous. Le groupe kvm ne sert qu'à
#      lancer QEMU soi-même, comme dans le mini TP ;
#   4. libvirt répond sur la connexion qemu:///system (groupe libvirt).
# Le script constate, il ne corrige rien. Code de sortie 0 : tout est prêt
# (un avertissement n'empêche pas d'utiliser libvirt) ; 1 sinon.
set -uo pipefail

connexion="qemu:///system"
pret=0

# virsh version interroge le démon : c'est le test qui compte, quel que soit
# le nom du service (libvirtd, ou virtqemud sur les distributions qui ont
# adopté les démons modulaires).
libvirt_repond=0
virsh --connect "$connexion" version > /dev/null 2>&1 && libvirt_repond=1

nb_processeurs="$(grep -cE 'vmx|svm' /proc/cpuinfo)"
if [ "$nb_processeurs" -gt 0 ]; then
  echo "OK     processeur : virtualisation matérielle exposée ($nb_processeurs processeurs logiques vmx/svm)"
else
  echo "ÉCHEC  processeur : ni vmx ni svm dans /proc/cpuinfo"
  echo "       → activer la virtualisation (VT-x, AMD-V, SVM) dans l'UEFI de la machine"
  pret=1
fi

if [ -c /dev/kvm ]; then
  echo "OK     noyau : /dev/kvm présent (module kvm chargé)"
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "OK     droits : votre compte peut ouvrir /dev/kvm"
  else
    echo "AVERT  droits : votre compte ne peut pas ouvrir /dev/kvm (groupe $(stat -c %G /dev/kvm))"
    echo "       → sans conséquence tant que $connexion répond (contrôle suivant) : libvirt lance QEMU sous un autre compte."
    echo "         Pour lancer QEMU vous-même (mini TP) : sudo adduser \"\$USER\" kvm, puis rouvrir la session"
  fi
else
  echo "ÉCHEC  noyau : /dev/kvm absent"
  echo "       → sudo modprobe kvm_intel (ou kvm_amd) ; sinon voir le contrôle du processeur"
  pret=1
fi

if [ "$libvirt_repond" -eq 1 ]; then
  echo "OK     libvirt : $connexion répond"
else
  echo "ÉCHEC  libvirt : $connexion ne répond pas"
  echo "       → paquet libvirt-daemon-system installé ? sudo adduser \"\$USER\" libvirt, puis rouvrir la session"
  pret=1
fi

exit "$pret"
