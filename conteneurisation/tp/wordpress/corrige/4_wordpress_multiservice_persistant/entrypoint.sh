#!/bin/sh
# Script d'entrée : root au démarrage seulement.
# Il est lancé en root, fait le peu qui exige root, puis lance chaque service
# sous son utilisateur. Une fois Apache lancé, plus aucun processus n'est root.
set -eu

# 1. Ce qui exige root : créer les dossiers d'exécution des deux services et
#    les donner à leurs utilisateurs. Les chemins d'Apache sont définis dans
#    /etc/apache2/envvars, que seul apache2ctl charge : on le charge ici, pour
#    ce script et pour Apache. Ce fichier lit APACHE_CONFDIR : sans elle,
#    « set -u » arrêterait le script.
export APACHE_CONFDIR=/etc/apache2
. /etc/apache2/envvars
mkdir -p /run/mysqld "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR"
chown mysql: /run/mysqld
chown www-data: "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR"

# 2. MariaDB en arrière-plan, sous l'utilisateur mysql. setpriv peut changer
#    d'identité parce que c'est root qui le lance : ce n'est pas un binaire
#    setuid, il fait descendre de root et jamais monter.
setpriv --reuid=mysql --regid=mysql --init-groups mariadbd &

# 3. Apache sous www-data. « exec » remplace ce script par la commande reçue en
#    arguments (CMD : apache2 -D FOREGROUND) : Apache devient le PID 1 et
#    reçoit le SIGTERM de « docker container stop ». Depuis Docker 20.10, un
#    processus sans privilège peut écouter sur le port 80 dans un conteneur.
#    Limite d'un conteneur à deux services : seul le PID 1 est prévenu de
#    l'arrêt. MariaDB, lui, est tué sans avoir fermé ses fichiers ; il les
#    répare au démarrage suivant. L'étape 5 lève cette limite.
exec setpriv --reuid=www-data --regid=www-data --init-groups "$@"
