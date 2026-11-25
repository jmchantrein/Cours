#!/bin/sh
# Étape 4 — la VM vm1 et le conteneur ct1, mesurés depuis l'hôte.
set -eu

titre() { printf '\n== %s\n' "$1"; }
# La même commande sur l'hôte, dans la VM, dans le conteneur.
partout() {
  printf 'hôte : '; "$@"
  printf 'vm1  : '; incus exec vm1 -- "$@"
  printf 'ct1  : '; incus exec ct1 -- "$@"
}

titre "Noyau : sa version, puis la ligne de commande qui l'a démarré"
partout uname -r
partout cat /proc/cmdline

titre "Ce que le système invité détecte"
printf 'vm1  : '; incus exec vm1 -- systemd-detect-virt
printf 'ct1  : '; incus exec ct1 -- systemd-detect-virt

titre "Démarrage : les phases que systemd a chronométrées"
# is-system-running --wait rend la main à la fin du démarrage ; son code de
# retour signale un service en échec, ce qui n'empêche pas la mesure.
for instance in vm1 ct1; do
  incus exec "$instance" -- systemctl is-system-running --wait > /dev/null || true
  printf '%s  : ' "$instance"; incus exec "$instance" -- systemd-analyze time | head -n 1
done

titre "Mémoire : le total que voit chaque système (Mio)"
partout sh -c "free -m | sed -n 2p"

titre "Processus et mémoire comptés par Incus"
incus list -c ntNm

titre "Processus apache2 vus de l'hôte : UID, PID, commande"
# Apache tourne aussi dans vm1 : cherchez ses processus dans cette liste.
ps -o uid,pid,args -C apache2 || true

titre "Correspondance des UID du conteneur : UID dedans, UID sur l'hôte, étendue"
incus exec ct1 -- cat /proc/self/uid_map

titre "La VM, elle, est un seul processus de l'hôte"
ps -o uid,pid,rss,comm -p "$(incus list vm1 -c p -f csv)"
