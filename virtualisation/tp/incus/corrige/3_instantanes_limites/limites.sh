#!/bin/sh
# Étape 3 — changer les ressources de la VM : 2 processeurs, 2 Gio de mémoire.
set -eu

# Sans réglage, une VM a 1 processeur et 1 Gio de mémoire.
incus exec vm1 -- nproc
incus exec vm1 -- free -m

# Les processeurs s'ajoutent à chaud : la VM continue de tourner.
incus config set vm1 limits.cpu=2
incus exec vm1 -- lscpu --extended

# La mémoire ne s'augmente pas à chaud (Incus 6.0) : on arrête la VM, on
# change la limite, on la redémarre.
incus stop vm1
incus config set vm1 limits.memory=2GiB
incus start vm1
until incus exec vm1 -- systemctl is-active --quiet apache2 mariadb 2> /dev/null; do sleep 2; done

# Les clés posées sur l'instance, puis ce que voit l'invité.
incus config show vm1
incus exec vm1 -- nproc
incus exec vm1 -- free -m
