# shellcheck shell=sh
# /etc/profile.d/cours.sh de la VM du terminal : invite courte, couleurs de ls.
# L'invite finit par « $ » : la page attend cette invite avant d'envoyer les commandes cliquées.
export LANG=C.UTF-8 TERM=${TERM:-xterm-256color}
PS1='\u@\h:\w\$ '
umask 002   # comme une session Debian : chaque compte a son groupe (TP « Droits »)
alias ls='ls --color=auto'
