#!/usr/bin/env bash
# preparer.sh — crée le dossier de travail du TP « Premiers pas dans le shell ».
#
# Usage : bash preparer.sh [dossier]      (par défaut : ~/atelier)
#
# Le dossier ne doit pas exister : le script refuse d'écraser quoi que ce soit.
# Pour repartir de zéro : rm -r ~/atelier, puis relancer le script.
# Les fichiers de départ sont datés du 1er septembre 2026, 8 h, pour que leurs
# lignes de ls -l soient les mêmes chez tout le monde ; ceux que vous créerez
# porteront la date du jour.
# Le même script sert au harnais de test des corrigés (tester.sh).
set -eu

dossier=${1:-"$HOME/atelier"}
if [ -e "$dossier" ]; then
  echo "$dossier existe déjà : rien n'est modifié." >&2
  echo "Pour repartir de zéro : rm -r $dossier, puis relancez ce script." >&2
  exit 1
fi
mkdir -p "$dossier"
cd "$dossier"
mkdir notes journaux projets projets/site projets/scripts vieux

# Le fichier de données du cours (diapositive « Le fil rouge : pionnieres.csv »).
cat > pionnieres.csv << 'FIN'
nom;annee;domaine;contribution
Lovelace Ada;1843;programmation;premier programme publié
Booth Kathleen;1947;langages;premier langage d'assemblage
Hopper Grace;1952;langages;premier compilateur A-0
Johnson Katherine;1962;calcul;trajectoires de Friendship 7
Hamilton Margaret;1969;logiciel;logiciel embarqué d'Apollo 11
Conway Lynn;1978;materiel;révolution VLSI
Perlman Radia;1985;reseau;protocole spanning tree
Goldwasser Shafi;1982;cryptographie;chiffrement probabiliste
FIN

cat > .reglages << 'FIN'
# Un fichier caché : son nom commence par un point.
# ls ne le montre pas ; ls -a, si.
couleur=oui
FIN

cat > notes/lisezmoi.txt << 'FIN'
Ce dossier est votre terrain de jeu : vous pouvez tout y casser.
Pour repartir de zéro : rm -r ~/atelier, puis relancez preparer.sh.
FIN

cat > notes/a-faire.txt << 'FIN'
- lire le manuel de ls
- ranger les notes
- archiver les journaux de 2025
FIN

cat > notes/idees.txt << 'FIN'
Une idée par ligne.
Un script qui compte les erreurs du serveur.
FIN

# Deux journaux de serveur web au nom presque identique (complétion), le second
# assez long pour less, head et tail : une requête toutes les 29 secondes ;
# toutes les 50 requêtes, une erreur ; toutes les 7, une réponse lente.
journal() { # $1 année  $2 nombre de lignes
  local i s pages=(/index.html /contact.html /api/commandes /images/logo.png)
  for ((i = 1; i <= $2; i++)); do
    s=$((i * 29))
    printf '%s-11-%02d %02d:%02d:%02d ' "$1" $((s / 86400 + 1)) $((s / 3600 % 24)) $((s / 60 % 60)) $((s % 60))
    if ((i % 50 == 0)); then printf 'ERROR GET /api/commandes 500\n'
    elif ((i % 7 == 0)); then printf 'WARN GET %s 200 lent\n' "${pages[i % 4]}"
    else printf 'INFO GET %s 200\n' "${pages[i % 4]}"
    fi
  done
}
journal 2025 120 > journaux/serveur-2025-novembre.log
journal 2026 1500 > journaux/serveur-2026-novembre.log

cat > projets/site/index.html << 'FIN'
<!doctype html>
<title>Pionnières de l'informatique</title>
<h1>Pionnières de l'informatique</h1>
FIN

cat > projets/scripts/bonjour.sh << 'FIN'
#!/bin/bash
echo "Script lancé"
for i in {1..3}; do
    echo "Itération $i"
done
# Un commentaire : le code de retour vaut 0 quand tout s’est bien passé
exit 0
FIN

printf 'premier jet\n' > vieux/brouillon-1.txt
printf 'second jet\n' > vieux/brouillon-2.txt

# Droits et dates identiques chez tout le monde, quel que soit le umask.
find . -type d -exec chmod 755 {} +
find . -type f -exec chmod 644 {} +
chmod 755 projets/scripts/bonjour.sh
find . -exec touch -h -d '2026-09-01 08:00' {} +

echo "Dossier de travail prêt : $dossier"
echo "Pour y entrer : cd $dossier"
