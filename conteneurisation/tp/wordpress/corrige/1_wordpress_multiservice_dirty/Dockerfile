# Étape 1 — tout le service dans une seule image, sans chercher à bien faire.
# Ce Dockerfile fonctionne, mais l'étape 2 en reprend chaque maladresse :
# une couche par commande, « apt-get update » seul dans son RUN, « RUN cd »,
# variable DEBIAN_FRONTEND laissée dans l'image, archive et index d'apt
# conservés, commande par défaut en forme shell.

FROM debian:13

# Fait taire les questions des paquets pendant l'installation… et reste définie
# dans tous les conteneurs de l'image.
ENV DEBIAN_FRONTEND=noninteractive

# Une couche par RUN.
RUN apt-get update
RUN apt-get install -y apache2
RUN apt-get install -y libapache2-mod-php php-mysql
RUN apt-get install -y mariadb-server
RUN apt-get install -y wget unzip

# Chaque RUN repart de la racine : il faut refaire le « cd » à chaque fois.
# L'archive se décompresse dans /var/www/html/wordpress : le site sera servi
# sous http://localhost:8080/wordpress.
RUN cd /var/www/html && wget https://wordpress.org/latest.zip
RUN cd /var/www/html && unzip latest.zip
# Apache traite les requêtes sous l'utilisateur www-data, et l'installation de
# WordPress écrit son fichier wp-config.php dans ce dossier.
RUN chown -R www-data:www-data /var/www/html/wordpress

# Exemple d'école : un mot de passe déclaré par ENV se lit dans l'image
# (docker image history, docker image inspect).
ENV MARIADB_DATABASE=wordpress
ENV MARIADB_USER=admin
ENV MARIADB_PASSWORD=tempo

# Chaque RUN s'exécute dans un conteneur neuf : le serveur démarré par un RUN
# n'existe plus au suivant, il faut le relancer à chaque fois. Le script de
# service crée aussi /run/mysqld, où MariaDB place son socket.
# L'utilisateur n'a de droits que sur sa base (wordpress.*), pas sur tout le
# serveur (*.*).
RUN service mariadb start && mariadb --execute "CREATE DATABASE $MARIADB_DATABASE"
RUN service mariadb start && mariadb --execute "CREATE USER '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASSWORD'"
RUN service mariadb start && mariadb --execute "GRANT ALL PRIVILEGES ON $MARIADB_DATABASE.* TO '$MARIADB_USER'@'%'"

# Forme shell : Docker exécute /bin/sh -c "…". Ce sh est le PID 1 du conteneur ;
# MariaDB part en arrière-plan, Apache reste au premier plan et maintient le
# conteneur en vie. Tout tourne en root, sauf les processus fils d'Apache et le
# serveur mariadbd.
CMD service mariadb start && apache2ctl -D FOREGROUND

# Construction et lancement :
#   docker image build -t mon_image_wordpress .
#   docker container run -d --name mon_conteneur_wordpress -p 8080:80 mon_image_wordpress
# Site : http://localhost:8080/wordpress
# Dans l'assistant d'installation : base « wordpress », identifiant « admin »,
# mot de passe « tempo », adresse de la base « localhost ».
