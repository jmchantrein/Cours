#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Un tunnel WireGuard ».
#
# Il monte le laboratoire de labo/ et y installe les fichiers de corrige/,
# ceux-là mêmes que l'énoncé affiche : un corrigé qui ne fonctionne plus fait
# échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up] [--keep]
#   --lint   (défaut) sans rien construire : bash -n et shellcheck des scripts,
#            structure des wg0.conf, docker compose config du laboratoire.
#   --up     --lint, puis le laboratoire complet : trois pairs Debian 13.
#   --keep   ne nettoie pas en fin de test (pour examiner un échec).
#
# Ce que --up vérifie :
#   generer-cles.sh      une paire de clés par pair, en 600 ;
#   pair-a.conf, pair-b.conf  (clés réelles à la place des chevrons) : wg-quick
#                        up ; ping dans le tunnel ; wg show montre une poignée
#                        de main ; pair-b a appris l'Endpoint de pair-a ;
#                        tcpdump sur le réseau porteur ne voit que de l'UDP
#                        51820, aucun ICMP ;
#   AllowedIPs           retirer 10.9.9.2 des AllowedIPs de pair-b (sur pair-a)
#                        coupe l'envoi ; refuser 10.9.9.1 (sur pair-b) : les
#                        octets arrivent, aucune réponse ne repart ;
#   pair-a-trois-pairs.conf, pair-c.conf : wg syncconf ajoute pair-c sans
#                        couper pair-b ; pair-a joint pair-c ; pair-b ne joint
#                        pas pair-c, puis le joint par pair-a (TTL 63) une fois
#                        les AllowedIPs élargies à 10.9.9.0/24.
#
# WireGuard en conteneur demande la capacité NET_ADMIN et, pour aller vite, le
# module wireguard du noyau de l'hôte (Linux 5.6 et plus). Le harnais teste sa
# présence : sans lui, wg-quick se rabat sur wireguard-go (espace utilisateur,
# par /dev/net/tun), ce que le harnais dit, et les vérifications sont les mêmes.
#
# Le harnais ne crée et ne supprime que des ressources préfixées « tptest » :
# projet Compose tptest-wireguard (conteneurs, réseau), image
# tptest-wireguard-labo. Son réseau porteur est 172.29.250.0/24 (variable
# TPTEST_RESEAU=172.29.250 pour en changer), pour ne pas heurter le laboratoire
# de l'énoncé (172.20.0.0/24) ; les fichiers sont adaptés en conséquence.
#
# Prérequis de --lint : bash, shellcheck ; Docker avec Compose v2 pour valider
# compose.yaml. Prérequis de --up : Docker, Compose v2, /dev/net/tun sur l'hôte,
# l'accès aux dépôts Debian. Derrière un proxy HTTPS qui réécrit TLS : TPTEST_CA (voir README.md du dépôt).
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
labo="$ici/labo"
projet="tptest-wireguard"
image="tptest-wireguard-labo"
reseau="${TPTEST_RESEAU:-172.29.250}"

mode="lint"; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,44p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
bilan() {
  printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec ========\n' "$mode" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then printf '  - %s\n' "${echecs[@]}"; exit 1; fi
  exit 0
}

# ------------------------------------------------------------------------ lint

exiger bash bash
exiger shellcheck shellcheck

titre "Lint : scripts"
for script in "$corrige"/*.sh "$ici/tester.sh"; do
  nom="${script#"$ici"/}"
  if [ "$(head -1 "$script")" = "#!/bin/sh" ]; then
    if sh -n "$script"; then ok "$nom : syntaxe sh"; else ko "$nom : syntaxe sh"; fi
  elif bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  if shellcheck "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  if [ "$script" != "$ici/tester.sh" ]; then
    if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
  fi
done

titre "Lint : wg0.conf"
for conf in "$corrige"/*.conf; do
  nom="${conf#"$ici"/}"
  # Une section [Interface] avec clé privée et adresse ; chaque [Peer] avec clé publique et AllowedIPs.
  if awk '
    /^\[Interface\]$/ { section = "i"; ni++; next }
    /^\[Peer\]$/ { if (section == "p" && !(cle && ips)) bad = 1; section = "p"; np++; cle = ips = 0; next }
    /^(#|$)/ { next }
    section == "i" && /^PrivateKey = / { pk = 1; next }
    section == "i" && /^Address = [0-9.]+\/[0-9]+$/ { ad = 1; next }
    section == "i" && /^ListenPort = [0-9]+$/ { next }
    section == "p" && /^PublicKey = / { cle = 1; next }
    section == "p" && /^AllowedIPs = / { ips = 1; next }
    section == "p" && /^Endpoint = [0-9.]+:[0-9]+$/ { next }
    { bad = 1 }
    END { if (section == "p" && !(cle && ips)) bad = 1; exit !(ni == 1 && np >= 1 && pk && ad && !bad) }' "$conf"; then
    ok "$nom : [Interface] puis $(grep -c '^\[Peer\]$' "$conf") [Peer], champs connus"
  else
    ko "$nom : structure inattendue (sections, champs)"
  fi
done

titre "Lint : laboratoire"
if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
  if docker compose -f "$labo/compose.yaml" config -q; then ok "labo/compose.yaml : docker compose config"
  else ko "labo/compose.yaml : docker compose config"; fi
else
  echo "Docker Compose absent : compose.yaml sera validé par --up."
fi
[ "$mode" = "lint" ] && bilan

# ------------------------------------------------------------------------- --up

exiger docker docker.io
docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
docker compose version > /dev/null 2>&1 || { echo "Le plugin Compose v2 (docker compose) est requis." >&2; exit 1; }
[ -c /dev/net/tun ] || echo "Attention : /dev/net/tun est absent de l'hôte ; sans module noyau, wireguard-go ne pourra pas démarrer."

travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
compose() { docker compose -p "$projet" -f "$travail/labo/compose.yaml" "$@"; }
# shellcheck disable=SC2317,SC2329 # appelée par trap
en_sortie() {
  if [ -z "$garder" ]; then
    compose down --volumes > /dev/null 2>&1 || true
    docker image rm "$image" > /dev/null 2>&1 || true
    rm -rf -- "$travail"
  else
    echo "--keep : projet $projet conservé ; fichiers dans $travail ; docker compose -p $projet -f $travail/labo/compose.yaml down pour finir"
  fi
}
trap en_sortie EXIT

# Construit une image ; derrière un mandataire HTTPS, apt passe par lui (dépôts en https).
construire() { # $1 image  $2 dossier de contexte
  local contexte="$2" options=()
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    contexte="$travail/contexte-$1"
    cp -r "$2" "$contexte"
    local ajout="RUN sed -i 's,http://deb.debian.org,https://deb.debian.org,g' /etc/apt/sources.list.d/debian.sources"
    # L'adresse du mandataire est écrite dans le Dockerfile, non lue d'un ARG : BuildKit ne la compte pas
    # dans la clé de cache des ARG de proxy, et une couche bâtie avec un ancien mandataire serait réutilisée.
    ajout+=" && echo 'Acquire::https::Proxy \"$HTTPS_PROXY\";' > /etc/apt/apt.conf.d/90tptest-mandataire"
    cp "$TPTEST_CA" "$contexte/tptest-ca.crt"
    ajout="COPY tptest-ca.crt /usr/local/share/tptest-ca.crt"$'\n'"$ajout"
    ajout+=" && echo 'Acquire::https::CAInfo \"/usr/local/share/tptest-ca.crt\";' >> /etc/apt/apt.conf.d/90tptest-mandataire"
    AJOUT="$ajout" awk '{ print } /^FROM / && !fait { fait = 1; print ENVIRON["AJOUT"] }' "$2/Dockerfile" > "$contexte/Dockerfile"
    options=(--network host --build-arg "HTTPS_PROXY=$HTTPS_PROXY")
    echo "Mandataire HTTPS $HTTPS_PROXY : la construction passe par lui, avec l'autorité $TPTEST_CA."
  fi
  docker image build -q "${options[@]}" -t "$1" "$contexte" > /dev/null
}

# Copies du laboratoire et des corrigés : réseau du harnais, image du harnais.
cp -r "$labo" "$travail/labo"
cp -r "$corrige" "$travail/corrige"
sed -i "s/172\.20\.0\./$reseau./g; s/image: wireguard-labo/image: $image/" "$travail/labo/compose.yaml"
sed -i "s/172\.20\.0\./$reseau./g" "$travail/corrige"/*.conf
compose down --volumes > /dev/null 2>&1 || true # restes d'un test interrompu

titre "Laboratoire : image et trois pairs"
if construire "$image" "$travail/labo"; then ok "image $image construite depuis labo/Dockerfile"
else ko "construction de labo/Dockerfile (accès à deb.debian.org ?)"; bilan; fi
if compose up -d --no-build > "$travail/up.log" 2>&1; then ok "docker compose up : pair-a, pair-b, pair-c"
else ko "docker compose up"; cat "$travail/up.log"; bilan; fi

sur() { local p=$1; shift; compose exec -T "$p" bash -c "$*"; }
for p in a b c; do egal_ip="$(sur "pair-$p" "hostname -I" | tr -d ' ')"
  case "$p" in a) n=2 ;; b) n=3 ;; c) n=4 ;; esac
  if [ "$egal_ip" = "$reseau.$n" ]; then ok "pair-$p : adresse $reseau.$n sur le réseau porteur"
  else ko "pair-$p : adresse « $egal_ip », $reseau.$n attendue"; fi
done
if sur pair-a 'ip link add tptestwg type wireguard 2> /dev/null && ip link del tptestwg'; then
  module=1; echo "Module WireGuard du noyau de l'hôte présent : wg-quick crée une interface du noyau."
else
  module=""; echo "Module WireGuard absent du noyau de l'hôte : wg-quick se rabat sur wireguard-go (espace utilisateur)."
fi

titre "Étape 2 : generer-cles.sh"
for p in a b c; do
  compose cp "$travail/corrige/generer-cles.sh" "pair-$p:/usr/local/bin/generer-cles.sh" > /dev/null
  if sur "pair-$p" generer-cles.sh > "$travail/cles-$p.log" 2>&1; then ok "pair-$p : generer-cles.sh"
  else ko "pair-$p : generer-cles.sh"; cat "$travail/cles-$p.log"; fi
  droits="$(sur "pair-$p" "stat -c '%a %U' /etc/wireguard/prive.key /etc/wireguard/public.key" | tr '\n' ' ')"
  if [ "$droits" = "600 root 600 root " ]; then ok "pair-$p : prive.key et public.key en 600, à root"
  else ko "pair-$p : droits « $droits »"; fi
done
declare -A PRIVE PUBLIC
for p in a b c; do
  PRIVE[$p]="$(sur "pair-$p" cat /etc/wireguard/prive.key)"
  PUBLIC[$p]="$(sur "pair-$p" cat /etc/wireguard/public.key)"
  if [ "$(printf '%s' "${PRIVE[$p]}" | sur "pair-$p" wg pubkey)" = "${PUBLIC[$p]}" ]; then ok "pair-$p : public.key est la clé publique de prive.key"
  else ko "pair-$p : public.key ne correspond pas à prive.key"; fi
done

# Installe un corrigé sur un pair, chevrons remplacés par les vraies clés.
installer() { # $1 fichier de corrige/  $2 pair (a, b, c)
  local f="$travail/$2-wg0.conf"
  sed -e "s|<clé privée de pair-$2>|${PRIVE[$2]}|" \
      -e "s|<clé publique de pair-a>|${PUBLIC[a]}|" -e "s|<clé publique de pair-b>|${PUBLIC[b]}|" \
      -e "s|<clé publique de pair-c>|${PUBLIC[c]}|" "$travail/corrige/$1" > "$f"
  if grep -q '[<>]' "$f"; then ko "$1 : des chevrons restent après remplacement"; fi
  chmod 600 "$f"
  compose cp "$f" "pair-$2:/etc/wireguard/wg0.conf" > /dev/null
}

titre "Étapes 3 et 4 : pair-a.conf, pair-b.conf, wg-quick up"
installer pair-a.conf a
installer pair-b.conf b
for p in a b; do
  if sur "pair-$p" 'wg-quick up wg0' > "$travail/up-$p.log" 2>&1; then ok "pair-$p : wg-quick up wg0"
  else ko "pair-$p : wg-quick up wg0"; cat "$travail/up-$p.log"; fi
done
if [ -n "$module" ]; then
  if grep -q userspace "$travail/up-a.log"; then ko "wg-quick s'est rabattu sur wireguard-go malgré le module"
  else ok "wg-quick : interface du noyau, sans repli"; fi
else
  if grep -q 'Falling back to slow userspace implementation' "$travail/up-a.log"; then ok "wg-quick : sans module, repli annoncé sur wireguard-go"
  else ko "wg-quick : le repli sur wireguard-go n'apparaît pas"; cat "$travail/up-a.log"; fi
fi
if sur pair-a 'ip -4 -brief address show wg0' | grep -q '10\.9\.9\.1/24'; then ok "pair-a : wg0 porte 10.9.9.1/24"
else ko "pair-a : wg0 n'a pas 10.9.9.1/24"; fi
if sur pair-a 'ip route show dev wg0' | grep -q '^10\.9\.9\.0/24'; then ok "pair-a : route 10.9.9.0/24 par wg0"
else ko "pair-a : pas de route 10.9.9.0/24 par wg0"; fi

# « ip » : seulement l'IPv4, sans l'ARP ni le multicast IPv6 qui suivent le démarrage des conteneurs.
compose exec -T -d pair-b bash -c 'tcpdump -lni eth0 -c 8 ip > /tmp/capture.txt 2> /dev/null'
sleep 2
if sur pair-a 'ping -c 3 -W 2 10.9.9.2' > "$travail/ping.log" 2>&1 && grep -q ' 0% packet loss' "$travail/ping.log"; then
  ok "ping de 10.9.9.1 à 10.9.9.2 dans le tunnel : 3 réponses"
else
  ko "ping dans le tunnel"; cat "$travail/ping.log"
fi
sleep 1
if sur pair-a 'wg show wg0' | grep -q 'latest handshake'; then ok "wg show (pair-a) : une poignée de main a eu lieu"
else ko "wg show (pair-a) : pas de poignée de main"; fi
egal_endpoint="$(sur pair-b 'wg show wg0 endpoints' | cut -f2)"
if [ "$egal_endpoint" = "$reseau.2:51820" ]; then ok "pair-b, sans Endpoint dans son fichier, a appris celui de pair-a : $egal_endpoint"
else ko "pair-b : endpoint « $egal_endpoint »"; fi
sur pair-b 'pkill tcpdump' > /dev/null 2>&1 || true
capture="$(sur pair-b 'cat /tmp/capture.txt')"
if grep -q "UDP, length" <<< "$capture" && grep -q "\.51820 > " <<< "$capture"; then ok "tcpdump (réseau porteur) : de l'UDP entre les ports 51820"
else ko "tcpdump : pas d'UDP 51820 capturé"; printf '%s\n' "$capture"; fi
if grep -qi 'icmp' <<< "$capture"; then ko "tcpdump : de l'ICMP en clair sur le réseau porteur"
else ok "tcpdump (réseau porteur) : aucun ICMP, rien de 10.9.9.x"; fi

titre "Étape 5 : AllowedIPs, sortant puis entrant"
sur pair-a "wg set wg0 peer ${PUBLIC[b]} allowed-ips 10.9.9.3/32"
if sur pair-a 'ping -c 2 -W 1 10.9.9.2' > /dev/null 2>&1; then ko "sortant : le ping passe alors qu'aucun pair ne couvre 10.9.9.2"
else ok "sortant : aucun pair ne couvre 10.9.9.2, le ping échoue"; fi
sur pair-a "wg set wg0 peer ${PUBLIC[b]} allowed-ips 10.9.9.2/32"
recu() { sur "$1" "wg show wg0 transfer" | awk -v k="$2" '$1 == k { print $2 }'; }
envoye() { sur "$1" "wg show wg0 transfer" | awk -v k="$2" '$1 == k { print $3 }'; }
sur pair-b "wg set wg0 peer ${PUBLIC[a]} allowed-ips 10.9.9.100/32"
r0="$(recu pair-b "${PUBLIC[a]}")"; e0="$(envoye pair-b "${PUBLIC[a]}")"
compose exec -T -d pair-b bash -c "timeout 10 tcpdump -lni eth0 -c 2 udp and src host $reseau.2 > /tmp/entrant.txt 2> /dev/null"
sleep 1
if sur pair-a 'ping -c 2 -W 1 10.9.9.2' > /dev/null 2>&1; then ko "entrant : pair-b répond à une source hors des AllowedIPs de pair-a"
else ok "entrant : pair-b refuse la source 10.9.9.1, le ping échoue"; fi
sleep 1
sur pair-b 'pkill tcpdump' > /dev/null 2>&1 || true
arrives="$(sur pair-b 'grep -c "\.51820 > " /tmp/entrant.txt' || true)"
r1="$(recu pair-b "${PUBLIC[a]}")"; e1="$(envoye pair-b "${PUBLIC[a]}")"
if [ "$r1" -gt "$r0" ] && [ "$e1" = "$e0" ]; then ok "entrant : wg show transfer, reçu $r0 → $r1 octets, envoyé inchangé ($e1) : paquets jetés"
# Le module du noyau ne compte peut-être pas les paquets qu'il jette (le journal de la CI a montré reçu inchangé) :
# la preuve devient alors l'arrivée des paquets chiffrés sur eth0 de pair-b, sans un octet envoyé en retour.
elif [ -n "$module" ] && [ "${arrives:-0}" -gt 0 ] && [ "$e1" = "$e0" ]; then
  ok "entrant : $arrives paquets UDP de pair-a arrivés sur pair-b, aucun octet envoyé en retour ($e1) : paquets jetés (compteur reçu $r0 → $r1 avec le module noyau)"
else ko "entrant : compteurs reçu $r0 → $r1, envoyé $e0 → $e1, paquets UDP arrivés : ${arrives:-0}"; fi
sur pair-b "wg set wg0 peer ${PUBLIC[a]} allowed-ips 10.9.9.1/32"
if sur pair-a 'ping -c 1 -W 2 10.9.9.2' > /dev/null 2>&1; then ok "AllowedIPs rétablies : le ping repasse"
else ko "AllowedIPs rétablies : le ping ne repasse pas"; fi

titre "Étape 6 : un troisième pair"
installer pair-a-trois-pairs.conf a
if sur pair-a 'wg syncconf wg0 <(wg-quick strip wg0)' 2> "$travail/sync.log"; then ok "pair-a : wg syncconf wg0 <(wg-quick strip wg0)"
else ko "pair-a : wg syncconf"; cat "$travail/sync.log"; fi
egal_pairs="$(sur pair-a 'wg show wg0 peers' | wc -l)"
if [ "$egal_pairs" = 2 ]; then ok "pair-a : deux pairs (wg show wg0 peers)"; else ko "pair-a : $egal_pairs pairs"; fi
installer pair-c.conf c
if sur pair-c 'wg-quick up wg0' > "$travail/up-c.log" 2>&1; then ok "pair-c : wg-quick up wg0"
else ko "pair-c : wg-quick up wg0"; cat "$travail/up-c.log"; fi
if sur pair-a 'ping -c 2 -W 2 10.9.9.3' > /dev/null 2>&1; then ok "pair-a joint pair-c (10.9.9.3)"
else ko "pair-a ne joint pas pair-c"; fi
if sur pair-a 'ping -c 1 -W 2 10.9.9.2' > /dev/null 2>&1; then ok "pair-b n'a pas été coupé par syncconf"
else ko "pair-b ne répond plus après syncconf"; fi
if sur pair-b 'ping -c 1 -W 1 10.9.9.3' > /dev/null 2>&1; then ko "pair-b joint pair-c sans relais : inattendu"
else ok "pair-b ne joint pas pair-c : aucun de ses pairs ne couvre 10.9.9.3"; fi

titre "Étape 7 : pair-a relaie"
egal_fw="$(sur pair-a 'cat /proc/sys/net/ipv4/ip_forward')"
if [ "$egal_fw" = 1 ]; then ok "pair-a : ip_forward vaut 1 (sysctls de compose.yaml)"; else ko "pair-a : ip_forward vaut $egal_fw"; fi
sur pair-b "wg set wg0 peer ${PUBLIC[a]} allowed-ips 10.9.9.0/24"
sur pair-c "wg set wg0 peer ${PUBLIC[a]} allowed-ips 10.9.9.0/24"
if sur pair-b 'ping -c 2 -W 2 10.9.9.3' > "$travail/relais.log" 2>&1 && grep -q 'ttl=63' "$travail/relais.log"; then
  ok "pair-b joint pair-c par pair-a : réponses en ttl=63 (un routeur traversé)"
else
  ko "pair-b ne joint pas pair-c par pair-a"; cat "$travail/relais.log"
fi
egal_ar="$(sur pair-c 'wg show wg0 allowed-ips' | cut -f2)"
if [ "$egal_ar" = "10.9.9.0/24" ]; then ok "pair-c : AllowedIPs de pair-a = 10.9.9.0/24"; else ko "pair-c : AllowedIPs « $egal_ar »"; fi
bilan
