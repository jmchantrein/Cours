#!/usr/bin/env python3
"""Vérifie l'exécutable de host-shell-access de bout en bout, sans navigateur, après construire.sh :
    python3 -I commun/terminal/host-shell-access/tester.py [exécutable]   (par défaut : dist/host-shell-access-linux-<arch>)

Porté de site/scripts/test-terminal-companion.py. Contrôle le protocole (poignée de main WebSocket,
redimensionnement, entrée, sortie du PTY) et les protections : écoute sur 127.0.0.1 seulement, jeton,
origine, un seul client, host-shell-access arrêté après un refus (jeton à usage unique).
"""

import base64
import json
import os
import re
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path

ARCH = {"x86_64": "amd64", "aarch64": "arm64"}.get(os.uname().machine, os.uname().machine)
EXECUTABLE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / f"dist/host-shell-access-linux-{ARCH}"
ORIGINE = "https://jmchantrein.github.io"
reussis = []


def lancer():
    """Démarre host-shell-access en mode local ; rend le processus, le port et le jeton."""
    processus = subprocess.Popen([str(EXECUTABLE), "local", "--shell", "/bin/sh"],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert processus.stdout.readline().strip() == "Adresse à coller dans la page :"
    adresse = processus.stdout.readline().strip()
    trouve = re.fullmatch(r"ws://localhost:(\d+)/\?token=(.+)", adresse)
    assert trouve, adresse
    return processus, int(trouve.group(1)), trouve.group(2)


def poignee(port, jeton, origine=ORIGINE):
    """Ouvre une connexion et envoie la requête d'ouverture WebSocket ; rend la socket et la réponse."""
    client = socket.create_connection(("127.0.0.1", port), timeout=5)
    cle = base64.b64encode(os.urandom(16)).decode()
    client.sendall((
        f"GET /?token={jeton} HTTP/1.1\r\nHost: localhost:{port}\r\nOrigin: {origine}\r\n"
        f"Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {cle}\r\nSec-WebSocket-Version: 13\r\n\r\n"
    ).encode())
    return client, client.recv(4096)


def trame(message):
    """Trame texte masquée, comme celles d'un navigateur."""
    donnees = json.dumps(message).encode()
    masque = os.urandom(4)
    assert len(donnees) < 126
    return bytes((0x81, 0x80 | len(donnees))) + masque + bytes(o ^ masque[i % 4] for i, o in enumerate(donnees))


def recevoir(client):
    entete = client.recv(2)
    taille = entete[1] & 0x7F
    if taille == 126:
        taille = struct.unpack("!H", client.recv(2))[0]
    elif taille == 127:
        taille = struct.unpack("!Q", client.recv(8))[0]
    charge = b""
    while len(charge) < taille:
        charge += client.recv(taille - len(charge))
    return json.loads(charge)


def ip_hors_bouclage():
    """Une adresse de cette machine hors bouclage, s'il y en a une (aucun paquet n'est envoyé)."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            s.connect(("192.0.2.1", 9))
            return s.getsockname()[0]
        except OSError:
            return None


# 1. Session complète : poignée de main, redimensionnement, commande, sortie.
processus, port, jeton = lancer()
client, reponse = poignee(port, jeton)
assert reponse.startswith(b"HTTP/1.1 101 Switching Protocols"), reponse
client.sendall(trame({"type": "resize", "cols": 90, "rows": 24}))
client.sendall(trame({"type": "input", "data": "stty size; printf 'HSA_%s\\n' OK\r"}))
sortie, limite = "", time.monotonic() + 5
while "HSA_OK" not in sortie and time.monotonic() < limite:
    sortie += recevoir(client).get("data", "")
assert "HSA_OK" in sortie and "24 90" in sortie, sortie
reussis.append("session : commande exécutée, sortie reçue, terminal 90 × 24")

# 2. Un seul client : pendant la session, une deuxième connexion n'obtient pas de réponse.
second = socket.create_connection(("127.0.0.1", port), timeout=1)
second.sendall(f"GET /?token={jeton} HTTP/1.1\r\nOrigin: {ORIGINE}\r\n\r\n".encode())
try:
    assert second.recv(4096) == b"", "un deuxième client a reçu une réponse"
except socket.timeout:
    pass
second.close()
reussis.append("un seul client : la deuxième connexion reste sans réponse")

# 3. Écoute sur le bouclage seulement.
ip = ip_hors_bouclage()
if ip and not ip.startswith("127."):
    try:
        socket.create_connection((ip, port), timeout=2).close()
        raise AssertionError(f"host-shell-access répond sur {ip}")
    except (ConnectionRefusedError, socket.timeout):
        reussis.append(f"écoute sur 127.0.0.1 seulement : {ip}:{port} refusé")
client.close()
processus.wait(timeout=5)
reussis.append("fin de session : host-shell-access s'arrête avec la page")

# 4. Mauvais jeton, puis mauvaise origine : refus, et host-shell-access s'arrête (pas de deuxième essai).
for cas, jeton_essai, origine, statut in (
    ("mauvais jeton", "faux", ORIGINE, b"401"),
    ("mauvaise origine", None, "https://exemple.org", b"403"),
):
    processus, port, jeton = lancer()
    client, reponse = poignee(port, jeton_essai or jeton, origine)
    assert reponse.startswith(b"HTTP/1.1 " + statut), (cas, reponse)
    client.close()
    processus.wait(timeout=5)
    try:
        socket.create_connection(("127.0.0.1", port), timeout=2).close()
        raise AssertionError(f"{cas} : host-shell-access écoute encore")
    except ConnectionRefusedError:
        pass
    reussis.append(f"{cas} : {statut.decode()}, puis host-shell-access arrêté")

print("host-shell-access :", len(reussis), "vérifications réussies")
for r in reussis:
    print(" -", r)
