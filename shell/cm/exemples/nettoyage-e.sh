#!/bin/bash
set -euo pipefail
cd /tmp/chantier
# la suppression réelle serait : rm -f ./*.tmp
echo "Je supprimerais les .tmp de : $(pwd)"
