#!/usr/bin/env bash
# Exercice 5 : interroger livres.yaml avec yq, livres.json avec jq, puis modifier livres.yaml en place.
# yq est ici celui du paquet yq de Debian 13 (yq 3.4.3, en Python) : il passe le JSON à jq,
# les filtres sont ceux de jq.
set -euo pipefail

# 1. Le titre du deuxième livre : on compte à partir de 0.
yq -r '.livres[1].titre' livres.yaml

# 2. Les titres seulement des livres d'Aldous Huxley.
yq -r '.livres[] | select(.auteur == "Aldous Huxley") | .titre' livres.yaml

# 3. Le même filtre, par jq sur le fichier JSON.
jq -r '.livres[] | select(.auteur == "Aldous Huxley") | .titre' livres.json

# 4. Retitrer 1984 en 2024, dans le fichier : -i (en place) exige -y (sortie YAML).
yq -yi '(.livres[] | select(.titre == "1984") | .titre) = "2024"' livres.yaml
