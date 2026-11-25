#!/usr/bin/env python3
"""Rejoue une commande sous un pseudo-terminal et affiche ce qu'un terminal montrerait.

Usage : attendre.py 'commande' [texte-attendu envoi]...
Chaque paire attend que la sortie contienne texte-attendu, puis envoie « envoi »
(\\n = Entrée). Sert à rejouer ssh-keygen, ssh-copy-id, la première connexion ssh.
"""
import os
import select
import sys
import time

commande = sys.argv[1]
paires = list(zip(sys.argv[2::2], sys.argv[3::2]))
pid, fd = os.forkpty()
if pid == 0:
    os.execvp("bash", ["bash", "-c", commande])

tampon, sortie = b"", b""


def lire(delai):
    """Lit ce qui est disponible pendant `delai` secondes ; False si la commande est finie."""
    global tampon, sortie
    r, _, _ = select.select([fd], [], [], delai)
    if not r:
        return True
    try:
        d = os.read(fd, 4096)
    except OSError:
        return False
    if not d:
        return False
    tampon += d
    sortie += d
    return True


for attendu, envoi in paires:
    fin = time.time() + 30
    while attendu.encode() not in tampon and time.time() < fin:
        if not lire(0.2):
            break
    tampon = b""
    time.sleep(0.3)
    os.write(fd, envoi.encode().decode("unicode_escape").encode())

fin = time.time() + 60
while time.time() < fin and lire(0.5):
    try:
        if os.waitpid(pid, os.WNOHANG)[0]:
            while lire(0.2) and select.select([fd], [], [], 0)[0]:
                pass
            break
    except ChildProcessError:
        break

sys.stdout.write(sortie.decode(errors="replace").replace("\r\n", "\n").replace("\r", ""))
