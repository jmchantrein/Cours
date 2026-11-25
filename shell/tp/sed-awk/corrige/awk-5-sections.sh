#!/bin/bash
# awk, exercice 5 : services.conf en tableau : une ligne par section, avec son port et son démarrage.
# Une ligne « [web] » ouvre une section ; ordre[] retient l'ordre du fichier, que for (… in …) ne garantit pas.
awk '/^\[/ { s = substr($0, 2, length($0) - 2); ordre[++n] = s }
     $1 == "port" { port[s] = $3 }
     $1 == "autostart" { auto[s] = $3 }
     END { for (i = 1; i <= n; i++) print ordre[i], port[ordre[i]], auto[ordre[i]] }' services.conf
