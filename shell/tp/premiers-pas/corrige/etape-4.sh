#!/usr/bin/env bash
# Étape 4 : se déplacer. Le cd d'un script ne change pas le dossier du
# terminal qui le lance : le script a son propre dossier courant.

cd ~/atelier
cd notes
pwd
# 1. Relatif : remonter dans atelier, puis descendre dans projets/site
cd ../projets/site
pwd
# 2. Absolu : ~ est remplacé par le chemin de votre dossier personnel
echo ~
cd ~/atelier/projets/site
pwd
# 3. Lister journaux sans quitter projets/site
ls ../../journaux
# 4. notes/../projets/./site : le même dossier, par un détour
cd ~/atelier
ls notes/../projets/./site
# 5. Un chemin absolu qui part de la racine, puis retour au dossier précédent
cd /tmp
pwd
cd -
cd
pwd
