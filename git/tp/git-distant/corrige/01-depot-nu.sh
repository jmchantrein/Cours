#!/bin/bash
# Étape 1 : le dépôt central, un dépôt nu (sans répertoire de travail), qui tient lieu de forge.
mkdir -p ~/collab
cd ~/collab || exit 1
git init --bare -b main depot-central.git
ls depot-central.git
