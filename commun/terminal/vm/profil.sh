# shellcheck shell=sh
# /etc/profile.d/cours.sh de la VM du terminal : invite courte, umask de Debian. Pas d'alias « ls --color » : il fait
# un stat par fichier, et `ls` d'un dossier sans droit x afficherait des erreurs que les sorties des énoncés ne montrent pas.
# L'invite finit par « $ » : la page attend cette invite avant d'envoyer les commandes cliquées.
export LANG=C.UTF-8 TERM=${TERM:-xterm-256color}
PS1='\u@\h:\w\$ '
umask 002   # comme une session Debian : chaque compte a son groupe (TP « Droits »)
