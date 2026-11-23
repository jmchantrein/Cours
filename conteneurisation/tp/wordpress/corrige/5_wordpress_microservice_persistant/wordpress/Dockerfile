# Service « wordpress » : Apache, PHP et les sources de WordPress. La base est
# dans un autre conteneur, joint par son nom : « db ».
# Construction et lancement : voir build_and_launch.sh (étape 5) ou
# compose.yaml (étape 6).

FROM debian:13

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -yq --no-install-recommends \
      apache2 \
      ca-certificates \
      libapache2-mod-php \
      php-mysql \
      unzip \
      wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

RUN wget -q https://wordpress.org/latest.zip && \
    unzip -q latest.zip && \
    cp -a wordpress/. . && \
    rm -rf latest.zip wordpress index.html && \
    chown -R www-data: .

# Un seul service, donc un seul utilisateur : plus besoin de root au démarrage
# ni de script d'entrée. Ce qui exigeait root se fait pendant le build :
# - les dossiers d'exécution et de verrou d'Apache, donnés à www-data
#   (leurs chemins sont dans /etc/apache2/envvars) ;
# - les journaux, renvoyés vers la sortie standard et la sortie d'erreur du
#   conteneur : « docker container logs wordpress » les affiche.
RUN . /etc/apache2/envvars && \
    mkdir -p "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR" && \
    ln -sf /dev/stdout "$APACHE_LOG_DIR/access.log" && \
    ln -sf /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log" && \
    ln -sf /dev/stderr "$APACHE_LOG_DIR/error.log" && \
    chown www-data: "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR" "$APACHE_LOG_DIR"

# Tout le conteneur tourne sous www-data, dès son premier processus.
USER www-data

EXPOSE 80

# apache2ctl n'est qu'un script qui charge /etc/apache2/envvars puis lance
# apache2 sans exec. On fait les deux ici ; « exec » remplace le shell par
# Apache, qui devient le PID 1 et reçoit le signal d'arrêt.
CMD ["sh", "-c", ". /etc/apache2/envvars && exec apache2 -D FOREGROUND"]
