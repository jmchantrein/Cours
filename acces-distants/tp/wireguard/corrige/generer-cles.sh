#!/bin/sh
# À lancer en root sur chaque pair : une paire de clés dans /etc/wireguard, lisible par root seul.
set -eu
mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077
wg genkey | tee prive.key | wg pubkey > public.key
ls -l /etc/wireguard
cat public.key
