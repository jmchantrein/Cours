#!/bin/bash
# sshd_config, exercice 3 : relire le résultat avec awk.
# Les deux directives durcies, avec leur numéro de ligne :
awk '$1 == "PasswordAuthentication" || $1 == "PermitRootLogin" { print NR ": " $0 }' sshd_config
# Le nombre de directives actives (ni commentaire, ni ligne vide : NF vaut 0 sur une ligne vide) :
awk '!/^#/ && NF { n++ } END { print n, "directives actives" }' sshd_config
