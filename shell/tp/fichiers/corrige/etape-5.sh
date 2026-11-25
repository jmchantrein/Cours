#!/usr/bin/env bash
# Étape 5 : le umask. Il vaut pour le shell qui le règle, et pour les
# commandes que ce shell lance : ici, le temps de ce script.

cd ~/fichiers
umask
umask -S
touch public.txt
mkdir public
ls -ld public.txt public
umask 077
touch prive.txt
mkdir prive
ls -ld prive.txt prive
