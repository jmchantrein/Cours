# Étape 2 — la même image, écrite selon les bonnes pratiques du cours.

# Un tag précis pour l'image de base : « latest » change avec le temps.
FROM debian:13

# Les paquets d'abord : c'est l'instruction la plus longue et la plus stable ;
# le cache de build la réutilise tant qu'elle ne change pas.
# - update et install dans le même RUN : sinon un « update » resté en cache
#   donnerait des index périmés à un « install » modifié ;
# - DEBIAN_FRONTEND en préfixe : la variable ne vaut que pour cette commande,
#   elle n'est pas dans l'image ;
# - --no-install-recommends : les dépendances strictes seulement. Il faut alors
#   nommer ca-certificates, que wget ne fait que recommander et sans lequel il
#   ne peut pas vérifier le certificat de wordpress.org ;
# - un paquet par ligne, dans l'ordre alphabétique : une modification se lit
#   d'un coup d'œil ;
# - les index d'apt sont supprimés dans le même RUN : ils ne sont dans aucune
#   couche.
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

# Les variables juste avant leur premier usage : les modifier n'invalide pas le
# cache de l'installation des paquets.
# Exemple d'école : un mot de passe déclaré par ENV se lit dans l'image
# (docker image history, docker image inspect).
ENV MARIADB_DATABASE=wordpress \
    MARIADB_USER=admin \
    MARIADB_PASSWORD=tempo

# La base et son utilisateur dans un seul RUN : le serveur ne vit que le temps
# de ce RUN. On l'arrête proprement, pour que ses fichiers soient enregistrés
# dans la couche dans un état cohérent.
RUN service mariadb start && \
    mariadb --execute "CREATE DATABASE ${MARIADB_DATABASE}" && \
    mariadb --execute "CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}'" && \
    mariadb --execute "GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%'" && \
    service mariadb stop

# WORKDIR change de répertoire pour les instructions suivantes et pour le
# conteneur ; un « RUN cd » ne vaut que pour son propre RUN.
WORKDIR /var/www/html

# Téléchargement, extraction et nettoyage dans le même RUN : l'archive n'est
# dans aucune couche. Les sources vont à la racine du serveur web, à la place
# de la page d'accueil de Debian : le site est servi sous http://localhost:8080/.
# Ce RUN reste en cache : pour obtenir la dernière version de WordPress,
# reconstruire avec --no-cache.
RUN wget -q https://wordpress.org/latest.zip && \
    unzip -q latest.zip && \
    rm -f latest.zip index.html && \
    mv wordpress/* . && \
    rmdir wordpress && \
    chown -R www-data: .

# Le dossier où Apache écrit son fichier PID. À l'étape 1, apache2ctl le créait
# à chaque lancement.
RUN mkdir -p /run/apache2

# Forme exec : pas de /bin/sh ajouté par Docker. Deux services à lancer imposent
# tout de même un shell ; il se termine par « exec », qui le remplace par
# Apache. Apache est alors le PID 1 et reçoit le SIGTERM de
# « docker container stop » : l'arrêt est immédiat.
# apache2ctl n'est qu'un script qui charge /etc/apache2/envvars puis lance
# apache2 sans exec : on fait ici les deux à sa place.
CMD ["sh", "-c", "service mariadb start && . /etc/apache2/envvars && exec apache2 -D FOREGROUND"]

# Construction, à cache vierge et en retéléchargeant l'image de base, puis
# lancement :
#   docker image build --no-cache --pull -t mon_image_wordpress .
#   docker container run -d --name mon_conteneur_wordpress -p 8080:80 mon_image_wordpress
# Site : http://localhost:8080/
# Dans l'assistant d'installation : base « wordpress », identifiant « admin »,
# mot de passe « tempo », adresse de la base « localhost ».
