// TP « Travailler dans tmux » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     acces-distants/tp/tmux/tmux.typ build/tmux.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/acces-distants-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Travailler dans tmux],
  surtitre: [Accès distants · travaux pratiques],
  sous-titre: [Des sessions, des fenêtres et des panneaux qui survivent à la coupure du terminal],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tunnel",
  terminal: ("vm", "compagnon"),
  depart: (ici: "~"),   // état de départ : la VM l’installe à son démarrage
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/acces-distants/tp/tmux/corrige"),
    ([Manuel de tmux], "https://man.openbsd.org/tmux"),
  ),
)

= Avant de commencer <avant>

Une mise à jour lancée par SSH s’arrête si le terminal se ferme : #d("tmux-probleme")[Une coupure, et le travail est perdu].
tmux garde les terminaux dans un *serveur* qui survit à ses clients : #d("tmux-survie")[tmux : un serveur qui garde les
terminaux]. Dans ce TP vous construisez la session de travail d’un administrateur, puis vous la perdez exprès,
la retrouvez, et vous la faites reconstruire par un script.

#bloc(role: "pratique")[Prérequis][
  - Le paquet `tmux` (version 3.4 ou plus), le shell `bash`, `top` et `vi`. Rien d’autre : le TP n’a besoin ni
    de réseau ni de SSH, il se fait sur votre machine, dans la machine virtuelle du navigateur, ou sur un serveur
    où vous êtes connecté.
  - Un terminal *hors de tmux* pour commencer. Dans tmux, le *préfixe* est `Ctrl+b` : on le presse, on le relâche,
    puis on tape la touche : « préfixe `d` » veut dire `Ctrl+b`, puis `d` :
    #d("tmux-clavier")[Au clavier : le préfixe Ctrl+b].
  - Les touches du préfixe ne se tapent pas dans les blocs de commandes de la page : elles sont écrites dans
    les consignes, vous les tapez dans le terminal.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification, sur Debian 13 (tmux 3.5a) : `tmux.conf` est chargé sans erreur et
  chaque réglage a l’effet annoncé ; les touches de l’énoncé sont envoyées à un vrai client tmux attaché à un
  pseudo-terminal ; la session survit à la mort de ce client ; le script construit les fenêtres et panneaux attendus.
]

#schema([Ce que vous construirez : une session, deux fenêtres, trois panneaux.], ch => {
  let c = ch.c
  let panneau(nom) = case(fond: c.invite-clair, largeur: 100pt, nom)
  boite([serveur tmux (un processus de votre machine)], trait: c.distant, fond: c.distant-clair,
    boite([session `atelier`], trait: c.bleu, grid(columns: 2, column-gutter: 12pt,
      boite([fenêtre `edition`], trait: c.gris, grid(columns: 2, column-gutter: 6pt, panneau[gauche], panneau[droite])),
      boite([fenêtre `surveillance`], trait: c.gris, panneau[`top`]),
    )))
})

= Étape 1 : une session que l’on quitte et retrouve <etape-1>

#bloc(role: "question")[Consignes][
  - Créez une session nommée `atelier`. Dans son shell, placez-vous dans `/tmp`.
  - Détachez-vous de la session *sans l’arrêter*. Que dit tmux ? La session existe-t-elle encore ?
  - Rattachez-vous : dans quel dossier est le shell ?
]

#indice(titre: [Indice : créer, détacher, rattacher])[
  `tmux new -s <nom>` crée la session et s’y attache. Le préfixe `d` détache. `tmux ls` liste les sessions,
  `tmux attach -t <nom>` se rattache : #d("tmux-clavier")[Au clavier : le préfixe Ctrl+b].
]

#corrige[
  #terminal[```console
  $ tmux new -s atelier
  # dans tmux :
  $ cd /tmp
  # préfixe d : le terminal affiche [detached (from session atelier)]
  $ tmux ls
  $ tmux attach -t atelier
  # dans tmux :
  $ pwd
  /tmp
  ```]
  Le shell a gardé son dossier : la session appartient au serveur tmux, pas au terminal qui l’affichait.
  `tmux ls` affiche une ligne `atelier: 1 windows (created …)` ; `(attached)` s’y ajoute quand un client la montre.
]

= Étape 2 : fenêtres et panneaux au clavier <etape-2>

#bloc(role: "question")[Consignes][
  - Dans `atelier`, renommez la première fenêtre en `edition`, puis coupez-la en *deux panneaux côte à côte*.
  - Revenez dans le panneau de gauche, agrandissez-le à tout l’écran, puis rendez-lui sa taille.
  - Ouvrez une seconde fenêtre, nommez-la `surveillance` et lancez-y `top`. Revenez à `edition`.
  - Sans toucher au clavier de tmux, listez les panneaux avec leur fenêtre et leur commande. Quel numéro porte le
    panneau de droite ?
  - Dans `surveillance`, quittez `top` (`q`) : la fenêtre disparaît-elle ? Et si l’on avait créé la fenêtre par
    `tmux new-window -n surveillance top` ?
]

#indice(titre: [Indice : les touches])[
  Préfixe `,` renomme la fenêtre (l’invite contient déjà l’ancien nom : effacez-le avec `Ctrl+u`). Préfixe `%` coupe
  en deux panneaux côte à côte, préfixe `"` l’un sur l’autre. Préfixe `←` change de panneau, préfixe `z` agrandit
  le panneau (et revient), préfixe `c` crée une fenêtre, préfixe `p` revient à la précédente.
]
#indice(titre: [Indice : la liste des panneaux])[
  `tmux list-panes -s -t atelier` liste tous les panneaux d’une session ; `-F` choisit les champs. Le nom du champ
  « commande en cours » est dans `man tmux`, section FORMATS : #d("tmux-commandes")[Construire l’arbre en commandes].
]

#corrige[
  Au clavier : préfixe `,`, `Ctrl+u`, `edition`, `Entrée` ; préfixe `%` ; préfixe `←` ; préfixe `z`, puis
  préfixe `z` ; préfixe `c`, préfixe `,`, `Ctrl+u`, `surveillance`, `Entrée` ; `top`, `Entrée` ; préfixe `p`.
  #terminal[```console
  $ tmux list-panes -s -t atelier -F '#{window_index}.#{pane_index} #{window_name} #{pane_current_command}'
  0.0 edition bash
  0.1 edition bash
  1.0 surveillance top
  ```]
  Tapée dans le panneau de gauche, la commande y affiche `0.0 edition tmux` : `pane_current_command` montre ce qui
  tourne à cet instant, ici `tmux list-panes` lui-même ; tapée hors de tmux, elle affiche `bash`.
  Le panneau de droite est `0.1` : fenêtre 0, panneau 1 (numérotation depuis 0 par défaut). `top` lancé depuis le
  shell : à `q`, le shell reprend la main et la fenêtre reste. Créée par `tmux new-window -n surveillance top`, la
  fenêtre n’a pas de shell : elle se ferme avec `top`, ce que le script de l’étape 5 fait exprès.
]

= Étape 3 : perdre le terminal, garder le travail <etape-3>

#bloc(role: "question")[Consignes][
  - Dans `atelier`, lancez dans une fenêtre `compteur` un travail long qui écrit `étape 1`, `étape 2`… à raison
    d’une ligne par seconde (600 au plus). Sans quitter la fenêtre `edition` : créez la fenêtre sans l’afficher.
  - Tuez brutalement *le client tmux* de votre terminal, comme le ferait la fermeture du terminal.
  - Depuis le shell qui reste : la session existe-t-elle ? Le compteur avance-t-il sans client ? Qui est le parent
    de son processus ?
  - Rattachez-vous. Qu’aurait fait le même travail lancé sans tmux ?
]

#indice(titre: [Indice : créer une fenêtre qui exécute une commande])[
  `tmux new-window -d -n compteur '<commande>'` : `-d` ne change pas la fenêtre affichée. Le client à tuer est
  celui que `tmux display-message -p '#{client_pid}'` désigne ; `kill -KILL` ne laisse aucune chance de se
  détacher proprement.
]
#indice(titre: [Indice : lire sans s’attacher])[
  `tmux capture-pane -p -t atelier:compteur` écrit le contenu du panneau sur la sortie standard :
  #d("tmux-script")[Piloter tmux par script : send-keys, capture-pane]. `ps -o ppid= -p <pid>` donne le parent d’un
  processus ; `#{pane_pid}` est le processus du panneau, `#{pid}` celui du serveur tmux.
]

#corrige[
  #terminal[```console
  # dans la fenêtre edition de tmux
  $ tmux new-window -d -n compteur 'for i in $(seq 1 600); do echo "étape $i"; sleep 1; done'
  $ kill -KILL "$(tmux display-message -p '#{client_pid}')"
  # le terminal est revenu au shell ordinaire : tmux a perdu son client
  $ tmux ls
  $ tmux capture-pane -p -t atelier:compteur | grep -v '^$' | tail -n 1
  étape 14
  # (vos numéros varient)
  $ sleep 3; tmux capture-pane -p -t atelier:compteur | grep -v '^$' | tail -n 1
  étape 17
  $ ps -o ppid= -p "$(tmux display-message -p -t atelier:compteur '#{pane_pid}')"
  $ tmux display-message -p '#{pid}'
  $ tmux attach -t atelier
  ```]
  Le compteur a continué sans client (les numéros dépendent de votre vitesse) : son parent est le *serveur* tmux
  (les deux dernières commandes affichent le même nombre), non le terminal. Sans tmux, la fermeture du terminal
  envoie `SIGHUP` aux processus qui lui sont attachés et le travail s’arrête :
  #d("tmux-probleme")[Une coupure, et le travail est perdu]. Une coupure réseau en SSH produit le même effet.
  Pour s’en servir : sur un serveur, ouvrir tmux *avant* de lancer quoi que ce soit de long.
]

= Étape 4 : `~/.tmux.conf` <etape-4>

#bloc(role: "question")[Consignes][
  - Écrivez `~/.tmux.conf` avec ces réglages : la souris active ; 50 000 lignes d’historique par panneau ;
    le mode copie aux touches de Vim ; fenêtres et panneaux numérotés à partir de 1, les fenêtres renumérotées
    quand l’une se ferme ; préfixe `|` pour couper côte à côte, préfixe `_` pour couper l’un sur l’autre ;
    préfixe `r` pour relire le fichier, avec un message.
  - Fermez tout (`tmux kill-server`), relancez une session : la configuration est-elle lue sans erreur ? Vérifiez
    chaque réglage par une commande, pas à l’œil.
  - Pourquoi `_` plutôt que `-` pour couper l’un sur l’autre ?
]

#indice(titre: [Indice : les mots-clés])[
  `set -g` fixe une option globale (de session), `setw -g` une option de fenêtre ; `bind <touche> <commande>` lie une
  touche du préfixe : #d("tmux-conf")[Configurer tmux : ~/.tmux.conf]. Les noms des options : `mouse`,
  `history-limit`, `mode-keys`, `base-index`, `pane-base-index`, `renumber-windows` (`man tmux`, section OPTIONS).
  Plusieurs commandes sur une ligne se séparent par `\;`.
]
#indice(titre: [Indice : vérifier])[
  `tmux show -g <option>` (ou `show -gw` pour une option de fenêtre) affiche la valeur ; `tmux list-keys -T prefix`
  affiche les touches liées. Un test qui passe doit pouvoir échouer : ajoutez une option qui n’existe pas et voyez
  ce que dit tmux.
]

#corrige[
  #f("tmux.conf")
  #terminal[```console
  $ tmux kill-server
  $ tmux new -d -s essai
  $ tmux show -g base-index
  base-index 1
  $ tmux show -gw mode-keys
  mode-keys vi
  $ tmux list-keys -T prefix | grep -E 'split-window( -[hv])?$'
  $ tmux list-keys -T prefix r
  $ tmux kill-server
  ```]
  Pour voir les erreurs d’un fichier, chargez-le à la main : `tmux source-file ~/.tmux.conf` les affiche.
  Attention : `source-file -n` ne vérifie que la
  *syntaxe* ; il accepte une option inconnue que le chargement refuse. Pour qu’un test soit probant, chargez le
  fichier pour de bon dans un serveur vide : `tmux -f /dev/null start-server \; source-file tmux.conf`.
  `-` est déjà lié par défaut (il supprime le dernier tampon copié), d’où `_`. Dans le mode copie de Vim, `v` ne
  sélectionne pas : il bascule la sélection rectangulaire ; la sélection commence par `Espace`, `Entrée` copie et sort.
  Une fenêtre créée avant le réglage garde son numéro, et `history-limit` ne vaut que pour les fenêtres créées
  ensuite : d’où `kill-server` avant de vérifier.
]

= Étape 5 : un script qui construit la session <etape-5>

#bloc(role: "question")[Consignes][
  - Écrivez `session-atelier.sh [nom]` : la session (`atelier` par défaut) a une fenêtre `edition`, avec l’éditeur
    de `$EDITOR` ouvert sur `notes.txt` à gauche et un shell à droite, et une fenêtre `surveillance` qui exécute `top`.
  - Lancé deux fois, il ne reconstruit rien : il se rattache. Lancé avec le nom `atel`, il crée une *autre* session :
    il ne prend pas `atelier` pour `atel`.
  - Lancé hors d’un terminal (par `cron`, par un autre script), il crée la session sans s’y attacher.
  - Vérifiez par `list-windows` et `list-panes`, sans vous attacher.
]

#indice(titre: [Indice : tester l’existence])[
  `tmux has-session -t <nom>` répond par son code de retour. Attention : `-t atel` accepte un *début* de nom ;
  la forme `-t =atel` exige le nom exact. `new-session -d -P -F '#{pane_id}'` crée sans s’attacher et affiche
  l’identifiant du panneau (`%0`, `%1`…), qui ne dépend d’aucun réglage de numérotation.
]
#indice(titre: [Indice : les panneaux et le terminal])[
  `split-window -h` coupe côte à côte ; `send-keys -t <panneau> 'commande' Enter` tape dans le shell d’un panneau :
  quand on quitte l’éditeur, le shell reste. Une commande donnée à `new-window` remplace le shell. Le test `[ -t 0 ]`
  dit si l’entrée standard est un terminal ; dans tmux (`$TMUX` définie), on change de session par
  `switch-client`, car un `attach` lancé dans un panneau imbriquerait un client tmux dans un autre : tmux le refuse
  tant que `$TMUX` est définie, et, forcé, il enverrait le préfixe au client extérieur.
]

#corrige[
  #f("session-atelier.sh")
  #terminal[```console
  $ chmod +x session-atelier.sh
  # sans terminal : la session est créée, le script s’arrête
  $ ./session-atelier.sh < /dev/null
  $ tmux list-windows -t atelier -F '#{window_index} #{window_name}'
  $ tmux list-panes -s -t atelier -F '#{window_index}.#{pane_index} #{window_name} #{pane_current_command}'
  $ ./session-atelier.sh < /dev/null
  $ tmux list-sessions
  $ ./session-atelier.sh atel < /dev/null
  $ tmux list-sessions -F '#{session_name}'
  $ tmux kill-server
  ```]
  Avec le `tmux.conf` de l’étape 4, les numéros commencent à 1 : `1.1 edition vi`, `1.2 edition bash`,
  `2.1 surveillance top`. L’éditeur est `vi` quand `$EDITOR` est vide. Relancé, le script ne change pas l’arbre ;
  avec `atel`, deux sessions existent : `atel` et `atelier`.
]

= Pour finir <fin>

#corrige(titre: [Corrigé : tout supprimer])[
  #terminal[```console
  $ tmux kill-server
  $ rm -f ~/.tmux.conf notes.txt session-atelier.sh
  ```]
  `kill-server` arrête toutes vos sessions tmux et ce qui y tourne : à ne pas lancer sur un serveur où d’autres
  travaux sont en cours.
]
