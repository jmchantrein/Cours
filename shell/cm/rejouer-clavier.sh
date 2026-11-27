#!/usr/bin/env bash
# Rejoue les gestes du diaporama « Le clavier du shell » (clavier.typ), touche par touche, dans un vrai terminal
# (pseudo-terminal de 100 × 30, TERM=xterm-256color, comme la VM du terminal des pages web), et relève après chaque
# geste l’écran : la ligne en cours et la colonne du curseur, ou l’écran entier pour les gestes marqués « * ».
# Usage : ./rejouer-clavier.sh > sorties-clavier.txt 2>&1
# Le script se relance tout seul dans un conteneur alpine:3.22.8 (l’image de base de commun/terminal/construire-vm.sh ;
# Docker requis, réseau pour apk) : Bash, bash-completion et coreutils comme dans la VM, le compte ada avec l’invite
# de la VM (commun/terminal/vm/profil.sh), ~/atelier préparé par shell/tp/premiers-pas/preparer.sh (l’état de départ
# de la page de cours). Python n’y sert qu’à piloter le pseudo-terminal et à lire l’écran (un petit émulateur).
# Derrière un proxy HTTPS qui réécrit TLS, TPTEST_CA (voir le README.md du dépôt) :
#   TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./rejouer-clavier.sh > sorties-clavier.txt 2>&1
# REJOUER_NOM (facultatif) : préfixe du nom du conteneur (défaut : rejeu-clavier).
set -u

if [ -z "${REJOUER_CONTENEUR:-}" ]; then
  depot=$(cd "$(dirname "$0")/../.." && pwd)
  command -v docker > /dev/null || { echo "Docker est nécessaire." >&2; exit 1; }
  reseau=(); apk_ca=""
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY" --volume "$TPTEST_CA:/run/ca-hote.crt:ro"); apk_ca="1"
  fi
  exec docker container run --rm --hostname cours --name "${REJOUER_NOM:-rejeu-clavier}-$$" "${reseau[@]}" \
    --env "APK_CA=$apk_ca" --volume "$depot/shell:/opt/shell:ro" \
    --volume "$depot/commun/terminal/vm/profil.sh:/opt/profil.sh:ro" alpine:3.22.8 sh -euc '
      if [ -n "$APK_CA" ]; then cat /run/ca-hote.crt >> /etc/ssl/certs/ca-certificates.crt; fi
      apk add --no-cache -q bash bash-completion coreutils python3 > /dev/null
      install -m 0644 /opt/profil.sh /etc/profile.d/cours.sh
      adduser -D -s /bin/bash ada
      su - ada -c "bash /opt/shell/tp/premiers-pas/preparer.sh" > /dev/null
      echo "# $(date -u -I) · $(uname -srm) · Alpine $(cat /etc/alpine-release) · $(bash --version | head -1)"
      REJOUER_CONTENEUR=1 exec bash /opt/shell/cm/rejouer-clavier.sh'
fi

# Les gestes, dans l’ordre des diapos (et de la page de cours) : un nom, puis les touches. {Tab}, {Entrée}, {Haut},
# {Bas}, {Retour} (retour arrière), {Ctrl+X}, {Ctrl+Gauche}, {Ctrl+Droite}, {Alt+Retour} ; le reste se tape tel quel.
# Un nom qui commence par « * » demande l’écran entier.
gestes=$(cat <<'FIN'
Compléter · whoa	whoa
Compléter · Tab	{Tab}
Compléter · Entrée	{Entrée}
Compléter · who	who
Compléter · who Tab	{Tab}
*Compléter · who Tab Tab	{Tab}
Compléter · effacer who	{Retour}{Retour}{Retour}
*Compléter · ls	ls{Entrée}
Compléter · ls at	ls at
Compléter · ls at Tab	{Tab}
*Compléter · Entrée	{Entrée}
Compléter · date --ut	date --ut
Compléter · date --ut Tab	{Tab}
*Compléter · Entrée	{Entrée}
Retrouver · Haut	{Haut}
Retrouver · Haut	{Haut}
Retrouver · Bas	{Bas}
Retrouver · Bas	{Bas}
Retrouver · Ctrl+R	{Ctrl+R}
Retrouver · Ctrl+R wh	wh
*Retrouver · Entrée	{Entrée}
*Retrouver · history	history{Entrée}
Se déplacer · la ligne	echo Katherine Johnson calcule la trajectoire
Se déplacer · Ctrl+A	{Ctrl+A}
Se déplacer · Ctrl+E	{Ctrl+E}
Se déplacer · Ctrl+Gauche	{Ctrl+Gauche}
Se déplacer · Ctrl+Gauche	{Ctrl+Gauche}
Se déplacer · Ctrl+Droite	{Ctrl+Droite}
Effacer · Ctrl+E	{Ctrl+E}
Effacer · Ctrl+W	{Ctrl+W}
Effacer · Ctrl+Y	{Ctrl+Y}
Effacer · Ctrl+Gauche, Ctrl+Gauche	{Ctrl+Gauche}{Ctrl+Gauche}
Effacer · Ctrl+K	{Ctrl+K}
Effacer · Ctrl+Y	{Ctrl+Y}
Effacer · Ctrl+Gauche, Ctrl+Gauche	{Ctrl+Gauche}{Ctrl+Gauche}
*Effacer · Ctrl+U	{Ctrl+U}
*Écran · Ctrl+L	{Ctrl+L}
Écran · Ctrl+E	{Ctrl+E}
*Écran · Ctrl+C	{Ctrl+C}
Écran · cat	cat{Entrée}
Écran · Ada	Ada{Entrée}
*Écran · Ctrl+D	{Ctrl+D}
Exercice · la ligne	echo Hedy Lamarr brevette un signal radio secret
Exercice · Ctrl+W	{Ctrl+W}
Exercice · Ctrl+A	{Ctrl+A}
Exercice · Ctrl+Droite	{Ctrl+Droite}
Exercice · Ctrl+K	{Ctrl+K}
Exercice · Ctrl+Y	{Ctrl+Y}
*Exercice · Entrée	{Entrée}
Hors diapos · Alt+Retour (à la place de Ctrl+W dans la page)	echo un deux trois{Alt+Retour}
Hors diapos · Ctrl+C	{Ctrl+C}
FIN
)
export GESTES="$gestes"

exec python3 - <<'PY'
import os, pty, re, select, time, fcntl, termios, struct
TOUCHES = {"Tab": "\t", "Entrée": "\r", "Haut": "\x1bOA", "Bas": "\x1bOB", "Retour": "\x7f",
           "Ctrl+Gauche": "\x1b[1;5D", "Ctrl+Droite": "\x1b[1;5C", "Alt+Retour": "\x1b\x7f"}
def octets(s):
    def un(m):
        t = m.group(1)
        if t in TOUCHES: return TOUCHES[t]
        if t.startswith("Ctrl+") and len(t) == 6: return chr(ord(t[5].upper()) - 64)
        raise SystemExit("touche inconnue : " + t)
    return re.sub(r"\{([^}]+)\}", un, s)
W, H = 100, 30
pid, fd = pty.fork()
if pid == 0:
    os.environ.update(TERM="xterm-256color", LANG="C.UTF-8")
    os.execvp("su", ["su", "-", "ada", "-s", "/bin/bash", "-c", "cd ~; exec bash -l"])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", H, W, 0, 0))
def lire(t):
    out, fin = b"", time.time() + t
    while time.time() < fin:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: out += os.read(fd, 65536)
            except OSError: break
    return out
# Écran : le sous-ensemble de séquences qu’emploient bash et readline avec TERM=xterm-256color.
scr = [[" "] * W for _ in range(H)]; cx = cy = 0
def nl():
    global cy
    if cy == H - 1: scr.pop(0); scr.append([" "] * W)
    else: cy += 1
def ecrire(d):
    global cx, cy
    i = 0
    while i < len(d):
        ch = d[i]
        if ch == "\x1b":
            m = re.match(r"\x1b\[([?>]?)([0-9;]*)([A-Za-z@])", d[i:])
            if m:
                p, a, f = m.groups(); n = int(a.split(";")[0] or 1) if a else 1
                if p or f == "m": pass
                elif f == "K": scr[cy][cx:] = [" "] * (W - cx)
                elif f == "C": cx = min(W - 1, cx + n)
                elif f == "D": cx = max(0, cx - n)
                elif f == "A": cy = max(0, cy - n)
                elif f == "B": cy = min(H - 1, cy + n)
                elif f == "P": del scr[cy][cx:cx + n]; scr[cy] += [" "] * n
                elif f == "@": scr[cy][cx:cx] = [" "] * n; del scr[cy][W:]
                elif f == "H":
                    v = [int(x) for x in a.split(";") if x]
                    cy, cx = (v[0] - 1 if v else 0), (v[1] - 1 if len(v) > 1 else 0)
                elif f == "J" and a in ("2", "3"):
                    if a == "2": scr[:] = [[" "] * W for _ in range(H)]
                elif f == "J":
                    scr[cy][cx:] = [" "] * (W - cx)
                    for r in range(cy + 1, H): scr[r] = [" "] * W
                i += m.end(); continue
            m = re.match(r"\x1b\][^\x07]*\x07|\x1b[=>]", d[i:])
            i += m.end() if m else 2; continue
        if ch == "\r": cx = 0
        elif ch == "\n": nl()
        elif ch == "\b": cx = max(0, cx - 1)
        elif ord(ch) >= 32:
            if cx >= W: cx = 0; nl()
            scr[cy][cx] = ch; cx += 1
        i += 1
ecrire(lire(3).decode("utf-8", "replace"))
os.write(fd, b"\x0c"); ecrire(lire(1.5).decode("utf-8", "replace"))   # Ctrl+L : écran vide, historique vide
for ligne in os.environ["GESTES"].splitlines():
    nom, touches = ligne.split("\t", 1)
    for ch in octets(touches): os.write(fd, ch.encode()); time.sleep(0.03)
    ecrire(lire(1.5).decode("utf-8", "replace"))
    courante = "".join(scr[cy]).rstrip()
    print(f"\n## {nom.lstrip('*')}   [{touches}]")
    if nom.startswith("*"):
        print("\n".join("   | " + "".join(r).rstrip() for r in scr if "".join(r).strip()))
    sous = f", sur « {courante[cx]} »" if cx < len(courante) else ", au bout"
    print(f"   ligne : {courante}\n   curseur : colonne {cx}{sous}")
PY
