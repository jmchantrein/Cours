#!/bin/sh
# Étape 3 — un instantané de la VM, site installé.
set -eu

incus snapshot create vm1 propre
incus snapshot list vm1
