# Une machine du labo SSH : Debian 13, le serveur et le client OpenSSH.
# Labo d'exercice : ces conteneurs jouent des machines distantes. En production,
# pas de sshd dans un conteneur (cours Conteneurisation, règle 5.7 du CIS Docker Benchmark).
FROM debian:13-slim
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server openssh-client rsync curl python3 iproute2 procps less nano vim-tiny \
 && rm -rf /var/lib/apt/lists/* /etc/ssh/ssh_host_*
# Le compte d'Ada, avec un mot de passe d'exercice connu de tous : jamais sur une vraie machine.
RUN useradd --create-home --shell /bin/bash ada \
 && echo 'ada:motdepasse' | chpasswd
# Comme sur bien des images cloud : un fichier de sshd_config.d qui autorise le mot de passe.
RUN echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/50-cloud-init.conf
# La page de supervision du serveur (étape 9).
RUN mkdir -p /srv/supervision \
 && echo 'Supervision : tout va bien' > /srv/supervision/index.html
COPY --chmod=755 demarrer.sh /usr/local/bin/demarrer.sh
CMD ["demarrer.sh"]
