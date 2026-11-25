#!/usr/bin/env bash
# Rejoue les démonstrations du cours « Accès distants » (SSH, tmux, WireGuard) et relève les versions.
# Les machines du cours (poste, bastion, serveur ; pair-a, pair-b, pair-c) sont ici des conteneurs jetables :
# un labo, pas une architecture à reproduire (le cours Conteneurisation enseigne « pas de sshd dans un conteneur »).
#
# Prérequis : Docker, Python 3 (pour attendre.py), droits sur le démon Docker.
# Usage : ./rejouer.sh [image] > sorties-acces-distants.txt 2>&1
#   sans argument : construit l'image acces-debian depuis debian:13-slim (apt-get : accès réseau nécessaire) ;
#   avec un argument : utilise cette image, qui doit déjà contenir les paquets listés plus bas.
# WireGuard : le module du noyau de l'hôte (Linux ≥ 5.6) est utilisé s'il est là ; sinon wg-quick se rabat
# sur wireguard-go (implémentation en espace utilisateur, /dev/net/tun), ce que la sortie signale.
# Tout ce qui est créé porte le préfixe acces- (REJEU_PREFIXE le change) et est supprimé à la fin.
# Derrière un proxy HTTPS qui réécrit TLS : TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./rejouer.sh
# (convention du dépôt, voir README.md) ; sans TPTEST_CA, le script ignore le proxy, comme en CI.
set -u
P=${REJEU_PREFIXE:-acces}
ICI=$(cd "$(dirname "$0")" && pwd)
IMAGE=${1:-${P}-debian}
RESEAUX=("${P}-public" "${P}-prive" "${P}-wg")
MACHINES=("${P}-poste" "${P}-bastion" "${P}-serveur" "${P}-exo" "${P}-wg-a" "${P}-wg-b" "${P}-wg-c")

nettoyer() {
  docker container rm -f "${MACHINES[@]}" >/dev/null 2>&1
  docker network rm "${RESEAUX[@]}" >/dev/null 2>&1
}
trap nettoyer EXIT
nettoyer

titre() { printf '\n\n########## %s\n' "$1"; }
# Commande d'ada sur une machine, sous pseudo-terminal : la sortie est celle d'un terminal.
sur() {
  local m=$1; shift
  printf '\n[ada@%s]$ %s\n' "$m" "$*"
  python3 "$ICI/attendre.py" "docker exec -it -u ada -w /home/ada -e HOME=/home/ada -e TERM=xterm ${P}-$m bash -c $(printf %q "umask 022; $*")"
}
# Commande de root sur une machine.
root_sur() {
  local m=$1; shift
  printf '\n[root@%s]# %s\n' "$m" "$*"
  docker exec -i "${P}-$m" bash -c "umask 022; $*" 2>&1
}
# Saisie interactive : sur_saisie machine 'commande' texte-attendu envoi…
sur_saisie() {
  local m=$1 c=$2; shift 2
  printf '\n[ada@%s]$ %s\n' "$m" "$c"
  python3 "$ICI/attendre.py" "docker exec -it -u ada -w /home/ada -e HOME=/home/ada -e TERM=xterm ${P}-$m bash -c $(printf %q "umask 022; $c")" "$@"
}
# Préparation silencieuse (pas une démonstration).
prep() { local m=$1; shift; docker exec -i "${P}-$m" bash -c "umask 022; $*" >/dev/null 2>&1; }

echo "# $(date -I) · hôte $(uname -srm) · image $IMAGE"

# ---------- Image ----------
if [ $# -eq 0 ]; then
  CTX=$(mktemp -d)
  cat > "$CTX/Dockerfile" <<'EOF'
FROM debian:13-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server openssh-client tmux wireguard-tools iproute2 iputils-ping procps \
      python3 curl rsync sshpass tcpdump bsdutils && \
    (apt-get install -y --no-install-recommends wireguard-go || true) && \
    rm -rf /var/lib/apt/lists/* /etc/ssh/ssh_host_*
CMD ["sleep", "infinity"]
EOF
  OPTIONS=()
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    cp "$TPTEST_CA" "$CTX/ca.crt"
    {
      echo "FROM debian:13-slim"
      echo "COPY ca.crt /usr/local/share/ca.crt"
      echo "RUN sed -i 's,http://deb.debian.org,https://deb.debian.org,g' /etc/apt/sources.list.d/debian.sources \\"
      echo " && echo 'Acquire::https::Proxy \"$HTTPS_PROXY\";' > /etc/apt/apt.conf.d/90mandataire \\"
      echo " && echo 'Acquire::https::CAInfo \"/usr/local/share/ca.crt\";' >> /etc/apt/apt.conf.d/90mandataire"
      tail -n +2 "$CTX/Dockerfile"
    } > "$CTX/Dockerfile.ca"
    mv "$CTX/Dockerfile.ca" "$CTX/Dockerfile"
    OPTIONS=(--network host --build-arg "HTTPS_PROXY=$HTTPS_PROXY")
  fi
  docker image build -q "${OPTIONS[@]}" -t "$IMAGE" "$CTX" >/dev/null || { echo "construction de l'image impossible"; rm -rf "$CTX"; exit 1; }
  rm -rf "$CTX"
fi

# ---------- Machines ----------
# poste et bastion sur le réseau « public » ; bastion et serveur sur le réseau « privé » (sans sortie) :
# le poste ne voit pas le serveur.
docker network create "${P}"-public >/dev/null
docker network create --internal "${P}"-prive >/dev/null
for m in poste bastion serveur; do
  docker container run -d --init --name "${P}-$m" --hostname "$m" --network none "$IMAGE" >/dev/null
done
docker network disconnect none "${P}"-poste; docker network disconnect none "${P}"-bastion; docker network disconnect none "${P}"-serveur
docker network connect "${P}"-public "${P}"-poste
docker network connect "${P}"-public "${P}"-bastion
docker network connect "${P}"-prive "${P}"-bastion
docker network connect "${P}"-prive "${P}"-serveur
for m in poste bastion serveur; do
  prep "$m" 'useradd -m -s /bin/bash ada && echo ada:motdepasse | chpasswd && ssh-keygen -A && mkdir -p /run/sshd && chmod 755 /run/sshd'
done
for m in bastion serveur; do prep "$m" '/usr/sbin/sshd -E /var/log/sshd.log'; done

titre "Versions"
root_sur poste 'ssh -V 2>&1; tmux -V; wg --version; . /etc/os-release; echo "$PRETTY_NAME"'

# ======================================================================
titre "SSH · générer la paire de clés"
sur_saisie poste 'ssh-keygen -t ed25519' 'save the key' '\n' 'passphrase' '\n' 'again' '\n'
sur poste 'ls -l ~/.ssh'
sur poste 'cat ~/.ssh/id_ed25519.pub'

titre "SSH · déployer la clé publique (première connexion : empreinte du bastion)"
root_sur bastion 'ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub'
sur_saisie poste 'ssh-copy-id ada@bastion' 'fingerprint' 'yes\n' 'password:' 'motdepasse\n'
sur bastion 'ls -l ~/.ssh; cat ~/.ssh/authorized_keys'
sur poste 'ssh ada@bastion hostname'
sur poste 'head -c 60 ~/.ssh/known_hosts; echo'

titre "SSH · StrictModes : un authorized_keys modifiable par tous est ignoré"
prep bastion 'chmod o+w /home/ada/.ssh/authorized_keys'
sur bastion 'ls -l ~/.ssh/authorized_keys'
sur poste 'ssh -o BatchMode=yes ada@bastion hostname; echo "code de retour : $?"'
root_sur bastion 'grep refused /var/log/sshd.log'
prep bastion 'chmod 600 /home/ada/.ssh/authorized_keys'

titre "SSH · la clé d'hôte du bastion change (réinstallation… ou attaque)"
prep bastion 'rm /etc/ssh/ssh_host_* && ssh-keygen -A && pkill -HUP -f "sshd -E"'
sleep 1
sur poste 'ssh ada@bastion hostname; echo "code de retour : $?"'
sur poste 'ssh-keygen -R bastion'
sur_saisie poste 'ssh ada@bastion hostname' 'fingerprint' 'yes\n'

titre "SSH · le serveur n'est joignable que par le bastion"
sur poste 'ssh ada@serveur hostname; echo "code de retour : $?"'
sur_saisie poste 'ssh-copy-id -o ProxyJump=ada@bastion ada@serveur' 'fingerprint' 'yes\n' 'password:' 'motdepasse\n'
sur poste 'ssh -J ada@bastion ada@serveur hostname'
root_sur bastion 'hostname -I'
sur poste "ssh -J ada@bastion ada@serveur 'echo \$SSH_CONNECTION'"
sur bastion 'ls ~/.ssh'

titre "SSH · ~/.ssh/config"
prep poste 'cat > /home/ada/.ssh/config <<EOF
Host bastion
    User ada

Host serveur
    User ada
    ProxyJump bastion

Host serveur1
    HostName serveur1.mon.domaine.fr
    User login1
    Port 2222
EOF
chown ada:ada /home/ada/.ssh/config'
sur poste 'cat ~/.ssh/config'
sur poste 'ssh serveur hostname'
sur poste "ssh -G serveur1 | grep -E '^(hostname|user|port) '"
sur poste "ssh -G serveur | grep -E '^(hostname|user|port|proxyjump) '"

titre "SSH · agent, et risque du transfert d'agent (-A)"
sur poste 'eval "$(ssh-agent)"; ssh-add; ssh-add -l'
docker exec -d -u ada -w /home/ada -e HOME=/home/ada "${P}"-poste bash -c 'eval "$(ssh-agent)"; ssh-add; ssh -A bastion sleep 30'
sleep 3
root_sur bastion 'ls -d /tmp/ssh-*/agent.*'
root_sur bastion 'export SSH_AUTH_SOCK=$(ls /tmp/ssh-*/agent.*); whoami; ssh-add -l; ssh -o StrictHostKeyChecking=accept-new ada@serveur hostname'

titre "SSH · redirections de port"
docker exec -d -u ada -w /home/ada "${P}"-serveur bash -c 'mkdir -p supervision && echo "Supervision : tout va bien" > supervision/index.html && cd supervision && exec python3 -m http.server 8000 --bind 127.0.0.1'
docker exec -d "${P}"-serveur bash -c 'mkdir -p /srv/wiki && echo "Wiki interne du réseau privé" > /srv/wiki/index.html && cd /srv/wiki && exec python3 -m http.server 80'
docker exec -d -u ada -w /home/ada "${P}"-poste bash -c 'mkdir -p maquette && echo "Maquette du site, sur le poste" > maquette/index.html && cd maquette && exec python3 -m http.server 9000 --bind 127.0.0.1'
sleep 2
sur serveur 'ss -ltn | grep -E ":(80|8000) "'
# -L : un port local mène à un service du serveur
sur poste 'curl -sS localhost:8080; echo "code de retour : $?"'
# (une seule session : le transfert passe par le bastion, dont le ssh -W meurt avec le terminal)
sur poste 'ssh -f -N -L 8080:localhost:8000 serveur; curl -sS localhost:8080'
# -R : un port du serveur mène à un service du poste
sur poste 'ssh -f -N -R 9000:localhost:9000 serveur; ssh serveur curl -sS localhost:9000'
# -D : un proxy SOCKS local, sorti par le bastion
sur poste 'curl -sS --max-time 3 http://serveur/; echo "code de retour : $?"'
sur poste 'ssh -f -N -D 1080 bastion; curl -sS --socks5-hostname localhost:1080 http://serveur/'

titre "SSH · transférer des fichiers"
prep poste 'su ada -c "umask 022; mkdir -p /home/ada/site && cd /home/ada/site && echo accueil > index.html && echo contact > contact.html && echo rapport > /home/ada/rapport.txt"'
sur poste 'scp rapport.txt serveur:/tmp/'
sur poste 'rsync -av site/ serveur:site/'
prep poste 'su ada -c "echo accueil2 > /home/ada/site/index.html"'
sur poste 'rsync -av site/ serveur:site/'
sur serveur 'ls site /tmp/rapport.txt'

titre "SSH · durcir le serveur"
root_sur serveur "sshd -T | grep -E '^(passwordauthentication|pubkeyauthentication|permitrootlogin|port) '"
root_sur serveur 'head -n 13 /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"'
# le piège : un fichier de sshd_config.d (souvent posé par cloud-init) l'emporte sur sshd_config
prep serveur "echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/50-cloud-init.conf"
root_sur serveur 'cat /etc/ssh/sshd_config.d/50-cloud-init.conf'
root_sur serveur "echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config; sshd -T | grep -i '^passwordauthentication'"
root_sur serveur "echo 'PasswordAuthentication no' > /etc/ssh/sshd_config.d/10-durcissement.conf"
root_sur serveur 'ls /etc/ssh/sshd_config.d/; sshd -t && echo "syntaxe correcte"'
root_sur serveur "sshd -T | grep -i '^passwordauthentication'"
# en conteneur, pas de systemd : SIGHUP fait relire la configuration (sur un serveur : systemctl reload ssh)
prep serveur 'pkill -HUP -f "sshd -E"'
sleep 1
sur poste 'ssh -o PubkeyAuthentication=no serveur hostname; echo "code de retour : $?"'
sur poste 'ssh serveur hostname'

titre "SSH · corrigé de l'exercice (sur un poste quelconque : ssh -G ne se connecte pas)"
docker container run -d --init --name "${P}"-exo --hostname poste --network none "$IMAGE" >/dev/null
prep exo 'useradd -m -s /bin/bash ada && mkdir -p /home/ada/.ssh && cat > /home/ada/.ssh/config <<FIN
Host bastion
    HostName bastion.example.org
    User admin
    Port 2222

Host base
    HostName base.interne
    User admin
    ProxyJump bastion
FIN
chown -R ada:ada /home/ada/.ssh && chmod 700 /home/ada/.ssh'
sur exo 'cat ~/.ssh/config'
sur exo "ssh -G bastion | grep -E '^(hostname|user|port) '"
sur exo "ssh -G -p 2222 admin@bastion.example.org | grep -E '^(hostname|user|port) '"
sur exo "ssh -G base | grep -E '^(hostname|user|proxyjump) '"
sur exo "ssh -G -L 3000:localhost:3000 base | grep -E '^localforward '"
docker container rm -f "${P}"-exo >/dev/null

# ======================================================================
titre "tmux · sans tmux, la coupure tue le travail"
docker exec -d -u ada -w /home/ada -e HOME=/home/ada -e TERM=xterm "${P}"-poste script -qfc 'ssh -t serveur sleep 600' /dev/null
sleep 3
sur serveur 'pgrep -afx "sleep 600"'
sur poste 'pkill -KILL -f "^ssh -t serveur"'
sleep 2
sur serveur 'pgrep -afx "sleep 600"; echo "code de retour : $?"'

titre "tmux · avec tmux, la session survit"
docker exec -d -u ada -w /home/ada -e HOME=/home/ada -e TERM=xterm "${P}"-poste script -qfc 'ssh -t serveur tmux new -s maj sleep 600' /dev/null
sleep 3
sur poste 'pkill -KILL -f "^ssh -t serveur"'
sleep 2
sur poste 'ssh serveur tmux ls'
sur poste "ssh serveur 'pgrep -afx \"sleep 600\"'"
sur poste 'ssh serveur tmux kill-session -t maj'

titre "tmux · session, fenêtres, panneaux"
sur serveur 'tmux new -d -s admin -n edition'
sur serveur 'tmux split-window -h -t admin:edition'
sur serveur 'tmux new-window -t admin -n journaux'
sur serveur 'tmux new -d -s perso'
sleep 1 # laisse le shell démarrer : le nom de fenêtre automatique devient « bash »
sur serveur 'tmux ls'
sur serveur "tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{window_name}'"
sur serveur "tmux send-keys -t admin:journaux 'hostname; whoami' Enter"
sleep 1
sur serveur 'tmux capture-pane -p -t admin:journaux | grep -v "^$"'
sur serveur 'tmux kill-session -t perso; tmux ls'
sur serveur 'tmux kill-server'

titre "tmux · configuration"
prep serveur 'su ada -c "umask 022; cat > /home/ada/.tmux.conf" <<EOF
set -g mouse on
set -g history-limit 50000
setw -g mode-keys vi
set -g base-index 1
setw -g pane-base-index 1
bind | split-window -h
bind _ split-window -v
EOF'
sur serveur 'cat ~/.tmux.conf'
sur serveur 'tmux new -d -s essai; tmux show -g mouse; tmux show -g base-index; tmux show -gw mode-keys; tmux list-keys | grep -E "split-window( -[hv])?\$"'
sleep 1
sur serveur "tmux list-windows -F '#{window_index} #{window_name}'"
sur serveur 'tmux kill-server'

titre "tmux · corrigé de l'exercice"
prep serveur 'rm -f /home/ada/.tmux.conf'
sur serveur 'tmux new -d -s atelier -n edition'
sur serveur 'tmux split-window -h -t atelier:edition'
sur serveur 'tmux new-window -t atelier -n surveillance top'
sleep 1
sur serveur "tmux list-panes -s -t atelier -F '#{window_index}.#{pane_index} #{window_name} #{pane_current_command}'"
sur serveur "tmux send-keys -t atelier:edition.1 'echo bonjour depuis le panneau de droite' Enter"
sleep 1
sur serveur 'tmux capture-pane -pJ -t atelier:edition.1 | grep -v "^$"'
sur serveur 'tmux ls'
sur serveur 'tmux kill-server'

# ======================================================================
titre "WireGuard · trois pairs sur un réseau ordinaire"
docker network create "${P}"-wg >/dev/null
for p in a b c; do
  docker container run -d --init --name "${P}-wg-$p" --hostname "pair-$p" --network "${P}"-wg \
    --cap-add NET_ADMIN --device /dev/net/tun "$IMAGE" >/dev/null
done
for p in a b c; do
  if docker exec "${P}-wg-$p" sh -c 'ip link add wgtest type wireguard 2>/dev/null && ip link del wgtest'; then
    echo "pair-$p : module WireGuard du noyau"
  else
    echo "pair-$p : pas de module WireGuard dans le noyau de l'hôte, wg-quick utilise wireguard-go"
  fi
done
root_sur wg-a 'hostname -I'
root_sur wg-b 'hostname -I'

titre "WireGuard · clés"
for p in a b c; do
  root_sur "wg-$p" 'mkdir -p /etc/wireguard && cd /etc/wireguard && umask 077 && wg genkey | tee prive.key | wg pubkey > public.key && ls -l && cat public.key'
done
PUB_A=$(docker exec "${P}"-wg-a cat /etc/wireguard/public.key)
PUB_B=$(docker exec "${P}"-wg-b cat /etc/wireguard/public.key)
PUB_C=$(docker exec "${P}"-wg-c cat /etc/wireguard/public.key)
IP_B=$(docker exec "${P}"-wg-b hostname -I | awk '{print $1}')
IP_C=$(docker exec "${P}"-wg-c hostname -I | awk '{print $1}')

titre "WireGuard · wg0.conf et wg-quick"
docker exec -i "${P}"-wg-a sh -c "umask 077; cat > /etc/wireguard/wg0.conf" <<EOF
[Interface]
PrivateKey = $(docker exec "${P}"-wg-a cat /etc/wireguard/prive.key)
Address = 10.9.9.1/24
ListenPort = 51820

[Peer]
# pair-b
PublicKey = $PUB_B
AllowedIPs = 10.9.9.2/32
Endpoint = $IP_B:51820
EOF
docker exec -i "${P}"-wg-b sh -c "umask 077; cat > /etc/wireguard/wg0.conf" <<EOF
[Interface]
PrivateKey = $(docker exec "${P}"-wg-b cat /etc/wireguard/prive.key)
Address = 10.9.9.2/24
ListenPort = 51820

[Peer]
# pair-a
PublicKey = $PUB_A
AllowedIPs = 10.9.9.1/32
EOF
root_sur wg-a 'sed "s,^PrivateKey = .*,PrivateKey = (clé privée de pair-a)," /etc/wireguard/wg0.conf'
root_sur wg-a 'wg-quick up wg0'
root_sur wg-b 'wg-quick up wg0'
root_sur wg-a 'ip -brief address show wg0; ip route show dev wg0'

titre "WireGuard · ping dans le tunnel, et ce que voit le réseau"
docker exec -d "${P}"-wg-b sh -c 'tcpdump -lni eth0 -c 6 udp > /tmp/capture.txt 2>/dev/null'
sleep 2
root_sur wg-a 'ping -c 3 10.9.9.2'
sleep 1
root_sur wg-b 'cat /tmp/capture.txt'
root_sur wg-a 'wg show'
root_sur wg-b 'wg show wg0 endpoints'

titre "WireGuard · AllowedIPs : routage sortant"
root_sur wg-a "wg set wg0 peer $PUB_B allowed-ips 10.9.9.3/32"
root_sur wg-a 'ping -c 2 -W 1 10.9.9.2; echo "code de retour : $?"'
root_sur wg-a "wg set wg0 peer $PUB_B allowed-ips 10.9.9.2/32"

titre "WireGuard · AllowedIPs : filtrage entrant"
root_sur wg-b "wg set wg0 peer $PUB_A allowed-ips 10.9.9.100/32"
root_sur wg-b 'wg show wg0 transfer'
root_sur wg-a 'ping -c 2 -W 1 10.9.9.2; echo "code de retour : $?"'
root_sur wg-b 'wg show wg0 transfer'
root_sur wg-b "wg set wg0 peer $PUB_A allowed-ips 10.9.9.1/32"
root_sur wg-a 'ping -c 1 -W 1 10.9.9.2 | grep received'

titre "WireGuard · exercice : quel pair reçoit le paquet ?"
docker exec -i "${P}"-wg-c sh -c "umask 077; cat > /etc/wireguard/wg0.conf" <<EOF
[Interface]
PrivateKey = $(docker exec "${P}"-wg-c cat /etc/wireguard/prive.key)
Address = 10.9.9.3/24
ListenPort = 51820

[Peer]
PublicKey = $PUB_A
AllowedIPs = 10.9.9.1/32
EOF
root_sur wg-c 'wg-quick up wg0 >/dev/null 2>&1; echo pair-c prêt'
root_sur wg-a "wg set wg0 peer $PUB_C allowed-ips 10.9.9.3/32,192.168.50.0/24 endpoint $IP_C:51820"
root_sur wg-a 'ip route add 192.168.50.0/24 dev wg0'
root_sur wg-a 'wg show wg0 allowed-ips'
root_sur wg-a 'wg show wg0 transfer'
root_sur wg-a 'ping -c 1 -W 1 192.168.50.7 >/dev/null; wg show wg0 transfer'
root_sur wg-a 'ping -c 1 -W 1 10.9.9.4; echo "code de retour : $?"'
root_sur wg-a 'ip route get 10.9.9.4'
# question 3 : pair-b usurpe une adresse du réseau de pair-c
root_sur wg-b 'ip address add 192.168.50.7/32 dev wg0'
root_sur wg-a 'wg show wg0 transfer'
root_sur wg-b 'ping -c 1 -W 1 -I 192.168.50.7 10.9.9.1 | grep received'
root_sur wg-a 'wg show wg0 transfer'
# question 4 : préfixes qui se chevauchent
root_sur wg-a "wg set wg0 peer $PUB_B allowed-ips 10.9.9.0/24"
root_sur wg-a 'wg show wg0 allowed-ips'
root_sur wg-a 'ping -c 1 -W 1 10.9.9.3 | grep received; wg show wg0 transfer'
root_sur wg-a 'ping -c 1 -W 1 10.9.9.5 | grep received; wg show wg0 transfer'
# question 5 : pair-b n'a pas d'Endpoint pour pair-a, il l'a appris
root_sur wg-b 'grep -c Endpoint /etc/wireguard/wg0.conf; wg show wg0 endpoints'
root_sur wg-a 'wg showconf wg0 | grep -v -i key'

echo
echo "# fin"
