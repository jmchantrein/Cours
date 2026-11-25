#!/usr/bin/env bash
# Rejoue les commandes du cours Docker dont la sortie est marquée « à rejouer » dans les notes de l'orateur,
# et relève les versions. À lancer sur un Debian 13 avec docker.io (26.1.5), AppArmor actif, utilisateur du
# groupe docker et accès sudo : ./rejouer.sh > sorties-conteneurisation.txt 2>&1
# Les commandes interactives (bash, ssh) ne sont pas rejouées ; tout est créé dans un dossier temporaire.
# Ports 8000, 8080 et 8081 libres. PRUNE=1 ./rejouer.sh rejoue aussi docker volume prune, qui agit sur tout le démon.
set -u
run() { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1; }
D=$(mktemp -d); cd "$D" || exit 1
echo "# $(date -I) · $(uname -srm) · $D"

# Versions
run 'docker version --format "{{.Server.Version}}"'
run 'docker compose version'
run 'docker buildx version'

# Bases
run 'docker container run --rm debian:13 /bin/ls'
run 'docker container run --name hw hello-world >/dev/null; docker container ls -a | head -3; docker container rm hw'
run 'docker container prune -f'
run 'docker container run ubuntu /bin/ps -eflH'
run 'docker info | grep -A3 "Security Options"'
run 'docker container run -d --name ctA alpine sleep infinity >/dev/null; docker container exec ctA ip route; docker container rm -f ctA'
run 'docker network create app && docker container run -d --network app --name web nginx && docker container run --rm --network app alpine nslookup web; docker container rm -f web; docker network rm app'
run 'docker container run -d --name web -p 8080:80 nginx:1.29-alpine >/dev/null; sleep 2; curl -s localhost:8080 >/dev/null; docker container logs web | tail -1; docker container rm -f web'

# Réseau : publication sur toutes les interfaces ou sur 127.0.0.1, puis les règles iptables (pare-feu contourné)
run 'docker container run -d --name web -p 8080:80 nginx:1.29-alpine >/dev/null; docker container run -d --name web-local -p 127.0.0.1:8081:80 nginx:1.29-alpine >/dev/null; sleep 2; docker container ls --format "table {{.Names}}\t{{.Ports}}" --filter name=web'
run 'H=$(hostname -I | cut -d" " -f1); echo "$H"; curl -s -o /dev/null -w "%{http_code}\n" "$H:8080"; curl -s -o /dev/null -w "%{http_code}\n" "$H:8081"'
run 'sudo iptables -t nat -S PREROUTING; sudo iptables -t nat -S DOCKER | grep 8080; sudo iptables -S DOCKER | grep "$(docker container inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" web)/"; sudo iptables -S FORWARD'
run 'docker container rm -f web web-local'
# Réseau : nom ou IP (exercice)
IPF='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
run 'docker network create front && docker network create back && docker container run -d --network front --name ctA alpine sleep infinity && docker container run -d --network back --name ctB alpine sleep infinity'
run "docker container exec ctA ping -c 1 -W 2 ctB; IP=\$(docker container inspect -f '$IPF' ctB); echo \$IP; docker container exec ctA ping -c 1 -W 2 \$IP"
run "docker network connect front ctB; docker container inspect -f '{{range \$n, \$c := .NetworkSettings.Networks}}{{\$n}} {{\$c.IPAddress}}{{\"\\n\"}}{{end}}' ctB; docker container exec ctA ping -c 1 -W 2 ctB"
run "docker container run -d --name ctC alpine sleep infinity && docker container run -d --name ctD alpine sleep infinity; docker container exec ctC ping -c 1 -W 2 ctD; IP=\$(docker container inspect -f '$IPF' ctD); echo \$IP; docker container exec ctC ping -c 1 -W 2 \$IP"
run 'docker container rm -f ctA ctB ctC ctD; docker network rm front back'
# Réseau : segmentation frontend / backend (mariadb avec mot de passe root aléatoire), puis mariadb sans mot de passe
run 'docker network create frontend && docker network create backend && docker container run -d --name db --network backend -e MARIADB_RANDOM_ROOT_PASSWORD=1 mariadb:11.8 && docker container run -d --name web --network frontend -p 8080:80 nginx:1.29-alpine && docker network connect backend web'
run 'sleep 5; docker container exec web nc -zv -w 2 db 3306; docker container run --rm --network frontend alpine nc -zv -w 2 db 3306'
run 'docker container stop db >/dev/null; docker container exec web nslookup db; docker container rm -f -v db web; docker network rm frontend backend'
run 'docker container run -d --name db0 mariadb:11.8 >/dev/null; sleep 5; docker container ls -a --filter name=db0 --format "{{.Status}}"; docker container logs db0 2>&1 | tail -2; docker container rm -f -v db0'
# Réseau : resolv.conf du conteneur, avec et sans --dns
run 'cat /etc/resolv.conf; docker container run --rm debian:13 cat /etc/resolv.conf; docker container run --rm --dns 192.0.2.53 debian:13 cat /etc/resolv.conf'

# Journaux : json-file sans rotation, puis avec max-size et max-file
run 'docker info --format "{{.LoggingDriver}}"'
run 'docker container run -d --name bavard alpine sh -c "seq 200000; sleep infinity" >/dev/null; sleep 5; sudo ls -l "$(dirname "$(docker container inspect -f "{{.LogPath}}" bavard)")"; docker container rm -f bavard'
run 'docker container run -d --name bavard --log-opt max-size=1m --log-opt max-file=3 alpine sh -c "seq 200000; sleep infinity" >/dev/null; sleep 5; sudo ls -l "$(dirname "$(docker container inspect -f "{{.LogPath}}" bavard)")"; docker container logs bavard | head -1; docker container logs bavard | wc -l; docker container rm -f bavard'
run 'docker container run --rm nginx:1.29-alpine ls -l /var/log/nginx'
# Volumes : volume anonyme de mariadb ; prune efface les volumes du démon entier : seulement avec PRUNE=1
run 'docker container run -d --name db1 -e MARIADB_RANDOM_ROOT_PASSWORD=1 mariadb:11.8 >/dev/null; docker container inspect -f "{{json .Mounts}}" db1; docker container rm -f -v db1'
if [ "${PRUNE:-0}" = 1 ]; then
  run 'docker volume create essai-nomme >/dev/null; docker container run --name anon -v /data debian:13 true; docker container rm anon; docker volume ls; docker volume prune -f; docker volume ls; docker volume rm essai-nomme'
fi

# Persistance : piège du montage écrit en root
run 'mkdir -p partage && docker container run --rm -v "$PWD/partage:/data" debian:13 sh -c "mkdir /data/build && touch /data/build/sortie" && ls -ln partage; rm -rf partage/build; sudo rm -rf partage'

# Dockerfile : fil rouge hello
printf 'server {\n  listen 80;\n  default_type text/plain;\n  location / {\n    return 200 "Bonjour depuis $hostname\\n";\n  }\n}\n' > hello.conf
printf 'FROM nginx:1.29-alpine\nCOPY hello.conf /etc/nginx/conf.d/default.conf\nEXPOSE 80\nHEALTHCHECK --interval=5s \\\n  CMD wget -qO- http://localhost/ || exit 1\n' > Dockerfile
run 'DOCKER_BUILDKIT=0 docker image build -t hello-legacy .'
run 'docker image build -t hello . && docker image history --format "table {{.CreatedBy}}\t{{.Size}}" hello | head -5'
run 'sed -i s/Bonjour/Salut/ hello.conf && docker image build -q -t hello . && docker image ls -a && docker system df'
run 'docker image prune -f; docker builder prune -f'

# Variables dans un Dockerfile
mkdir -p var && printf 'FROM debian:13\nENV APP_DIR=/app\nWORKDIR ${APP_DIR}\nLABEL p="${PATH}" h="[${HOME}]"\n' > var/Dockerfile
run 'docker image build -q -t variables var && docker image inspect -f "{{json .Config.Labels}}" variables'

# Forme shell : ENTRYPOINT enregistré
mkdir -p fs && printf 'FROM debian:13\nENTRYPOINT echo HOME=$HOME bonjour\n' > fs/Dockerfile
run 'docker image build -q -t forme-shell fs && docker image inspect -f "{{json .Config.Entrypoint}}" forme-shell'

# CMD × ENTRYPOINT : les neuf combinaisons (forme shell, forme exec, absent), puis arguments de run et --entrypoint
i=0
for E in none shell exec; do for C in none exec shell; do
  i=$((i+1)); mkdir -p ce$i
  { echo 'FROM debian:13'
    case $E in shell) echo 'ENTRYPOINT echo e1 e2';; exec) echo 'ENTRYPOINT ["echo", "e1", "e2"]';; esac
    case $C in exec) echo 'CMD ["c1", "c2"]';; shell) echo 'CMD c1 c2';; none) [ $E = none ] && echo 'CMD []';; esac
  } > ce$i/Dockerfile
  run "echo ENTRYPOINT=$E CMD=$C; docker image build -q -t ce$i ce$i >/dev/null; docker image inspect -f '{{json .Config.Entrypoint}} {{json .Config.Cmd}}' ce$i; docker container run --rm ce$i; docker container run --rm ce$i x y"
done; done
run 'docker container run --rm --entrypoint echo ce8 | od -c | head -1'

# Audit : le projet fautif, puis le projet corrigé (build du Dockerfile corrigé : apt-get, accès à deb.debian.org)
mkdir -p audit-f/site audit-c/site
echo '<h1>Bonjour</h1>' > audit-f/site/index.html; cp audit-f/site/index.html audit-c/site/
printf 'FROM debian:latest\nARG API_TOKEN=s3cr3t\nRUN apt-get update\nRUN apt-get install -y python3\nADD . /srv\nWORKDIR /srv/site\nCMD python3 -m http.server 8000\n' > audit-f/Dockerfile
printf 'services:\n  web:\n    build: .\n    privileged: true\n    ports:\n      - "8000:8000"\n    volumes:\n      - /var/run/docker.sock:/var/run/docker.sock\n  db:\n    image: mariadb:11.8\n    environment:\n      MARIADB_RANDOM_ROOT_PASSWORD: "1"\n    ports:\n      - "3306:3306"\n' > audit-f/compose.yaml
printf 'FROM debian:13\nRUN apt-get update && \\\n  apt-get install -y --no-install-recommends \\\n  python3 && rm -rf /var/lib/apt/lists/*\nCOPY site/ /srv/site/\nUSER nobody\nWORKDIR /srv/site\nCMD ["python3", "-m", "http.server", "8000"]\n' > audit-c/Dockerfile
printf '.git\ncompose.yaml\n' > audit-c/.dockerignore
printf 'services:\n  web:\n    build: .\n    init: true\n    ports:\n      - "8000:8000"\n    logging:\n      options:\n        max-size: "10m"\n        max-file: "3"\n  db:\n    image: mariadb:11.8\n    environment:\n      MARIADB_RANDOM_ROOT_PASSWORD: "1"\n    volumes:\n      - donnees:/var/lib/mysql\nvolumes:\n  donnees:\n' > audit-c/compose.yaml
run 'cd audit-f && docker compose -p audit-f up -d --build 2>&1 | grep -iE "warn|SecretsUsed|JSONArgs"; sleep 5; curl -s localhost:8000/; docker compose -p audit-f top web; docker compose -p audit-f exec web ls /srv; docker image history --no-trunc --format "{{.CreatedBy}}" audit-f-web | grep TOKEN; docker compose -p audit-f ps --format "table {{.Name}}\t{{.Ports}}"; docker container inspect -f "{{json .Mounts}}" audit-f-db-1; time docker compose -p audit-f stop web; docker compose -p audit-f down -v'
run 'cd audit-c && docker compose -p audit-c up -d --build; sleep 5; curl -s localhost:8000/; docker compose -p audit-c top web; docker compose -p audit-c exec web ls /srv; docker compose -p audit-c ps --format "table {{.Name}}\t{{.Ports}}"; docker container inspect -f "{{json .HostConfig.LogConfig}}" audit-c-web-1; time docker compose -p audit-c stop web; docker compose -p audit-c down -v'

# Dockerfile ping
mkdir -p ping && printf 'FROM debian:13\nRUN apt-get update && apt-get install -y inetutils-ping && rm -rf /var/lib/apt/lists/*\nCMD ["ping", "-c", "2", "localhost"]\n' > ping/Dockerfile
run 'docker image build -q -t mon_image ping && docker container run --rm mon_image'

# Sécurité : no-new-privileges sur un binaire setuid
run 'docker container run --rm --security-opt no-new-privileges debian:13 sh -c "cp /bin/id /tmp/id && chmod u+s /tmp/id && ls -l /tmp/id && /tmp/id -u"'

# Orchestration : Swarm sur un seul nœud (sorties du cours relevées sur Docker Engine 29.10.0).
# Prérequis : Swarm inactif (docker info --format "{{.Swarm.LocalNodeState}}" répond « inactive »), port 8080 libre.
# Sur une machine à plusieurs adresses IP, docker swarm init demande --advertise-addr <adresse>.
sed -i s/Salut/Bonjour/ hello.conf
printf 'services:\n  hello:\n    image: hello:1.0\n    ports:\n      - "8080:80"\n    deploy:\n      replicas: 3\n' > compose.yaml
run 'docker image build -q -t hello:1.0 .'
# le jeton d'adhésion est un secret : il est masqué dans la sortie
run 'docker swarm init | sed "s/SWMTKN-[A-Za-z0-9-]*/SWMTKN-(masqué)/"'
run 'docker stack deploy -c compose.yaml boutique'
run 'sleep 15; docker service ls; docker network ls --filter driver=overlay'
# répartition de charge par le routing mesh (demande IPVS dans le noyau) : plusieurs conteneurs doivent répondre
run 'for i in 1 2 3 4; do curl -s --max-time 5 localhost:8080; done'
run 'docker service scale boutique_hello=5'
run 'docker container kill $(docker container ls -q --filter name=boutique_hello.2)'
run 'sleep 20; docker service ls; docker service ps boutique_hello'
run 'docker service inspect --format "{{json .Spec.UpdateConfig}}" boutique_hello'
# build: est-il ignoré par docker stack deploy ? (message attendu : « Ignoring unsupported options: build »)
printf 'services:\n  hello:\n    build: .\n    image: hello:1.0\n' > compose-build.yaml
run 'docker stack deploy -c compose-build.yaml essai; docker stack rm essai'
run 'docker stack rm boutique; sleep 8; docker swarm leave --force; docker network rm docker_gwbridge'

echo; echo '# Nettoyage'
docker image rm -f hello hello:1.0 hello-legacy variables forme-shell mon_image ce1 ce2 ce3 ce4 ce5 ce6 ce7 ce8 ce9 audit-f-web audit-c-web >/dev/null 2>&1
rm -rf "$D"
