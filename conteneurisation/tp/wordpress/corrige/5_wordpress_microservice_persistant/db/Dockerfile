# Service « db » : MariaDB seul, avec la base du site.
# Construction et lancement : voir build_and_launch.sh (étape 5) ou
# compose.yaml (étape 6).

FROM debian:13

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -yq --no-install-recommends \
      mariadb-server && \
    rm -rf /var/lib/apt/lists/*

# Exemple d'école : un mot de passe déclaré par ENV se lit dans l'image.
ENV MARIADB_DATABASE=wordpress \
    MARIADB_USER=admin \
    MARIADB_PASSWORD=tempo

# '%' : l'utilisateur peut se connecter depuis une autre machine, ici le
# conteneur « wordpress ». Le dossier du socket, /run/mysqld, est donné à
# mysql pendant le build : plus rien n'exige root au démarrage.
RUN service mariadb start && \
    mariadb --execute "CREATE DATABASE ${MARIADB_DATABASE}" && \
    mariadb --execute "CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}'" && \
    mariadb --execute "GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%'" && \
    service mariadb stop && \
    mkdir -p /run/mysqld && \
    chown mysql: /run/mysqld

# Tout le conteneur tourne sous mysql, dès son premier processus.
USER mysql

# Port documenté, pas publié : la base n'est joignable que depuis le réseau
# des conteneurs.
EXPOSE 3306

# mariadbd est le PID 1 : il reçoit le SIGTERM de « docker container stop » et
# ferme ses fichiers proprement, ce qu'il ne pouvait pas faire aux étapes 3
# et 4. Ses journaux sortent sur la sortie d'erreur, donc dans
# « docker container logs db ».
# Le paquet Debian n'écoute que sur 127.0.0.1 (ligne bind-address de
# /etc/mysql/mariadb.conf.d/50-server.cnf) : une option de la ligne de commande
# l'emporte sur ce fichier.
CMD ["mariadbd", "--bind-address=0.0.0.0"]
