#!/bin/bash
# sshd_config, exercice 2 : durcir le fichier, en place, avec une copie de secours.
# #? : la ligne peut être commentée ou non ; (…|…) capture le nom de la directive, que \1 recopie.
sed -E -i.bak 's/^#?(PasswordAuthentication|PermitRootLogin) .*/\1 no/' sshd_config
diff sshd_config.bak sshd_config
