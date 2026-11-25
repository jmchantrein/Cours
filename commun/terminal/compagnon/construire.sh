#!/usr/bin/env bash
# construire.sh — compile le compagnon (iadmin-terminal) en exécutables statiques, dans dist/ (ignoré par git,
# publié par la CI avec le site) : linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, plus SHA256SUMS et
# les licences des modules Go qu'ils embarquent. Demande Go (version de go.mod) ; modules fixés par go.sum.
#
# Usage : commun/terminal/compagnon/construire.sh
set -euo pipefail

ICI=$(cd "$(dirname "$0")" && pwd)
cd "$ICI"
rm -rf dist
mkdir -p dist
go vet ./...
for cible in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64; do
  CGO_ENABLED=0 GOOS=${cible%/*} GOARCH=${cible#*/} \
    go build -trimpath -buildvcs=false -ldflags "-s -w" -o "dist/iadmin-terminal-${cible%/*}-${cible#*/}" .
done
# Les licences MIT et ISC des modules demandent leur mention avec les exécutables.
for module in $(go list -m -f '{{if not .Main}}{{.Path}}@{{.Version}}{{end}}' all); do
  dossier=$(go mod download -json "$module" | sed -n 's/^[[:space:]]*"Dir": "\(.*\)",$/\1/p')
  printf '==== %s ====\n\n' "$module"
  cat "$dossier"/LICENSE*
  printf '\n'
done > dist/LICENCES-modules.txt
(cd dist && sha256sum iadmin-terminal-* > SHA256SUMS)
ls -l dist
