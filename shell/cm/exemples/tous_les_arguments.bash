#!/bin/bash
# "$@" : un mot par argument reçu, espaces compris
for argument in "$@"; do
    echo "[$argument]"
done
echo "---"
# $* sans guillemets : les arguments sont redécoupés
# shellcheck disable=SC2048,SC2086  # voulu : montre le découpage
for argument in $*; do
    echo "[$argument]"
done
