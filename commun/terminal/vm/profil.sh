# shellcheck shell=sh
# /etc/profile.d/cours.sh de la VM du terminal : invite courte, couleurs de ls.
# L'invite finit par « # » (root) : la page attend cette invite avant d'envoyer les commandes cliquées.
PS1='\u@\h:\w\$ '
alias ls='ls --color=auto'
