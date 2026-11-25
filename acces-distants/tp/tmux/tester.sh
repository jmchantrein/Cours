#!/usr/bin/env bash
# Harnais de test des corrigés du TP « Travailler dans tmux ».
#
# Il charge et exécute les fichiers de corrige/, ceux-là mêmes que l'énoncé
# affiche : un corrigé qui ne fonctionne plus fait échouer le harnais.
#
# Usage : ./tester.sh [--lint | --up | --dedans] [--keep]
#   --lint    (défaut) sans rien construire : bash -n et shellcheck des scripts,
#             exécution de tmux.conf dans un serveur tmux vide (si tmux est installé).
#   --up      --lint, puis les vérifications dans un conteneur Debian 13
#             (image tptest-tmux : tmux, procps, vim-tiny), en compte ordinaire.
#   --dedans  les vérifications seules, sur la machine courante : c'est ce que
#             --up lance dans le conteneur. Elles emploient un serveur tmux et
#             un HOME temporaires : vos sessions et votre ~/.tmux.conf n'y sont
#             pour rien.
#   --keep    ne supprime ni le conteneur ni l'image (pour examiner un échec).
#
# Ce que les vérifications couvrent :
#   tmux.conf          se charge sans erreur ; une erreur ajoutée exprès est
#                      détectée ; chaque option et chaque touche annoncées dans
#                      ses commentaires ont l'effet dit (numérotation à partir
#                      de 1, renumérotation, | et _, préfixe r, mode copie vi) ;
#   session-atelier.sh crée les fenêtres et panneaux attendus (list-windows,
#                      list-panes), avec et sans tmux.conf ; relancé, il ne
#                      reconstruit rien ; « =nom » distingue atel d'atelier ;
#   étapes 1 à 3       les touches de l'énoncé, envoyées à un client attaché
#                      sous pseudo-terminal (send-keys -K), donnent l'arbre du
#                      corrigé ; la session survit à la mort du client
#                      (kill -KILL), le compteur continue, son processus est un
#                      enfant du serveur ; sans tmux, la même mort tue le travail.
#
# Le harnais ne crée et ne supprime que des ressources préfixées « tptest » :
# l'image et le conteneur tptest-tmux.
#
# Prérequis de --lint : bash, shellcheck ; tmux pour vérifier tmux.conf.
# Prérequis de --up : Docker, et l'accès aux dépôts Debian (deb.debian.org).
# Derrière un proxy HTTPS qui réécrit TLS : TPTEST_CA (voir README.md du dépôt).
# Prérequis de --dedans : tmux, procps (pgrep, ps), script (util-linux), vi.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
corrige="$ici/corrige"
image="tptest-tmux"
conteneur="tptest-tmux"

mode="lint"; garder=""
for argument in "$@"; do
  case "$argument" in
    --lint) mode="lint" ;;
    --up) mode="up" ;;
    --dedans) mode="dedans" ;;
    --keep) garder="1" ;;
    -h | --help) sed -n '2,42p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $argument" >&2; exit 2 ;;
  esac
done

exiger() { # $1 commande  $2 paquet Debian qui la fournit
  command -v "$1" > /dev/null || { echo "$1 est introuvable dans le PATH : installez le paquet $2." >&2; exit 1; }
}

# ---------------------------------------------------------------- comptes rendus

reussis=0; echecs=()
ok() { printf 'OK     %s\n' "$*"; reussis=$((reussis + 1)); }
ko() { printf 'ÉCHEC  %s\n' "$*"; echecs+=("$*"); }
titre() { printf '\n======== %s ========\n' "$*"; }
bilan() {
  printf '\n======== Bilan (--%s) : %s vérifications réussies, %s en échec ========\n' "$mode" "$reussis" "${#echecs[@]}"
  if [ "${#echecs[@]}" -gt 0 ]; then printf '  - %s\n' "${echecs[@]}"; exit 1; fi
  exit 0
}
# egal attendu obtenu message
egal() {
  if [ "$2" = "$1" ]; then ok "$3"
  else ko "$3 : « $2 », « $1 » attendu"; fi
}

# ======================================================================
# --dedans : les vérifications, sur la machine courante
# ======================================================================
if [ "$mode" = "dedans" ]; then
  exiger tmux tmux
  exiger pgrep procps
  exiger script bsdutils
  exiger vi vim-tiny
  # Un serveur tmux et un HOME à part : rien ne touche aux sessions de la machine.
  travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
  export TMUX_TMPDIR="$travail" HOME="$travail/home" TERM="${TERM:-xterm}" EDITOR=vi
  unset TMUX VISUAL
  mkdir -p "$HOME"; cd "$HOME"
  trap 'tmux kill-server > /dev/null 2>&1 || true; rm -rf -- "$travail"' EXIT
  neuf() { tmux kill-server > /dev/null 2>&1 || true; rm -f "$HOME/.tmux.conf"; sleep 0.2; }
  # Un client attaché sous pseudo-terminal, comme dans un vrai terminal ; il vit au plus 60 s.
  attacher() { # $1 session  $2 fichier où script écrit l'écran
    { sleep 60 | script -qfc "tmux attach-session -t $1" "$2" > /dev/null 2>&1; } &
    for _ in $(seq 1 50); do
      [ -n "$(tmux list-clients -t "$1" 2> /dev/null)" ] && return 0
      sleep 0.1
    done
    return 1
  }
  client() { tmux list-clients -F '#{client_name}' | head -1; }
  touches() { tmux send-keys -K -c "$(client)" "$@"; sleep 0.3; }
  panneaux='#{window_index}.#{pane_index} #{window_name} #{pane_current_command}'
  arbre() { tmux list-panes -s -t "$1" -F "$panneaux" | tr '\n' ';'; }
  attendre_commande() { # $1 cible  $2 commande attendue au premier plan du panneau
    for _ in $(seq 1 30); do
      [ "$(tmux display-message -p -t "$1" '#{pane_current_command}')" = "$2" ] && return 0
      sleep 0.1
    done
    return 1
  }
  echo "tmux $(tmux -V | cut -d' ' -f2), $(grep -s '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)"

  # ------------------------------------------------------------- tmux.conf
  titre "tmux.conf : chargement"
  # source-file exécute le fichier dans un serveur vide (-f /dev/null) : une option inconnue est une erreur.
  # (source-file -n ne fait que l'analyse syntaxique : il accepterait une option inconnue.)
  if tmux -f /dev/null start-server \; source-file "$corrige/tmux.conf" 2> "$travail/erreur"; then
    ok "tmux.conf : exécuté sans erreur par source-file"
  else
    ko "tmux.conf : $(cat "$travail/erreur")"
  fi
  { cat "$corrige/tmux.conf"; echo "set -g option-inexistante on"; } > "$travail/casse.conf"
  if tmux -f /dev/null start-server \; source-file "$travail/casse.conf" 2> /dev/null; then
    ko "une option inconnue ajoutée exprès passe inaperçue : la vérification ne prouve rien"
  else
    ok "une option inconnue ajoutée exprès est refusée : la vérification est probante"
  fi
  if tmux -f /dev/null start-server \; source-file -n "$travail/casse.conf" 2> /dev/null; then
    ok "source-file -n accepte la même option inconnue : il ne vérifie que la syntaxe"
  else
    ko "source-file -n refuse l'option inconnue : l'énoncé dit le contraire"
  fi
  neuf
  cp "$corrige/tmux.conf" "$HOME/.tmux.conf"
  if tmux new-session -d -s essai 2> "$travail/erreur" && [ ! -s "$travail/erreur" ]; then
    ok "tmux.conf en place : le serveur démarre et le lit sans message d'erreur"
  else
    ko "tmux.conf en place : $(cat "$travail/erreur")"
  fi

  titre "tmux.conf : chaque réglage a l'effet annoncé"
  egal "mouse on" "$(tmux show-options -g mouse)" "set -g mouse on"
  egal "history-limit 50000" "$(tmux show-options -g history-limit)" "set -g history-limit 50000"
  egal 50000 "$(tmux display-message -p -t essai '#{history_limit}')" "une nouvelle fenêtre garde 50 000 lignes"
  egal "mode-keys vi" "$(tmux show-options -gw mode-keys)" "setw -g mode-keys vi"
  egal "1.1" "$(tmux display-message -p -t essai '#{window_index}.#{pane_index}')" "base-index et pane-base-index : la première fenêtre est 1, son panneau 1"
  tmux new-window -t essai; tmux new-window -t essai
  tmux kill-window -t essai:2
  egal "1 2" "$(tmux list-windows -t essai -F '#{window_index}' | tr '\n' ' ' | sed 's/ $//')" "renumber-windows : 1 2 3, on ferme 2, il reste 1 2"
  cle() { tmux list-keys -T "$1" "$2" 2> /dev/null | sed -E 's/^bind-key +(-r +)?-T +[^ ]+ +[^ ]+ +//'; }
  egal "split-window -h" "$(cle prefix '|')" "préfixe | : split-window -h (côte à côte)"
  egal "split-window -v" "$(cle prefix _)" "préfixe _ : split-window -v (l'un sur l'autre)"
  egal "split-window -h" "$(cle prefix %)" "préfixe % reste lié"
  egal "split-window" "$(cle prefix '"')" "préfixe \" reste lié"
  egal "delete-buffer" "$(cle prefix -)" "préfixe - supprime le dernier tampon copié (d'où _)"
  egal "send-keys -X begin-selection" "$(cle copy-mode-vi Space)" "mode copie vi : Espace commence la sélection"
  if [[ "$(cle copy-mode-vi Enter)" == "send-keys -X copy-"*"-and-cancel" ]]; then ok "mode copie vi : Entrée copie et sort ($(cle copy-mode-vi Enter))"
  else ko "mode copie vi : Entrée fait « $(cle copy-mode-vi Enter) »"; fi
  if [[ "$(cle copy-mode-vi /)" == *search-forward* ]]; then ok "mode copie vi : / cherche vers le bas"
  else ko "mode copie vi : / fait « $(cle copy-mode-vi /) »"; fi
  egal "send-keys -X cancel" "$(cle copy-mode-vi q)" "mode copie vi : q sort"
  egal "send-keys -X rectangle-toggle" "$(cle copy-mode-vi v)" "mode copie vi : v bascule la sélection rectangulaire (il ne sélectionne pas)"
  egal "" "$(cle copy-mode-vi y)" "mode copie vi : y n'est lié à rien par défaut"
  # préfixe r, tapé dans un vrai client : le fichier modifié est relu.
  attacher essai "$travail/ecran-r" || ko "préfixe r : aucun client n'a pu s'attacher"
  echo "set -g @tptest relu" >> "$HOME/.tmux.conf"
  touches C-b r
  egal "relu" "$(tmux show-options -gv @tptest 2> /dev/null)" "préfixe r : ~/.tmux.conf modifié est relu sans redémarrer"
  neuf

  # ---------------------------------------------- étapes 1 et 2 : au clavier
  titre "Étapes 1 et 2 : les touches de l'énoncé, dans un client attaché"
  tmux new-session -d -s atelier
  attacher atelier "$travail/ecran-1" || ko "étape 1 : aucun client n'a pu s'attacher"
  touches 'cd /tmp' Enter
  touches C-b d
  sleep 0.3
  egal "" "$(tmux list-clients)" "étape 1 : préfixe d détache le client"
  if grep -aq 'detached (from session atelier)' "$travail/ecran-1"; then ok "étape 1 : le terminal affiche [detached (from session atelier)]"
  else ko "étape 1 : le message de détachement n'apparaît pas"; fi
  egal "/tmp" "$(tmux display-message -p -t atelier '#{pane_current_path}')" "étape 1 : rattachable, le shell est resté dans /tmp"
  attacher atelier "$travail/ecran-2" || ko "étape 2 : aucun client n'a pu s'attacher"
  # La touche qui ouvre une invite, puis ce qu'on y tape : deux envois, comme deux gestes.
  touches C-b ,
  touches C-u edition Enter
  touches C-b %
  touches C-b Left
  touches C-b z
  egal "1" "$(tmux display-message -p -t atelier '#{window_zoomed_flag}')" "étape 2 : préfixe z agrandit le panneau"
  touches C-b z
  touches C-b c
  touches C-b ,
  touches C-u surveillance Enter
  touches top Enter
  attendre_commande atelier:surveillance top || true
  touches C-b p
  egal "edition" "$(tmux display-message -p -t atelier '#{window_name}')" "étape 2 : préfixe p revient à edition"
  egal "0.0 edition bash;0.1 edition bash;1.0 surveillance top;" "$(arbre atelier)" "étape 2 : l'arbre du corrigé (list-panes)"
  egal "0" "$(tmux display-message -p -t atelier '#{pane_index}')" "étape 2 : préfixe ← a rendu actif le panneau de gauche"
  # top lancé depuis le shell : le quitter rend le shell, la fenêtre reste.
  tmux send-keys -t atelier:surveillance q
  attendre_commande atelier:surveillance bash || true
  egal "edition surveillance" "$(tmux list-windows -t atelier -F '#{window_name}' | tr '\n' ' ' | sed 's/ $//')" "étape 2 : q quitte top, la fenêtre surveillance reste"
  tmux new-window -d -t atelier: -n top-seul top
  attendre_commande atelier:top-seul top || true
  sleep 1 # top doit avoir pris le terminal avant de recevoir q
  tmux send-keys -t atelier:top-seul q
  for _ in $(seq 1 30); do
    tmux list-windows -t atelier -F '#{window_name}' | grep -qx top-seul || break
    sleep 0.1
  done
  if tmux list-windows -t atelier -F '#{window_name}' | grep -qx top-seul; then ko "étape 2 : une fenêtre créée avec la commande top survit à top"
  else ok "étape 2 : une fenêtre créée par new-window … top se ferme avec top"; fi
  neuf

  # ---------------------------------------------- étape 3 : la mort du client
  titre "Étape 3 : la session survit à la mort du client"
  script -qfc 'sleep 600' /dev/null < <(sleep 60) > /dev/null 2>&1 &
  for _ in $(seq 1 30); do pgrep -f '^sleep 600' > /dev/null && break; sleep 0.1; done
  pkill -KILL -f '^script -qfc sleep 600' || true
  sleep 1
  if pgrep -a -f '^sleep 600'; then ko "sans tmux : sleep 600 survit à la mort de son terminal"
  else ok "sans tmux : la mort du terminal tue sleep 600 (SIGHUP)"; fi
  tmux new-session -d -s atelier -n edition
  # La commande de l'énoncé, telle quelle : c'est tmux qui la passe au shell.
  # shellcheck disable=SC2016
  tmux new-window -t atelier -n compteur 'for i in $(seq 1 600); do echo "étape $i"; sleep 1; done'
  attacher atelier "$travail/ecran-3" || ko "étape 3 : aucun client n'a pu s'attacher"
  egal 1 "$(tmux list-clients | wc -l)" "étape 3 : un client attaché"
  tmux send-keys -t atelier:edition "kill -KILL \"\$(tmux display-message -p '#{client_pid}')\"" Enter
  sleep 1
  egal "" "$(tmux list-clients)" "étape 3 : kill -KILL tue le client (le terminal)"
  if pgrep -f '^tmux attach-session -t atelier' > /dev/null; then ko "étape 3 : le processus client est toujours là"
  else ok "étape 3 : plus aucun processus client"; fi
  if tmux has-session -t =atelier 2> /dev/null; then ok "étape 3 : la session atelier existe toujours (tmux ls)"
  else ko "étape 3 : la session atelier a disparu"; fi
  avant="$(tmux capture-pane -p -t atelier:compteur | grep -v '^$' | tail -n 1)"
  sleep 2
  apres="$(tmux capture-pane -p -t atelier:compteur | grep -v '^$' | tail -n 1)"
  if [[ "$avant" == "étape "* && "$apres" == "étape "* && "${apres#étape }" -gt "${avant#étape }" ]]; then
    ok "étape 3 : le compteur continue sans client ($avant, puis $apres)"
  else
    ko "étape 3 : le compteur ne progresse pas (« $avant », puis « $apres »)"
  fi
  pid_panneau="$(tmux display-message -p -t atelier:compteur '#{pane_pid}')"
  egal "$(tmux display-message -p '#{pid}')" "$(ps -o ppid= -p "$pid_panneau" | tr -d ' ')" "étape 3 : le parent du compteur est le serveur tmux"
  neuf

  # ------------------------------------------------- session-atelier.sh
  titre "session-atelier.sh, sans tmux.conf"
  if "$corrige/session-atelier.sh" < /dev/null > "$travail/session.log" 2>&1; then ok "session-atelier.sh : code de sortie 0, sans terminal il ne s'attache pas"
  else ko "session-atelier.sh : échec"; cat "$travail/session.log"; fi
  attendre_commande atelier:edition.0 vi || true
  egal "0 edition;1 surveillance;" "$(tmux list-windows -t atelier -F '#{window_index} #{window_name}' | tr '\n' ';')" "list-windows : edition puis surveillance"
  egal "0.0 edition vi;0.1 edition bash;1.0 surveillance top;" "$(arbre atelier)" "list-panes : vi à gauche, un shell à droite, top"
  egal "edition 0 0" "$(tmux display-message -p -t atelier '#{window_name} #{pane_index} #{pane_left}')" "fenêtre edition active, panneau de gauche actif"
  "$corrige/session-atelier.sh" < /dev/null > /dev/null 2>&1 || ko "session-atelier.sh relancé : échec"
  egal "0.0 edition vi;0.1 edition bash;1.0 surveillance top;" "$(arbre atelier)" "relancé, il ne reconstruit rien"
  egal 1 "$(tmux list-sessions | wc -l)" "relancé, toujours une seule session"
  "$corrige/session-atelier.sh" atel < /dev/null > /dev/null 2>&1 || ko "session-atelier.sh atel : échec"
  egal "atel atelier" "$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ' | sed 's/ $//')" "« =atel » ne prend pas atelier pour atel"
  neuf
  titre "session-atelier.sh, avec tmux.conf"
  cp "$corrige/tmux.conf" "$HOME/.tmux.conf"
  "$corrige/session-atelier.sh" < /dev/null > /dev/null 2>&1 || ko "session-atelier.sh avec tmux.conf : échec"
  attendre_commande atelier:edition.1 vi || true
  egal "1.1 edition vi;1.2 edition bash;2.1 surveillance top;" "$(arbre atelier)" "list-panes : la même session, numérotée à partir de 1"
  neuf
  bilan
fi

# ======================================================================
# --lint
# ======================================================================
exiger bash bash
exiger shellcheck shellcheck

titre "Lint : scripts de corrige/"
for script in "$corrige"/*.sh "$ici/tester.sh"; do
  nom="${script#"$ici"/}"
  if bash -n "$script"; then ok "$nom : syntaxe bash"; else ko "$nom : syntaxe bash"; fi
  if shellcheck "$script"; then ok "$nom : shellcheck"; else ko "$nom : shellcheck"; fi
  if [ "$script" != "$ici/tester.sh" ]; then
    if [ -x "$script" ]; then ok "$nom : exécutable"; else ko "$nom : pas exécutable (chmod +x)"; fi
  fi
done
titre "Lint : tmux.conf"
if command -v tmux > /dev/null; then
  socket="tptest-lint-$$"
  # Un serveur à part (-L), sans configuration (-f /dev/null) : source-file exécute le fichier, puis
  # le serveur s'arrête, faute de session.
  if tmux -L "$socket" -f /dev/null start-server \; source-file "$corrige/tmux.conf" 2> /dev/null; then
    ok "corrige/tmux.conf : exécuté sans erreur par tmux $(tmux -V | cut -d' ' -f2) (source-file)"
  else
    ko "corrige/tmux.conf : $(tmux -L "$socket" -f /dev/null start-server \; source-file "$corrige/tmux.conf" 2>&1)"
  fi
else
  echo "tmux absent : la vérification de tmux.conf se fera dans le conteneur de --up."
fi
[ "$mode" = "lint" ] && bilan

# ======================================================================
# --up : les vérifications dans un conteneur Debian 13
# ======================================================================
exiger docker docker.io
docker info > /dev/null 2>&1 || { echo "Le démon Docker ne répond pas (docker info)." >&2; exit 1; }
travail="$(mktemp -d "${TMPDIR:-/tmp}/tptest.XXXXXX")"
nettoyer() { docker container rm -f "$conteneur" > /dev/null 2>&1 || true; }
# shellcheck disable=SC2317,SC2329 # appelée par trap
en_sortie() {
  if [ -z "$garder" ]; then nettoyer; docker image rm "$image" > /dev/null 2>&1 || true
  else echo "--keep : conteneur et image $image conservés"; fi
  rm -rf -- "$travail"
}
trap en_sortie EXIT
nettoyer

# Construit une image ; derrière un mandataire HTTPS, apt passe par lui (dépôts en https).
construire() { # $1 image  $2 dossier de contexte
  local contexte="$2" options=()
  if [ -n "${TPTEST_CA:-}" ]; then
    : "${HTTPS_PROXY:?TPTEST_CA demande aussi HTTPS_PROXY}"
    contexte="$travail/contexte-$1"
    cp -r "$2" "$contexte"
    local ajout="RUN sed -i 's,http://deb.debian.org,https://deb.debian.org,g' /etc/apt/sources.list.d/debian.sources"
    ajout+=" && printf 'Acquire::https::Proxy \"%s\";\\n' \"\$HTTPS_PROXY\" > /etc/apt/apt.conf.d/90tptest-mandataire"
    cp "$TPTEST_CA" "$contexte/tptest-ca.crt"
    ajout="COPY tptest-ca.crt /usr/local/share/tptest-ca.crt"$'\n'"$ajout"
    ajout+=" && echo 'Acquire::https::CAInfo \"/usr/local/share/tptest-ca.crt\";' >> /etc/apt/apt.conf.d/90tptest-mandataire"
    AJOUT="$ajout" awk '{ print } /^FROM / && !fait { fait = 1; print ENVIRON["AJOUT"] }' "$2/Dockerfile" > "$contexte/Dockerfile"
    options=(--network host --build-arg "HTTPS_PROXY=$HTTPS_PROXY")
    echo "Mandataire HTTPS $HTTPS_PROXY : la construction passe par lui, avec l'autorité $TPTEST_CA."
  fi
  docker image build -q "${options[@]}" -t "$1" "$contexte" > /dev/null
}

titre "Image $image (debian:13-slim)"
mkdir -p "$travail/image"
cat > "$travail/image/Dockerfile" << 'FIN'
FROM debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends tmux procps vim-tiny \
 && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash ada
ENV LANG=C.UTF-8 TERM=xterm
FIN
if construire "$image" "$travail/image"; then ok "image $image construite"
else ko "construction de l'image $image (accès à deb.debian.org ?)"; bilan; fi

docker container run -d --init --name "$conteneur" --hostname poste "$image" sleep infinity > /dev/null
docker container cp "$ici/." "$conteneur:/tp" > /dev/null
docker container exec "$conteneur" chmod -R a+rX /tp
# Chaque ligne OK / ÉCHEC du conteneur compte dans le bilan.
while IFS= read -r ligne; do
  case "$ligne" in
    "OK     "*) ok "${ligne#OK     }" ;;
    "ÉCHEC  "*) ko "${ligne#ÉCHEC  }" ;;
    "======== Bilan"*) ;;
    "  - "*) ;;
    *) printf '%s\n' "$ligne" ;;
  esac
done < <(docker container exec -u ada -w /home/ada "$conteneur" bash /tp/tester.sh --dedans 2>&1 || true)
[ "$reussis" -gt 1 ] || ko "les vérifications du conteneur n'ont rien produit"
bilan
