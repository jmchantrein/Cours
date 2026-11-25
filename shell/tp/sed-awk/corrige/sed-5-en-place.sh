#!/bin/bash
# sed, exercice 5 : sur une copie de services.conf, commenter toute la section [sauvegarde], dans le fichier.
# La plage n'a pas de ligne vide après elle : elle court jusqu'à la fin du fichier.
cp services.conf services.copie
sed -i.bak '/^\[sauvegarde\]/,/^$/ s/^/# /' services.copie
diff services.copie.bak services.copie
