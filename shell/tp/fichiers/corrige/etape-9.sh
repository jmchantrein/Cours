#!/usr/bin/env bash
# Étape 9 : archiver avec tar, compresser avec gzip, restaurer.

cd ~/fichiers
# 1. Une archive, puis la même compressée
tar -cf journaux.tar journaux
tar -czf journaux.tar.gz journaux
ls -l journaux/serveur.log journaux.tar journaux.tar.gz
tar -tzf journaux.tar.gz
# 2. Extraire ailleurs, puis comparer à l'original
mkdir restauration
tar -xzf journaux.tar.gz -C restauration
diff -r journaux restauration/journaux && echo "identiques"
# 3. Compresser un seul fichier, en gardant l'original (-k)
gzip -k journaux/serveur.log
ls journaux
zcat journaux/serveur.log.gz | tail -n 1
# 4. Le script de sauvegarde du cours, puis une restauration après suppression
./scripts/sauvegarde.sh documents
ls sauvegarde_*.tar.gz
tar -tzf sauvegarde_*.tar.gz | sort
rm -r documents
tar -xzf sauvegarde_*.tar.gz
ls documents
