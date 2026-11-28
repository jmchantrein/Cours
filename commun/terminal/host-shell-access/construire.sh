#!/usr/bin/env bash
# construire.sh — compile host-shell-access (host-shell-access) en exécutables statiques, dans dist/ (ignoré par git,
# publié par la CI avec le site) : linux/amd64 et linux/arm64 (host-shell-access ne sert que sous Linux), plus SHA256SUMS
# et les licences des modules Go qu'ils embarquent. Demande Go (version de go.mod) ; modules fixés par go.sum.
#
# Usage : commun/terminal/host-shell-access/construire.sh
set -euo pipefail

ICI=$(cd "$(dirname "$0")" && pwd)
cd "$ICI"
rm -rf dist
mkdir -p dist
go vet ./...
for cible in linux/amd64 linux/arm64; do
  CGO_ENABLED=0 GOOS=${cible%/*} GOARCH=${cible#*/} \
    go build -trimpath -buildvcs=false -ldflags "-s -w" -o "dist/host-shell-access-${cible%/*}-${cible#*/}" .
done
# Les licences de Go (BSD-3-Clause) et des modules (MIT, ISC) demandent leur mention avec les exécutables.
{
  printf '==== Go %s (bibliothèque standard et exécution, compilées dans chaque exécutable) ====\n\n' "$(go env GOVERSION)"
  cat "$(go env GOROOT)/LICENSE"
  printf '\n'
for module in $(go list -m -f '{{if not .Main}}{{.Path}}@{{.Version}}{{end}}' all); do
  dossier=$(go mod download -json "$module" | sed -n 's/^[[:space:]]*"Dir": "\(.*\)",$/\1/p')
  printf '==== %s ====\n\n' "$module"
  cat "$dossier"/LICENSE*
  printf '\n'
done
} > dist/LICENCES-modules.txt
(cd dist && sha256sum host-shell-access-* > SHA256SUMS)
ls -l dist
