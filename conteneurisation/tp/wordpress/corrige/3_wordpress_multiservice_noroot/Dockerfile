# Étape 3 — plus aucun processus root une fois le conteneur démarré.
# Modèle du cours « root au démarrage seulement » : entrypoint.sh, lancé en
# root, prépare ce qui exige root, puis lance chaque service sous son
# utilisateur. Aucun bit setuid n'est ajouté à l'image.

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
    rm -f latest.zip index.html && \
    mv wordpress/* . && \
    rmdir wordpress && \
    chown -R www-data: .

# Le paquet apache2 crée ses journaux pour root : Apache, désormais lancé sous
# www-data, doit pouvoir y écrire. Ils restent dans des fichiers :
#   docker container exec mon_conteneur_wordpress tail /var/log/apache2/error.log
RUN chown -R www-data: /var/log/apache2

# Le script doit être exécutable dans le contexte de build (chmod +x).
COPY entrypoint.sh /usr/local/bin/

# Pas d'instruction USER : le script d'entrée démarre en root, et c'est lui qui
# abandonne les privilèges. ENTRYPOINT reçoit CMD en arguments : le script
# termine par « exec … apache2 -D FOREGROUND ».
ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2", "-D", "FOREGROUND"]

# Construction :
#   docker image build -t mon_image_wordpress .
# Lancement avec le moins de pouvoirs possible : toutes les capabilities sont
# retirées, sauf les trois dont le script d'entrée a besoin (CHOWN pour donner
# les dossiers, SETUID et SETGID pour changer d'utilisateur), et plus aucun
# binaire setuid ne peut redonner root :
#   docker container run -d --name mon_conteneur_wordpress -p 8080:80 \
#     --cap-drop ALL --cap-add CHOWN --cap-add SETUID --cap-add SETGID \
#     --security-opt no-new-privileges mon_image_wordpress
# Vérification : aucun processus root, et Apache porte le PID 1.
#   docker container top mon_conteneur_wordpress
#   docker container exec mon_conteneur_wordpress grep -E 'CapEff|NoNewPrivs' /proc/1/status
# Site : http://localhost:8080/ (adresse de la base : « localhost »).
