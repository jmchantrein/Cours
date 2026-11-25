#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Administrer des VM avec libvirt ».
#
# Il valide et exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé
# affiche : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--keep]
#   --lint   (défaut) sans rien créer : bash -n et shellcheck des scripts,
#            virt-xml-validate des XML contre les schémas de libvirt.
#   --up     --lint, puis le cycle complet sur qemu:///system, en émulation
#            (domaine de type qemu, TCG) : /dev/kvm n'est pas nécessaire.
#   --keep   ne nettoie pas en fin de test (pour examiner un échec).
#
# Ce que --up vérifie :
#   verifier-hote.sh  son code de sortie dit si l'hôte est prêt (processeur,
#                     /dev/kvm, connexion qemu:///system) ;
#   reseau-default.xml et labo.xml, renommés : net-define, net-start, le pont
#                     existe sur l'hôte ;
#   vm-exemple.xml    (pool, volume et réseau renommés) : define, l'état est
#                     « shut off », start, l'état est « running » ;
#   deuxieme-vm.sh    le clone a un nom, un uuid, une adresse MAC et un volume
#                     neufs ;
#   troisieme-vm.sh   le disque s'appuie sur la base (qemu-img info), il pèse
#                     moins de 1 Mio, la VM démarre ; undefine
#                     --remove-all-storage supprime son disque, pas la base ;
#   instantanés       snapshot-create-as sur la VM en marche, destroy, puis
#                     snapshot-revert la remet en marche ; undefine est refusé
#                     tant qu'il reste un instantané ; undefine
#                     --snapshots-metadata --remove-all-storage efface la VM
#                     et son volume.
# Non testé (il faut un invité installé ou un écran) : premiere-vm.sh (lint
# seulement), l'installation de Debian, SSH et domifaddr, l'extinction ACPI
# (shutdown), la configuration réseau dans l'invité, virt-manager.
#
# Le harnais ne crée et ne supprime que des ressources préfixées « tptest » :
# domaines tptest-vm, tptest-vm-2, tptest-vm-3 ; réseaux tptest-nat (pont
# tptestbr0, 192.168.250.0/24) et tptest-labo (pont tptestbr1,
# 192.168.251.0/24) ; pool tptest-pool, dans un répertoire temporaire. Il ne
# touche ni au réseau default, ni au pool default, ni à vos VM.
#
# Prérequis de --lint : bash, shellcheck, virt-xml-validate (libvirt-clients).
# Prérequis de --up : en plus libvirt-daemon-system, qemu-system-x86,
# qemu-utils, virtinst (virt-clone), dnsmasq-base, iproute2 ; et l'accès à
# qemu:///system : root, membre du groupe libvirt, ou sudo sans mot de passe
# (le harnais se relance alors avec sudo).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
connexion="qemu:///system"
export LIBVIRT_DEFAULT_URI="$connexion"
# Messages de virsh en anglais : le harnais lit les états (« running »).
export LC_ALL=C

mode="lint"; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,45p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian ou Ubuntu qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}
exiger bash bash
exiger shellcheck shellcheck
exiger virt-xml-validate libvirt-clients
if [ "$mode" = "up" ]; then
  exiger virsh libvirt-clients
  exiger qemu-system-x86_64 qemu-system-x86
  exiger qemu-img qemu-utils
  exiger virt-clone virtinst
  exiger ip iproute2
  if ! virsh --connect "$connexion" version > /dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ] && sudo -n true 2> /dev/null; then
      echo "qemu:///system refuse ce compte : le harnais se relance avec sudo."
      exec sudo -n env PATH="$PATH" bash "$0" "$@"
    fi
    echo "La connexion $connexion ne répond pas : libvirt-daemon-system est-il installé et le démon démarré ?" >&2
    echo "Il faut aussi être root, ou membre du groupe libvirt." >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
silencieux() { "$@" > /dev/null 2>&1 || true; }

# ------------------------------------------------------------------ validation

titre "Lint : scripts et XML de corrige/"
for script in "$corrige"/*.sh "$0"; do
  nom="${script#"$ici"/}"
  if bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  if shellcheck "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  if [ "$script" != "$0" ]; then
    if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
  fi
done

valider() { # $1 fichier  $2 schéma (domain, network…)
  local nom="${1#"$ici"/}"
  if virt-xml-validate "$1" "$2" > /dev/null; then ok "$nom : conforme au schéma $2"
  else ko "$nom : non conforme au schéma $2"; virt-xml-validate "$1" "$2" || true; fi
}
valider "$corrige/vm-exemple.xml" domain
valider "$corrige/reseau-default.xml" network
valider "$corrige/labo.xml" network

if [ "$mode" = "lint" ]; then
  printf '\n======== Bilan (--lint) : %s vérifications réussies, %s en échec ========\n' "$reussis" "${#echecs[@]}"
  [ "${#echecs[@]}" -eq 0 ] || { printf '  - %s\n' "${echecs[@]}"; exit 1; }
  exit 0
fi

# ------------------------------------------------------------------- nettoyage

travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
# QEMU tourne sous un compte dédié (libvirt-qemu) : il doit traverser le dossier.
chmod 755 "$travail"
pool="tptest-pool"
dossier_pool="$travail/pool"
domaines=(tptest-vm tptest-vm-2 tptest-vm-3)
reseaux=(tptest-nat tptest-labo)

nettoyer() {
  for d in "${domaines[@]}"; do
    silencieux virsh destroy "$d"
    silencieux virsh undefine "$d" --snapshots-metadata --remove-all-storage
    silencieux virsh undefine "$d" --snapshots-metadata
  done
  for r in "${reseaux[@]}"; do
    silencieux virsh net-destroy "$r"
    silencieux virsh net-undefine "$r"
  done
  if virsh pool-info "$pool" > /dev/null 2>&1; then
    for v in $(virsh vol-list --pool "$pool" 2> /dev/null | awk 'NR > 2 && NF { print $1 }'); do
      silencieux virsh vol-delete --pool "$pool" "$v"
    done
    silencieux virsh pool-destroy "$pool"
    silencieux virsh pool-undefine "$pool"
  fi
}
en_sortie() {
  if [ -z "$garder" ]; then nettoyer; rm -rf -- "$travail" "$dossier_pool"
  else echo "--keep : ressources « tptest » conservées ; fichiers dans $travail et $dossier_pool"; fi
}
trap en_sortie EXIT
nettoyer # restes d'un test interrompu

# Dès ici, une commande qui échoue ne doit pas arrêter le harnais en silence : chaque commande
# virsh passe par essayer(), qui note l'échec comme une vérification en échec, avec le message
# de la commande. Le bilan s'affiche donc toujours.
set +e

diagnostic() { # $1 domaine : ce qui explique un refus d'accès au disque (permissions, AppArmor, journal QEMU)
  local d="$1" disque
  disque="$(virsh domblklist "$d" 2> /dev/null | awk 'NR > 2 && $1 == "vda" { print $2 }')"
  case "$disque" in /*) ;; *) disque="$(virsh vol-path --pool "$pool" "$disque" 2> /dev/null)" ;; esac
  {
    echo "  --- diagnostic de $d ---"
    echo "  disque : ${disque:-inconnu}"
    [ -n "$disque" ] && command -v namei > /dev/null && namei -l "$disque" 2>&1
    echo "  compte de QEMU (qemu.conf) : $(grep -E '^[[:space:]]*(user|group|security_driver|dynamic_ownership)[[:space:]]*=' /etc/libvirt/qemu.conf 2> /dev/null | tr '\n' ' ')"
    echo "  module de sécurité : $(cat /sys/module/apparmor/parameters/enabled 2> /dev/null || echo aucun)"
    [ -r "/var/log/libvirt/qemu/$d.log" ] && { echo "  journal QEMU :"; tail -n 5 "/var/log/libvirt/qemu/$d.log"; }
    command -v dmesg > /dev/null && dmesg 2> /dev/null | grep -iE 'apparmor.*(DENIED|denied)' | tail -n 5
    command -v journalctl > /dev/null && journalctl -k --no-pager -n 400 2> /dev/null | grep -iE 'apparmor.*DENIED' | tail -n 5
  } 2>&1 | sed 's/^/       /'
}
essayer() { # $1 libellé  $2… commande : OK si elle réussit, ÉCHEC avec son message sinon ; garde son code de sortie
  local libelle="$1" journal code
  shift
  journal="$(mktemp "$travail/essai.XXXXXX")"
  "$@" > /dev/null 2> "$journal"; code=$?
  if [ "$code" -eq 0 ]; then rm -f "$journal"; return 0; fi
  ko "$libelle : $(tr '\n' ' ' < "$journal")"
  rm -f "$journal"
  return "$code"
}
demarrer() { # $1 domaine  $2 contexte : virsh start ; un refus d'accès au disque est expliqué
  essayer "$2 : virsh start $1" virsh start "$1" || diagnostic "$1"
}

etat() { virsh domstate "$1" 2> /dev/null | head -1; }
attendre_etat() { # $1 domaine  $2 état attendu : quelques secondes au plus
  for _ in $(seq 1 20); do
    [ "$(etat "$1")" = "$2" ] && return 0
    sleep 0.5
  done
  return 1
}
verifier_etat() { # $1 domaine  $2 état attendu  $3 contexte
  if attendre_etat "$1" "$2"; then ok "$3 : $1 est « $2 »"
  else ko "$3 : $1 est « $(etat "$1") », « $2 » attendu"; fi
}
volume_existe() { virsh vol-key --pool "$pool" "$1" > /dev/null 2>&1; }

# ------------------------------------------------------------- verifier-hote.sh

titre "verifier-hote.sh"
attendu=0
grep -qE 'vmx|svm' /proc/cpuinfo || attendu=1
{ [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; } || attendu=1
virsh --connect "$connexion" version > /dev/null 2>&1 || attendu=1
"$corrige/verifier-hote.sh" > "$travail/verifier-hote.log" 2>&1; obtenu=$?
sed 's/^/       /' "$travail/verifier-hote.log"
if [ "$obtenu" -eq "$attendu" ]; then ok "verifier-hote.sh : code de sortie $obtenu, conforme à cet hôte"
else ko "verifier-hote.sh : code de sortie $obtenu, $attendu attendu"; fi

# --------------------------------------------------------------------- réseaux

titre "Réseaux : reseau-default.xml et labo.xml"
definir_reseau() { # $1 fichier source  $2 nom  $3 pont  $4 troisième octet
  local xml="$travail/$2.xml"
  sed -e "s|<name>[^<]*</name>|<name>$2</name>|" \
      -e "s|<bridge name=\"[^\"]*\"/>|<bridge name=\"$3\"/>|" \
      -e "s|192\.168\.[0-9]*\.|192.168.$4.|g" "$1" > "$xml"
  valider "$xml" network
  if virsh net-define "$xml" > /dev/null && virsh net-start "$2" > /dev/null; then
    ok "${1#"$ici"/} (renommé $2) : net-define, net-start"
    if ip link show "$3" > /dev/null 2>&1; then ok "$2 : le pont $3 existe sur l'hôte"
    else ko "$2 : le pont $3 est absent de l'hôte"; fi
  else
    ko "${1#"$ici"/} (renommé $2) : net-define ou net-start"
  fi
}
definir_reseau "$corrige/reseau-default.xml" tptest-nat tptestbr0 250
definir_reseau "$corrige/labo.xml" tptest-labo tptestbr1 251
if grep -q "<forward mode='nat'" <<< "$(virsh net-dumpxml tptest-nat)"; then ok "tptest-nat : <forward/> vaut mode nat"
else ko "tptest-nat : le mode nat n'apparaît pas dans net-dumpxml"; fi
if grep -q '<forward' <<< "$(virsh net-dumpxml tptest-labo)"; then ko "tptest-labo : un élément forward est apparu"
else ok "tptest-labo : isolé, sans élément forward"; fi

# ----------------------------------------------------------------- vm-exemple.xml

titre "Domaine : vm-exemple.xml"
mkdir -p "$dossier_pool"; chmod 755 "$dossier_pool"
essayer "pool-define-as $pool" virsh pool-define-as "$pool" dir --target "$dossier_pool"
essayer "pool-start $pool" virsh pool-start "$pool"
essayer "vol-create-as tptest-vm.qcow2" virsh vol-create-as "$pool" tptest-vm.qcow2 1G --format qcow2
xml_vm="$travail/tptest-vm.xml"
sed -e 's|<domain type="kvm">|<domain type="qemu">|' \
    -e 's|<name>vm-exemple</name>|<name>tptest-vm</name>|' \
    -e 's|pool="default" volume="vm-exemple.qcow2"|pool="tptest-pool" volume="tptest-vm.qcow2"|' \
    -e 's|<source network="default"/>|<source network="tptest-labo"/>|' "$corrige/vm-exemple.xml" > "$xml_vm"
if [ "$(grep -c 'tptest' "$xml_vm")" -eq 3 ] && grep -q 'type="qemu"' "$xml_vm"; then
  ok "vm-exemple.xml : nom, pool, volume, réseau et type remplacés"
else
  ko "vm-exemple.xml : un remplacement n'a pas eu lieu (le corrigé a changé ?)"
fi
valider "$xml_vm" domain
if virsh define "$xml_vm" > /dev/null; then ok "vm-exemple.xml : virsh define"
else ko "vm-exemple.xml : virsh define"; fi
verifier_etat tptest-vm "shut off" "après define"

# ------------------------------------------------------------- deuxieme-vm.sh

titre "deuxieme-vm.sh : copie complète par virt-clone"
if "$corrige/deuxieme-vm.sh" tptest-vm tptest-vm-2 > "$travail/deuxieme-vm.log" 2>&1; then
  ok "deuxieme-vm.sh tptest-vm tptest-vm-2"
  if [ "$(virsh domuuid tptest-vm)" != "$(virsh domuuid tptest-vm-2)" ]; then ok "le clone a un uuid neuf"
  else ko "le clone a le même uuid"; fi
  mac() { virsh domiflist "$1" | awk 'NR > 2 && NF { print $5 }'; }
  if [ -n "$(mac tptest-vm-2)" ] && [ "$(mac tptest-vm)" != "$(mac tptest-vm-2)" ]; then ok "le clone a une adresse MAC neuve"
  else ko "le clone a la même adresse MAC"; fi
  if volume_existe tptest-vm-2.qcow2; then ok "le clone a son volume, tptest-vm-2.qcow2, dans le pool"
  else ko "le volume tptest-vm-2.qcow2 est absent du pool"; fi
else
  ko "deuxieme-vm.sh tptest-vm tptest-vm-2"; cat "$travail/deuxieme-vm.log"
fi
demarrer tptest-vm "démarrage avant le refus de clonage"
if "$corrige/deuxieme-vm.sh" tptest-vm tptest-vm-refus > /dev/null 2>&1; then
  ko "deuxieme-vm.sh accepte une VM en marche"; silencieux virsh undefine tptest-vm-refus --remove-all-storage
else
  ok "deuxieme-vm.sh refuse une VM en marche"
fi
essayer "destroy tptest-vm" virsh destroy tptest-vm

# ------------------------------------------------------------ troisieme-vm.sh

titre "troisieme-vm.sh : copie sur écriture"
if "$corrige/troisieme-vm.sh" tptest-vm tptest-vm-3 > "$travail/troisieme-vm.log" 2>&1; then
  ok "troisieme-vm.sh tptest-vm tptest-vm-3"
  disque="$(virsh vol-path --pool "$pool" tptest-vm-3.qcow2)"
  base="$(virsh vol-path --pool "$pool" base-tptest-vm.qcow2)"
  if grep -qxF "backing file: $base" <<< "$(qemu-img info -U "$disque")"; then ok "tptest-vm-3.qcow2 s'appuie sur base-tptest-vm.qcow2 (qemu-img info)"
  else ko "tptest-vm-3.qcow2 ne s'appuie pas sur la base"; qemu-img info -U "$disque"; fi
  if [ "$(grep -c '^image:' <<< "$(qemu-img info -U --backing-chain "$disque")")" -eq 2 ]; then ok "qemu-img info --backing-chain : deux images dans la chaîne"
  else ko "qemu-img info --backing-chain ne montre pas deux images"; fi
  if grep -qF "<path>$base</path>" "$travail/troisieme-vm.log"; then ok "troisieme-vm.sh affiche l'image de base vue par libvirt"
  else ko "troisieme-vm.sh n'affiche pas l'image de base"; cat "$travail/troisieme-vm.log"; fi
  octets="$(du -B1 "$disque" | cut -f1)"
  if [ "$octets" -lt 1048576 ]; then ok "le disque de la VM occupe $octets octets, moins de 1 Mio"
  else ko "le disque de la VM occupe $octets octets"; fi
  if grep -qF "$disque" <<< "$(virsh dumpxml tptest-vm-3)"; then ok "tptest-vm-3 est branchée sur ce disque"
  else ko "tptest-vm-3 n'est pas branchée sur tptest-vm-3.qcow2"; fi
  demarrer tptest-vm-3 "start sur le disque adossé"
  verifier_etat tptest-vm-3 running "start sur le disque adossé"
  essayer "destroy tptest-vm-3" virsh destroy tptest-vm-3
  essayer "undefine tptest-vm-3 --remove-all-storage" virsh undefine tptest-vm-3 --remove-all-storage
  if volume_existe tptest-vm-3.qcow2; then ko "undefine --remove-all-storage a laissé tptest-vm-3.qcow2"
  else ok "undefine --remove-all-storage supprime le disque de la VM"; fi
  if volume_existe base-tptest-vm.qcow2; then ok "… et conserve l'image de base"
  else ko "undefine --remove-all-storage a supprimé l'image de base"; fi
else
  ko "troisieme-vm.sh tptest-vm tptest-vm-3"; cat "$travail/troisieme-vm.log"
fi

# ------------------------------------------------------------------ instantanés

titre "Cycle de vie et instantanés"
demarrer tptest-vm "start"
verifier_etat tptest-vm running "start"
if virsh snapshot-create-as tptest-vm avant-tp --description "état sain" > /dev/null; then
  ok "snapshot-create-as sur la VM en marche (BIOS : instantané interne)"
else
  ko "snapshot-create-as"
fi
if grep -qx avant-tp <<< "$(virsh snapshot-list --name tptest-vm)"; then ok "snapshot-list montre avant-tp"
else ko "snapshot-list ne montre pas avant-tp"; fi
essayer "destroy tptest-vm" virsh destroy tptest-vm
verifier_etat tptest-vm "shut off" "destroy"
if virsh snapshot-revert tptest-vm avant-tp > /dev/null; then ok "snapshot-revert"
else ko "snapshot-revert"; fi
verifier_etat tptest-vm running "snapshot-revert d'un instantané pris en marche"
essayer "destroy tptest-vm (après revert)" virsh destroy tptest-vm
if virsh undefine tptest-vm > "$travail/undefine.log" 2>&1; then
  ko "undefine accepte une VM qui a un instantané"
elif grep -q 'snapshot' "$travail/undefine.log"; then
  ok "undefine refusé tant qu'il reste un instantané : $(grep -o 'cannot.*' "$travail/undefine.log")"
else
  ko "undefine refusé pour une autre raison : $(cat "$travail/undefine.log")"
fi
if virsh undefine tptest-vm --snapshots-metadata --remove-all-storage > /dev/null; then
  ok "undefine --snapshots-metadata --remove-all-storage"
else
  ko "undefine --snapshots-metadata --remove-all-storage"
fi
if virsh dominfo tptest-vm > /dev/null 2>&1; then ko "tptest-vm est encore définie"
else ok "tptest-vm n'est plus définie"; fi
if volume_existe tptest-vm.qcow2; then ko "le volume tptest-vm.qcow2 est resté"
else ok "le volume tptest-vm.qcow2 est supprimé"; fi

# ----------------------------------------------------------------------- bilan

printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec ========\n' "$mode" "$reussis" "${#echecs[@]}"
if [ "${#echecs[@]}" -gt 0 ]; then
  printf '  - %s\n' "${echecs[@]}"
  exit 1
fi
