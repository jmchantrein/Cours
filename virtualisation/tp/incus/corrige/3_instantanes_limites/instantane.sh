#!/bin/sh
# Étape 3 — un instantané de la VM, site installé.
set -eu

# L'instantané d'une VM en marche fige son disque, pas sa mémoire : ce que le
# système invité garde encore en cache (fichiers écrits depuis quelques
# secondes) n'y serait pas. sync l'écrit d'abord sur le disque.
incus exec vm1 -- sync
incus snapshot create vm1 propre
incus snapshot list vm1
