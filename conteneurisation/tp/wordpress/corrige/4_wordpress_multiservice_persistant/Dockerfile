# Étape 4 — les données survivent au conteneur.
# L'image change à peine : la persistance se décide au lancement, par deux
# volumes nommés (commandes en fin de fichier). entrypoint.sh est celui de
# l'étape 3.

FROM debian:13

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -yq --no-install-recommends \
      apache2 \
      ca-certificates \
      libapache2-mod-php \
      mariadb-server \
      php-mysql \
      unzip \
      wget && \
    rm -rf /var/lib/apt/lists/*

# Exemple d'école : un mot de passe déclaré par ENV se lit dans l'image.
ENV MARIADB_DATABASE=wordpress \
    MARIADB_USER=admin \
    MARIADB_PASSWORD=tempo

RUN service mariadb start && \
    mariadb --execute "CREATE DATABASE ${MARIADB_DATABASE}" && \
    mariadb --execute "CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}'" && \
    mariadb --execute "GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%'" && \
    service mariadb stop

WORKDIR /var/www/html

RUN wget -q https://wordpress.org/latest.zip && \
    unzip -q latest.zip && \
    cp -a wordpress/. . && \
    rm -rf latest.zip wordpress index.html && \
    chown -R www-data: .

RUN chown -R www-data: /var/log/apache2

COPY entrypoint.sh /usr/local/bin/

# EXPOSE documente le port du service ; il ne publie rien (c'est le rôle de -p).
# Le port de MariaDB n'est pas déclaré : la base ne sert qu'à l'intérieur du
# conteneur.
EXPOSE 80

# Pas d'instruction VOLUME : elle créerait à chaque lancement un volume anonyme,
# que rien ne relie au conteneur suivant. Les volumes sont nommés au lancement.

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2", "-D", "FOREGROUND"]

# Construction :
#   docker image build -t mon_image_wordpress .
# Lancement, avec un volume nommé pour la base et un pour le code du site :
#   docker container run -d --name mon_conteneur_wordpress -p 8080:80 \
#     -v data_wordpress:/var/lib/mysql \
#     -v source_code_wordpress:/var/www/html \
#     --cap-drop ALL --cap-add CHOWN --cap-add SETUID --cap-add SETGID \
#     --security-opt no-new-privileges mon_image_wordpress
# Au premier lancement, les deux volumes sont vides : Docker y copie ce que
# l'image contient à ces emplacements, propriétaires compris. La base créée
# pendant le build et les sources de WordPress s'y retrouvent donc.
# Vérification : installer WordPress, puis supprimer et recréer le conteneur.
#   docker container rm -f mon_conteneur_wordpress
#   (relancer la commande docker container run ci-dessus)
# Site : http://localhost:8080/ (adresse de la base : « localhost »).
