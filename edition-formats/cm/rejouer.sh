#!/usr/bin/env bash
# Rejoue les commandes du cours « Éditer et structurer du texte » et relève les versions.
# Environnement de référence : Debian 13 (conteneur debian:13-slim, paquets Debian). Lancé sur l'hôte, le script
# construit ce conteneur (nom rejeu-edition-formats-…), y installe vim, jq, yq, yamllint, pandoc, python3-yaml,
# python3-ruamel.yaml, vim-tiny, bsdutils (commande script) et les locales, puis s'y rejoue lui-même. Il a donc besoin de Docker et d'un accès
# aux dépôts Debian. Le yq écrit en Go (mikefarah, pour la diapo « Deux outils nommés yq ») n'existe pas dans Debian :
# le script télécharge le binaire amont (amd64), en version et SHA-256 fixés ; sans accès à GitHub, ses commandes sont sautées.
# Derrière un proxy HTTPS qui réécrit TLS : TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port ./rejouer.sh
# (voir le README.md du dépôt). Sans TPTEST_CA, HTTPS_PROXY est ignoré, comme en CI.
# Usage : ./rejouer.sh > sorties-edition-formats.txt 2>&1
# Dans le conteneur (REJEU_INTERNE=1) ou sur une Debian 13 qui a déjà les paquets : tout est créé dans un dossier
# temporaire ; un outil absent est signalé, et ses commandes sont sautées.
set -u
YQ_GO_VERSION=v4.44.3
YQ_GO_SHA256=a2c097180dd884a8d50c956ee16a9cec070f30a7947cf4ebf87d5f36213e9ed7

if [ -z "${REJEU_INTERNE:-}" ]; then
  ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
  reseau=(); apt_https=""
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    reseau+=(--network host --env "HTTPS_PROXY=$HTTPS_PROXY" --env "SSL_CERT_FILE=/run/ca-hote.crt"
      --volume "$TPTEST_CA:/run/ca-hote.crt:ro"); apt_https="1"
  fi
  nom="rejeu-edition-formats-$$"
  trap 'docker container rm -f "$nom" > /dev/null 2>&1' EXIT
  # Un conteneur Debian n'a souvent aucun éditeur : on le vérifie avant d'installer quoi que ce soit.
  for image in debian:13-slim debian:13; do
    printf '\n$ docker container run --rm %s sh -c "command -v vi nano vim || echo aucun éditeur"\n' "$image"
    docker container run --rm "$image" sh -c 'command -v vi nano vim || echo aucun éditeur' 2>&1
  done
  docker container run --rm --name "$nom" "${reseau[@]}" --env "APT_HTTPS=$apt_https" --env REJEU_INTERNE=1 \
    --env "YQ_GO_VERSION=$YQ_GO_VERSION" --env "YQ_GO_SHA256=$YQ_GO_SHA256" \
    --volume "$ici/rejouer.sh:/rejouer.sh:ro" debian:13-slim bash -euc '
      if [ -n "$APT_HTTPS" ]; then
        sed -i "s|http://deb.debian.org|https://deb.debian.org|g" /etc/apt/sources.list.d/debian.sources
        printf "Acquire::https::Proxy \"%s\";\nAcquire::https::CAInfo \"/run/ca-hote.crt\";\n" "$HTTPS_PROXY" \
          > /etc/apt/apt.conf.d/99mandataire
      fi
      apt-get update -qq > /dev/null
      printf "\n$ apt-cache policy vim-tiny vim ; apt-cache show vim-tiny | grep -E \"^(Package|Version|Priority|Essential):\"\n"
      apt-cache policy vim-tiny vim | grep -E "^[a-z]|Candidate"
      apt-cache show vim-tiny | grep -E "^(Package|Version|Priority|Essential):"
      printf "\n$ dpkg -l | grep -c vim\n%s\n" "$(dpkg -l | grep -c vim || true)"
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        vim vim-tiny jq yq yamllint pandoc python3-yaml python3-ruamel.yaml bsdutils util-linux locales ca-certificates curl > /dev/null
      sed -i "s/^# *fr_FR.UTF-8/fr_FR.UTF-8/" /etc/locale.gen; locale-gen > /dev/null
      if [ "$(dpkg --print-architecture)" = amd64 ] && curl -fsSL -o /usr/local/bin/yq-go \
        "https://github.com/mikefarah/yq/releases/download/$YQ_GO_VERSION/yq_linux_amd64" 2> /dev/null \
        && [ "$(sha256sum /usr/local/bin/yq-go | cut -d" " -f1)" = "$YQ_GO_SHA256" ]; then
        chmod +x /usr/local/bin/yq-go
      else
        rm -f /usr/local/bin/yq-go
      fi
      bash /rejouer.sh'
  exit $?
fi
run() { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1; printf '(code de retour : %s)\n' "$?"; }
a() { command -v "$1" >/dev/null 2>&1 || { printf '\n# %s absent : commandes sautées\n' "$1"; return 1; }; }
D=$(mktemp -d); cd "$D" || exit 1
echo "# $(date -I) · $(uname -srm) · $(cat /etc/debian_version 2>/dev/null) · $D"

# ---------------------------------------------------------------- versions
a dpkg-query && run "dpkg-query -W -f '\${Package} \${Version}\n' vim vim-tiny vim-runtime jq yq yamllint pandoc python3-yaml python3-ruamel.yaml"
a vim && run 'vim --version | sed -n "1p;2p"'
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
# touches_avec(commande, fichier, touches) : comme touches, avec la commande donnée (vim-tiny, vi en mode compatible…).
touches_avec() {
  local t; t=$(mktemp -d); cp "$2" "$t/f"
  # shellcheck disable=SC2059
  printf "$3" > "$t/k"
  TERM=xterm script -qc "$1 -s $t/k $t/f" /dev/null >/dev/null
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
  echo; echo '# dd u Ctrl+r (vim, avec defaults.vim)'; touches_avec 'vim -u DEFAULTS -i NONE' config.yaml 'jddu\x12:wq\r' | head -3
  echo; echo '# dd u Ctrl+r (vim -N)'; touches config.yaml 'jddu\x12:wq\r' | head -3
  echo; echo '# dd u Ctrl+r (vi, mode compatible, paquet vim)'; touches_avec 'vi -u NONE -i NONE' config.yaml 'jddu\x12:wq\r' | head -3
  echo; echo '# dd u u (vi, mode compatible, paquet vim)'; touches_avec 'vi -u NONE -i NONE' config.yaml 'jdduu:wq\r' | head -3
  if a vim.tiny; then
    echo; echo '# dd u Ctrl+r (vim-tiny)'; touches_avec 'vim.tiny -u NONE -i NONE' config.yaml 'jddu\x12:wq\r' | head -3
    echo; echo '# dd u u (vim-tiny)'; touches_avec 'vim.tiny -u NONE -i NONE' config.yaml 'jdduu:wq\r' | head -3
    echo; echo '# dd u Ctrl+r (vim-tiny -N)'; touches_avec 'vim.tiny -u NONE -N -i NONE' config.yaml 'jddu\x12:wq\r' | head -3
  fi
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
  if a vim.tiny; then
    echo; echo '# le même ~/.vimrc avec vim-tiny : message au démarrage'
    TERM=xterm script -qc "vim.tiny -u vimrc-complet -i NONE -c q" /dev/null | tr -d '\r' | grep -a -o 'E319.*' | head -1
    echo '# options en vigueur sur config.yaml avec vim-tiny (ici vim-runtime est présent, car le paquet vim aussi : filetype=yaml ;'
    echo '# avec vim-tiny seul, relevé dans un conteneur debian:13-slim, filetype est vide ; dans les deux cas, pas de réglages YAML)'
    vim.tiny -u vimrc-complet -N -i NONE -es -c 'e config.yaml' -c 'redir! > opts-tiny' \
      -c 'set tabstop? shiftwidth? expandtab? filetype?' -c 'redir END' -c 'q' >/dev/null 2>&1; tr -s ' \n' ' ' < opts-tiny; echo
  fi
fi

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

Voir le [manuel de GNU coreutils](https://www.gnu.org/software/coreutils/manual/coreutils.html).

Pour lister un dossier :

1. Ouvrir un terminal
2. Aller dans le dossier avec `cd`
3. Lancer `ls -lh`
EOF
if a pandoc; then
  run 'printf "**gras** et *italique*\n" | pandoc -t html'
  run 'pandoc -f commonmark -t html tableau.md'
  run 'pandoc -f gfm -t html tableau.md'
  run 'pandoc -f gfm -t html doc.md | head -3'
  run 'pandoc -f gfm -s --metadata title="ls" doc.md -o doc.html && ls doc.html'
  run 'pandoc doc.md -o doc.pdf'
  run 'pandoc -f gfm -s doc.md -o sans-titre.html; ls sans-titre.html'
  run 'pandoc doc.md -o doc.odt && pandoc doc.md -o doc.docx && ls doc.odt doc.docx'
  run 'pandoc -f gfm -s --metadata title="ls" doc.md -o doc.html && grep -o '"'"'href="https[^"]*"'"'"' doc.html && grep -o '"'"'<ol[^>]*>'"'"' doc.html'
  run 'pandoc doc.md -o doc.odt && ls doc.html doc.odt'
  run 'grep -m1 "<title>" sans-titre.html'
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
printf '%%YAML 1.1\n---\n{\t"a": 1}\n' > tabulation11.yaml
cat > matrice.yaml <<'EOF'
t: true
T: True
Y: yes
YY: YES
n: no
nn: No
o: on
f: off
y: y
N: n
nul: null
til: ~
vide:
int: 42
oct11: 0644
oct12: 0o644
hex: 0x1F
sex: 22:22
fl: 3.14
fl2: 1.10
inf: .inf
date: 2024-01-15
str: web01
v: 1.2.3
q: "1984"
EOF
cat > matrice.py <<'EOF'
import yaml
from ruamel.yaml import YAML
a = yaml.safe_load(open("matrice.yaml"))
b = YAML(typ="safe").load(open("matrice.yaml"))
print("%-6s %-28s %s" % ("cle", "PyYAML", "ruamel.yaml (typ safe)"))
for k in a:
    print("%-6s %-28r %r" % (k, a[k], b[k]))
EOF
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
  run $'python3 -c \'import yaml\nprint(yaml.load(open("tabulation.json"), Loader=yaml.CSafeLoader))\''
  run $'python3 -c \'from ruamel.yaml import YAML\nprint(YAML(typ="safe", pure=True).load(open("tabulation11.yaml")))\''
  run $'python3 -c \'from ruamel.yaml import YAML\ny = YAML(); y.version = (1, 1)\nprint(y.load(open("tabulation11.yaml")))\''
  run "python3 -c '$PY12' < doublon.json 2>&1 | grep -m1 -i duplicate"
fi
if a python3; then
  run 'python3 matrice.py'
  # une directive %YAML en tête de document
  run 'printf -- "%%YAML 1.1\n---\na: no\n" | python3 -c "import sys; from ruamel.yaml import YAML; print(YAML(typ=\"safe\").load(sys.stdin))"'
  run 'printf -- "%%YAML 1.1\n---\na: no\n" | python3 -c "import sys; from ruamel.yaml import YAML; print(YAML(typ=\"safe\", pure=True).load(sys.stdin))"'
  run 'printf -- "%%YAML 1.2\n---\na: no\n" | python3 -c "import sys, yaml; print(yaml.safe_load(sys.stdin))"'
fi
if a jq; then
  run 'echo "{\"a\": 1} # commentaire" | jq .'
  run 'jq -c . doublon.json'
fi
if a yq; then
  run 'yq . config.yaml'
  run 'yq -c . tabulation.json'
  run 'printf "mode: 0644\n" | yq -c .'
  run 'yq . config.yaml > config.json && jq -r ".application.nom" config.json'
  run 'jq -S . config.json > a.json; yq -S . config.yaml > b.json; cmp a.json b.json && echo identiques'
  run 'yq -r ".application.environnements.production.url" config.yaml'
  run 'cp config.yaml c.yaml; yq -i ".application.version = \"1.2.4\"" c.yaml'
  run 'yq -yi ".application.version = \"1.2.4\"" c.yaml && grep version c.yaml'
  run 'yq -y . config.yaml | head -2 ; yq -y --explicit-start . config.yaml | head -2'
  run 'yq -c . ancres.yaml'
  run "yq -c '.objet1, .objet2' ancres.yaml"
  run 'yq -c .application.environnements commente.yaml'
  run 'yq . livre.yaml > livre.json && cat livre.json'
  run 'yq -c "[.titre, .annee_publication] | map(type)" livre.yaml'
  run 'printf "titre: 1984\n" | yq -c ".titre | type"'
  run 'yq -c . matrice.yaml'
  run 'yq -c . norvege.yaml'
  run 'yq -c . typage.yaml'
  run 'yq eval ".a" config.yaml'
  run 'yq -Y . commente.yaml'
  run 'printf -- "---\ncommand:\n  - bash\n  - -c\n  - |\n    echo hello world\n" > commande.yaml; yq -c . commande.yaml'
  run 'echo "{personne: {nom: John Doe, age: 30, hobbies: [lecture, course]}}" | yq -c .'
fi
if a yq-go; then
  run 'yq-go ".application.environnements.production.url" config.yaml'
  run 'cp config.yaml g.yaml; yq-go -i ".application.version = \"1.2.4\"" g.yaml && grep version g.yaml'
  run 'yq-go -o=json -I=0 . typage.yaml'
  run 'yq-go -o=json -I=0 . tabulation.json'
  run 'printf "mode: 0644\n" | yq-go -o=json -I=0 .'
  run 'yq-go ".[] | key + \" \" + tag" matrice.yaml | paste -sd";"'
  run 'yq-go -i ".application.version = \"1.2.4\"" commente.yaml && cat commente.yaml'
  run 'yq-go -o=json -I=0 . norvege.yaml'
fi
if a yamllint; then
  run 'yamllint livre.yaml config.yaml ancres.yaml'
  run 'yamllint norvege.yaml'
  run 'yamllint tabulation.yaml'
  run 'yamllint indentation.yaml'
fi
