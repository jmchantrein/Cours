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

titre "Redémarrage : de incus restart à la première réponse de incus exec (s)"
for instance in ct1 vm1; do
  debut="$(date +%s)"
  incus restart "$instance"
  until incus exec "$instance" -- true 2> /dev/null; do sleep 1; done
  printf '%s  : %s s\n' "$instance" "$(($(date +%s) - debut))"
  # La suite mesure ce démarrage : on attend qu'il soit fini. Le code de
  # retour signale un service en échec, ce qui n'empêche pas la mesure.
  incus exec "$instance" -- systemctl is-system-running --wait > /dev/null || true
done

titre "Démarrage : les phases que systemd a chronométrées"
for instance in vm1 ct1; do
  printf '%s  : ' "$instance"; incus exec "$instance" -- systemd-analyze time | head -n 1
done

titre "Mémoire : le total que voit chaque système (Mio)"
partout sh -c "free -m | sed -n 2p"

titre "Processus et mémoire comptés par Incus"
incus list -c ntNm

titre "Processus apache2 vus de l'hôte : UID, PID, commande"
# Apache tourne aussi dans vm1 : cherchez ses processus dans cette liste.
ps -o uid,pid,args -C apache2 || true

titre "Les mêmes processus, vus dans ct1"
incus exec ct1 -- ps -o uid,pid,args -C apache2

titre "Correspondance des UID du conteneur : UID dedans, UID sur l'hôte, étendue"
incus exec ct1 -- cat /proc/self/uid_map

titre "La VM, elle, est un seul processus de l'hôte"
ps -o uid,pid,rss,comm -p "$(incus list vm1 -c p -f csv)"
