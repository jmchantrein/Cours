#!/bin/bash
# Étape 10 d : revenir au tout premier commit par git reset --hard, puis tout retrouver par le reflog.
cd ~/mon_projet || exit 1
git log --oneline | wc -l
# le premier commit est le seul sans parent : son identifiant, sans le recopier
git rev-list --max-parents=0 HEAD
git reset --hard "$(git rev-list --max-parents=0 HEAD)"
git log --oneline
ls -A
git status --short
git reflog -3
# HEAD@{1} : la position de HEAD avant ce reset
git reset --hard "HEAD@{1}"
git log --oneline | wc -l
git status --short
