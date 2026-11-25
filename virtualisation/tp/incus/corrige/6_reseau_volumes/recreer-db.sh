#!/bin/sh
# Étape 6 — supprimer l'instance db, puis la recréer : les données sont sur le
# volume, elles survivent à l'instance.
set -eu
cd "$(dirname "$0")"

# Un arrêt propre : MariaDB ferme ses fichiers avant la suppression.
incus stop db
incus delete db
incus storage volume list default

# La même création qu'au premier lancement, sur le volume déjà rempli.
./db.sh
