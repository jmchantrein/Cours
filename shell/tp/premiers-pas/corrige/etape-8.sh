#!/usr/bin/env bash
# Étape 8 : premiers tubes et redirections.

cd ~/atelier
# 1. La sortie de ls -l dans un fichier
ls -l > liste.txt
cat liste.txt
# 2. Ajouter une ligne à la fin, sans écraser
echo "- relire les diapos" >> notes/a-faire.txt
cat notes/a-faire.txt
# 3. Séparer la sortie et les erreurs
ls pionnieres.csv absent.txt
ls pionnieres.csv absent.txt 2> erreurs.txt
cat erreurs.txt
# 4. Compter les erreurs du serveur
grep ERROR journaux/serveur-2026-novembre.log | wc -l
# 5. La 4e ligne de pionnieres.csv
head -n 4 pionnieres.csv | tail -n 1
# 6. Les trois pionnières les plus anciennes, sans la ligne d'en-tête
tail -n +2 pionnieres.csv | sort -t';' -k2 -n | head -n 3
# 7. Les trois dernières erreurs, dans un fichier
grep ERROR journaux/serveur-2026-novembre.log | tail -n 3 > dernieres-erreurs.txt
cat dernieres-erreurs.txt
