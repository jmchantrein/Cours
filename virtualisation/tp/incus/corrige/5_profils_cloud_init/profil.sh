#!/bin/sh
# Étape 5 — un profil « wordpress », appliqué à une VM et à un conteneur.
set -eu

# cloud-init.yaml est cherché à côté du script.
cd "$(dirname "$0")"

# Le profil porte des limites et la configuration cloud-init ; « - » fait lire
# la valeur de la clé sur l'entrée standard.
incus profile create wordpress
incus profile set wordpress limits.cpu=2 limits.memory=1GiB
incus profile set wordpress cloud-init.user-data - < cloud-init.yaml
incus profile show wordpress

# Deux instances, la même configuration. L'image « cloud » contient cloud-init.
# Le profil default donne le disque et la carte réseau ; wordpress s'y ajoute.
incus launch images:debian/13/cloud wp-vm --vm --profile default --profile wordpress
incus launch images:debian/13/cloud wp-ct --profile default --profile wordpress

# cloud-init travaille au premier démarrage : status --wait rend la main quand
# il a fini (un code de retour non nul signale une erreur ou un avertissement).
for instance in wp-vm wp-ct; do
  until incus exec "$instance" -- true 2> /dev/null; do sleep 2; done
  incus exec "$instance" -- cloud-init status --wait || true
done

# La configuration que chaque instance hérite de ses profils.
incus config show wp-vm --expanded
incus list wp-
