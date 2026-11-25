#!/usr/bin/env bash
# Rejoue les commandes du cours « Éditer et structurer du texte » et relève les versions.
# Prérequis (Debian 13) : sudo apt install vim jq yq yamllint pandoc python3-yaml python3-ruamel.yaml script
# Facultatif : le yq écrit en Go (mikefarah), installé sous le nom yq-go, pour la diapo « Deux outils nommés yq ».
# Usage : ./rejouer.sh > sorties-edition-formats.txt 2>&1
# Tout est créé dans un dossier temporaire ; un outil absent est signalé, et ses commandes sont sautées.
set -u
run() { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1; printf '(code de retour : %s)\n' "$?"; }
a() { command -v "$1" >/dev/null 2>&1 || { printf '\n# %s absent : commandes sautées\n' "$1"; return 1; }; }
D=$(mktemp -d); cd "$D" || exit 1
echo "# $(date -I) · $(uname -srm) · $(cat /etc/debian_version 2>/dev/null) · $D"

# ---------------------------------------------------------------- versions
a vim && run 'vim --version | head -1'
a jq && run 'jq --version'
a yq && run 'yq --version'
a yq-go && run 'yq-go --version'
a yamllint && run 'yamllint --version'
a pandoc && run 'pandoc --version | head -1'
a python3 && run 'python3 -c "import yaml; print(\"PyYAML\", yaml.__version__)"'
a python3 && run 'python3 -c "import ruamel.yaml; print(\"ruamel.yaml\", ruamel.yaml.__version__)"'

# ---------------------------------------------------------------- fil rouge
cat > config.yaml <<'EOF'
---
application:
  nom: MonApplication
  version: 1.2.3
  environnements:
    production:
      url: https://prod.example.org
    developpement:
      url: http://dev.example.org
EOF

# ---------------------------------------------------------------- Vim
# touches(fichier, touches) : joue les touches (syntaxe printf) dans Vim sans configuration, puis affiche le fichier.
touches() {
  # les touches sont écrites au format de printf (\033 pour Échap, \r pour Entrée)
  local t; t=$(mktemp -d); cp "$1" "$t/f"
  # shellcheck disable=SC2059
  printf "$2" > "$t/k"
  TERM=xterm script -qc "vim -u NONE -N -i NONE -s $t/k $t/f" /dev/null >/dev/null
  cat "$t/f"; rm -rf "$t"
}
if a vim && a script; then
  : > vide
  echo; echo '# Survivre : i Hello World ! Échap :wq Entrée'; touches vide 'iHello World !\033:wq\r'
  echo; echo '# :q sur un tampon modifié (message en français)'
  LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 vim -u NONE -N -i NONE -es -c 'normal dd' \
    -c 'try|q|catch|call writefile([v:exception], "msg")|endtry' -c 'q!' config.yaml; cat msg
  echo; echo '# /1.2.3 Entrée cW 2.0.0 Échap'; touches config.yaml '/1.2.3\rcW2.0.0\033:wq\r' | sed -n 4p
  echo; echo '# /1.2.3 Entrée cw 2.0.0 Échap'; touches config.yaml '/1.2.3\rcw2.0.0\033:wq\r' | sed -n 4p
  echo; echo '# /nom Entrée yyp'; touches config.yaml '/nom\ryyp:wq\r' | sed -n 2,5p
  echo; echo '# /environ Entrée d2j'; touches config.yaml '/environ\rd2j:wq\r'
  echo; echo '# /production Entrée dG'; touches config.yaml '/production\rdG:wq\r'
  echo; echo '# /version Entrée dd .'; touches config.yaml '/version\rdd.:wq\r'
  echo; echo '# dd u Ctrl+r'; touches config.yaml 'jddu\x12:wq\r' | head -3
  echo; echo '# :%s/o/0/'; touches config.yaml ':%%s/o/0/\r:wq\r' | sed -n 2,4p
  echo; echo '# :%s/o/0/g'; touches config.yaml ':%%s/o/0/g\r:wq\r' | sed -n 2,4p
  echo; echo '# :%s/example.org/example.net/g'; touches config.yaml ':%%s/example.org/example.net/g\r:wq\r' | grep url
  echo; echo '# /developpement Entrée Ctrl+v j I # Échap'; touches config.yaml '/developpement\r\x16jI# \033:wq\r' | tee commente.yaml
  echo; echo '# corrigé du ~/.vimrc : i set number Entrée set tabstop=4 Échap :wq'
  touches vide 'iset number\rset tabstop=4\033:wq\r' > vimrc; cat vimrc
  echo; echo '# puis /4 Entrée r2 :wq'; touches vimrc '/4\rr2:wq\r'
  printf 'set number\nset autoindent\nset tabstop=4\nsyntax on\nfiletype plugin indent on\n' > vimrc-complet
  echo; echo '# options en vigueur sur config.yaml avec ce ~/.vimrc'
  vim -u vimrc-complet -N -i NONE -es -c 'e config.yaml' -c 'redir! > opts' \
    -c 'set tabstop? shiftwidth? expandtab?' -c 'redir END' -c 'q' >/dev/null; tr -s ' \n' ' ' < opts; echo
fi
# Un conteneur Debian n'a souvent aucun éditeur.
a docker && run 'docker container run --rm debian:13 sh -c "command -v vi nano vim || echo aucun éditeur"'

# ---------------------------------------------------------------- Markdown
cat > tableau.md <<'EOF'
| Option | Effet |
|:-------|:------|
| `-l` | format long |
EOF
cat > doc.md <<'EOF'
# Documentation de la commande `ls`

`ls` liste le contenu d’un répertoire : ses fichiers et ses sous-répertoires.

```bash
ls -lh /etc/ssh
```

Options courantes :

- `-l` : format long (droits, propriétaire, taille, date)
- `-a` : affiche aussi les fichiers cachés (nom commençant par `.`)
- `-h` : tailles lisibles (Kio, Mio), avec `-l`
- `-t` : trie par date de modification
EOF
if a pandoc; then
  run 'printf "**gras** et *italique*\n" | pandoc -t html'
  run 'pandoc -f commonmark -t html tableau.md'
  run 'pandoc -f gfm -t html tableau.md'
  run 'pandoc -f gfm -t html doc.md | head -3'
  run 'pandoc -f gfm -s --metadata title="ls" doc.md -o doc.html && ls doc.html'
  run 'pandoc doc.md -o doc.pdf'
fi

# ---------------------------------------------------------------- YAML et JSON
cat > livre.yaml <<'EOF'
---
titre: "1984"
auteur: George Orwell
annee_publication: 1949
genre: Dystopie
mots_cles:
  - dystopie
  - politique
  - science-fiction
EOF
printf 'titre: 1984\nauteur: George Orwell\nmots_cles:\n  - dystopie\n\t- politique\n' > tabulation.yaml
printf -- '---\napplication:\n  nom: MonApplication\n   version: 1.2.3\n' > indentation.yaml
printf -- '---\npays: [FR, NO, SE]\nactif: yes\n' > norvege.yaml
cat > typage.yaml <<'EOF'
---
mode: 0644
mode_12: 0o644
duree: 22:22
version: 1.10
date: 2024-01-15
titre: 1984
titre_chaine: "1984"
EOF
cat > multi.yaml <<'EOF'
---
litteral: |
  ligne 1
  ligne 2
replie: >
  ligne 1
  ligne 2
sans_fin: |-
  ligne 1
  ligne 2
EOF
cat > ancres.yaml <<'EOF'
---
defaut: &defaut
  couleur: bleu
  taille: M
objet1:
  <<: *defaut
  taille: L
objet2: *defaut
EOF
printf '{\t"a": 1}\n' > tabulation.json
printf '{"a": 1, "a": 2}\n' > doublon.json
# Les commandes Python du cours, sur deux lignes comme dans les diapos.
PY11=$'import sys, yaml\nprint(yaml.safe_load(sys.stdin))'
PY12=$'from ruamel.yaml import YAML; import sys\nprint(YAML(typ="safe").load(sys.stdin))'
if a python3; then
  run $'python3 -c \'import sys, json, yaml\njson.dump(yaml.safe_load(sys.stdin), sys.stdout, indent=2)\' < config.yaml'
  run "python3 -c '$PY11' < norvege.yaml"
  run "python3 -c '$PY12' < norvege.yaml"
  run "python3 -c '$PY11' < typage.yaml"
  run "python3 -c '$PY12' < typage.yaml"
  run "python3 -c 'import json, yaml; json.dumps(yaml.safe_load(open(\"typage.yaml\")))' 2>&1 | tail -1"
  run $'python3 -c \'import sys, json, yaml\nprint(json.dumps(yaml.safe_load(sys.stdin), indent=1))\' < multi.yaml'
  run "python3 -c '$PY11' < tabulation.json 2>&1 | tail -2"
  run "python3 -c '$PY12' < tabulation.json"
  run "python3 -c '$PY12' < doublon.json 2>&1 | grep -m1 -i duplicate"
fi
if a jq; then
  run 'echo "{\"a\": 1} # commentaire" | jq .'
  run 'jq -c . doublon.json'
fi
if a yq; then
  run 'yq . config.yaml'
  run 'yq . config.yaml > config.json && jq -r ".application.nom" config.json'
  run 'jq -S . config.json > a.json; yq -S . config.yaml > b.json; cmp a.json b.json && echo identiques'
  run 'yq -r ".application.environnements.production.url" config.yaml'
  run 'cp config.yaml c.yaml; yq -i ".application.version = \"1.2.4\"" c.yaml'
  run 'yq -yi ".application.version = \"1.2.4\"" c.yaml && grep version c.yaml'
  run 'yq -c . ancres.yaml'
  run "yq -c '.objet1, .objet2' ancres.yaml"
  run 'yq -c .application.environnements commente.yaml'
  run 'yq . livre.yaml > livre.json && cat livre.json'
  run 'yq -c "[.titre, .annee_publication] | map(type)" livre.yaml'
fi
if a yq-go; then
  run 'yq-go ".application.environnements.production.url" config.yaml'
  run 'cp config.yaml g.yaml; yq-go -i ".application.version = \"1.2.4\"" g.yaml && grep version g.yaml'
  run 'yq-go -o=json -I=0 . typage.yaml'
fi
if a yamllint; then
  run 'yamllint livre.yaml config.yaml ancres.yaml'
  run 'yamllint norvege.yaml'
  run 'yamllint tabulation.yaml'
  run 'yamllint indentation.yaml'
fi
