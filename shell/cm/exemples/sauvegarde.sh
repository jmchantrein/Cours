#!/bin/bash
# Archive le dossier donné en premier argument, avec la date du jour dans le nom
date_jour=$(date +%Y%m%d)
tar -czf "sauvegarde_${date_jour}.tar.gz" "$1"
exit 0
