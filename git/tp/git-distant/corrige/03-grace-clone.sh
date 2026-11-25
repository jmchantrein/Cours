#!/bin/bash
# Étape 3 : Grace clone le même dépôt central ; elle reçoit l'historique d'Ada.
cd ~/collab || exit 1
git clone depot-central.git grace
cd grace || exit 1
git config user.name "Grace Hopper"
git config user.email grace@example.org
git branch -a
git log --oneline
