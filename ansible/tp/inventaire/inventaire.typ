// TP « Ansible, séance 1 : inventaire et commandes ad hoc » — page web compilée par Typst
// (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     ansible/tp/inventaire/inventaire.typ build/ansible/tp-inventaire.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/ansible-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Ansible, séance 1 : inventaire et commandes ad hoc],
  surtitre: [Ansible : automatiser les configurations · travaux pratiques],
  sous-titre: [Un labo de trois conteneurs, SSH câblé à la main, un inventaire, puis les premiers modules],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "vm",
  terminal: ("host-shell-access",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/ansible/tp/inventaire/corrige"),
    ([Séance 2 : playbooks], "../playbooks/index.html"),
    ([Documentation d’Ansible], "https://docs.ansible.com/"),
  ),
)

= Avant de commencer <avant>

Le TP Ansible compte trois séances, qui partagent le même labo : cette première séance monte le labo, câble SSH
et décrit les machines (inventaire) ; la deuxième écrit des playbooks ; la troisième les range dans un rôle.
Chaque séance reprend le dossier de travail de la précédente.

#bloc(role: "pratique")[Prérequis][
  - Une machine Linux avec Docker et Compose v2, et votre compte dans le groupe `docker` :
    #link("../../../conteneurisation/cm/conteneurisation-projection.pdf")[cours Conteneurisation].
    Le labo télécharge des images Debian 13 et des paquets : il a besoin du réseau à sa première construction.
  - `git`, pour récupérer le labo.
  - Les notions de la première moitié du cours : le modèle (#d("modele-ansible")[Un nœud de contrôle, des nœuds
    gérés, aucun agent]) et l’inventaire (#d("inventaire")[L’inventaire : les machines et leurs groupes]).
]

#bloc(role: "precaution")[La documentation d’abord][
  Pour tout ce qui concerne Ansible, cherchez l’information à la source : #link("https://docs.ansible.com/")[docs.ansible.com].
  Savoir naviguer dans la documentation d’un outil est une compétence professionnelle. `ansible-doc <module>`
  documente un module sans quitter le terminal. Les corrigés servent à vérifier votre travail, pas à le remplacer.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification : le labo est construit, SSH câblé par `cabler-ssh.sh`, puis chaque
  commande de l’énoncé est jouée. Les sorties montrées viennent d’ansible-core 2.19.4 sur des nœuds Debian 13.
  Vos numéros de version et vos dates peuvent différer.
]

#schema([Le labo : un nœud de contrôle et deux nœuds gérés, sur un réseau Docker dont le DNS résout leurs noms. Le dossier de travail de l’hôte est monté dans `/etc/ansible`.], ch => {
  let c = ch.c
  let noeud(nom, couleur, ..cases) = boite(nom, trait: couleur, largeur: 190pt, stack(spacing: 5pt, ..cases))
  grid(columns: (auto, 60pt, auto), align: horizon, column-gutter: 0pt,
    stack(spacing: 8pt,
      noeud([control-node], c.bleu, case(fond: c.appli, largeur: 150pt)[ansible-core, ansible-lint], case(largeur: 150pt)[client SSH, git, vim]),
      boite([dossier de l’hôte], fond: ch.roles.retenir.fond, largeur: 190pt, text(size: 9pt)[`$ANSIBLE_PROJET` ↔ `/etc/ansible`]),
    ),
    align(center, text(size: 9pt, fill: c.gris)[SSH · port 22 \ #sym.arrow.r]),
    stack(spacing: 8pt,
      noeud([managed-node-1], c.distant, case(largeur: 150pt)[sshd, python3]),
      noeud([managed-node-2], c.distant, case(largeur: 150pt)[sshd, python3]),
    ),
  )
})

= Étape 1 : monter le labo <etape-1>

#bloc(role: "question")[Consignes][
  - Récupérez le dépôt du cours : le labo est dans `ansible/cm/labo/`, le même que celui des diapos
    (#d("labo")[Le labo du cours : trois conteneurs]).
  - Créez un dossier de travail `~/tp-ansible` et donnez son chemin absolu au labo par la variable
    `ANSIBLE_PROJET` : Compose le monte dans `/etc/ansible` du nœud de contrôle, vos fichiers survivent donc aux
    conteneurs. Gardez la variable pour toute la séance (ouvrez-la dans chaque nouveau terminal).
  - Construisez et démarrez les trois conteneurs.
  - Depuis le nœud de contrôle, essayez de joindre `managed-node-1` par SSH, sans rien demander (option
    `BatchMode=yes`). Que répond SSH, et pourquoi ?
]

#indice(titre: [Indice : Compose])[
  `docker compose up --detach --build` construit les images puis démarre les services ; `docker compose ps` les
  liste. `docker compose exec <service> <commande>` lance une commande dans un conteneur en marche. Toutes ces
  commandes se lancent depuis le dossier du labo, où est `compose.yaml`.
]
#indice(titre: [Indice : l’échec de SSH])[
  Deux choses manquent au nœud de contrôle : il ne connaît pas la clé d’hôte du nœud géré, et il n’a pas de clé
  que le nœud géré accepte. Lequel des deux SSH vérifie-t-il en premier ?
]

#corrige[
  #terminal[```console
  $ cd ~
  $ git clone https://github.com/jmchantrein/Cours.git
  $ cd Cours/ansible/cm/labo
  $ mkdir ~/tp-ansible
  $ export ANSIBLE_PROJET="$HOME/tp-ansible"
  $ docker compose up --detach --build
  $ docker compose ps
  $ docker compose exec control-node ssh -o BatchMode=yes managed-node-1 hostname
  Host key verification failed.
  ```]
  SSH refuse d’abord l’hôte : le fichier `known_hosts` du nœud de contrôle est vide, SSH ne peut pas vérifier
  que `managed-node-1` est bien la machine qu’il croit. Même avec l’empreinte, la connexion échouerait ensuite :
  `Permission denied (publickey)`, parce que le nœud géré ne connaît aucune clé du nœud de contrôle. L’étape 2
  règle les deux.
]

= Étape 2 : câbler SSH <etape-2>

Ansible n’a besoin que de SSH : ce câblage est le seul réglage des nœuds gérés. En production, vous le feriez
avec `ssh-copy-id` ou à l’installation de la machine ; ici, vous l’écrivez en script.

#bloc(role: "question")[Consignes][
  - Écrivez un script `cabler-ssh.sh`, à ranger dans le dossier du labo, à côté de `compose.yaml`, et à lancer
    depuis là, sur l’hôte (`./cabler-ssh.sh`) ; il :
    + génère sur `control-node` une paire de clés ed25519, sans phrase secrète, s’il n’en a pas déjà une ;
    + dépose la clé publique dans le fichier des clés autorisées de `root`, sur chaque nœud géré, avec les
      droits qu’exige `sshd` ;
    + enregistre les empreintes des deux nœuds dans le `known_hosts` du nœud de contrôle ;
    + vérifie en affichant le nom de chaque nœud, obtenu par SSH.
  - Le script doit pouvoir se rejouer : relancez-le deux fois de suite. (Il faudra le relancer après chaque
    `docker compose down`, qui efface les conteneurs.)
]

#note(role: "avertissement")[Le fichier s’appelle `authorized_keys`, ni `autorized_keys` ni `authorised_keys`.
  `sshd` ignore sans rien dire un fichier mal nommé, et la connexion échoue en `Permission denied (publickey)`.
  Vérifiez d’abord ce nom, puis les droits : `700` sur `~/.ssh`, `600` sur le fichier.]

#indice(titre: [Indice : agir sur un conteneur depuis l’hôte])[
  `docker compose exec -T <service> sh -c '…'` lance un script dans le conteneur ; avec `-T`, l’entrée standard
  est celle du script appelant, ce qui permet d’y envoyer la clé (`<<<`). `ssh-keygen -t ed25519 -N "" -f
  ~/.ssh/id_ed25519` crée la paire sans phrase secrète.
]
#indice(titre: [Indice : les empreintes])[
  `ssh-keyscan` interroge un serveur SSH et affiche sa clé d’hôte, dans le format de `known_hosts`. En vrai,
  vous comparez cette empreinte à celle que l’administrateur du nœud vous donne : ici, vous faites confiance au
  réseau du labo.
]

#corrige[
  #f("cabler-ssh.sh")
  #terminal[```console
  $ cd ~/Cours/ansible/cm/labo
  $ cp ../../tp/inventaire/corrige/cabler-ssh.sh .
  $ ./cabler-ssh.sh
  managed-node-1
  managed-node-2
  ```]
  Le script se rejoue : il garde la paire de clés existante, remplace `authorized_keys` et `known_hosts`. Le
  `ssh-keyscan -t ed25519` ne demande que l’empreinte ed25519, celle que SSH préfère.
]

= Étape 3 : la configuration d’Ansible <etape-3>

#bloc(role: "question")[Consignes][
  - Ouvrez un shell dans le nœud de contrôle : `docker compose exec control-node bash`. Vous y restez jusqu’à la
    fin du TP ; son dossier de départ est `/etc/ansible`, votre dossier de travail.
  - Quelle est la version d’Ansible ? Quel fichier de configuration lit-il (ligne `config file`) ?
  - Écrivez le fichier `/etc/ansible/ansible.cfg` : le ou les fichiers d’inventaire se trouvent dans le
    dossier `/etc/ansible/inventory`. Ajoutez le réglage `interpreter_python = auto_silent`, qui évite un
    avertissement à chaque commande : lancez `ansible all -i managed-node-1, -m ansible.builtin.ping` avant et après
    pour le voir (l’inventaire n’existe pas encore : `-i` suivi d’un nom et d’une virgule en donne un d’un seul hôte).
  - Où Ansible cherche-t-il sa configuration, et dans quel ordre ?
]

#indice(titre: [Indice : la documentation])[
  La page #link("https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html")[Ansible Configuration Settings]
  donne l’ordre de recherche des fichiers, et la liste des réglages avec leur clé INI : `inventory` et
  `interpreter_python` sont dans la section `[defaults]`. Le diaporama montre ce fichier :
  #d("labo")[Le labo du cours : trois conteneurs].
]

#corrige[
  #terminal[```console
  $ docker compose exec control-node bash
  # dans control-node : avant ansible.cfg
  $ ansible --version
  ansible [core 2.19.4]
    config file = None
  # … (chemins, version de Python et de Jinja)
  # après ansible.cfg
  $ ansible --version
  ansible [core 2.19.4]
    config file = /etc/ansible/ansible.cfg
  # … (chemins, version de Python et de Jinja)
  ```]
  #f("ansible.cfg", lang: "ini")
  Ordre de recherche : la variable d’environnement `ANSIBLE_CONFIG`, puis `./ansible.cfg` (le dossier courant),
  puis `~/.ansible.cfg`, enfin `/etc/ansible/ansible.cfg` ; le premier trouvé l’emporte, les autres sont
  ignorés. Donner un dossier en inventaire (et non un fichier) permet d’y déposer plusieurs fichiers, tous lus.
  Sans `interpreter_python`, Ansible avertit que le Python découvert sur le nœud pourrait changer si l’on
  installait un autre interpréteur ; la valeur `auto_silent` garde la découverte automatique, sans l’avertissement.
]

= Étape 4 : l’inventaire <etape-4>

#bloc(role: "question")[Consignes][
  - Créez le dossier `inventory/`, et dedans le fichier `hosts.yaml` qui déclare les deux nœuds,
    `managed-node-1` et `managed-node-2`.
  - Ajoutez un groupe `mon_groupe` qui contient les deux nœuds, et un groupe `web_server` qui contient le premier.
  - Affichez l’inventaire résolu avec `ansible-inventory`, sans connexion à personne. Où sont `all` et `ungrouped` ?
  - Joignez tout le monde avec le module `ansible.builtin.ping`, puis le seul groupe `mon_groupe`.
]

#indice(titre: [Indice : le format])[
  Le fichier est en YAML : #d("inventaire")[L’inventaire : les machines et leurs groupes]. Un groupe est une clé
  de premier niveau, sous laquelle `hosts:` liste ses membres ; un hôte peut figurer dans plusieurs groupes. La
  documentation : #link("https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html")[How to build your inventory].
]
#indice(titre: [Indice : la commande ad hoc])[
  `ansible <motif> -m <module>` : le motif désigne les hôtes, et peut être `all`, un hôte ou un groupe :
  #d("ad-hoc")[Commandes ad hoc : un module, une fois].
]

#corrige[
  #f("inventory/hosts.yaml")
  #terminal[```console
  $ mkdir inventory
  # écrivez inventory/hosts.yaml (avec Vim, dans control-node)
  $ ansible-inventory --graph
  @all:
    |--@ungrouped:
    |--@mon_groupe:
    |  |--managed-node-1
    |  |--managed-node-2
    |--@web_server:
    |  |--managed-node-1
  $ ansible all -m ansible.builtin.ping
  managed-node-1 | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3.13"
      },
      "changed": false,
      "ping": "pong"
  }
  # … managed-node-2 : même réponse
  $ ansible mon_groupe -m ansible.builtin.ping
  ```]
  `all` est le groupe de tous les hôtes, `ungrouped` celui des hôtes d’aucun autre groupe : tous deux existent
  toujours, même non déclarés. `ungrouped` est vide ici, puisque chaque nœud est dans `mon_groupe`. Dans le labo,
  le DNS de Docker résout les noms des services ; sur un vrai réseau, la variable `ansible_host` porterait
  l’adresse IP ou le nom DNS complet de l’hôte, son nom d’inventaire restant un alias. Le `ping` d’Ansible n’est
  pas un `ping` ICMP : il prouve que SSH fonctionne et que Python répond sur le nœud.
]

= Étape 5 : les motifs <etape-5>

#bloc(role: "question")[Consignes][
  - Sans rien exécuter sur les nœuds, listez les hôtes que visent chacun de ces motifs, avec l’option
    `--list-hosts` : `web_server`, `all:!web_server`, `mon_groupe:&web_server`, `managed-node-*`, `inconnu`.
  - Avant de lancer chaque commande, écrivez les hôtes que vous attendez. Qu’affiche Ansible pour un groupe
    qui n’existe pas ?
]

#indice(titre: [Indice : les opérateurs])[
  `:` réunit, `:&` garde l’intersection, `:!` exclut : #d("motifs-hotes")[Motifs : des groupes aux hôtes visés].
  Les caractères `!` et `&` ont un sens pour le shell : mettez le motif entre apostrophes. La même syntaxe sert
  pour `hosts:` d’un playbook, à la séance suivante.
]

#corrige[
  #terminal[```console
  $ ansible web_server --list-hosts
    hosts (1):
      managed-node-1
  $ ansible 'all:!web_server' --list-hosts
    hosts (1):
      managed-node-2
  $ ansible 'mon_groupe:&web_server' --list-hosts
    hosts (1):
      managed-node-1
  $ ansible 'managed-node-*' --list-hosts
    hosts (2):
      managed-node-1
      managed-node-2
  $ ansible inconnu --list-hosts
  [WARNING]: Could not match supplied host pattern, ignoring: inconnu
  [WARNING]: No hosts matched, nothing to do
    hosts (0):
  ```]
  `all:!web_server` : tous les hôtes, sauf ceux de `web_server`. `mon_groupe:&web_server` : les hôtes qui sont
  dans les deux groupes. Un nom inconnu ne vise personne, et Ansible ne s’en plaint que par un avertissement :
  une faute de frappe dans un groupe ne fait donc rien, au lieu d’échouer. Surveillez les avertissements.
]

= Étape 6 : les modules, les facts, l’état voulu <etape-6>

#bloc(role: "question")[Consignes][
  - Avec le module `ansible.builtin.setup`, affichez les *facts* de `managed-node-1` : où est la distribution ?
    Réduisez la sortie aux facts dont le nom commence par `ansible_distribution`. Quelle version de Debian
    tourne sur les nœuds ?
  - Affichez le fact `ansible_distribution` en YAML plutôt qu’en JSON.
  - Avec le module `ansible.builtin.file`, créez sur tous les nœuds le dossier `/srv/tp`, de droits `0755`, puis
    relancez la même commande. Comparez les deux réponses : `CHANGED` ou `SUCCESS`, et la valeur de `changed`.
  - Avec la commande ad hoc `ansible all -a "ls -ld /srv/tp"`, affichez les droits du dossier. Pourquoi Ansible
    répond-il `CHANGED` pour une simple lecture ?
]

#indice(titre: [Indice : les facts])[
  `-a` passe les arguments au module : `-a "filter=ansible_distribution*"`. Les facts sont aussi des variables
  `ansible_*` dans les playbooks, à la séance suivante. La documentation :
  #link("https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/setup_module.html")[ansible.builtin.setup].
]
#indice(titre: [Indice : le format de sortie])[
  Le format de la réponse est un réglage de la sortie standard d’Ansible (le *callback* `default`) : cherchez
  `result_format` dans la page
  #link("https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/default_callback.html")[ansible.builtin.default].
  Une variable d’environnement le change pour une seule commande.
]
#indice(titre: [Indice : le module file])[
  `ansible-doc ansible.builtin.file` donne les paramètres `path`, `state` et `mode`. Le module décrit un état
  (« ce dossier existe, avec ces droits ») : #d("ad-hoc")[Commandes ad hoc : un module, une fois].
]

#corrige[
  #terminal[```console
  $ ansible managed-node-1 -m ansible.builtin.setup | head -n 15
  $ ansible managed-node-1 -m ansible.builtin.setup -a "filter=ansible_distribution*"
  managed-node-1 | SUCCESS => {
      "ansible_facts": {
          "ansible_distribution": "Debian",
          "ansible_distribution_file_parsed": true,
          "ansible_distribution_file_path": "/etc/os-release",
          "ansible_distribution_file_variety": "Debian",
          "ansible_distribution_major_version": "13",
          "ansible_distribution_minor_version": "8",
          "ansible_distribution_release": "trixie",
          "ansible_distribution_version": "13.8",
          "discovered_interpreter_python": "/usr/bin/python3.13"
      },
      "changed": false
  }
  $ ANSIBLE_CALLBACK_RESULT_FORMAT=yaml ansible managed-node-1 -m ansible.builtin.setup \
      -a "filter=ansible_distribution"
  managed-node-1 | SUCCESS =>
      ansible_facts:
          ansible_distribution: Debian
          discovered_interpreter_python: /usr/bin/python3.13
      changed: false
  $ ansible all -m ansible.builtin.file -a "path=/srv/tp state=directory mode=0755"
  managed-node-1 | CHANGED => {
      # … "changed": true, "path": "/srv/tp", "state": "directory"
  }
  # … managed-node-2 : de même
  $ ansible all -m ansible.builtin.file -a "path=/srv/tp state=directory mode=0755"
  managed-node-1 | SUCCESS => {
      # … "changed": false
  }
  # … managed-node-2 : de même
  $ ansible all -a "ls -ld /srv/tp"
  managed-node-1 | CHANGED | rc=0 >>
  drwxr-xr-x 2 root root 4096 Nov 25 15:01 /srv/tp
  # … managed-node-2 : de même
  ```]
  Le fact `ansible_distribution` porte le nom de la distribution, `ansible_distribution_release` son nom de code.
  Les `…` marquent des champs omis : `setup` sans filtre répond sur plusieurs centaines de lignes.
  `file` décrit un état : au premier passage le dossier manque, `file` le crée et répond `CHANGED` ; au second il
  existe déjà avec les bons droits, `file` n’y touche pas et répond `SUCCESS`, `"changed": false`. C’est
  l’idempotence, constatée : #d("idempotence")[L’idempotence : état voulu, état constaté]. Sans `-m`, une
  commande ad hoc emploie le module `command`, qui exécute le programme tel quel : il ne sait pas s’il modifie
  le nœud, et répond toujours `CHANGED`, même pour lire. La séance suivante revient sur ce piège.
]

#bloc(role: "retenir")[Ce que cette séance a montré][
  - Ansible n’a besoin que de SSH et de Python sur les nœuds gérés ; le câblage SSH est le seul réglage de ceux-ci.
  - `ansible.cfg` désigne l’inventaire ; le premier fichier de configuration trouvé l’emporte.
  - L’inventaire range les hôtes en groupes ; un motif (`:`, `:&`, `:!`) choisit les hôtes visés, et un nom
    inconnu ne vise personne.
  - Un module décrit un état et répond `CHANGED` ou `SUCCESS` selon qu’il a dû agir ; `command` agit toujours.
  - Suite : la #link("../playbooks/index.html")[séance 2] écrit des playbooks avec ces mêmes nœuds.
]
