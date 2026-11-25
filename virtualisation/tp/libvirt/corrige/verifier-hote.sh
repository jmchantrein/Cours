#!/bin/bash
# Cet hôte est-il prêt pour KVM et libvirt ? Quatre contrôles, dans l'ordre
# où ils dépendent les uns des autres :
#   1. le processeur expose la virtualisation matérielle (vmx = Intel VT-x,
#      svm = AMD-V) ;
#   2. le module kvm est chargé : /dev/kvm existe ;
#   3. votre compte peut ouvrir /dev/kvm (groupe kvm) ;
#   4. libvirt répond sur la connexion qemu:///system (groupe libvirt).
# Le script constate, il ne corrige rien. Code de sortie 0 : tout est prêt.
set -uo pipefail

connexion="qemu:///system"
pret=0

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
    echo "ÉCHEC  droits : /dev/kvm appartient au groupe $(stat -c %G /dev/kvm), dont vous n'êtes pas membre"
    echo "       → sudo adduser \"\$USER\" kvm, puis fermer et rouvrir la session"
    pret=1
  fi
else
  echo "ÉCHEC  noyau : /dev/kvm absent"
  echo "       → sudo modprobe kvm_intel (ou kvm_amd) ; sinon voir le contrôle du processeur"
  pret=1
fi

# virsh version interroge le démon : c'est le test qui compte, quel que soit
# le nom du service (libvirtd, ou virtqemud sur les distributions qui ont
# adopté les démons modulaires).
if virsh --connect "$connexion" version > /dev/null 2>&1; then
  echo "OK     libvirt : $connexion répond"
else
  echo "ÉCHEC  libvirt : $connexion ne répond pas"
  echo "       → paquet libvirt-daemon-system installé ? sudo adduser \"\$USER\" libvirt, puis rouvrir la session"
  pret=1
fi

exit "$pret"
