#!/usr/bin/env bash
# Étape 3 : complétion et historique. Les touches (Tab, flèches, Ctrl+R) ne se
# rejouent pas dans un script : voici les commandes qu'elles ont produites.

cd ~/atelier
# wc -l jo, Tab (journaux/), Tab (serveur-202), Tab Tab (la liste), 6, Tab :
wc -l journaux/serveur-2026-novembre.log
# whoa, Tab :
whoami
# Ctrl+R, wc : la commande wc retrouvée, puis Entrée
wc -l journaux/serveur-2026-novembre.log
