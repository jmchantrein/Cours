#!/bin/sh
# Étape 3 — changer les ressources de la VM : 2 processeurs, 2 Gio de mémoire.
set -eu

# Avant : 1 processeur et 1 Gio, les valeurs par défaut d'une VM.
incus exec vm1 -- nproc
incus exec vm1 -- free -m

# Incus 6.0 n'augmente pas la mémoire d'une VM en marche : on l'arrête, on
# change sa configuration, on la redémarre.
incus stop vm1
incus config set vm1 limits.cpu=2 limits.memory=2GiB
incus start vm1
until incus exec vm1 -- systemctl is-active --quiet apache2 mariadb 2> /dev/null; do sleep 2; done

# Après.
incus exec vm1 -- nproc
incus exec vm1 -- free -m
incus config show vm1
