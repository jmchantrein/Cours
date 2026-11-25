#!/bin/sh
# Étape 1 — instances et images : une machine virtuelle Debian 13.
set -eu

# L'image vient du serveur « images: » ; --vm demande une machine virtuelle.
incus launch images:debian/13 vm1 --vm

# incus exec passe par l'agent de la VM, qui ne répond qu'une fois le système
# invité démarré : on attend sa première réponse.
until incus exec vm1 -- true 2> /dev/null; do sleep 2; done

incus list
incus info vm1
incus exec vm1 -- uname -r
incus exec vm1 -- systemd-detect-virt

# La console de la VM, pour suivre un démarrage ou se connecter sans réseau :
#   incus console vm1        (la quitter : Ctrl+a, puis q)

# La VM est un processus QEMU de l'hôte ; incus list donne son PID (colonne p).
pid="$(incus list vm1 -c p -f csv)"
ps -o pid,user,args -p "$pid"
