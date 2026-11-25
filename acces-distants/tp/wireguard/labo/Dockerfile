# Une machine du laboratoire WireGuard : Debian 13, les outils de WireGuard et de quoi observer le réseau.
# Le tunnel lui-même est le module WireGuard du noyau de l'hôte ; s'il manque, wg-quick se rabat sur
# wireguard-go, la même chose en espace utilisateur (plus lent, mêmes commandes).
FROM debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      wireguard-tools wireguard-go iproute2 iputils-ping tcpdump procps nano \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /etc/wireguard
CMD ["sleep", "infinity"]
