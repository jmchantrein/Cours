#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Incus ».
#
# Il enchaîne les scripts de corrige/, ceux-là mêmes que l'énoncé affiche, puis
# vérifie ce que l'énoncé annonce : un corrigé qui ne fonctionne plus fait
# échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--only N] [--keep] [--nesting]
#   --lint    (défaut) validation sans Incus : syntaxe, droits et shellcheck des
#             scripts, validité des YAML (corrigé et squelette cloud-init),
#             cohérence des fichiers que l'énoncé dit identiques.
#   --up      --lint, puis pour chaque étape : jouer les scripts du corrigé,
#             vérifier, nettoyer.
#   --only N  ne traite que l'étape N (1 à 7). En mode --up, les étapes 2, 3,
#             4 et 6 rejouent d'abord celles dont elles dépendent (la VM de
#             l'étape 1, le site de l'étape 2).
#   --keep    ne nettoie pas en fin de test (pour examiner un échec).
#   --nesting pose security.nesting=true sur le profil default du projet de
#             test. Contournement constaté nécessaire sur le runner Ubuntu
#             26.04 de l'intégration continue : sans lui, le profil AppArmor
#             d'un conteneur y refuse à systemd ptrace et signal vers les
#             processus qu'il crée dans un espace de noms utilisateur ;
#             journald et networkd ne démarrent pas, le conteneur n'a pas
#             d'IPv4. L'énoncé ne le demande pas à l'étudiant.
#
# Ce que --up vérifie, étape par étape :
#   1  vm1 est une machine virtuelle, un processus QEMU de l'hôte sous un compte
#      sans privilège ; son système se sait sous KVM ; elle joint les dépôts ;
#   2  WordPress répond en HTTP, joint sa base et s'installe ;
#   3  l'instantané restaure le site cassé ; à chaud, Incus refuse d'augmenter
#      la mémoire de la VM s'il n'a pas l'extension memory_hotplug (6.0.4, celui
#      de Debian 13) et l'accepte s'il l'a (6.0.5) ; après redémarrage elle a
#      2 processeurs et 2 Gio, et ses services sont revenus seuls ;
#   4  (avant les étapes 4, 5 et 6, une fois) un conteneur témoin reçoit une
#      adresse IPv4 sur le pont ; sinon, diagnostic du réseau des conteneurs,
#      et ces étapes sont abandonnées ;
#      le conteneur partage le noyau de l'hôte et la VM non ; il redémarre plus
#      vite qu'elle ; ses processus sont visibles de l'hôte sous des UID
#      décalés, et sous 0 et 33 dans le conteneur ; il voit la mémoire de
#      l'hôte, puis sa limite ; le proxy publie son port 80 sur le port 8080
#      de l'hôte ; sans NAT, le proxy est refusé sur la VM ;
#   5  le profil wordpress produit un WordPress fonctionnel dans une VM et dans
#      un conteneur ; une clé posée sur l'instance l'emporte sur celle du
#      profil ; sans le profil default, pas de disque racine ; une carte
#      héritée ne se modifie pas dans l'instance ; recharger cloud-init dans
#      le profil change l'identifiant cloud-init des instances ;
#   6  web et db se joignent par leur nom ; le site survit à la suppression de
#      l'instance db, ses données étant sur le volume ; en mode NAT, le proxy
#      publie le port 80 de la VM sur le port 8081 de l'hôte ;
#   7  Docker exécute un conteneur applicatif dans la VM.
#
# Isolation : tout est créé dans un projet Incus « tptest », relié à un pont à
# lui, « tptestbr0 ». Les scripts tournent tels quels (variable INCUS_PROJECT),
# avec les noms de l'énoncé ; le harnais ne touche à aucune instance, aucun
# profil, aucun volume du projet default. Un pont à part est nécessaire : Incus
# refuse deux instances de même nom sur un même pont, même dans deux projets.
# Le projet et le pont portent la clé user.tptest=harnais : le harnais refuse
# de supprimer un projet ou un pont de ce nom qui ne la porte pas.
# Le harnais a besoin des ports 8080 et 8081 de l'hôte, et du pool de stockage
# « default » que crée « incus admin init --minimal ».
#
# Prérequis de --up : bash, curl, Incus initialisé et joignable par le compte
# courant (groupe incus-admin), /dev/kvm, le réseau (images.linuxcontainers.org,
# dépôts Debian ; Docker Hub pour l'étape 7). Si Docker est installé sur
# l'hôte, autorisez le pont « tptestbr0 » dans la chaîne DOCKER-USER (voir
# l'énoncé, « Avant de commencer »).
#
# Intégration continue (.github/workflows/test-corriges.yml), qui lit ces deux
# lignes : délai du job en minutes, prérequis à installer.
# Chaque attente est bornée (deux minutes en général) : un passage normal
# dure une demi-heure environ, le délai du job n'est qu'un filet.
#   ci-delai: 120
#   ci-prerequis: incus
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
projet="tptest"
pont="tptestbr0"
marque="user.tptest"   # clé posée sur le projet et le pont que le harnais crée

mode="lint"; seule=""; garder=""; nesting=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --only) seule="${2:-}"; shift ;;
    --keep) garder="1" ;;
    --nesting) nesting="1" ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
case "$seule" in "" | [1-7]) ;; *) echo "--only attend un numéro d'étape, de 1 à 7." >&2; exit 2 ;; esac

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
bilan() { # le compte rendu final, et le code de sortie
  printf '\n======== Bilan (%s) : %s vérifications réussies, %s en échec ========\n' "--$mode" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then
    printf '  - %s\n' "${echecs[@]}"
    exit 1
  fi
  exit 0
}
# Interrompu (délai du job, Ctrl+C) : le bilan de ce qui a été vérifié, puis le
# nettoyage (trap EXIT).
# shellcheck disable=SC2317 # appelée par trap
interrompu() { # $1 signal
  trap "" TERM INT   # un second signal (sudo le relaie) ne doit pas couper le bilan
  if [ -n "${enfant:-}" ]; then kill "$enfant" 2> /dev/null || true; fi
  ko "harnais interrompu par le signal $1 (délai dépassé ?)"
  bilan
}
trap 'interrompu TERM' TERM
trap 'interrompu INT' INT
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
info() { printf '       %s\n' "$*"; }
retrait() { sed 's/^/       | /'; }
titre_etape() { printf '\n======== Étape %s — %s (corrige/%s) ========\n' "$1" "$3" "$2"; }

# Étape à traiter ? En mode --up, les étapes 2 à 4 et 6 dépendent des étapes 1 et 2.
voulue() { # $1 étape
  [ -z "$seule" ] && return 0
  [ "$seule" = "$1" ] && return 0
  [ "$mode" = "up" ] || return 1
  case "$seule:$1" in 2:1 | 3:1 | 3:2 | 4:1 | 4:2 | 6:1 | 6:2) return 0 ;; esac
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

# Le squelette que l'énoncé fait compléter : les mêmes clés que le corrigé, les
# mêmes fichiers, et rien à compléter hors des paquets, de defer et de runcmd.
verifier_squelette() { # $1 squelette  $2 corrigé complet
  local sortie
  if [ -z "$yaml_dispo" ]; then info "(python3 avec PyYAML indisponible : $1 non comparé)"; return 0; fi
  if sortie="$(python3 - "$corrige/$1" "$corrige/$2" 2>&1 << 'PYTHON'
import sys, yaml

with open(sys.argv[1], encoding="utf-8") as f:
    squelette = yaml.safe_load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    complet = yaml.safe_load(f)
if set(squelette) != set(complet):
    sys.exit(f"clés {sorted(squelette)} au lieu de {sorted(complet)}")
a_completer = "À COMPLÉTER"
if squelette["packages"] != [a_completer] or squelette["runcmd"] != [a_completer]:
    sys.exit("packages et runcmd doivent se réduire à « À COMPLÉTER »")
if len(squelette["write_files"]) != len(complet["write_files"]):
    sys.exit("write_files n'a pas le même nombre de fichiers que le corrigé")
for s, c in zip(squelette["write_files"], complet["write_files"]):
    if s.get("defer") != a_completer:
        sys.exit(f"{s['path']} : defer doit valoir « À COMPLÉTER »")
    for cle in set(s) | set(c):
        if cle != "defer" and s.get(cle) != c.get(cle):
            sys.exit(f"{s['path']} : la clé {cle} diffère du corrigé")
for cle in set(complet) - {"packages", "runcmd", "write_files"}:
    if squelette[cle] != complet[cle]:
        sys.exit(f"la clé {cle} diffère du corrigé")
PYTHON
  )"; then
    ok "squelette $1 : le corrigé $2 en retire seulement les paquets, defer et les commandes"
  else
    ko "squelette $1 : $sortie"
  fi
}

# ------------------------------------------------- mode --up : préalables, isolation

travail=""
isolation_prete=""
version_serveur=""; memoire_a_chaud=""; debut_harnais=""

mourir() { printf '%s\n' "$@" >&2; exit 1; }

# Un projet ou un pont de ce nom existe-t-il, et porte-t-il la marque du harnais ?
# Le harnais refuse de toucher à ce qu'il n'a pas créé.
projet_existe() { incus project show "$projet" > /dev/null 2>&1; }
pont_existe() { incus network show "$pont" --project default > /dev/null 2>&1; }
verifier_marques() {
  if projet_existe && [ "$(incus project get "$projet" "$marque" 2> /dev/null || true)" != "harnais" ]; then
    mourir "Un projet Incus « $projet » existe sans la clé $marque=harnais : le harnais ne l'a pas créé" \
      "et refuse de le supprimer. Renommez-le (incus project rename $projet autre-nom) ou supprimez-le vous-même."
  fi
  if pont_existe && [ "$(incus network get "$pont" "$marque" --project default 2> /dev/null || true)" != "harnais" ]; then
    mourir "Un réseau Incus « $pont » existe sans la clé $marque=harnais : le harnais ne l'a pas créé" \
      "et refuse de le supprimer. Renommez-le (incus network rename $pont autre-nom) ou supprimez-le vous-même."
  fi
}

# Suppression de tout ce que le harnais a pu créer. Appelée avant le test
# (restes d'un test interrompu) et en sortie, toujours après verifier_marques.
# Les options --project sont explicites : la fonction ne dépend pas de
# INCUS_PROJECT.
nettoyer_tout() {
  local i
  if projet_existe; then
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
  if pont_existe; then
    incus network delete "$pont" --project default > /dev/null 2>&1 || true
  fi
}

# Suppression d'instances une à une : « incus delete » vérifie d'abord que toutes
# celles qu'il nomme existent, et n'en supprime aucune si l'une manque.
supprimer_instances() { # $1… instances
  local i
  for i in "$@"; do incus delete --force "$i" > /dev/null 2>&1 || true; done
}

# shellcheck disable=SC2317 # appelée par trap
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
  debut_harnais="$(date '+%Y-%m-%d %H:%M:%S')"

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
  version_serveur="$(sed -n 's/^ *server_version: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$travail/incus-info.txt" | head -n 1)"
  # L'extension d'API memory_hotplug (Incus 6.12, reportée dans 6.0.5) décide
  # de ce que l'étape 3 attend d'une augmentation de mémoire à chaud.
  if grep -qx -e '- memory_hotplug' "$travail/incus-info.txt"; then memoire_a_chaud="1"; else memoire_a_chaud=""; fi
  info "extension memory_hotplug : $(if [ -n "$memoire_a_chaud" ]; then echo présente; else echo absente; fi)"
  # Le pilote dir copie le disque d'une VM avec dd (instantanés) : celui du PATH du démon.
  info "dd de l'hôte : $(dd --version 2>&1 | head -n 1)"
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
  # Restes d'un test interrompu : supprimés s'ils portent la marque du harnais.
  verifier_marques
  nettoyer_tout
  isolation_prete="1"
  incus network create "$pont" ipv6.address=none "$marque=harnais" --project default > /dev/null \
    || mourir "Création du pont $pont impossible."
  incus project create "$projet" --config "$marque=harnais" > /dev/null || mourir "Création du projet $projet impossible."
  # Le profil default d'un projet neuf est vide : le disque et la carte réseau.
  incus profile device add default root disk path=/ pool=default --project "$projet" > /dev/null \
    || mourir "Profil default du projet $projet : ajout du disque racine impossible."
  incus profile device add default eth0 nic network="$pont" name=eth0 --project "$projet" > /dev/null \
    || mourir "Profil default du projet $projet : ajout de la carte réseau impossible."
  if [ -n "$nesting" ]; then
    incus profile set default security.nesting=true --project "$projet" > /dev/null \
      || mourir "Profil default du projet $projet : security.nesting=true refusé."
    info "--nesting : security.nesting=true sur le profil default du projet $projet (contournement, voir --help)"
  fi
  export INCUS_PROJECT="$projet"
  info "projet $projet, pont $pont ($(incus network get "$pont" ipv4.address --project default 2>&1 || true))"
}

# --------------------------------------------------------- jouer un script du corrigé
# Le script tourne tel quel, dans le projet du harnais, avec la trace de ses
# commandes (sh -x) : en cas d'échec, la fin du journal montre la commande fautive.

# Le script tourne en arrière-plan : « wait » laisse le harnais traiter aussitôt
# un signal (délai du job), au lieu d'attendre la fin du script.
enfant=""
jouer() { # $1 script, relatif à corrige/  $2 délai en secondes
  local journal code=0
  journal="$travail/$(tr '/' '_' <<< "$1").log"
  info "→ corrige/$1 (délai : $2 s)"
  timeout -k 30 "$2" sh -x "$corrige/$1" > "$journal" 2>&1 &
  enfant=$!
  wait "$enfant" || code=$?
  enfant=""
  # Les barres de progression d'incus launch réécrivent leur ligne : une seule ligne suffit.
  sed -i -e 's/.*\r\([^\r]\)/\1/' -e '/^Retrieving image: /d' "$journal" 2> /dev/null || true
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

# Toute attente du harnais est bornée : une à deux minutes sans résultat, et
# l'échec est constaté.
pendant() { # $1 secondes  $2… commande : rejouée toutes les 2 s jusqu'à son succès ou la fin du délai
  local fin=$((SECONDS + $1)); shift
  while :; do
    if "$@"; then return 0; fi
    [ "$SECONDS" -lt "$fin" ] || return 1
    sleep 2
  done
}

adresse() { # $1 instance  [$2 délai en s, 120 par défaut] : son adresse IPv4 sur le pont
  local a fin=$((SECONDS + ${2:-120}))
  while :; do
    a="$(colonne "$1" 4 | grep -m 1 -o '^[0-9.]*' || true)"
    if [ -n "$a" ]; then echo "$a"; return 0; fi
    [ "$SECONDS" -lt "$fin" ] || return 1
    sleep 2
  done
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
    timeout 20 incus exec "$i" -- sh -c 'systemctl --failed --no-pager --no-legend; journalctl -n 25 --no-pager' 2>&1 \
      | tail -n 40 | retrait || true
    # Un conteneur en marche sans IPv4 : le diagnostic du réseau.
    if [ "$(colonne "$i" ts)" = "CONTAINER,RUNNING" ] && [ -z "$(colonne "$i" 4)" ]; then diagnostic_reseau "$i"; fi
  done
}

# Un site qui ne répond pas comme attendu : ce qu'il répond, et sa configuration.
diagnostic_site() { # $1 instance  $2 url
  echo "------ $2 : code HTTP, titre de la page"
  curl -s -o "$travail/page.html" -m 10 -w '%{http_code}\n' "$2/" 2>&1 | retrait || true
  grep -o -m 1 '<title>[^<]*' "$travail/page.html" 2> /dev/null | retrait || true
  echo "------ $1 : configuration de WordPress et d'Apache"
  timeout 20 incus exec "$1" -- sh -c 'ls -l /etc/wordpress/ /etc/apache2/sites-enabled/ /usr/share/wordpress/index.php; systemctl is-active apache2 mariadb' 2>&1 \
    | retrait || true
}

diagnostic_cloud_init() { # $1 instance
  echo "------ $1 : cloud-init status --long, fin de cloud-init-output.log"
  timeout 20 incus exec "$1" -- sh -c 'cloud-init status --long; tail -n 40 /var/log/cloud-init-output.log' 2>&1 \
    | retrait || true
}

# Une commande de l'hôte, sous sudo sans mot de passe si possible, sinon sous le
# compte courant ; sa sortie est bornée.
hote() { # $1 titre  $2… commande
  local titre="$1"; shift
  echo "------ hôte : $titre"
  if sudo -n true 2> /dev/null; then timeout 30 sudo -n "$@" 2>&1 | head -n 200 | retrait || true
  else timeout 30 "$@" 2>&1 | head -n 200 | retrait || true; fi
}

# Un conteneur système sans adresse IPv4 : de quoi départager, en un passage, le
# client DHCP du conteneur (systemd-networkd et le reste de systemd), le
# serveur DHCP du pont (dnsmasq), le pare-feu de l'hôte et le pont lui-même.
# La partie hôte et les témoins ne sont joués qu'une fois par passage.
diagnostic_reseau_fait=""
diagnostic_reseau() { # $1 conteneur sans IPv4
  local ct="$1" t pid temoins=()
  echo "======== Diagnostic : $ct n'a pas d'adresse IPv4 sur $pont"
  incus info "$ct" 2>&1 | sed -n '/^Network usage:/,$p' | head -n 30 | retrait || true
  echo "------ $ct : console (messages de systemd au démarrage, fin)"
  incus console "$ct" --show-log 2>&1 | tail -n 60 | retrait || true
  echo "------ $ct : systemd, systemd-networkd, adresses, processus"
  # Chaque commande a son délai : un systemd bloqué ne doit pas bloquer le diagnostic.
  # shellcheck disable=SC2016 # développé dans le conteneur
  timeout 90 incus exec "$ct" -- sh -c '
    t() { echo "--- $*"; timeout 10 "$@" 2>&1 | tail -n 40; }
    t systemctl --version
    t systemctl is-system-running
    t systemctl --failed --no-pager --no-legend
    t systemctl list-jobs --no-pager
    t systemctl status --no-pager --lines=5 systemd-networkd systemd-journald
    t networkctl status eth0 --no-pager
    t journalctl -b -u systemd-networkd --no-pager
    echo "--- /etc/systemd/network/*"; head -n 30 /etc/systemd/network/* 2>&1
    t ip -4 addr
    t ip route
    echo "--- /etc/resolv.conf"; cat /etc/resolv.conf 2>&1
    echo "--- ps (état, attente noyau)"; ps -eo pid,ppid,stat,wchan:30,etime,args 2>&1 | head -n 60
    echo "--- ps -e | wc -l : $(ps -e | wc -l)"
    echo "--- étiquettes AppArmor : PID 1, puis les processus (sd-mkuserns) de systemd"
    cat /proc/1/attr/current 2>&1
    for p in $(ps -eo pid=,args= | awk "/sd-mkuser/ { print \$1 }"); do echo "$p : $(cat /proc/$p/attr/current 2>&1)"; done
  ' 2>&1 | retrait || true

  [ -z "$diagnostic_reseau_fait" ] || return 0
  diagnostic_reseau_fait="1"

  echo "------ hôte : le pont $pont, et incusbr0 pour comparer"
  incus network show "$pont" --project default 2>&1 | retrait || true
  incus network info "$pont" --project default 2>&1 | head -n 20 | retrait || true
  incus network show incusbr0 --project default 2>&1 | sed -n '/^config:/,/^description:/p' | retrait || true
  hote "baux et réservations de dnsmasq pour $pont" sh -c \
    "ls -l /var/lib/incus/networks/$pont/; cat /var/lib/incus/networks/$pont/dnsmasq.leases; ls /var/lib/incus/networks/$pont/dnsmasq.hosts/"
  hote "processus dnsmasq" ps -o pid,args -C dnsmasq
  hote "journal du démon depuis le début du test (dnsmasq, dhcp)" sh -c \
    "journalctl -u incus --since '$debut_harnais' --no-pager | grep -i -E 'dnsmasq|dhcp' | tail -n 40"
  hote "table nftables d'Incus" nft list table inet incus
  hote "règles nftables (début)" nft list ruleset
  hote "br_netfilter et sysctl des ponts" sh -c \
    "if [ -d /sys/module/br_netfilter ]; then echo 'br_netfilter chargé'; else echo 'br_netfilter non chargé'; fi; sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.bridge.bridge-nf-call-arptables 2>&1"
  hote "AppArmor : refus, tâches bloquées (dmesg)" sh -c \
    "dmesg | grep -i -E 'apparmor=\"DENIED\"|blocked for more than|hung_task' | tail -n 30; echo \"apparmor_restrict_unprivileged_userns = \$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>&1)\"; apparmor_parser --version 2>&1 | head -n 1"
  # Processus bloqués dans le noyau (état D) : leur pile dit où.
  for pid in $(ps -eo pid=,stat= | awk '$2 ~ /^D/ { print $1 }' | head -n 5); do
    hote "pile noyau du processus $pid (état D) : $(ps -o args= -p "$pid" | cut -c 1-80)" cat "/proc/$pid/stack"
  done
  # Le DHCP sur le pont pendant que le conteneur renouvelle son bail : une
  # demande sans réponse, une réponse ignorée, ou aucune demande.
  if command -v tcpdump > /dev/null && sudo -n true 2> /dev/null; then
    echo "------ hôte : DHCP sur $pont pendant 20 s (networkctl renew eth0 dans $ct)"
    # shellcheck disable=SC2024 # le fichier appartient au compte courant
    sudo -n timeout 20 tcpdump -n -e -vv -i "$pont" -c 20 'udp port 67 or udp port 68' > "$travail/dhcp.txt" 2>&1 &
    t=$!
    sleep 2
    timeout 15 incus exec "$ct" -- networkctl renew eth0 > /dev/null 2>&1 || true
    wait "$t" || true
    head -n 80 "$travail/dhcp.txt" | retrait
  else
    info "(tcpdump ou sudo sans mot de passe indisponible : pas de capture DHCP)"
  fi

  # Témoins (security.nesting explicite : --nesting le pose sur le profil) :
  # la même image, sur incusbr0, puis sur $pont avec security.nesting
  # (systemd peut alors monter ce que l'AppArmor d'un conteneur lui refuse),
  # puis privilégié (pas d'espace de noms utilisateur).
  echo "------ témoins : la même image, autrement lancée (adresse attendue 90 s)"
  if incus network show incusbr0 --project default > /dev/null 2>&1 \
    && incus launch images:debian/13 tptest-temoin-incusbr0 --network incusbr0 -c security.nesting=false > /dev/null 2>&1; then
    temoins+=(tptest-temoin-incusbr0)
  fi
  incus launch images:debian/13 tptest-temoin-nesting -c security.nesting=true > /dev/null 2>&1 \
    && temoins+=(tptest-temoin-nesting)
  incus launch images:debian/13 tptest-temoin-privilegie -c security.privileged=true -c security.nesting=false > /dev/null 2>&1 \
    && temoins+=(tptest-temoin-privilegie)
  pendant 90 tous_adresses "${temoins[@]}" || true
  for t in "${temoins[@]}"; do
    info "$t : IPv4 « $(colonne "$t" 4) », $(timeout 10 incus exec "$t" -- systemctl is-system-running 2>&1 || true), $(colonne "$t" N) processus"
  done
  supprimer_instances "${temoins[@]}"
  echo "======== Fin du diagnostic de $ct"
}

# shellcheck disable=SC2317 # appelée par pendant
tous_adresses() { # $1… instances : toutes ont une adresse IPv4
  local i
  for i in "$@"; do [ -n "$(colonne "$i" 4)" ] || return 1; done
}

# Le réseau des conteneurs système, établi une fois par passage sur un témoin
# avant la première étape qui en lance : sans lui, ces étapes sont abandonnées
# en quelques minutes au lieu d'attendre leurs délais.
reseau_conteneurs=""   # vide : pas encore établi ; ok ; ko
controler_reseau_conteneurs() { # $1 étape ; réussit si les conteneurs ont le réseau
  local a sortie
  if [ -z "$reseau_conteneurs" ]; then
    reseau_conteneurs="ko"
    if ! sortie="$(incus launch images:debian/13 tptest-temoin 2>&1)"; then
      ko "étape $1 : lancement du conteneur témoin impossible"; tail -n 5 <<< "$sortie" | retrait
    elif a="$(adresse tptest-temoin 90)"; then
      reseau_conteneurs="ok"
      ok "étape $1 : un conteneur témoin reçoit une adresse sur $pont ($a)"
    else
      ko "étape $1 : un conteneur témoin n'a pas d'adresse IPv4 sur $pont après 90 s"
      diagnostic_reseau tptest-temoin
    fi
    supprimer_instances tptest-temoin
  elif [ "$reseau_conteneurs" = "ko" ]; then
    ko "étape $1 : non jouée, les conteneurs n'ont pas de réseau (voir le diagnostic plus haut)"
  fi
  [ "$reseau_conteneurs" = "ok" ]
}

# ------------------------------------------------------------------ HTTP, WordPress

attendre_http() { # $1 url : une réponse 2xx ou 3xx en moins de deux minutes
  local code fin=$((SECONDS + 120))
  while :; do
    code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$1" 2> /dev/null || true)"
    case "$code" in 2?? | 3??) return 0 ;; esac
    [ "$SECONDS" -lt "$fin" ] || break
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
  local corps pret="" fin=$((SECONDS + 120))
  while :; do
    corps="$(curl -s -m 15 "$1/wp-admin/install.php?step=1" 2> /dev/null || true)"
    if [[ "$corps" == *'name="weblog_title"'* ]]; then pret="1"; break; fi
    [ "$SECONDS" -lt "$fin" ] || break
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
  local corps fin=$((SECONDS + 60))
  while :; do
    corps="$(curl -sL -m 10 "$1/" 2> /dev/null || true)"
    if [[ "$corps" == *"<title>$2"* ]]; then return 0; fi
    [ "$SECONDS" -lt "$fin" ] || return 1
    sleep 3
  done
}

wp_titre_absent() { # $1 url du site  $2 titre : un seul essai
  local corps
  corps="$(curl -sL -m 10 "$1/" 2> /dev/null || true)"
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
  if [ "$mode" = "up" ] && jouer 1_instances_images/lancer.sh 600; then
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
    if pendant 120 timeout 10 incus exec vm1 -- bash -c 'exec 3<> /dev/tcp/deb.debian.org/80' 2> /dev/null; then
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
  elif jouer 2_administrer/installer.sh 900; then
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
      if jouer 3_instantanes_limites/restaurer.sh 600; then
        site_vm1="http://$(adresse vm1 || true)"
        if wp_titre_present "$site_vm1" "$titre_vm1"; then ok "étape 3 : l'instantané restaure le site ($site_vm1)"
        else ko "étape 3 : le site n'est pas revenu après la restauration"; diagnostic_site vm1 "$site_vm1"; diagnostic vm1; fi
      else
        diagnostic vm1
      fi
    fi

    # À chaud. Ce qu'Incus répond dépend de sa version (updateMemoryLimit,
    # internal/server/instance/drivers/driver_qemu.go) : sans l'extension
    # memory_hotplug (6.0.4, celle de Debian 13), un refus ; avec elle (6.0.5,
    # 6.12 et suivantes), QEMU reçoit une barrette de mémoire, sauf si
    # limits.memory.hotplug vaut false.
    hotplug="$(incus config get vm1 limits.memory.hotplug --expanded 2> /dev/null || true)"
    avant="$(dans vm1 cat /proc/meminfo 2> /dev/null | memoire_ko || true)"
    if sortie="$(incus config set vm1 limits.memory=2GiB 2>&1)"; then
      if [ -z "$memoire_a_chaud" ]; then
        ko "étape 3 : Incus $version_serveur, sans l'extension memory_hotplug, accepte d'augmenter à chaud la mémoire de la VM"
      elif [ "$hotplug" = "false" ]; then
        ko "étape 3 : Incus $version_serveur accepte la mémoire à chaud malgré limits.memory.hotplug=false"
      else
        ok "étape 3 : Incus $version_serveur (memory_hotplug) accepte d'augmenter à chaud la mémoire de la VM"
        # Relevé pour l'énoncé : l'invité voit-il la barrette ajoutée ?
        sleep 5
        apres="$(dans vm1 cat /proc/meminfo 2> /dev/null | memoire_ko || true)"
        info "MemTotal dans vm1 : $((${avant:-0} / 1024)) Mio avant, $((${apres:-0} / 1024)) Mio 5 s après"
        dans vm1 sh -c 'lsmem --summary 2>&1 || true' 2>&1 | retrait || true
      fi
    elif [ -z "$memoire_a_chaud" ] && [[ "$sortie" == *"Cannot increase memory size beyond boot time size when VM is running"* ]]; then
      ok "étape 3 : à chaud, Incus $version_serveur refuse d'augmenter la mémoire de la VM"
      retrait <<< "$sortie"
    elif [ -n "$memoire_a_chaud" ] && [ "$hotplug" = "false" ] && [[ "$sortie" == *"Memory hotplug feature is disabled"* ]]; then
      ok "étape 3 : limits.memory.hotplug=false : Incus $version_serveur refuse la mémoire à chaud"
      retrait <<< "$sortie"
    else
      ko "étape 3 : réponse inattendue d'Incus $version_serveur à limits.memory=2GiB à chaud (memory_hotplug : ${memoire_a_chaud:-absente})"
      retrait <<< "$sortie"
    fi

    # Le script ajoute un processeur à chaud, puis arrête la VM pour la mémoire.
    if jouer 3_instantanes_limites/limites.sh 600; then
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
        ko "étape 3 : le site ne répond plus après le redémarrage de la VM"; diagnostic_site vm1 "$site_vm1"; diagnostic vm1
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
  for s in conteneur.sh comparer.sh proxy.sh; do verifier_script "4_conteneur_systeme/$s"; done
  if [ "$mode" != "up" ]; then
    :
  elif [ -z "$site_vm1" ]; then
    ko "étape 4 : non jouée, vm1 et son site ne sont pas prêts (étapes 1 et 2)"
  elif ! controler_reseau_conteneurs 4; then
    :
  elif jouer 4_conteneur_systeme/conteneur.sh 600; then
    etat="$(colonne ct1 ts)"
    if [ "$etat" = "CONTAINER,RUNNING" ]; then ok "étape 4 : ct1 est un conteneur en marche"
    else ko "étape 4 : état de ct1 inattendu ($etat)"; fi

    # Les mesures de l'énoncé : le journal du script les montre toutes.
    if jouer 4_conteneur_systeme/comparer.sh 600; then
      journal_comparer="$travail/4_conteneur_systeme_comparer.sh.log"
      sed -n '/^== /,$p' "$journal_comparer" | grep -v '^+ ' | retrait || true
      # Redémarrage : le script chronomètre les deux instances, en secondes.
      duree_ct="$(sed -n 's/^ct1  : \([0-9]*\) s$/\1/p' "$journal_comparer")"
      duree_vm="$(sed -n 's/^vm1  : \([0-9]*\) s$/\1/p' "$journal_comparer")"
      if [ -n "$duree_ct" ] && [ -n "$duree_vm" ] && [ "$duree_ct" -lt "$duree_vm" ]; then
        ok "étape 4 : le conteneur redémarre plus vite que la VM ($duree_ct s contre $duree_vm s)"
      else
        ko "étape 4 : redémarrages inattendus (ct1 : ${duree_ct:-?} s, vm1 : ${duree_vm:-?} s)"
      fi
    fi

    # Noyau : celui de l'hôte dans le conteneur, un autre dans la VM.
    noyau_hote="$(uname -r)"; ligne_hote="$(cat /proc/cmdline)"
    # Sans 2>&1 : un message d'erreur ne doit pas passer pour une ligne de commande.
    noyau_ct="$(dans ct1 uname -r 2> /dev/null || true)"; ligne_ct="$(dans ct1 cat /proc/cmdline 2> /dev/null || true)"
    noyau_vm="$(dans vm1 uname -r 2> /dev/null || true)"; ligne_vm="$(dans vm1 cat /proc/cmdline 2> /dev/null || true)"
    if [ -n "$noyau_ct" ] && [ "$noyau_ct" = "$noyau_hote" ] && [ "$ligne_ct" = "$ligne_hote" ]; then
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
    if [ "$virt" = "lxc" ]; then ok "étape 4 : le système du conteneur se sait dans un conteneur système (systemd-detect-virt : lxc)"
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
    uid_ct="$({ dans ct1 ps -o uid= -C apache2 2> /dev/null || true; } | sort -un | xargs)"
    if [ "$uid_ct" = "0 33" ]; then
      ok "étape 4 : dans le conteneur, les mêmes processus apparaissent sous les UID 0 et 33"
    else
      ko "étape 4 : dans ct1, les processus apache2 ont les UID « $uid_ct », 0 et 33 attendus"
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

    # La commande de l'énoncé sur la VM : refusée sans NAT (le mode NAT est à l'étape 6).
    if sortie="$(incus config device add vm1 web proxy listen=tcp:0.0.0.0:8081 connect=tcp:127.0.0.1:80 2>&1)"; then
      ko "étape 4 : Incus accepte un proxy sans NAT sur une VM, l'énoncé annonce un refus"
      incus config device remove vm1 web > /dev/null 2>&1 || true
    elif [[ "$sortie" == *"Only NAT mode is supported for proxies on VM instances"* ]]; then
      ok "étape 4 : sur la VM, le proxy sans NAT est refusé"
      retrait <<< "$sortie"
    else
      ko "étape 4 : proxy sur la VM refusé pour une autre raison"
      retrait <<< "$sortie"
    fi
  else
    diagnostic ct1
  fi
  # vm1 sert encore à l'étape 6 : le harnais la supprime après celle-ci, ou en sortie.
  if [ "$mode" = "up" ] && [ -z "$garder" ]; then supprimer_instances ct1; fi
fi

# ============================================================================
# Étape 5 — profils et cloud-init
# ============================================================================

if voulue 5; then
  titre_etape 5 5_profils_cloud_init "profils et cloud-init"
  verifier_script 5_profils_cloud_init/profil.sh
  verifier_cloud_init 5_profils_cloud_init/cloud-init.yaml 2_administrer
  verifier_cloud_init 5_profils_cloud_init/squelette.yaml 2_administrer
  verifier_squelette 5_profils_cloud_init/squelette.yaml 5_profils_cloud_init/cloud-init.yaml
  # wp-ct est un conteneur : sans réseau des conteneurs, l'étape est abandonnée.
  if [ "$mode" = "up" ] && controler_reseau_conteneurs 5; then
    if jouer 5_profils_cloud_init/profil.sh 1500; then
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
      if ! sortie="$(incus config set wp-ct limits.memory=512MiB 2>&1)"; then
        ko "étape 5 : incus config set wp-ct limits.memory=512MiB refusé"; retrait <<< "$sortie"
      elif [ "$(incus config get wp-ct limits.memory --expanded 2>&1 || true)" = "512MiB" ] \
        && [ "$(incus config get wp-vm limits.memory --expanded 2>&1 || true)" = "1GiB" ]; then
        ok "étape 5 : la clé posée sur wp-ct l'emporte sur le profil ; wp-vm garde la valeur du profil"
      else
        ko "étape 5 : la clé posée sur l'instance ne l'emporte pas sur le profil"
      fi
      # Sans le profil default, ni disque ni carte réseau : la création échoue
      # (ErrNoRootDisk, internal/instance/device.go).
      if sortie="$(incus create images:debian/13/cloud essai --profile wordpress 2>&1)"; then
        ko "étape 5 : une instance se crée avec le seul profil wordpress, l'énoncé annonce un refus"
        supprimer_instances essai
      elif [[ "$sortie" == *"No root device could be found"* ]]; then
        ok "étape 5 : avec le seul profil wordpress, la création échoue faute de disque racine"
        tail -n 2 <<< "$sortie" | retrait
      else
        ko "étape 5 : création refusée pour une autre raison"
        retrait <<< "$sortie"
      fi

      # Une carte héritée du profil ne se modifie pas dans l'instance.
      adresse_wp_ct="$(adresse wp-ct || true)"
      if sortie="$(incus config device set wp-ct eth0 "ipv4.address=$adresse_wp_ct" 2>&1)"; then
        ko "étape 5 : Incus modifie dans wp-ct la carte eth0 du profil, l'énoncé annonce un refus"
      elif [[ "$sortie" == *"Device from profile(s) cannot be modified for individual instance"* ]]; then
        ok "étape 5 : la carte eth0, héritée du profil default, ne se modifie pas dans l'instance"
      else
        ko "étape 5 : modification de eth0 refusée pour une autre raison"
        retrait <<< "$sortie"
      fi

      # cloud-init rechargé dans le profil : Incus tire un nouvel identifiant
      # (needsNewInstanceID), que cloud-init lira au prochain démarrage.
      avant="$(incus config get wp-ct volatile.cloud-init.instance-id 2> /dev/null || true)"
      if { cat "$corrige/5_profils_cloud_init/cloud-init.yaml"; echo "# modifié par le harnais"; } \
        | incus profile set wordpress cloud-init.user-data -; then
        apres="$(incus config get wp-ct volatile.cloud-init.instance-id 2> /dev/null || true)"
        if [ -n "$apres" ] && [ "$apres" != "$avant" ]; then
          ok "étape 5 : recharger cloud-init dans le profil change volatile.cloud-init.instance-id de wp-ct"
        else
          ko "étape 5 : volatile.cloud-init.instance-id de wp-ct inchangé (« $avant », puis « $apres »)"
        fi
      else
        ko "étape 5 : incus profile set wordpress cloud-init.user-data refusé"
      fi
    else
      diagnostic_cloud_init wp-vm; diagnostic_cloud_init wp-ct; diagnostic wp-vm wp-ct
    fi
    if [ -z "$garder" ]; then
      supprimer_instances wp-vm wp-ct essai
      incus profile delete wordpress > /dev/null 2>&1 || true
    fi
  fi
fi

# ============================================================================
# Étape 6 — réseau et volumes
# ============================================================================

if voulue 6; then
  titre_etape 6 6_reseau_volumes "réseau et volumes"
  for s in db.sh deployer.sh recreer-db.sh proxy-vm.sh; do verifier_script "6_reseau_volumes/$s"; done
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
    if ! controler_reseau_conteneurs 6; then
      : # db et web sont des conteneurs
    elif jouer 6_reseau_volumes/deployer.sh 1500; then
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
        if jouer 6_reseau_volumes/recreer-db.sh 900; then
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

    # Le port de la VM, publié en mode NAT. Il faut vm1 et son site (étapes 1 et 2).
    if [ -z "$site_vm1" ]; then
      ko "étape 6 : proxy-vm.sh non joué, vm1 et son site ne sont pas prêts (étapes 1 et 2)"
    elif jouer 6_reseau_volumes/proxy-vm.sh 300; then
      hote="$(incus config device get vm1 web listen 2> /dev/null | sed 's/^tcp://' || true)"
      if [ -n "$hote" ] && attendre_http "http://$hote/"; then
        ok "étape 6 : en mode NAT, http://$hote/ mène à l'Apache de la VM"
      else
        ko "étape 6 : le proxy NAT de la VM ne répond pas (http://$hote/)"
        incus config show vm1 2>&1 | retrait || true
      fi
    fi

    if [ -z "$garder" ]; then
      supprimer_instances web db vm1
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
    if jouer 7_imbrication/docker.sh 1200; then
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
    if [ -z "$garder" ]; then supprimer_instances docker; fi
  fi
fi

# ----------------------------------------------------------------------- bilan

bilan
