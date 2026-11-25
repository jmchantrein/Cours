#!/bin/sh
# Étape 3 — revenir à l'instantané.
set -eu

# Incus arrête la VM, remet son disque dans l'état de l'instantané, puis la
# redémarre.
incus snapshot restore vm1 propre

# Le site est de retour quand Apache et MariaDB ont redémarré (deux minutes au plus).
timeout 120 sh -c 'until incus exec vm1 -- systemctl is-active --quiet apache2 mariadb 2> /dev/null; do sleep 2; done'
incus snapshot list vm1
