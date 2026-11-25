#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Incus ».
#
# Il enchaîne les scripts de corrige/, ceux-là mêmes que l'énoncé affiche, puis
# vérifie ce que l'énoncé annonce : un corrigé qui ne fonctionne plus fait
# échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--only N] [--keep]
#   --lint    (défaut) validation sans Incus : syntaxe, droits et shellcheck des
#             scripts, validité des YAML, cohérence des fichiers que l'énoncé
#             dit identiques.
#   --up      --lint, puis pour chaque étape : jouer les scripts du corrigé,
#             vérifier, nettoyer.
#   --only N  ne traite que l'étape N (1 à 7). En mode --up, les étapes 2 à 4
#             rejouent d'abord celles dont elles dépendent (la VM de l'étape 1,
#             le site de l'étape 2).
#   --keep    ne nettoie pas en fin de test (pour examiner un échec).
#
# Ce que --up vérifie, étape par étape :
#   1  vm1 est une machine virtuelle, un processus QEMU de l'hôte sous un compte
#      sans privilège ; son système se sait sous KVM ; elle joint les dépôts ;
#   2  WordPress répond en HTTP, joint sa base et s'installe ;
#   3  l'instantané restaure le site cassé ; Incus 6.0 refuse d'augmenter à
#      chaud la mémoire de la VM ; après redémarrage elle a 2 processeurs et
#      2 Gio, et ses services sont revenus seuls ;
#   4  le conteneur partage le noyau de l'hôte et la VM non ; ses processus
#      sont visibles de l'hôte sous des UID décalés ; il voit la mémoire de
#      l'hôte, puis sa limite ; le proxy publie son port 80 sur le port 8080
#      de l'hôte ; la même commande est refusée sur la VM, que le mode NAT
#      publie sur le port 8081 ;
#   5  le profil wordpress produit un WordPress fonctionnel dans une VM et dans
#      un conteneur ; une clé posée sur l'instance l'emporte sur celle du
#      profil ; sans le profil default, pas de disque racine ;
#   6  web et db se joignent par leur nom ; le site survit à la suppression de
#      l'instance db, ses données étant sur le volume ;
#   7  Docker exécute un conteneur applicatif dans la VM.
#
# Isolation : tout est créé dans un projet Incus « tptest », relié à un pont à
# lui, « tptestbr0 ». Les scripts tournent tels quels (variable INCUS_PROJECT),
# avec les noms de l'énoncé ; le harnais ne touche à aucune instance, aucun
# profil, aucun volume du projet default. Un pont à part est nécessaire : Incus
# refuse deux instances de même nom sur un même pont, même dans deux projets.
# Le harnais a besoin des ports 8080 et 8081 de l'hôte, et du pool de stockage
# « default » que crée « incus admin init --minimal ».
#
# Prérequis de --up : bash, curl, Incus initialisé et joignable par le compte
# courant (groupe incus-admin), /dev/kvm, le réseau (images.linuxcontainers.org,
# dépôts Debian ; Docker Hub pour l'étape 7). Si Docker est installé sur
# l'hôte, autorisez le pont « tptestbr0 » dans la chaîne DOCKER-USER (voir
# l'énoncé, « Avant de commencer »).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
projet="tptest"
pont="tptestbr0"

mode="lint"; seule=""; garder=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --only) seule="${2:-}"; shift ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,50p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
case "$seule" in "" | [1-7]) ;; *) echo "--only attend un numéro d'étape, de 1 à 7." >&2; exit 2 ;; esac

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
info() { printf '       %s\n' "$*"; }
retrait() { sed 's/^/       | /'; }
titre_etape() { printf '\n======== Étape %s — %s (corrige/%s) ========\n' "$1" "$3" "$2"; }

# Étape à traiter ? En mode --up, les étapes 2 à 4 dépendent des précédentes.
voulue() { # $1 étape
  [ -z "$seule" ] && return 0
  [ "$seule" = "$1" ] && return 0
  [ "$mode" = "up" ] || return 1
  case "$seule:$1" in 2:1 | 3:1 | 3:2 | 4:1 | 4:2) return 0 ;; esac
  return 1
}

# ------------------------------------------------------------------ validation

verifier_script() { # $1 script, relatif à corrige/
  local script="$corrige/$1"
  if ! sh -n "$script"; then ko "syntaxe $1"; return 0; fi
  if [ ! -x "$script" ]; then ko "$1 n'est pas exécutable (chmod +x)"; return 0; fi
  if command -v shellcheck > /dev/null && ! shellcheck "$script"; then ko "shellcheck $1"; return 0; fi
  # L'isolation du harnais repose sur ces deux règles.
  if grep -q -e 'incusbr0' -e '--project' "$script"; then
    ko "$1 nomme le pont incusbr0 ou un projet : le harnais ne pourrait plus l'isoler"; return 0
  fi
  ok "script $1"
}

identiques() { # $1 $2 fichiers que l'énoncé dit identiques, relatifs à corrige/
  if cmp -s "$corrige/$1" "$corrige/$2"; then ok "identiques : $1 et $2"
  else ko "$1 et $2 diffèrent"; fi
}

# PyYAML n'est pas toujours installé : sans lui, les YAML ne sont pas vérifiés.
yaml_dispo=""
if command -v python3 > /dev/null && python3 -c 'import yaml' 2> /dev/null; then yaml_dispo="1"; fi

# Le fichier cloud-init : première ligne « #cloud-config », YAML valide, clés
# attendues, et fichiers de write_files identiques à ceux de l'étape 2.
verifier_cloud_init() { # $1 fichier cloud-init  $2 dossier des fichiers de référence
  local fichier="$corrige/$1" sortie
  if [ "$(head -n 1 "$fichier")" != "#cloud-config" ]; then
    ko "$1 : la première ligne doit être « #cloud-config »"; return 0
  fi
  if [ -z "$yaml_dispo" ]; then info "(python3 avec PyYAML indisponible : $1 non vérifié)"; return 0; fi
  if sortie="$(python3 - "$fichier" "$corrige/$2" 2>&1 << 'PYTHON'
import os, sys, yaml

fichier, reference = sys.argv[1], sys.argv[2]
with open(fichier, encoding="utf-8") as f:
    config = yaml.safe_load(f)
if not isinstance(config, dict):
    sys.exit("le document n'est pas un dictionnaire YAML")
for cle, genre in (("packages", list), ("write_files", list), ("runcmd", list)):
    if not isinstance(config.get(cle), genre):
        sys.exit(f"clé {cle} absente ou mal typée")
for entree in config["write_files"]:
    nom = os.path.basename(entree["path"])
    with open(os.path.join(reference, nom), encoding="utf-8") as f:
        if f.read() != entree["content"]:
            sys.exit(f"{entree['path']} diffère de {os.path.basename(reference)}/{nom}")
    print(f"{entree['path']} = {os.path.basename(reference)}/{nom}")
PYTHON
  )"; then
    ok "cloud-init $1 : YAML valide, fichiers identiques à ceux de $2"
    retrait <<< "$sortie"
  else
    ko "cloud-init $1 : $sortie"
  fi
}

# ------------------------------------------------- mode --up : préalables, isolation

travail=""
isolation_prete=""

mourir() { printf '%s\n' "$@" >&2; exit 1; }

# Suppression de tout ce que le harnais a pu créer. Appelée avant le test
# (restes d'un test interrompu) et en sortie. Les options --project sont
# explicites : la fonction ne dépend pas de INCUS_PROJECT.
nettoyer_tout() {
  local i
  if incus project show "$projet" > /dev/null 2>&1; then
    for i in $(incus list --project "$projet" -c n -f csv 2> /dev/null); do
      incus delete --force --project "$projet" "$i" > /dev/null 2>&1 || true
    done
    if ! incus project delete "$projet" --force > /dev/null 2>&1; then
      # Version d'Incus sans « project delete --force » : vider le projet à la main.
      for i in $(incus profile list --project "$projet" -c n -f csv 2> /dev/null); do
        [ "$i" = "default" ] || incus profile delete --project "$projet" "$i" > /dev/null 2>&1 || true
      done
      for i in $(incus storage volume list default --project "$projet" -c tn -f csv 2> /dev/null | sed -n 's/^custom,//p'); do
        incus storage volume delete default "$i" --project "$projet" > /dev/null 2>&1 || true
      done
      for i in $(incus image list --project "$projet" -c F -f csv 2> /dev/null); do
        incus image delete --project "$projet" "$i" > /dev/null 2>&1 || true
      done
      incus project delete "$projet" > /dev/null 2>&1 || true
    fi
  fi
  if incus network show "$pont" --project default > /dev/null 2>&1; then
    incus network delete "$pont" --project default > /dev/null 2>&1 || true
  fi
}

en_sortie() {
  [ -n "$travail" ] || return 0
  if [ -z "$garder" ]; then
    if [ -n "$isolation_prete" ]; then nettoyer_tout; fi
    rm -rf -- "$travail"
  else
    echo "--keep : projet « $projet » et pont « $pont » conservés ; journaux dans $travail"
    echo "         examiner : INCUS_PROJECT=$projet incus list"
    echo "         supprimer : incus project delete $projet --force ; incus network delete $pont"
  fi
}

port_libre() { ! (exec 3<> "/dev/tcp/127.0.0.1/$1") 2> /dev/null; }

preparer() {
  local port
  command -v incus > /dev/null || mourir "incus est introuvable dans le PATH : installez le paquet incus."
  command -v curl > /dev/null || mourir "curl est introuvable dans le PATH."
  travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest-incus.XXXXXX")"
  trap en_sortie EXIT

  # Les faits utiles au diagnostic, d'abord.
  echo "======== Environnement ========"
  info "noyau $(uname -sr), $(nproc) processeur(s), $(awk '/^MemTotal:/ { printf "%d Mio", $2 / 1024 }' /proc/meminfo)"
  info "client incus $(incus --version 2>&1 || true)"
  if [ -e /dev/kvm ]; then info "$(ls -l /dev/kvm)"; else info "/dev/kvm absent"; fi

  if ! incus info > "$travail/incus-info.txt" 2>&1; then
    retrait < "$travail/incus-info.txt" >&2
    mourir "Le démon Incus ne répond pas. Vérifiez : paquet incus installé, « incus admin init --minimal » fait," \
      "compte courant dans le groupe incus-admin (session rouverte, ou « newgrp incus-admin »)."
  fi
  grep -E '^ +(driver|driver_version|kernel_version|server_version|storage|firewall|os_name|os_version):' \
    "$travail/incus-info.txt" | retrait || true
  [ -e /dev/kvm ] || mourir "/dev/kvm est absent : pas de machine virtuelle sans KVM." \
    "Activez VT-x ou AMD-V dans l'UEFI ; dans une VM, activez la virtualisation imbriquée."
  grep -Eq '^ +driver: .*qemu' "$travail/incus-info.txt" || mourir \
    "Incus n'a pas de pilote de machines virtuelles (ligne « driver » ci-dessus, sans qemu)." \
    "Vérifiez les paquets qemu-system-x86 et ovmf, puis redémarrez le démon : systemctl restart incus."
  incus storage show default --project default > /dev/null 2>&1 || mourir \
    "Le pool de stockage « default » n'existe pas : les corrigés de l'étape 6 le nomment." \
    "« incus admin init --minimal » le crée."
  for port in 8080 8081; do
    port_libre "$port" || mourir "Le port $port de l'hôte est occupé : arrêtez ce qui l'utilise, puis relancez."
  done

  # L'isolation : un pont et un projet à part. IPv6 est coupé sur ce pont : sans
  # route IPv6 sur l'hôte (cas des machines de CI), apt attendrait pour rien.
  nettoyer_tout
  isolation_prete="1"
  incus network create "$pont" ipv6.address=none --project default > /dev/null \
    || mourir "Création du pont $pont impossible."
  incus project create "$projet" > /dev/null || mourir "Création du projet $projet impossible."
  # Le profil default d'un projet neuf est vide : le disque et la carte réseau.
  incus profile device add default root disk path=/ pool=default --project "$projet" > /dev/null \
    || mourir "Profil default du projet $projet : ajout du disque racine impossible."
  incus profile device add default eth0 nic network="$pont" name=eth0 --project "$projet" > /dev/null \
    || mourir "Profil default du projet $projet : ajout de la carte réseau impossible."
  export INCUS_PROJECT="$projet"
  info "projet $projet, pont $pont ($(incus network get "$pont" ipv4.address --project default 2>&1 || true))"
}

# --------------------------------------------------------- jouer un script du corrigé
# Le script tourne tel quel, dans le projet du harnais, avec la trace de ses
# commandes (sh -x) : en cas d'échec, la fin du journal montre la commande fautive.

jouer() { # $1 script, relatif à corrige/  $2 délai en secondes
  local journal code=0
  journal="$travail/$(tr '/' '_' <<< "$1").log"
  info "→ corrige/$1 (délai : $2 s)"
  timeout -k 30 "$2" sh -x "$corrige/$1" > "$journal" 2>&1 || code=$?
  if [ "$code" -eq 0 ]; then
    ok "script $1"
    tail -n 8 "$journal" | retrait
    return 0
  fi
  if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then ko "script $1 : délai de $2 s dépassé"
  else ko "script $1 : code de retour $code"; fi
  tail -n 80 "$journal" | retrait
  return 1
}

dans() { # $1 instance  $2… commande
  local instance="$1"; shift
  incus exec "$instance" -- "$@"
}

# Colonne d'incus list pour une instance, désignée par son nom exact.
colonne() { incus list "^$1\$" -c "$2" -f csv 2> /dev/null || true; } # $1 instance  $2 colonne

adresse() { # $1 instance : son adresse IPv4 sur le pont, attendue jusqu'à deux minutes
  local a
  for _ in $(seq 1 60); do
    a="$(colonne "$1" 4 | grep -m 1 -o '^[0-9.]*' || true)"
    if [ -n "$a" ]; then echo "$a"; return 0; fi
    sleep 2
  done
  return 1
}

# Ce qu'il faut pour comprendre un échec sans accès à la machine.
diagnostic() { # $1… instances
  local i
  echo "------ incus list"
  incus list -c ntsN4 2>&1 | retrait || true
  for i in "$@"; do
    echo "------ incus info $i --show-log (fin)"
    incus info "$i" --show-log 2>&1 | tail -n 30 | retrait || true
    echo "------ $i : services en échec, fin du journal"
    timeout 60 incus exec "$i" -- sh -c 'systemctl --failed --no-pager --no-legend; journalctl -n 25 --no-pager' 2>&1 \
      | tail -n 40 | retrait || true
  done
}

diagnostic_cloud_init() { # $1 instance
  echo "------ $1 : cloud-init status --long, fin de cloud-init-output.log"
  timeout 60 incus exec "$1" -- sh -c 'cloud-init status --long; tail -n 40 /var/log/cloud-init-output.log' 2>&1 \
    | retrait || true
}

# ------------------------------------------------------------------ HTTP, WordPress

attendre_http() { # $1 url : une réponse 2xx ou 3xx en moins de deux minutes
  local code
  for _ in $(seq 1 60); do
    code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$1" 2> /dev/null || true)"
    case "$code" in 2?? | 3??) return 0 ;; esac
    sleep 2
  done
  info "dernier code HTTP de $1 : ${code:-aucun}"
  return 1
}

# Installation de WordPress : crée les tables et le compte d'administration.
# Le formulaire (step=1) ne s'affiche que si WordPress joint sa base ; après
# l'installation, la page d'accueil porte le titre choisi, lu dans la base.
mot_de_passe_wp="tptest-$RANDOM-$RANDOM"
wp_installer() { # $1 url du site  $2 titre
  local corps pret=""
  for _ in $(seq 1 40); do
    corps="$(curl -s -m 30 "$1/wp-admin/install.php?step=1" 2> /dev/null || true)"
    if [[ "$corps" == *'name="weblog_title"'* ]]; then pret="1"; break; fi
    sleep 3
  done
  if [ -z "$pret" ]; then
    info "install.php?step=1 n'affiche pas le formulaire ; début de la réponse :"
    head -c 600 <<< "$corps" | retrait
    return 1
  fi
  curl -s -o /dev/null -m 120 \
    --data-urlencode "weblog_title=$2" --data-urlencode "user_name=tptest" \
    --data-urlencode "admin_password=$mot_de_passe_wp" --data-urlencode "admin_password2=$mot_de_passe_wp" \
    --data-urlencode "pw_weak=on" --data-urlencode "admin_email=tptest@example.org" \
    --data-urlencode "blog_public=0" --data-urlencode "language=" \
    "$1/wp-admin/install.php?step=2" || return 1
  wp_titre_present "$1" "$2"
}

wp_titre_present() { # $1 url du site  $2 titre : attendu jusqu'à une minute
  local corps
  for _ in $(seq 1 20); do
    corps="$(curl -sL -m 30 "$1/" 2> /dev/null || true)"
    if [[ "$corps" == *"<title>$2"* ]]; then return 0; fi
    sleep 3
  done
  return 1
}

wp_titre_absent() { # $1 url du site  $2 titre : un seul essai
  local corps
  corps="$(curl -sL -m 30 "$1/" 2> /dev/null || true)"
  [[ "$corps" != *"<title>$2"* ]]
}

# Un site WordPress complet sur une instance : il répond, joint sa base, s'installe.
site_wordpress() { # $1 étape  $2 instance  $3 titre ; écrit l'URL dans url_site, vide en cas d'échec
  url_site=""
  local a
  if ! a="$(adresse "$2")"; then ko "étape $1 : $2 n'a pas d'adresse IPv4"; return 1; fi
  if ! attendre_http "http://$a/"; then ko "étape $1 : $2 ne répond pas en HTTP (http://$a/)"; return 1; fi
  ok "étape $1 : $2 répond en HTTP (http://$a/)"
  if ! wp_installer "http://$a" "$3"; then ko "étape $1 : WordPress ne s'installe pas dans $2"; return 1; fi
  ok "étape $1 : dans $2, WordPress joint sa base, s'installe et affiche son titre"
  url_site="http://$a"
}

memoire_ko() { awk '/^MemTotal:/ { print $2 }'; } # MemTotal d'un /proc/meminfo lu sur l'entrée

# ============================================================================
# Préalables du mode --up
# ============================================================================

if [ "$mode" = "up" ]; then
  # Plusieurs commandes d'incus lisent leur entrée standard quand ce n'est pas
  # un terminal (create, launch, profile create…) : on la ferme une fois pour toutes.
  exec < /dev/null
  preparer
fi

vm1_prete=""     # étape 1 réussie : vm1 répond
site_vm1=""      # étape 2 réussie : URL du site de vm1
titre_vm1="tptest-vm1-$RANDOM"

# ============================================================================
# Étape 1 — instances et images
# ============================================================================

if voulue 1; then
  titre_etape 1 1_instances_images "instances et images"
  verifier_script 1_instances_images/lancer.sh
  if [ "$mode" = "up" ] && jouer 1_instances_images/lancer.sh 900; then
    vm1_prete="1"
    etat="$(colonne vm1 ts)"
    if [ "$etat" = "VIRTUAL-MACHINE,RUNNING" ]; then ok "étape 1 : vm1 est une machine virtuelle en marche"
    else ko "étape 1 : état de vm1 inattendu ($etat)"; fi

    # La VM est un processus QEMU de l'hôte, lancé sous un compte sans privilège.
    pid="$(colonne vm1 p)"
    ligne="$(ps -o user=,args= -p "${pid:-0}" 2> /dev/null || true)"
    info "PID $pid : $(cut -c 1-150 <<< "$ligne")…"
    if [[ "$ligne" == *qemu-system* && "$ligne" == *"-name vm1 "* ]]; then
      ok "étape 1 : la VM est un processus QEMU de l'hôte (PID $pid)"
    else
      ko "étape 1 : le PID $pid donné par Incus n'est pas un processus QEMU nommé vm1"
    fi
    proprietaire="${ligne%% *}"
    if [ -n "$proprietaire" ] && [ "$proprietaire" != "root" ]; then
      ok "étape 1 : ce processus tourne sous un compte sans privilège ($proprietaire)"
    else
      ko "étape 1 : le processus QEMU tourne sous « $proprietaire »"
    fi

    virt="$(dans vm1 systemd-detect-virt 2>&1 || true)"
    if [ "$virt" = "kvm" ]; then ok "étape 1 : le système invité se sait sous KVM (systemd-detect-virt)"
    else ko "étape 1 : systemd-detect-virt répond « $virt » dans vm1"; fi

    # Le réseau du pont : sans lui, aucune des étapes suivantes n'aboutit.
    joint=""
    for _ in $(seq 1 30); do
      if timeout 30 incus exec vm1 -- bash -c 'exec 3<> /dev/tcp/deb.debian.org/80' 2> /dev/null; then joint="1"; break; fi
      sleep 4
    done
    if [ -n "$joint" ]; then
      ok "étape 1 : la VM joint les dépôts Debian (pont, NAT, résolution de noms)"
    else
      ko "étape 1 : la VM ne joint pas deb.debian.org"
      info "Si Docker est installé sur l'hôte, il bloque le trafic des ponts d'Incus :"
      info "  iptables -I DOCKER-USER -i $pont -j ACCEPT"
      info "  iptables -I DOCKER-USER -o $pont -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
      incus network show "$pont" --project default 2>&1 | retrait || true
      timeout 30 incus exec vm1 -- sh -c 'ip -brief address; ip route; cat /etc/resolv.conf' 2>&1 | retrait || true
      diagnostic vm1
    fi
  elif [ "$mode" = "up" ]; then
    diagnostic vm1
  fi
fi

# ============================================================================
# Étape 2 — administrer comme une machine
# ============================================================================

if voulue 2; then
  titre_etape 2 2_administrer "administrer comme une machine"
  verifier_script 2_administrer/installer.sh
  if [ "$mode" != "up" ]; then
    :
  elif [ -z "$vm1_prete" ]; then
    ko "étape 2 : non jouée, vm1 n'est pas prête (étape 1)"
  elif jouer 2_administrer/installer.sh 1500; then
    if site_wordpress 2 vm1 "$titre_vm1"; then site_vm1="$url_site"; else diagnostic vm1; fi
  else
    diagnostic vm1
  fi
fi

# ============================================================================
# Étape 3 — instantanés et limites
# ============================================================================

if voulue 3; then
  titre_etape 3 3_instantanes_limites "instantanés et limites"
  for s in instantane.sh restaurer.sh limites.sh; do verifier_script "3_instantanes_limites/$s"; done
  if [ "$mode" != "up" ]; then
    :
  elif [ -z "$site_vm1" ]; then
    ko "étape 3 : non jouée, le site de vm1 n'est pas installé (étape 2)"
  else
    # Instantané, casse, restauration.
    if jouer 3_instantanes_limites/instantane.sh 600; then
      if incus snapshot list vm1 -f csv 2> /dev/null | grep -q '^propre,'; then
        ok "étape 3 : l'instantané propre existe"
      else
        ko "étape 3 : l'instantané propre n'apparaît pas dans incus snapshot list"
      fi
      # La casse de l'énoncé : le code de WordPress disparaît.
      dans vm1 rm -r /usr/share/wordpress || true
      if wp_titre_absent "$site_vm1" "$titre_vm1"; then
        ok "étape 3 : site cassé (code HTTP $(curl -s -o /dev/null -m 10 -w '%{http_code}' "$site_vm1/" || true))"
      else
        ko "étape 3 : le site répond encore après la suppression de son code"
      fi
      if jouer 3_instantanes_limites/restaurer.sh 900; then
        site_vm1="http://$(adresse vm1 || true)"
        if wp_titre_present "$site_vm1" "$titre_vm1"; then ok "étape 3 : l'instantané restaure le site ($site_vm1)"
        else ko "étape 3 : le site n'est pas revenu après la restauration"; diagnostic vm1; fi
      else
        diagnostic vm1
      fi
    fi

    # À chaud. L'énoncé annonce le comportement d'Incus 6.0 : la mémoire d'une VM
    # en marche ne s'augmente pas. Sur une autre série, le résultat est noté sans juger.
    version="$(incus --version 2> /dev/null || true)"
    if sortie="$(incus config set vm1 limits.memory=2GiB 2>&1)"; then
      case "$version" in
        6.0.*) ko "étape 3 : Incus $version accepte d'augmenter à chaud la mémoire de la VM, l'énoncé annonce un refus" ;;
        *) info "Incus $version accepte d'augmenter à chaud la mémoire de la VM (l'énoncé décrit la série 6.0)" ;;
      esac
    elif [[ "$sortie" == *"beyond boot time size"* ]]; then
      ok "étape 3 : à chaud, Incus refuse d'augmenter la mémoire de la VM"
      retrait <<< "$sortie"
    else
      ko "étape 3 : refus inattendu de limits.memory à chaud"
      retrait <<< "$sortie"
    fi

    # Le script ajoute un processeur à chaud, puis arrête la VM pour la mémoire.
    if jouer 3_instantanes_limites/limites.sh 900; then
      # Relevé pour l'énoncé : le processeur ajouté à chaud est-il en ligne (lscpu) ?
      sed -n '/lscpu --extended/,/incus stop vm1/p' "$travail/3_instantanes_limites_limites.sh.log" | retrait || true
      processeurs="$(dans vm1 nproc 2>&1 || true)"
      if [ "$processeurs" = "2" ]; then ok "étape 3 : après redémarrage, la VM a 2 processeurs"
      else ko "étape 3 : la VM a « $processeurs » processeur(s), 2 attendus"; fi
      memoire="$(dans vm1 cat /proc/meminfo 2> /dev/null | memoire_ko || true)"
      if [ "${memoire:-0}" -gt 1700000 ] && [ "${memoire:-0}" -le 2097152 ]; then
        ok "étape 3 : après redémarrage, la VM a 2 Gio de mémoire (MemTotal : $((memoire / 1024)) Mio)"
      else
        ko "étape 3 : MemTotal de la VM : ${memoire:-inconnu} Kio, environ 2 Gio attendus"
      fi
      site_vm1="http://$(adresse vm1 || true)"
      if wp_titre_present "$site_vm1" "$titre_vm1"; then
        ok "étape 3 : après redémarrage, Apache et MariaDB sont revenus seuls, le site répond"
      else
        ko "étape 3 : le site ne répond plus après le redémarrage de la VM"; diagnostic vm1
      fi
    else
      diagnostic vm1
    fi
  fi
fi

# ============================================================================
# Étape 4 — conteneur système
# ============================================================================

if voulue 4; then
  titre_etape 4 4_conteneur_systeme "conteneur système"
  for s in conteneur.sh comparer.sh proxy.sh proxy-vm.sh; do verifier_script "4_conteneur_systeme/$s"; done
  if [ "$mode" != "up" ]; then
    :
  elif [ -z "$site_vm1" ]; then
    ko "étape 4 : non jouée, vm1 et son site ne sont pas prêts (étapes 1 et 2)"
  elif jouer 4_conteneur_systeme/conteneur.sh 900; then
    etat="$(colonne ct1 ts)"
    if [ "$etat" = "CONTAINER,RUNNING" ]; then ok "étape 4 : ct1 est un conteneur en marche"
    else ko "étape 4 : état de ct1 inattendu ($etat)"; fi

    # Les mesures de l'énoncé : le journal du script les montre toutes.
    if jouer 4_conteneur_systeme/comparer.sh 600; then
      sed -n '/^== /,$p' "$travail/4_conteneur_systeme_comparer.sh.log" | grep -v '^+ ' | retrait || true
    fi

    # Noyau : celui de l'hôte dans le conteneur, un autre dans la VM.
    noyau_hote="$(uname -r)"; ligne_hote="$(cat /proc/cmdline)"
    noyau_ct="$(dans ct1 uname -r 2>&1 || true)"; ligne_ct="$(dans ct1 cat /proc/cmdline 2>&1 || true)"
    noyau_vm="$(dans vm1 uname -r 2>&1 || true)"; ligne_vm="$(dans vm1 cat /proc/cmdline 2>&1 || true)"
    if [ "$noyau_ct" = "$noyau_hote" ] && [ "$ligne_ct" = "$ligne_hote" ]; then
      ok "étape 4 : le conteneur partage le noyau de l'hôte ($noyau_hote, même /proc/cmdline)"
    else
      ko "étape 4 : noyau du conteneur ($noyau_ct) différent de celui de l'hôte ($noyau_hote)"
    fi
    if [ -n "$ligne_vm" ] && [ "$ligne_vm" != "$ligne_hote" ]; then
      ok "étape 4 : la VM a son propre noyau ($noyau_vm, démarré par sa propre ligne de commande)"
    else
      ko "étape 4 : la VM montre la ligne de commande du noyau de l'hôte"
    fi
    virt="$(dans ct1 systemd-detect-virt 2>&1 || true)"
    if [ "$virt" = "lxc" ]; then ok "étape 4 : le système du conteneur se sait dans un conteneur LXC"
    else ko "étape 4 : systemd-detect-virt répond « $virt » dans ct1"; fi

    # Démarrage : systemd chronomètre un noyau dans la VM, pas dans le conteneur.
    demarrage_vm="$(dans vm1 systemd-analyze time 2>&1 | head -n 1 || true)"
    demarrage_ct="$(dans ct1 systemd-analyze time 2>&1 | head -n 1 || true)"
    if [[ "$demarrage_vm" == *"(kernel)"* && "$demarrage_ct" == *"(userspace)"* && "$demarrage_ct" != *"(kernel)"* ]]; then
      ok "étape 4 : le démarrage de la VM compte une phase noyau, celui du conteneur non"
    else
      ko "étape 4 : phases de démarrage inattendues"
      info "vm1 : $demarrage_vm"; info "ct1 : $demarrage_ct"
    fi

    # Processus : ceux du conteneur sont des processus de l'hôte, sous des UID décalés.
    base="$(dans ct1 cat /proc/self/uid_map 2> /dev/null | awk '$1 == 0 { print $2 }' || true)"
    uid_hote=" $({ ps -o uid= -C apache2 || true; } | sort -un | tr -s ' \n' ' ') "
    info "UID des processus apache2 vus de l'hôte :$uid_hote; root du conteneur = UID ${base:-inconnu} de l'hôte"
    if [ "${base:-0}" -gt 0 ] && [[ "$uid_hote" == *" $base "* && "$uid_hote" == *" $((base + 33)) "* ]]; then
      ok "étape 4 : l'hôte voit les processus du conteneur, sous des UID décalés (root = $base, www-data = $((base + 33)))"
    else
      ko "étape 4 : processus apache2 du conteneur introuvables sur l'hôte sous les UID attendus"
    fi

    # Mémoire : sans limite, le conteneur voit celle de l'hôte ; la VM a la sienne.
    memoire_hote="$(memoire_ko < /proc/meminfo)"
    memoire_ct="$(dans ct1 cat /proc/meminfo 2> /dev/null | memoire_ko || true)"
    memoire_vm="$(dans vm1 cat /proc/meminfo 2> /dev/null | memoire_ko || true)"
    info "MemTotal (Kio) : hôte $memoire_hote, ct1 ${memoire_ct:-?}, vm1 ${memoire_vm:-?}"
    ecart=$((memoire_hote - ${memoire_ct:-0})); ecart="${ecart#-}"
    if [ "$ecart" -le $((memoire_hote / 100)) ]; then ok "étape 4 : sans limite, le conteneur voit toute la mémoire de l'hôte"
    else ko "étape 4 : le conteneur ne voit pas la mémoire de l'hôte"; fi
    if [ "${memoire_vm:-0}" -gt 0 ] && [ "$memoire_vm" -lt "$memoire_hote" ]; then
      ok "étape 4 : la VM ne voit que la mémoire qu'Incus lui a donnée"
    else
      ko "étape 4 : mémoire de la VM inattendue"
    fi
    # Une limite posée à chaud sur le conteneur est un réglage de son cgroup.
    if incus config set ct1 limits.memory=512MiB; then
      plafond="$(dans ct1 cat /sys/fs/cgroup/memory.max 2>&1 || true)"
      if [ "$plafond" = "536870912" ]; then ok "étape 4 : limits.memory s'applique à chaud au conteneur (memory.max de son cgroup)"
      else ko "étape 4 : memory.max du conteneur vaut « $plafond », 536870912 attendu"; fi
      info "free -m dans ct1 : $(dans ct1 sh -c 'free -m | sed -n 2p' 2>&1 || true)"
    else
      ko "étape 4 : incus config set ct1 limits.memory=512MiB refusé"
    fi

    # Le proxy sur le conteneur.
    if jouer 4_conteneur_systeme/proxy.sh 300; then
      if attendre_http "http://127.0.0.1:8080/" && curl -s -m 10 "http://127.0.0.1:8080/" | grep -q 'Apache2'; then
        ok "étape 4 : le proxy publie le port 80 du conteneur sur le port 8080 de l'hôte"
      else
        ko "étape 4 : http://127.0.0.1:8080/ ne mène pas à l'Apache du conteneur"; diagnostic ct1
      fi
    fi

    # La même commande sur la VM : refusée, sauf en mode NAT.
    if sortie="$(incus config device add vm1 web proxy listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:80 2>&1)"; then
      ko "étape 4 : Incus accepte un proxy sans NAT sur une VM, l'énoncé annonce un refus"
      incus config device remove vm1 web > /dev/null 2>&1 || true
    elif [[ "$sortie" == *"Only NAT mode is supported"* ]]; then
      ok "étape 4 : sur la VM, le proxy sans NAT est refusé"
      retrait <<< "$sortie"
    else
      ko "étape 4 : proxy sur la VM refusé pour une autre raison"
      retrait <<< "$sortie"
    fi
    if jouer 4_conteneur_systeme/proxy-vm.sh 300; then
      hote="$(incus config device get vm1 web listen 2> /dev/null | sed 's/^tcp://' || true)"
      if [ -n "$hote" ] && attendre_http "http://$hote/"; then
        ok "étape 4 : en mode NAT, http://$hote/ mène à l'Apache de la VM"
      else
        ko "étape 4 : le proxy NAT de la VM ne répond pas (http://$hote/)"
        incus config show vm1 2>&1 | retrait || true
      fi
    fi
  else
    diagnostic ct1
  fi
  if [ "$mode" = "up" ] && [ -z "$garder" ]; then incus delete --force vm1 ct1 > /dev/null 2>&1 || true; fi
fi

# ============================================================================
# Étape 5 — profils et cloud-init
# ============================================================================

if voulue 5; then
  titre_etape 5 5_profils_cloud_init "profils et cloud-init"
  verifier_script 5_profils_cloud_init/profil.sh
  verifier_cloud_init 5_profils_cloud_init/cloud-init.yaml 2_administrer
  if [ "$mode" = "up" ]; then
    if jouer 5_profils_cloud_init/profil.sh 2700; then
      for paire in wp-vm:VIRTUAL-MACHINE wp-ct:CONTAINER; do
        instance="${paire%%:*}"; genre="${paire#*:}"
        info "$instance : cloud-init $(dans "$instance" cloud-init status 2>&1 | tr '\n' ' ' || true)"
        if [ "$(colonne "$instance" t)" != "$genre" ]; then ko "étape 5 : $instance n'est pas de type $genre"; fi
        if site_wordpress 5 "$instance" "tptest-$instance-$RANDOM"; then
          ok "étape 5 : le profil wordpress produit un site fonctionnel dans $instance ($genre)"
        else
          diagnostic_cloud_init "$instance"; diagnostic "$instance"
        fi
      done

      # Héritage : la clé vient du profil ; posée sur l'instance, elle l'emporte.
      herite="$(incus config get wp-ct limits.memory --expanded 2>&1 || true)"
      propre="$(incus config get wp-ct limits.memory 2>&1 || true)"
      if [ "$herite" = "1GiB" ] && [ -z "$propre" ]; then
        ok "étape 5 : wp-ct hérite limits.memory=1GiB du profil (absente de sa configuration propre)"
      else
        ko "étape 5 : limits.memory de wp-ct : « $herite » avec les profils, « $propre » sans"
      fi
      incus config set wp-ct limits.memory=512MiB || true
      if [ "$(incus config get wp-ct limits.memory --expanded 2>&1 || true)" = "512MiB" ] \
        && [ "$(incus config get wp-vm limits.memory --expanded 2>&1 || true)" = "1GiB" ]; then
        ok "étape 5 : la clé posée sur wp-ct l'emporte sur le profil ; wp-vm garde la valeur du profil"
      else
        ko "étape 5 : la clé posée sur l'instance ne l'emporte pas sur le profil"
      fi
      # Sans le profil default, ni disque ni carte réseau : la création échoue.
      if sortie="$(incus create images:debian/13/cloud sans-default --profile wordpress 2>&1)"; then
        ko "étape 5 : une instance se crée avec le seul profil wordpress, l'énoncé annonce un refus"
        incus delete --force sans-default > /dev/null 2>&1 || true
      elif [[ "$sortie" == *"root"* ]]; then
        ok "étape 5 : avec le seul profil wordpress, la création échoue faute de disque racine"
        tail -n 2 <<< "$sortie" | retrait
      else
        ko "étape 5 : création refusée pour une autre raison"
        retrait <<< "$sortie"
      fi
    else
      diagnostic_cloud_init wp-vm; diagnostic_cloud_init wp-ct; diagnostic wp-vm wp-ct
    fi
    if [ -z "$garder" ]; then
      incus delete --force wp-vm wp-ct > /dev/null 2>&1 || true
      incus profile delete wordpress > /dev/null 2>&1 || true
    fi
  fi
fi

# ============================================================================
# Étape 6 — réseau et volumes
# ============================================================================

if voulue 6; then
  titre_etape 6 6_reseau_volumes "réseau et volumes"
  for s in db.sh deployer.sh recreer-db.sh; do verifier_script "6_reseau_volumes/$s"; done
  identiques 2_administrer/wordpress.conf 6_reseau_volumes/wordpress.conf
  # « À une ligne près » : seule l'adresse de la base, et son commentaire, changent.
  if diff <(grep -v 'DB_HOST' "$corrige/2_administrer/config-default.php") \
    <(grep -v -e 'DB_HOST' -e '^// La base est dans une autre instance' "$corrige/6_reseau_volumes/config-default.php") > /dev/null \
    && grep -q "'DB_HOST', 'db.incus'" "$corrige/6_reseau_volumes/config-default.php"; then
    ok "6_reseau_volumes/config-default.php ne diffère de celui de l'étape 2 que par l'adresse de la base"
  else
    ko "6_reseau_volumes/config-default.php s'écarte de celui de l'étape 2 au-delà de DB_HOST"
  fi
  if [ "$mode" = "up" ]; then
    titre="tptest-web-$RANDOM"
    if jouer 6_reseau_volumes/deployer.sh 2400; then
      adresse_db="$(adresse db || true)"
      resolue="$(dans web getent hosts db.incus 2>&1 | awk '{ print $1 }' || true)"
      if [ -n "$adresse_db" ] && [ "$resolue" = "$adresse_db" ]; then ok "étape 6 : web résout db.incus ($adresse_db)"
      else ko "étape 6 : dans web, db.incus donne « $resolue », l'adresse de db est « $adresse_db »"; fi
      if dans db getent hosts web.incus > /dev/null 2>&1; then ok "étape 6 : db résout web.incus"
      else ko "étape 6 : db ne résout pas web.incus"; fi
      if incus storage volume list default -c tn -f csv 2> /dev/null | grep -qx 'custom,donnees'; then
        ok "étape 6 : le volume donnees existe dans le pool default"
      else
        ko "étape 6 : volume donnees introuvable"
      fi

      if site_wordpress 6 web "$titre"; then
        ok "étape 6 : WordPress, dans web, joint sa base dans db par son nom"
        avant="$(incus config get db volatile.uuid 2> /dev/null || true)"
        if jouer 6_reseau_volumes/recreer-db.sh 1500; then
          apres="$(incus config get db volatile.uuid 2> /dev/null || true)"
          if [ -n "$apres" ] && [ "$apres" != "$avant" ]; then ok "étape 6 : db est une nouvelle instance ($(adresse db || true))"
          else ko "étape 6 : db n'a pas été recréée"; fi
          if wp_titre_present "$url_site" "$titre"; then
            ok "étape 6 : le site installé survit à la suppression de db : ses données sont sur le volume"
          else
            ko "étape 6 : données perdues à la recréation de db"; diagnostic db web
          fi
        else
          diagnostic db
        fi
      else
        diagnostic web db
      fi
    else
      diagnostic db web
    fi
    if [ -z "$garder" ]; then
      incus delete --force web db > /dev/null 2>&1 || true
      incus storage volume delete default donnees > /dev/null 2>&1 || true
    fi
  fi
fi

# ============================================================================
# Étape 7 — imbrication : Docker dans une VM
# ============================================================================

if voulue 7; then
  titre_etape 7 7_imbrication "imbrication"
  verifier_script 7_imbrication/docker.sh
  if [ "$mode" = "up" ]; then
    if jouer 7_imbrication/docker.sh 1800; then
      if [ "$(colonne docker t)" = "VIRTUAL-MACHINE" ]; then ok "étape 7 : docker est une machine virtuelle"
      else ko "étape 7 : docker n'est pas une machine virtuelle"; fi
      if dans docker docker container run --rm hello-world 2>&1 | grep -q 'Hello from Docker'; then
        ok "étape 7 : Docker exécute un conteneur applicatif dans la VM"
      else
        ko "étape 7 : docker container run hello-world échoue dans la VM"; diagnostic docker
      fi
      info "dans la VM : $(dans docker docker version --format 'Docker {{.Server.Version}}' 2>&1 || true), $(dans docker nproc 2>&1 || true) processeur(s)"
      dans docker df -h / 2>&1 | retrait || true
    else
      diagnostic docker
    fi
    if [ -z "$garder" ]; then incus delete --force docker > /dev/null 2>&1 || true; fi
  fi
fi

# ----------------------------------------------------------------------- bilan

printf '\n======== Bilan (%s) : %s vérifications réussies, %s en échec ========\n' "--$mode" "$reussis" "${#echecs[@]}"
if [ "${#echecs[@]}" -gt 0 ]; then
  printf '  - %s\n' "${echecs[@]}"
  exit 1
fi
