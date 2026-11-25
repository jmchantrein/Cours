#!/bin/bash
# sed, exercice 3 : une plage entre deux motifs, de l'en-tête d'une section à la ligne vide qui la termine.
# La section [base_de_donnees], seule :
sed -n '/^\[base_de_donnees\]/,/^$/p' services.conf
# Le port de la section [web] seulement, passé à 8443 : la substitution ne vaut que dans la plage.
sed '/^\[web\]/,/^$/ s/^port = .*/port = 8443/' services.conf | grep -n '^port'
