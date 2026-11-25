#!/usr/bin/env bash
# preparer.sh — crée le dossier de travail du TP « Droits, liens, recherche et archives ».
#
# Usage : bash preparer.sh [dossier]      (par défaut : ~/fichiers)
#
# Le dossier ne doit pas exister : le script refuse d'écraser quoi que ce soit.
# Pour repartir de zéro : chmod -R u+rwx ~/fichiers && rm -r ~/fichiers, puis
# relancer le script (chmod d'abord : le TP retire des droits).
# Les fichiers de départ sont datés du 1er septembre 2026, 8 h, et leurs droits
# sont fixés ici : leurs lignes de ls -l sont les mêmes chez tout le monde.
# Le même script sert au harnais de test des corrigés (tester.sh).
set -eu

dossier=${1:-"$HOME/fichiers"}
if [ -e "$dossier" ]; then
  echo "$dossier existe déjà : rien n'est modifié." >&2
  echo "Pour repartir de zéro : chmod -R u+rwx $dossier && rm -r $dossier, puis relancez ce script." >&2
  exit 1
fi
mkdir -p "$dossier"
cd "$dossier"
mkdir scripts documents documents/notes documents/brouillons journaux coffre

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

# Les scripts des diapositives (« Un script : shebang, droit x, ./ », « Exemple : sauvegarder un dossier »).
cat > scripts/bonjour.sh << 'FIN'
#!/bin/bash
echo "Script lancé"
for i in {1..3}; do
    echo "Itération $i"
done
# Un commentaire : le code de retour vaut 0 quand tout s’est bien passé
exit 0
FIN

cat > scripts/sauvegarde.sh << 'FIN'
#!/bin/bash
# Archive le dossier donné en premier argument, avec la date du jour dans le nom
date_jour=$(date +%Y%m%d)
tar -czf "sauvegarde_${date_jour}.tar.gz" "$1"
exit 0
FIN

cat > documents/rapport.txt << 'FIN'
Rapport d'activité
Rien à signaler : le serveur a répondu toute la journée.
FIN

cat > documents/notes/reunion-2026-11-18.txt << 'FIN'
Réunion du 18 novembre : relire les droits du dossier partagé.
FIN

cat > documents/notes/reunion-2026-11-25.txt << 'FIN'
Réunion du 25 novembre : archiver les journaux.
FIN

: > documents/brouillons/vide.txt

cat > coffre/secret.txt << 'FIN'
Le code du coffre est 1843.
FIN

# Un journal de serveur web, assez gros pour find -size et pour la compression :
# une requête toutes les 29 secondes ; toutes les 50, une erreur ; toutes les 7, une réponse lente.
pages=(/index.html /contact.html /api/commandes /images/logo.png)
for ((i = 1; i <= 1500; i++)); do
  s=$((i * 29))
  printf '2026-11-%02d %02d:%02d:%02d ' $((s / 86400 + 1)) $((s / 3600 % 24)) $((s / 60 % 60)) $((s % 60))
  if ((i % 50 == 0)); then printf 'ERROR GET /api/commandes 500\n'
  elif ((i % 7 == 0)); then printf 'WARN GET %s 200 lent\n' "${pages[i % 4]}"
  else printf 'INFO GET %s 200\n' "${pages[i % 4]}"
  fi
done > journaux/serveur.log

# Droits et dates identiques chez tout le monde, quel que soit le umask.
find . -type d -exec chmod 755 {} +
find . -type f -exec chmod 644 {} +
find . -exec touch -h -d '2026-09-01 08:00' {} +

echo "Dossier de travail prêt : $dossier"
echo "Pour y entrer : cd $dossier"
