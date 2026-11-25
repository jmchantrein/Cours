# shellcheck shell=bash
# Accommodement facultatif pour construire le labo derrière un proxy HTTPS qui réécrit TLS
# (convention du dépôt, voir README.md) : « . proxy.sh <projet> <dossier temporaire> ».
# Sans TPTEST_CA, ne fait rien : le labo se construit comme en CI. Avec TPTEST_CA=/chemin/ca.crt
# (et HTTPS_PROXY), construit une base debian:13-slim qui passe par le proxy, la substitue à
# debian:13-slim (contexte nommé), construit sur le réseau de l’hôte et transmet HTTPS_PROXY aux
# constructions ; les Dockerfile ne changent pas. Ajoute le fichier à COMPOSE_FILE.
# Supprimer l’image : docker image rm "<projet>-base".
labo_proxy() { # $1 projet Compose, $2 dossier temporaire
  [ -n "${TPTEST_CA:-}" ] || return 0
  : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
  local base="$2/base"
  mkdir -p "$base"
  cp "$TPTEST_CA" "$base/ca.crt"
  cat > "$base/Dockerfile" <<DOCKERFILE
FROM debian:13-slim
COPY ca.crt /usr/local/share/ca-certificates/proxy.crt
RUN sed -i 's,http://,https://,g' /etc/apt/sources.list.d/debian.sources \\
 && printf 'Acquire::https::Proxy "%s";\nAcquire::https::CAInfo "/usr/local/share/ca-certificates/proxy.crt";\n' "$HTTPS_PROXY" > /etc/apt/apt.conf.d/99proxy
DOCKERFILE
  docker build -q -t "$1-base" "$base" > /dev/null
  cat > "$2/proxy.yaml" <<YAML
x-proxy: &proxy
  build:
    network: host
    args:
      HTTPS_PROXY: "$HTTPS_PROXY"
    additional_contexts:
      "debian:13-slim": "docker-image://$1-base"
services:
  control-node: *proxy
  managed-node-1: *proxy
  managed-node-2: *proxy
YAML
  COMPOSE_FILE="${COMPOSE_FILE:-compose.yaml}:$2/proxy.yaml"
  export COMPOSE_FILE
}
