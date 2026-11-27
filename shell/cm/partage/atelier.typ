// partage/atelier.typ — l’arborescence du fil rouge, partagée par les diaporamas de cm/ : celle que crée
// shell/tp/premiers-pas/preparer.sh sous ~/atelier (compte ada), qui est aussi celle de la VM du terminal ;
// la racine est celle d’un conteneur debian:13-slim (ls /, rejoué par rejouer-arbo.sh). Format : voir arbre(…)
// dans commun/theme-cours.typ.

#let atelier-tp = ("atelier", (
  ".reglages",
  ("journaux", ("serveur-2025-novembre.log", "serveur-2026-novembre.log")),
  ("notes", ("a-faire.txt", "idees.txt", "lisezmoi.txt")),
  "pionnieres.csv",
  ("projets", (("scripts", ("bonjour.sh",)), ("site", ("index.html",)))),
  ("vieux", ("brouillon-1.txt", "brouillon-2.txt")),
))
// la racine et ses 19 répertoires ; /home ne contient que ada ; ~ contient les fichiers cachés de /etc/skel
#let racine-tp = ("/", (
  ("bin", ()), ("boot", ()), ("dev", ()), ("etc", ()),
  ("home", (("ada", (".bash_logout", ".bashrc", ".profile", atelier-tp)),)),
  ("lib", ()), ("lib64", ()), ("media", ()), ("mnt", ()), ("opt", ()), ("proc", ()), ("root", ()), ("run", ()),
  ("sbin", ()), ("srv", ()), ("sys", ()), ("tmp", ()), ("usr", ()), ("var", ()),
))
