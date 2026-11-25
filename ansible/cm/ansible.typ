// Cours « Ansible : automatiser les configurations » — Typst + Touying.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts ansible/cm/ansible.typ build/ansible/ansible.pdf
// Une diapo = un titre `==` ; une section (surtitre bleu) = un titre `=`.
// Structure : règles de .claude/skills/structurer-diapos-cours ; apparence : charte de commun/.
// Sorties rejouées avec ansible-core 2.19.4 et ansible-lint 26.11.0 (pip, Python 3.12), sur un labo
// de trois conteneurs (un nœud de contrôle, deux nœuds gérés Ubuntu 24.04) : voir ansible/cm/rejouer.sh.

#import "../../commun/theme-cours.typ": *

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Ansible : automatiser les configurations],
)

// ---------- Schéma du modèle d’Ansible (remplace AnsibleMap du site) ----------
// Une puce de schéma, dans une machine : fond de la page, texte encre.
#let puce-schema(t, trait: none) = box(fill: if trait == none { c.fond } else { none },
  stroke: trait, radius: px(8), inset: (x: px(12), y: px(6)), text(size: px(22), weight: 600, t))
#let schema-ansible(uncover) = grid(columns: (px(620), 1fr, px(600)), align: horizon, column-gutter: px(16),
  machine([Nœud de contrôle · control-node], distant: false, taille: px(24),
    puce-schema[ansible-core], puce-schema[ansible.cfg], puce-schema[inventaire],
    puce-schema[playbooks, rôles], puce-schema[clé SSH privée]),
  uncover("2-", stack(spacing: px(120),
    ..range(2).map(_ => fleche(haut: [SSH, port 22], taille: px(22))))),
  uncover("2-", stack(spacing: px(24),
    ..(1, 2).map(i => machine([Nœud géré · managed-node-#i], taille: px(24),
      puce-schema[sshd], puce-schema[python3],
      puce-schema(trait: (paint: c.gris, thickness: px(2), dash: "dashed"))[aucun agent])))),
)

#couverture(illustration: "noeuds")[Ansible][Automatiser les configurations][Jean-Mathieu Chantrein][25 novembre 2026]
#speaker-note[Cours compagnon des cours Virtualisation et Conteneurisation : ils fournissent les machines ; celui-ci les configure. Versions employées pour toutes les sorties : ansible-core 2.19.4 et ansible-lint 26.11.0 (installés par pip, Python 3.12), nœuds gérés Ubuntu 24.04 dans des conteneurs Docker. Le labo du TP repose sur Debian : les sorties qui dépendent de la distribution sont signalées « à rejouer ». Script de rejeu : ansible/cm/rejouer.sh.]

// ======================================================================
= Sommaire

== Plan du cours

#anime(plan-anime(
  ([Introduction], [Configurer N machines à la main ; décrire un état plutôt que des actions]),
  ([Le modèle d’Ansible], [Nœud de contrôle, nœuds gérés, SSH sans agent ; le labo ; inventaire et motifs]),
  ([Agir], [Commandes ad hoc, modules, facts, playbooks ; l’idempotence : changed ou ok]),
  ([Structurer], [Variables et précédence, gabarits Jinja2, handlers, rôles, bonnes pratiques]),
))

// ======================================================================
= Introduction

== Configurer N machines à la main : la boucle ssh dérive <probleme>
#let _note = [Sortie réelle dans le labo du cours : managed-node-3 n’existe pas, comme une machine éteinte ou renommée pendant la boucle. La boucle est lancée deux fois, comme après une interruption : le fichier de managed-node-1 contient alors deux lignes. Le script énumère des actions ; il ne vérifie ni ce qui est déjà fait ni ce qui a échoué. Trois symptômes à faire dire : une machine oubliée en silence (la boucle continue), une action répétée (>> ajoute), et plus personne ne sait dire dans quel état est chaque machine.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Terminal · une boucle, lancée deux fois][
      #terminal(titre: none, taille: px(21))[
        ```
        # sur trois machines : ajouter un message d’accueil
        $ for h in managed-node-1 managed-node-2 managed-node-3; do
            ssh "$h" "echo Bienvenue >> /etc/motd"
          done
        ssh: Could not resolve hostname managed-node-3: Name or service not known
        # … même boucle, relancée
        ssh: Could not resolve hostname managed-node-3: Name or service not known
        $ ssh managed-node-1 grep -c Bienvenue /etc/motd
        2
        ```
      ]
    ],
    bloc(role: "avertissement")[Ce que la boucle ne sait pas][
      - Une machine éteinte : la boucle passe à la suivante
      - Relancée, l’action se répète : deux lignes au lieu d’une
      - L’état réel de chaque machine : personne ne le connaît
    ],
  ),
  note: _note,
)

== Décrire un état, pas des actions <etat-voulu>
#let _note = [Le renversement de la gestion de configuration : on écrit l’état voulu, l’outil constate l’état réel et ne fait que l’écart. Lien avec le cours Conteneurisation, sans le redire : la diapositive « Un orchestrateur maintient l’état désiré du cluster » emploie la même idée (état désiré \= état voulu). Différence à faire dire : un orchestrateur (Swarm, Kubernetes) ou un agent GitOps (Argo CD, Flux) tourne en permanence et tire l’état voulu ; Ansible agit quand on le lance, et pousse depuis le nœud de contrôle. Puppet et Chef installent par défaut un agent sur chaque machine (Puppet Bolt et chef-solo font exception) ; Salt aussi (salt-minion), avec un mode salt-ssh. IaC et IaaS : deux sigles voisins, sans rapport ; l’IaaS est une offre de cloud. Ansible est un projet Red Hat (racheté en 2015), sous licence GPLv3.]
#anime(
  rang(
    bloc[Gestion de configuration][
      - On décrit l’*état voulu* : « nginx est installé, configuré ainsi, démarré »
      - L’outil constate l’*état réel* de chaque machine et ne fait que l’écart
      - Écrit dans des fichiers : relus, versionnés dans Git, rejoués : l’*IaC* (_infrastructure as code_)
    ],
    bloc(role: "precaution")[À ne pas confondre][
      - *IaC* : une pratique, l’infrastructure décrite par du code
      - *IaaS* (_infrastructure as a service_) : une offre de cloud, des machines louées
    ],
  ),
  rang(bloc(role: "retenir")[Déjà vu en Conteneurisation][
    L’« état désiré » d’un orchestrateur : même idée. L’orchestrateur et les agents GitOps (Argo CD, Flux) réconcilient en permanence ; *Ansible* agit quand on le lance, depuis une machine, *sans agent* sur les autres.
  ]),
  source-de: [#link("https://docs.ansible.com/ansible/latest/getting_started/introduction.html")[docs.ansible.com, Introduction to Ansible] · #link("https://jmchantrein.github.io/Cours/conteneurisation/cm/conteneurisation-projection.pdf")[cours Conteneurisation, « Un orchestrateur maintient l’état désiré »]],
  note: _note,
)

// ======================================================================
= Le modèle d’Ansible

== Un nœud de contrôle, des nœuds gérés, aucun agent <modele-ansible>
#let _note = [Clic 1 : le nœud de contrôle (control node), la seule machine où Ansible est installé ; elle porte la configuration, l’inventaire, les playbooks et la clé SSH. Clic 2 : les nœuds gérés (managed nodes), deux comme dans le labo du TP ; ils n’ont qu’un serveur SSH et Python 3. Clic 3 et suivants : les conséquences. La documentation précise que le nœud de contrôle doit être un système de type Unix (Linux, macOS, WSL sous Windows). Pour les nœuds Windows, Ansible passe par WinRM ou SSH et des modules PowerShell ; pour les équipements réseau, par des connexions dédiées (network\_cli). Le module raw fonctionne sans Python : il sert à installer Python.]
#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  schema-ansible(uncover)
  v(px(32))
  let b1 = bloc(taille: px(25))[Ce que cela change][
    - Rien à installer ni à mettre à jour sur les nœuds gérés
    - La sécurité est celle de SSH : clés, comptes, pare-feu
    - Ansible agit quand on le lance : rien ne tourne entre deux passages
  ]
  let b2 = bloc(role: "precaution", taille: px(25))[Sans agent, mais pas sans rien][
    - Python 3 sur le nœud géré (sauf le module `raw`)
  ]
  rangee(poids: (1.6, 1),
    h => bloc-anime(b1, 3, uncover, hauteur: h),
    h => bloc-anime(b2, 5, uncover, hauteur: h))
  source[#link("https://docs.ansible.com/ansible/latest/getting_started/index.html")[docs.ansible.com, Getting started] · #link("https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html")[Installation guide]]
  utils.speaker-note(self: self, _note)
})

== Une tâche : un module copié, exécuté, effacé <sans-agent>
#let _note = [Sortie réelle de -vvv (ansible-core 2.19.4), très abrégée : les options de ssh (ControlMaster, ControlPersist, ConnectTimeout…) et les guillemets imbriqués sont retirés, l’identifiant du répertoire temporaire est tronqué (ansible-tmp-1795600592.2088647-901-…). AnsiballZ : le module Python et ses dépendances, empaquetés en un seul fichier. Le module renvoie du JSON sur sa sortie standard ; c’est ce JSON qu’affiche la commande ad hoc. ANSIBLE\_KEEP\_REMOTE\_FILES\=1 garde le fichier sur le nœud, pour le déboguer. Le « pipelining » (option de ansible.cfg) évite l’écriture du fichier en passant le module par l’entrée standard de python.]
#anime(
  rang(bloc(role: "pratique")[Terminal · nœud de contrôle][
    #terminal(titre: none, taille: px(19))[
      ```
      $ ansible managed-node-1 -m ansible.builtin.ping -vvv
      # … extrait : options de ssh et guillemets retirés, identifiants tronqués
      # 1. un répertoire temporaire sur le nœud
      <managed-node-1> SSH: EXEC ssh -C managed-node-1 '… mkdir … /root/.ansible/tmp/ansible-tmp-… '
      # 2. le module, copié par sftp
      <managed-node-1> PUT …/tmp4ls7woby TO /root/.ansible/tmp/ansible-tmp-…/AnsiballZ_ping.py
      # 3. exécuté par le Python du nœud
      <managed-node-1> SSH: EXEC ssh -C -tt managed-node-1 '… /usr/bin/python3.12 …/AnsiballZ_ping.py …'
      # 4. puis effacé
      <managed-node-1> SSH: EXEC ssh -C managed-node-1 '… rm -f -r /root/.ansible/tmp/ansible-tmp-…/ …'
      ```
    ]
  ]),
  rang(bloc(role: "retenir", taille: px(26))[À retenir][
    Chaque tâche ouvre des connexions SSH, dépose un petit programme Python (le *module*), l’exécute, lit sa réponse en JSON, puis l’efface : rien ne reste installé.
  ]),
  source-de: [#link("https://docs.ansible.com/ansible/latest/dev_guide/developing_program_flow_modules.html")[docs.ansible.com, Ansible module architecture]],
  note: _note,
)

== Le labo du cours : trois conteneurs <labo>
#let _note = [Le même labo que le TP : un conteneur control-node, deux conteneurs managed-node-1 et managed-node-2, sur un réseau Docker dont le DNS résout les noms des services. Ici les images sont Ubuntu 24.04 (le TP emploie Debian) ; ansible-core 2.19.4 est installé par pip dans un environnement virtuel. Câblage SSH, fait par le script du labo : paire de clés ed25519 sur le nœud de contrôle, clé publique dans /root/.ssh/authorized\_keys de chaque nœud, empreintes des nœuds dans known\_hosts (en vrai : les vérifier). interpreter\_python \= auto\_silent : sans cette ligne, chaque commande avertit qu’Ansible a découvert l’interpréteur /usr/bin/python3.12. Ordre de recherche de la configuration : variable ANSIBLE\_CONFIG, ./ansible.cfg, \~/.ansible.cfg, /etc/ansible/ansible.cfg ; le premier trouvé l’emporte, les autres sont ignorés.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[`/etc/ansible/ansible.cfg`][
      #terminal(titre: none, taille: px(21))[
        ```
        [defaults]
        inventory = /etc/ansible/inventory
        interpreter_python = auto_silent
        ```
      ]
      - `inventory` : un répertoire, dont chaque fichier est lu
      - `interpreter_python` : Python du nœud, trouvé sans avertissement
    ],
    bloc(role: "pratique", poids: 1.3)[Terminal · control-node][
      #terminal(titre: none, taille: px(21))[
        ```
        $ cd /etc/ansible
        $ ansible --version
        ansible [core 2.19.4]
          config file = /etc/ansible/ansible.cfg
        # … (chemins, version de Python et de Jinja)
        # SSH : la clé publique est sur les nœuds
        $ ssh managed-node-1 hostname
        managed-node-1
        ```
      ]
    ],
  ),
  rang(bloc(taille: px(25))[Prérequis][
    - Nœud de contrôle : `ansible-core`, un client SSH, une paire de clés ; nœuds gérés : `sshd`, `python3` (`python3-apt` pour le module `apt`)
  ]),
  source-de: [#link("https://docs.ansible.com/ansible/latest/reference_appendices/config.html")[docs.ansible.com, Ansible Configuration Settings]],
  note: _note,
)

== L’inventaire : les machines et leurs groupes <inventaire>
#let _note = [Fichier du TP, au format YAML (le format INI existe aussi). Un hôte peut appartenir à plusieurs groupes : managed-node-1 est dans all, mon\_groupe et web\_server. all et ungrouped existent toujours, même non déclarés ; ungrouped ne contient que les hôtes d’aucun autre groupe : ici il est vide, puisque chaque hôte est aussi dans mon\_groupe. Dans le labo, les noms se résolvent par le DNS de Docker ; sur un vrai réseau, la variable ansible\_host porte l’adresse IP ou le nom DNS complet (FQDN) de l’hôte, son nom d’inventaire restant un alias. ansible-inventory lit l’inventaire sans se connecter à personne.]
#anime(
  rang(
    bloc(role: "pratique")[`inventory/hosts.yaml`][
      #terminal(titre: none, taille: px(21))[
        ```
        all:
          hosts:
            managed-node-1:
            managed-node-2:

        mon_groupe:
          hosts:
            managed-node-1:
            managed-node-2:

        web_server:
          hosts:
            managed-node-1:
        ```
      ]
    ],
    bloc(role: "pratique")[Terminal · l’inventaire résolu][
      #terminal(titre: none, taille: px(21))[
        ```
        $ ansible-inventory --graph
        @all:
          |--@ungrouped:
          |--@mon_groupe:
          |  |--managed-node-1
          |  |--managed-node-2
          |--@web_server:
          |  |--managed-node-1
        ```
      ]
      - Un *groupe* : un ensemble d’hôtes, la cible d’une commande
      - `all` et `ungrouped` : toujours là, même non déclarés
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html")[docs.ansible.com, How to build your inventory]],
  note: _note,
)

== Motifs : des groupes aux hôtes visés <motifs-hotes>
#let _note = [Modèle de résolution, d’après la page « Patterns » : un motif (pattern) désigne des hôtes de l’inventaire. Éléments : all ou \*, un hôte, un groupe, un joker (managed-node-\*). Opérateurs : « : » ou « , » réunit, « :& » garde l’intersection, « :! » exclut. Ordre de traitement, quel que soit l’ordre d’écriture : d’abord les unions, puis les intersections, puis les exclusions. Un hôte ou un groupe absent de l’inventaire ne correspond à rien : avertissement « Could not match supplied host pattern », et aucun hôte. --list-hosts n’exécute rien : il affiche la liste des hôtes visés. Entre apostrophes : le shell interpréterait « ! » et « & ». Même syntaxe dans hosts: d’un playbook et dans l’option --limit (-l). Sorties réelles, inventaire de la diapositive précédente.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.25)[Terminal · `--list-hosts` n’exécute rien][
      #terminal(titre: none, taille: px(19))[
        ```
        $ ansible web_server --list-hosts
          hosts (1):
            managed-node-1
        $ ansible 'all:!web_server' --list-hosts
          hosts (1):
            managed-node-2
        $ ansible 'mon_groupe:&web_server' --list-hosts
          hosts (1):
            managed-node-1
        $ ansible inconnu --list-hosts
        [WARNING]: Could not match supplied host pattern, ignoring: inconnu
        [WARNING]: No hosts matched, nothing to do
          hosts (0):
        ```
      ]
    ],
    bloc(taille: px(25))[Lire un motif][
      - `all` ou `*` : tous les hôtes ; un nom : un hôte ou un groupe
      - `a:b` : union ; `a:&b` : intersection ; `a:!b` : exclusion
      - Traités dans cet ordre : unions, puis intersections, puis exclusions
      - Un nom inconnu : aucun hôte, un simple avertissement
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html")[docs.ansible.com, Patterns: targeting hosts and groups]],
  note: _note,
)

== À vous : quels hôtes ?
#let _note = [Inventaire d’exercice (exercice/parc.yaml), lu sans connexion : les hôtes web1, web2, bdd1, bastion n’existent pas, --list-hosts n’en a pas besoin. prod a deux groupes enfants, web et bdd ; web2 et bdd1 sont aussi dans nouveaux ; bastion n’est dans aucun groupe. Laisser chercher, puis corrigé à la diapositive suivante.]
#anime(
  rang(
    bloc(role: "pratique")[Terminal · un parc fictif][
      #terminal(titre: none, taille: px(21))[
        ```
        $ ansible-inventory -i parc.yaml --graph
        @all:
          |--@ungrouped:
          |  |--bastion
          |--@prod:
          |  |--@web:
          |  |  |--web1
          |  |  |--web2
          |  |--@bdd:
          |  |  |--bdd1
          |--@nouveaux:
          |  |--web2
          |  |--bdd1
        ```
      ]
    ],
    bloc(role: "question")[À vous][
      Quels hôtes vise chaque motif ?
      + `ungrouped`
      + `'prod:!bdd'`
      + `'web:&nouveaux'`
      + `'nouveaux:!web:&prod'`
    ],
  ),
  note: _note,
)

== Quels hôtes : corrigé
#let _note = [Sorties réelles de ansible -i parc.yaml « motif » --list-hosts (ansible-core 2.19.4), présentées sur une ligne. Question 4 : l’ordre d’écriture ne compte pas ; nouveaux:!web:&prod se lit (nouveaux) ∩ prod, privé de web.]
#corriges(note: _note,
  (1, [`ungrouped`], reponse[`bastion` : le seul hôte d’aucun groupe.]),
  (2, [`'prod:!bdd'`], reponse[`web1`, `web2` : les hôtes de prod (par ses enfants), sauf ceux de bdd.]),
  (3, [`'web:&nouveaux'`], reponse[`web2` : le seul dans les deux groupes.]),
  (4, [`'nouveaux:!web:&prod'`], reponse[`bdd1` : unions, puis intersection (nouveaux et prod : `web2`, `bdd1`), puis exclusion de web.]),
)

// ======================================================================
= Agir

== Commandes ad hoc : un module, une fois <ad-hoc>
#let _note = [Une commande ad hoc lance un seul module sur les hôtes d’un motif, sans playbook : ansible « motif » -m « module » -a « arguments ». Sortie 1 : SUCCESS, la réponse JSON du module ; "changed": false, ping ne modifie rien ; ansible\_facts.discovered\_interpreter\_python : le Python trouvé sur le nœud (managed-node-2 répond de même). Sortie 2 : setup collecte les facts, la « carte d’identité » du nœud ; sans filtre, 799 lignes ici. Les facts sont aussi collectés au début de chaque play (tâche « Gathering Facts »), et deviennent des variables ansible\_\*. Nœuds Ubuntu 24.04 dans le labo du cours : sur le labo Debian du TP, ansible\_distribution vaut "Debian" (à rejouer). ansible-core contient 71 modules ansible.builtin (ansible-doc -l) ; le paquet « ansible » ajoute des collections, avec des milliers de modules. ansible-doc ansible.builtin.apt affiche la documentation d’un module.]
#anime(
  rang(
    bloc(role: "pratique")[Terminal · le nœud répond-il ?][
      #terminal(titre: none, taille: px(19))[
        ```
        $ ansible all -m ansible.builtin.ping
        managed-node-1 | SUCCESS => {
            "ansible_facts": {
                "discovered_interpreter_python": "/usr/bin/python3.12"
            },
            "changed": false,
            "ping": "pong"
        }
        # … managed-node-2 : même réponse
        ```
      ]
    ],
    bloc(role: "pratique")[Terminal · les facts d’un nœud][
      #terminal(titre: none, taille: px(19))[
        ```
        $ ansible managed-node-1 -m ansible.builtin.setup \
            -a "filter=ansible_distribution*"
        managed-node-1 | SUCCESS => {
            "ansible_facts": {
                "ansible_distribution": "Ubuntu",
        # … (fichier lu, famille)
                "ansible_distribution_release": "noble",
                "ansible_distribution_version": "24.04",
        # …
            "changed": false
        }
        ```
      ]
    ],
  ),
  rang(bloc(taille: px(25))[Vocabulaire][
    - *Module* : l’unité d’action, nommée par son nom complet (FQCN) : `ansible.builtin.apt`, `copy`, `service`, `template`… ; `ansible-doc <module>` le documente
    - *Facts* : ce qu’Ansible relève sur un nœud (distribution, adresses, mémoire), disponible en variables `ansible_*`
  ]),
  source-de: [#link("https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html")[docs.ansible.com, Introduction to ad hoc commands] · #link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html")[ansible.builtin]],
  note: _note,
)

== Le playbook : un play, des tâches <playbook>
#let _note = [Un playbook est une liste de plays (d’où le tiret) ; un play associe un motif d’hôtes (hosts) à une liste de tâches ; une tâche appelle un module avec ses paramètres, et porte un nom (name), affiché pendant l’exécution. Les tâches s’exécutent dans l’ordre, chacune sur tous les hôtes (en parallèle, 5 hôtes à la fois par défaut : réglage forks), avant la suivante. Lecture de la sortie : TASK \[Gathering Facts\] collecte les facts ; ok : rien à changer ; PLAY RECAP : un bilan par hôte. Les lignes d’astérisques sont raccourcies, et les colonnes skipped, rescued, ignored (toutes à 0) retirées du bilan, ici comme dans la suite du cours. welcome\_msg est déclarée dans les fichiers de variables : diapositive « Où déclarer une variable ». Accolades doubles : une expression Jinja2 ; une valeur qui commence par des accolades doit être entre guillemets en YAML.]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.9)[`hello_world.yml`][
      #terminal(titre: none, taille: px(19))[
        ```
        ---
        - name: Hello world
          hosts: all
          tasks:
            - name: Pinguer les nœuds gérés
              ansible.builtin.ping:

            - name: Afficher le message d’accueil
              ansible.builtin.debug:
                msg: "{{ welcome_msg }}"
        ```
      ]
      - `hosts` : un motif ; `tasks` : dans l’ordre
      - Une tâche : un `name`, un module, ses paramètres
    ],
    bloc(role: "pratique", poids: 1.1)[Terminal][
      #terminal(titre: none, taille: px(18))[
        ```
        $ ansible-playbook hello_world.yml
        PLAY [Hello world] ***
        TASK [Gathering Facts] ***
        ok: [managed-node-2]
        ok: [managed-node-1]
        TASK [Pinguer les nœuds gérés] ***
        ok: [managed-node-2]
        ok: [managed-node-1]
        TASK [Afficher le message d’accueil] ***
        ok: [managed-node-1] => {
            "msg": "Bonjour le monde from host_vars"
        }
        ok: [managed-node-2] => {
            "msg": "Bonjour le monde from group_vars"
        }
        PLAY RECAP ***
        managed-node-1 : ok=3 changed=0 unreachable=0 failed=0 …
        managed-node-2 : ok=3 changed=0 unreachable=0 failed=0 …
        ```
      ]
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html")[docs.ansible.com, Ansible playbooks]],
  note: _note,
)

== L’idempotence : état voulu, état constaté <idempotence>
#let _note = [Modèle énoncé ici, et repris par l’artefact « idempotence » : pour chaque tâche et chaque hôte, le module lit l’état constaté, le compare à l’état voulu (ses paramètres), agit seulement en cas d’écart, et le dit : changed s’il a modifié le nœud, ok sinon. Un module idempotent rejoué ne trouve plus d’écart : ok. Les modules qui exécutent une commande (command, shell, raw, script) ne savent pas lire l’état : ils agissent toujours et répondent changed. Statuts du bilan : ok, changed (compté aussi dans ok), unreachable (pas de connexion), failed (erreur), skipped (tâche sautée par une condition when, ou en mode --check pour un module qui ne le prend pas en charge). Définition mathématique : f(f(x)) \= f(x).]
#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  let etape-cycle(n, t, d) = uncover(str(d) + "-", block(width: 100%, fill: roles.notion.fond, radius: px(12),
    inset: (x: px(18), y: px(14)), text(size: px(25))[#text(weight: 600, fill: c.bleu)[#n.] #t]))
  grid(columns: (1fr, 1fr), column-gutter: px(40),
    stack(spacing: px(14),
      etape-cycle(1, [*État voulu* : les paramètres de la tâche (`name: htop`, `state: present`)], 1),
      etape-cycle(2, [*État constaté* : le module lit le nœud (htop est-il installé ?)], 2),
      etape-cycle(3, [*Écart ?* Oui : il agit et répond *changed*. Non : il ne touche à rien et répond *ok*], 3),
    ),
    stack(spacing: px(20),
      bloc-anime(bloc(taille: px(26))[Idempotence][
        - Rejouer ne change plus rien après la première fois : $f(f(x)) = f(x)$
        - Un playbook idempotent se relance sans risque : après une panne, une modification, chaque nuit
      ], 4, uncover),
      bloc-anime(bloc(role: "retenir", taille: px(26))[À retenir][
        Le second passage d’un playbook correct affiche `changed=0` ; un `changed` signale une dérive du nœud, ou une tâche qui n’est pas idempotente.
      ], 6, uncover),
    ),
  )
  source[#link("https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html")[docs.ansible.com, Glossary (Idempotency)]]
  utils.speaker-note(self: self, _note)
})

== apt : changed, puis ok <idempotence-apt>
#let _note = [Sorties réelles, nœuds neufs. Premier passage : les paquets manquent, apt les installe, changed. Second passage : apt constate qu’ils sont présents et ne fait rien, ok, changed\=0. state: present décrit un état ; state: latest décrirait « la dernière version » : le résultat dépendrait alors du jour de l’exécution (diapositive « Bonnes pratiques »). Les nœuds du labo gardent les listes de paquets de leur image : la tâche n’a pas besoin de update\_cache, qui rafraîchit les listes (l’option update\_cache de apt avec cache\_valid\_time évite de le faire à chaque passage).]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.85)[`install-common-software.yaml`][
      #terminal(titre: none, taille: px(19))[
        ```
        ---
        - name: Installer les logiciels communs
          hosts: all
          tasks:
            - name: Installer la liste de paquets communs
              ansible.builtin.apt:
                name:
                  - htop
                  - ncdu
                  - vim
                state: present
        ```
      ]
    ],
    bloc(role: "pratique", poids: 1.15)[Terminal · deux passages][
      #terminal(titre: none, taille: px(18))[
        ```
        $ ansible-playbook install-common-software.yaml
        # … (Gathering Facts : ok)
        TASK [Installer la liste de paquets communs] ***
        changed: [managed-node-1]
        changed: [managed-node-2]
        PLAY RECAP ***
        managed-node-1 : ok=2 changed=1 unreachable=0 failed=0 …
        managed-node-2 : ok=2 changed=1 unreachable=0 failed=0 …
        $ ansible-playbook install-common-software.yaml
        # …
        TASK [Installer la liste de paquets communs] ***
        ok: [managed-node-1]
        ok: [managed-node-2]
        PLAY RECAP ***
        managed-node-1 : ok=2 changed=0 unreachable=0 failed=0 …
        managed-node-2 : ok=2 changed=0 unreachable=0 failed=0 …
        ```
      ]
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html")[docs.ansible.com, ansible.builtin.apt]],
  note: _note,
)

== shell et command : changed à chaque passage <shell-command>
#let _note = [Sorties réelles, deux passages sur managed-node-1 (-l limite le play à un motif). Le module shell exécute sa commande à chaque passage et répond toujours changed : il ne sait pas ce qu’elle fait. Avec >>, le résultat lui-même diverge : une ligne de plus par passage. Même avec >, la date de modification change à chaque fois. lineinfile, lui, décrit un état (« cette ligne est présente ») : changed au premier passage, ok au second. Le module command ne passe pas par un shell : ni redirection, ni tube, ni variable d’environnement ; pour écrire un fichier, il faudrait un détour (le TP le montre), signe que ce n’est pas le bon module. La commande ad hoc de la fin passe par command, le module par défaut d’ansible, d’où CHANGED pour une simple lecture.]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.9)[`write_hello_world_naif.yaml`][
      #terminal(titre: none, taille: px(19))[
        ```
        ---
        - name: Écrire hello world (version naïve)
          hosts: all
          tasks:
            - name: Écrire /hello avec le module shell
              ansible.builtin.shell: echo hello >> /hello

            - name: Écrire /hello_world avec lineinfile
              ansible.builtin.lineinfile:
                path: /hello_world
                line: "Hello world !"
                create: true
                mode: "0644"
        ```
      ]
      - `shell` ne lit pas l’état : *changed* à chaque passage
      - Avec `>>`, le fichier grossit à chaque passage
    ],
    bloc(role: "pratique", poids: 1.1)[Terminal · deux passages][
      #terminal(titre: none, taille: px(18))[
        ```
        $ ansible-playbook write_hello_world_naif.yaml -l managed-node-1
        # … 1er passage : changed=2
        $ ansible-playbook write_hello_world_naif.yaml -l managed-node-1
        TASK [Écrire /hello avec le module shell] ***
        changed: [managed-node-1]
        TASK [Écrire /hello_world avec lineinfile] ***
        ok: [managed-node-1]
        PLAY RECAP ***
        managed-node-1 : ok=3 changed=1 unreachable=0 failed=0 …
        $ ansible managed-node-1 -a "cat /hello /hello_world"
        managed-node-1 | CHANGED | rc=0 >>
        hello
        hello
        Hello world !
        ```
      ]
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html")[ansible.builtin.shell] · #link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html")[ansible.builtin.command]],
  note: _note,
)

== Réparer : un module dédié, sinon creates <idempotence-reparer>
#let _note = [Sorties réelles, après suppression des deux fichiers sur les deux nœuds (ansible all -m ansible.builtin.file -a "path\=/hello state\=absent" : file aussi est idempotent, il répond SUCCESS sur le nœud où le fichier manquait déjà). creates: la commande ne s’exécute pas si le fichier existe : ok au second passage. Limite de creates : il ne regarde que l’existence du fichier, pas son contenu. D’où l’ordre de préférence : un module qui décrit l’état (lineinfile, copy, template, file…) ; à défaut, une garde : creates ou removes, ou une condition when avec changed\_when (le corrigé du TP en montre une, avec le module stat). ansible-lint exige l’une d’elles sur command et shell (règle no-changed-when, diapositive « Bonnes pratiques »).]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.9)[`write_hello_world.yaml`][
      #terminal(titre: none, taille: px(19))[
        ```
        ---
        - name: Écrire hello world
          hosts: all
          tasks:
            - name: Écrire /hello, seulement s’il manque
              ansible.builtin.shell: echo hello > /hello
              args:
                creates: /hello

            - name: Écrire /hello_world avec lineinfile
              ansible.builtin.lineinfile:
                path: /hello_world
                line: "Hello world !"
                create: true
                mode: "0644"
        ```
      ]
      - Un module dédié d’abord ; sinon une garde : `creates`
    ],
    bloc(role: "pratique", poids: 1.1)[Terminal · deux passages][
      #terminal(titre: none, taille: px(18))[
        ```
        $ ansible-playbook write_hello_world.yaml
        # … 1er passage : changed=2 sur chaque nœud
        $ ansible-playbook write_hello_world.yaml
        TASK [Écrire /hello, seulement s’il manque] ***
        ok: [managed-node-1]
        ok: [managed-node-2]
        TASK [Écrire /hello_world avec lineinfile] ***
        ok: [managed-node-2]
        ok: [managed-node-1]
        PLAY RECAP ***
        managed-node-1 : ok=3 changed=0 unreachable=0 failed=0 …
        managed-node-2 : ok=3 changed=0 unreachable=0 failed=0 …
        ```
      ]
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html")[ansible.builtin.shell, paramètre creates] · #link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/lineinfile_module.html")[ansible.builtin.lineinfile]],
  note: _note,
)

== À vous : prédire changed
#let _note = [Exercice fait en séance, sur managed-node-1 du labo (nœud où tree n’est pas encore installé). Faire écrire les trois bilans avant de lancer. Gathering Facts compte dans ok. Corrigé à la diapositive suivante.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.05)[`preparer.yml`][
      #terminal(titre: none, taille: px(18))[
        ```
        - name: Préparer les nœuds
          hosts: all
          tasks:
            - name: Installer tree
              ansible.builtin.apt:
                name: tree
                state: present
            - name: Créer le répertoire du site
              ansible.builtin.file:
                path: /srv/site
                state: directory
                mode: "0755"
            - name: Noter la date du déploiement
              ansible.builtin.shell: date > /srv/site/deploiement.txt
            - name: Déposer la page d’accueil
              ansible.builtin.copy:
                content: "Bonjour\n"
                dest: /srv/site/index.txt
                mode: "0644"
        ```
      ]
    ],
    bloc(role: "question")[À vous][
      Sur `managed-node-1`, que dit `PLAY RECAP` (`ok=`, `changed=`) :
      + au premier passage ?
      + au second passage ?
      + au troisième, après qu’un collègue a écrit « Modifié à la main » dans `/srv/site/index.txt` ?
    ],
  ),
  note: _note,
)

== Prédire changed : corrigé
#let _note = [Sorties réelles (ansible-playbook preparer.yml -l managed-node-1). Question 3, avec --diff : copy affiche l’écart entre l’état constaté et l’état voulu, puis le corrige. C’est la dérive (drift) : un changed inattendu au passage suivant la signale. Complément : ansible-playbook --check simule sans rien modifier ; ici il affiche skipped\=1, car shell ne prend pas en charge le mode vérification.]
#corriges(note: _note,
  (1, [Premier passage ?], reponse[`ok=5 changed=4` : les quatre tâches modifient le nœud ; Gathering Facts compte dans ok.]),
  (2, [Second passage ?], reponse[`ok=5 changed=1` : seule la tâche `shell` (la date) répond encore *changed*.]),
  (3, [Après une modification à la main ?], reponse(terminal(titre: none, taille: px(18))[
    ```
    $ ansible-playbook preparer.yml -l managed-node-1 --diff
    # … TASK [Déposer la page d’accueil]
    -Modifié à la main
    +Bonjour
    changed: [managed-node-1]
    managed-node-1 : ok=5 changed=2 unreachable=0 failed=0 …
    ```
  ])),
)

// ======================================================================
= Structurer

== Où déclarer une variable <variables>
#let _note = [Fichiers du TP. group\_vars/ et host\_vars/ sont cherchés à côté de l’inventaire et à côté du playbook ; un fichier porte le nom du groupe ou de l’hôte (avec ou sans extension .yaml, .yml, .json). Sortie réelle : c’est celle de hello\_world.yml (diapositive « Le playbook »). managed-node-1 affiche la valeur de host\_vars, managed-node-2, qui n’a pas de fichier host\_vars, celle de group\_vars/all. On peut aussi déclarer des variables dans le fichier d’inventaire (clé vars d’un groupe, ou sous l’hôte), dans le play (vars:), dans un rôle (defaults/, vars/), sur la ligne de commande (-e). Quand plusieurs déclarations existent : la précédence, diapositive suivante. Règle de nommage : lettres, chiffres, soulignés ; pas de tiret.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.1)[Terminal · deux fichiers, deux valeurs][
      #terminal(titre: none, taille: px(20))[
        ```
        $ cat group_vars/all.yaml
        welcome_msg: "Bonjour le monde from group_vars"
        $ cat host_vars/managed-node-1.yaml
        welcome_msg: "Bonjour le monde from host_vars"
        $ ansible-playbook hello_world.yml
        # … TASK [Afficher le message d’accueil]
        ok: [managed-node-1] => {
            "msg": "Bonjour le monde from host_vars"
        }
        ok: [managed-node-2] => {
            "msg": "Bonjour le monde from group_vars"
        }
        ```
      ]
    ],
    bloc(taille: px(25))[Où l’écrire][
      - `group_vars/<groupe>.yaml` : pour les hôtes d’un groupe
      - `host_vars/<hôte>.yaml` : pour un hôte
      - `vars:` d’un play, `defaults/` et `vars/` d’un rôle
      - `-e` (_extra vars_) : sur la ligne de commande
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html")[docs.ansible.com, Organizing host and group variables]],
  note: _note,
)

== Précédence : un ordre fixe de sources <precedence-variables>
#let _note = [Modèle énoncé ici, repris par l’artefact « précédence » : la liste de la documentation, « Understanding variable precedence », 22 entrées du plus faible au plus fort (la première, -u et autres options de connexion, n’est pas une variable). Regroupées ici : 3 à 10 \= l’inventaire, dans l’ordre groupes du fichier, group\_vars/all de l’inventaire puis du playbook, group\_vars/\* de l’inventaire puis du playbook, hôtes du fichier, host\_vars/\* de l’inventaire puis du playbook ; 11 \= facts et set\_fact mis en cache ; 12 à 14 \= vars, vars\_prompt, vars\_files du play ; 16 \= vars d’un bloc ; 18 à 21 \= include\_vars, register et set\_fact, paramètres de rôle, paramètres d’include. La documentation résume : priorité à ce qui est défini plus récemment, plus activement, avec une portée plus explicite. « Le plus spécifique gagne », dit souvent, n’est vrai qu’à l’intérieur de l’inventaire (all < parent < enfant < hôte). Faux en général : un vars: de play vise tous les hôtes et bat pourtant host\_vars ; les defaults/ d’un rôle, propres à ce rôle, perdent contre tout. Dans un même niveau, la dernière définition chargée gagne. Comportement par défaut hash\_behaviour \= replace : un dictionnaire est remplacé en entier, pas fusionné. Démonstration : diapositive suivante.]
#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  let niveaux = (
    ([1], [options de connexion (`-u`…) : pas des variables]),
    ([2], [`defaults/` d’un rôle]),
    ([3–10], [inventaire : groupes (`all`, puis les autres), puis hôtes]),
    ([11], [facts de l’hôte]),
    ([12–14], [`vars`, `vars_prompt`, `vars_files` du play]),
    ([15], [`vars/` d’un rôle]),
    ([16–17], [`vars` d’un bloc, d’une tâche]),
    ([18–21], [`include_vars`, `register`, `set_fact`, paramètres de rôle]),
    ([22], [`-e` (_extra vars_) : gagne toujours]),
  )
  grid(columns: (px(860), 1fr), column-gutter: px(40),
    block(width: 100%, {
      text(size: px(22), weight: 600, fill: c.gris)[Du plus faible (1) au plus fort (22)]
      v(px(4))
      grid(columns: (px(110), 1fr), align: horizon,
        inset: (x, y) => (y: px(7), left: if x == 1 { px(16) } else { 0pt }),
        stroke: (x, y) => if y < niveaux.len() - 1 { (bottom: px(1) + c.filet) },
        ..niveaux.map(((n, t)) => (text(size: px(24), weight: 600, fill: c.bleu, n), text(size: px(23), t))).flatten())
    }),
    stack(spacing: px(20),
      bloc-anime(bloc(role: "retenir", taille: px(24))[La règle exacte][
        - D’abord la *source* : un ordre fixe de 22 niveaux
        - Dans l’inventaire : `all` < groupe parent < groupe enfant < hôte
        - À même niveau : la dernière définition chargée gagne
      ], 1, uncover),
    ),
  )
  uncover("4-", place(bottom + right, dy: px(-8), block(width: px(764), note(role: "precaution", taille: px(22))[« Le plus spécifique gagne » : vrai dans l’inventaire seulement. Un `vars:` de play, commun à tous les hôtes, bat `host_vars`.])))
  source[#link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence")[docs.ansible.com, Understanding variable precedence]]
  utils.speaker-note(self: self, _note)
})

== Précédence : un vars de play bat host_vars <precedence-demo>
#let _note = [Sorties réelles, mêmes fichiers group\_vars/all.yaml et host\_vars/managed-node-1.yaml qu’à la diapositive « Où déclarer une variable ». Premier passage : le vars: du play (niveau 12) bat host\_vars (niveau 9) sur les deux nœuds, alors qu’il est moins « spécifique ». Second passage : -e (niveau 22) bat tout. Guillemets de -e : sous la forme clé\=valeur, une valeur avec espace doit être entre guillemets à l’intérieur de l’argument ; sans eux, -e welcome\_msg\='from -e' donne « from ». La forme JSON -e '{"welcome\_msg": "from -e"}' évite l’ambiguïté. Démontré aussi, mêmes versions : les vars d’une tâche battent celles du play ; les vars/ d’un rôle (niveau 15) battent le play, et, pour un rôle importé par import\_role, s’appliquent même aux tâches du play qui suivent l’import.]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.8)[`precedence.yml`][
      #terminal(titre: none, taille: px(20))[
        ```
        ---
        - name: Qui gagne ?
          hosts: all
          gather_facts: false
          vars:
            welcome_msg: "from play vars"
          tasks:
            - name: Afficher welcome_msg
              ansible.builtin.debug:
                var: welcome_msg
        ```
      ]
      - `gather_facts: false` : pas de facts, plus rapide
    ],
    bloc(role: "pratique", poids: 1.2)[Terminal][
      #terminal(titre: none, taille: px(19))[
        ```
        $ ansible-playbook precedence.yml
        # … TASK [Afficher welcome_msg]
        ok: [managed-node-1] => {
            "welcome_msg": "from play vars"
        }
        ok: [managed-node-2] => {
            "welcome_msg": "from play vars"
        }
        $ ansible-playbook precedence.yml \
            -e 'welcome_msg="from -e"'
        # …
        ok: [managed-node-1] => {
            "welcome_msg": "from -e"
        }
        # … managed-node-2 : de même
        ```
      ]
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence")[docs.ansible.com, Understanding variable precedence]],
  note: _note,
)

== Entre groupes : profondeur, puis priorité, puis alphabet <precedence-groupes>
#let _note = [Règles de la page « How variables are merged » (guide de l’inventaire), rejouées avec ansible-inventory --host, sans connexion. Fichiers : group\_vars/mon\_groupe.yaml (welcome\_msg: "from mon\_groupe") et group\_vars/web\_server.yaml (welcome\_msg: "from web\_server") ; managed-node-1 est dans les deux groupes. Cas 1 : deux groupes de même niveau, fusionnés par ordre alphabétique, le dernier chargé gagne : web\_server. Cas 2 : ansible\_group\_priority (1 par défaut ; plus grand \= chargé plus tard) remplace l’ordre alphabétique. Il ne se règle que dans la source d’inventaire : écrit dans group\_vars/mon\_groupe.yaml, il est ignoré (rejoué : web\_server gagne encore). Cas 3 : un groupe enfant bat son parent, quel que soit son nom. Plusieurs sources d’inventaire : fusionnées dans l’ordre des -i, ou par ordre alphabétique des fichiers d’un répertoire.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.25)[Terminal · managed-node-1 dans deux groupes][
      #terminal(titre: none, taille: px(18))[
        ```
        # 1. mon_groupe et web_server, deux groupes enfants de all
        $ ansible-inventory -i hosts.yaml --host managed-node-1
        {
            "welcome_msg": "from web_server"
        }
        # 2. dans hosts-prio.yaml, mon_groupe a  vars: ansible_group_priority: 10
        $ ansible-inventory -i hosts-prio.yaml --host managed-node-1
        {
            "welcome_msg": "from mon_groupe"
        }
        # 3. dans hosts-enfant.yaml, mon_groupe est un enfant de web_server
        $ ansible-inventory -i hosts-enfant.yaml --host managed-node-1
        {
            "welcome_msg": "from mon_groupe"
        }
        ```
      ]
    ],
    bloc(role: "retenir", taille: px(25))[Dans l’inventaire][
      - Un groupe enfant bat son parent
      - À même profondeur : la plus grande `ansible_group_priority`
      - À priorité égale : ordre alphabétique, le dernier gagne
      - L’hôte bat tous ses groupes
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#how-variables-are-merged")[docs.ansible.com, How variables are merged]],
  note: _note,
)

== À vous : qui gagne ?
#let _note = [Même parc fictif que l’exercice sur les motifs : prod a deux enfants, web et bdd ; web2 et bdd1 sont aussi dans nouveaux. Chaque fichier déclare msg. web n’a pas de fichier de variables. Laisser chercher ; corrigé à la diapositive suivante.]
#anime(
  rang(
    bloc(role: "pratique")[Terminal · le parc et ses variables][
      #terminal(titre: none, taille: px(19))[
        ```
        $ ansible-inventory -i parc.yaml --graph
        @all:
          |--@ungrouped:
          |  |--bastion
          |--@prod:
          |  |--@web:
          |  |  |--web1
          |  |  |--web2
          |  |--@bdd:
          |  |  |--bdd1
          |--@nouveaux:
          |  |--web2
          |  |--bdd1
        $ grep -r msg group_vars host_vars | sort
        group_vars/all.yaml:msg: all
        group_vars/bdd.yaml:msg: bdd
        group_vars/nouveaux.yaml:msg: nouveaux
        group_vars/prod.yaml:msg: prod
        host_vars/web1.yaml:msg: host_vars
        ```
      ]
    ],
    bloc(role: "question")[À vous][
      Que vaut `msg` ?
      + pour `web1`
      + pour `web2`
      + pour `bdd1`
      + pour `web1`, dans un play qui déclare `vars: {msg: play}`
    ],
  ),
  note: _note,
)

== Qui gagne : corrigé
#let _note = [Sorties réelles : ansible-inventory -i parc.yaml --host « hôte » pour les questions 1 à 3 ; pour la question 4, ansible-playbook -i parc.yaml qui-gagne.yml (connection: local, sans facts), qui affiche « play » pour les quatre hôtes. Question 2 : web, le groupe le plus profond de web2, n’a pas de variables ; restent prod et nouveaux, de même profondeur : ordre alphabétique, prod est chargé en dernier. Question 3 : bdd est plus profond que nouveaux, il gagne bien que « nouveaux » vienne après « bdd » dans l’alphabet.]
#corriges(note: _note,
  (1, [`msg` pour `web1` ?], reponse[`host_vars` : l’hôte bat tous ses groupes.]),
  (2, [`msg` pour `web2` ?], reponse[`prod` : prod et nouveaux sont au même niveau ; prod vient après dans l’alphabet.]),
  (3, [`msg` pour `bdd1` ?], reponse[`bdd` : groupe enfant de prod, plus profond que nouveaux, malgré l’alphabet.]),
  (4, [`msg` pour `web1`, avec `vars: {msg: play}` ?], reponse[`play` : le play (niveau 12) bat tout l’inventaire, `host_vars` compris.]),
)

== Gabarits Jinja2 : un fichier à trous <gabarits>
#let _note = [Fichiers du rôle du TP (roles/nginx\_hello\_world/templates/). Le module template lit le gabarit sur le nœud de contrôle, remplace les expressions Jinja2 par les valeurs des variables de l’hôte (variables, facts), et dépose le résultat sur le nœud, s’il diffère du fichier en place : idempotent comme copy. ansible\_managed vaut « Ansible managed » par défaut ; la clé ansible\_managed de ansible.cfg la personnalise (le TP le demande). La ligne listen \[::\] du corrigé du TP est retirée ici : le noyau de la machine de démonstration n’a pas d’IPv6, et nginx refuse alors de démarrer. Jinja2 offre aussi des filtres (\{\{ nom | upper \}\}), des conditions et des boucles : au-delà de ce cours. Sortie réelle : la commande ad hoc lit le fichier déployé (module command, d’où CHANGED).]
#anime(
  rang(
    bloc(role: "pratique")[`etc_nginx_sites_available_default.j2`][
      #terminal(titre: none, taille: px(19))[
        ```
        # {{ ansible_managed }}

        server {
                listen {{ nginx_hello_world_port }} default_server;

                root /var/www/html;
                index index.html index.htm index.nginx-debian.html;
                server_name _;

                location / {
                        try_files $uri $uri/ =404;
                }
        }
        ```
      ]
    ],
    bloc(role: "pratique")[Terminal · le fichier déployé][
      #terminal(titre: none, taille: px(19))[
        ```
        $ ansible web_server -a \
            "head -4 /etc/nginx/sites-available/default"
        managed-node-1 | CHANGED | rc=0 >>
        # Ansible managed

        server {
                listen 8080 default_server;
        ```
      ]
      - `{{ … }}` : une expression Jinja2, remplacée par sa valeur pour chaque hôte
      - Un seul gabarit, un port par environnement
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html")[ansible.builtin.template] · #link("https://jinja.palletsprojects.com/en/stable/templates/")[Jinja, Template Designer Documentation]],
  note: _note,
)

== Handlers : redémarrer seulement si besoin <handlers>
#let _note = [Sorties réelles, rôle nginx\_hello\_world du TP. Un handler est une tâche qui ne s’exécute que si une tâche qui le notifie (notify) répond changed ; il s’exécute une seule fois, après toutes les tâches du play, même s’il a été notifié plusieurs fois. Clic 1 : premier passage, le gabarit est déposé (changed), le handler redémarre nginx en fin de play. Second passage, non montré : changed\=0, aucun handler. Clic 2 : le port passe à 80 par group\_vars/web\_server.yaml ; --diff montre l’écart, le gabarit change, le handler redémarre nginx ; curl http:\/\/managed-node-1/ répond « \<h1\>Hello world !\</h1\> ». La variable de groupe (niveau 6) bat le defaults/ du rôle (niveau 2). Nginx sans systemd, dans un conteneur : le module service passe par le script /etc/init.d/nginx.]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.95)[`handlers/main.yml` et la tâche qui notifie][
      #terminal(titre: none, taille: px(16))[
        ```
        # roles/nginx_hello_world/handlers/main.yml
        - name: Redémarrer nginx
          ansible.builtin.service:
            name: nginx
            state: restarted
        # roles/nginx_hello_world/tasks/main.yml (extrait)
        - name: Configurer nginx sur le port {{ nginx_hello_world_port }}
          ansible.builtin.template:
            src: etc_nginx_sites_available_default.j2
            dest: /etc/nginx/sites-available/default
            mode: "0644"
          notify: Redémarrer nginx
        ```
      ]
      - Le handler ne tourne que si la tâche répond *changed*
      - Une seule fois, en fin de play
    ],
    bloc(role: "pratique", poids: 1.05)[Terminal][
      #terminal(titre: none, taille: px(16))[
        ```
        $ ansible-playbook site-web.yml
        # … (installer, publier : changed)
        TASK [nginx_hello_world : Configurer nginx sur le port 8080] ***
        changed: [managed-node-1]
        TASK [nginx_hello_world : Démarrer nginx] ***
        changed: [managed-node-1]
        RUNNING HANDLER [nginx_hello_world : Redémarrer nginx] ***
        changed: [managed-node-1]
        managed-node-1 : ok=6 changed=5 unreachable=0 failed=0 …
        # group_vars/web_server.yaml : nginx_hello_world_port: 80
        $ ansible-playbook site-web.yml --diff
        # …
        -        listen 8080 default_server;
        +        listen 80 default_server;
        changed: [managed-node-1]
        # … (Démarrer nginx : ok)
        RUNNING HANDLER [nginx_hello_world : Redémarrer nginx] ***
        changed: [managed-node-1]
        ```
      ]
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html")[docs.ansible.com, Handlers: running operations on change]],
  note: _note,
)

== Rôles : ranger un service, le réutiliser <roles>
#let _note = [Arborescence du rôle du TP (tree 2.1.1, installé sur le nœud de contrôle). Chaque répertoire a son main.yml, lu automatiquement : defaults/ (variables par défaut, niveau de précédence le plus faible : faites pour être surchargées), vars/ (variables du rôle, niveau 15 : à ne pas surcharger), tasks/, handlers/, templates/ et files/ (cherchés là par template et copy, sans chemin), meta/ (auteur, licence, plateformes, dépendances). Préfixer les variables d’un rôle par son nom (nginx\_hello\_world\_port) évite les collisions entre rôles. import\_role est statique (lu à l’analyse du playbook) ; include\_role est dynamique (évalué à l’exécution, peut dépendre d’une condition). On peut aussi écrire roles: au niveau du play. ansible-galaxy role init crée l’arborescence complète, avec en plus vars/, tests/ et un README.md. Ansible Galaxy (galaxy.ansible.com) partage des rôles et des collections ; une collection regroupe rôles, modules et plugins, versionnés ensemble ; un requirements.yml les liste pour ansible-galaxy install -r. Lire le code d’un rôle éprouvé (geerlingguy.docker, au TP) avant d’écrire le sien.]
#anime(
  rang(
    bloc(role: "pratique", poids: 0.95)[Terminal · l’arborescence][
      #terminal(titre: none, taille: px(20))[
        ```
        $ tree roles/nginx_hello_world
        roles/nginx_hello_world
        ├── defaults
        │   └── main.yml
        ├── files
        │   └── index.html
        ├── handlers
        │   └── main.yml
        ├── meta
        │   └── main.yml
        ├── tasks
        │   └── main.yml
        └── templates
            └── etc_nginx_sites_available_default.j2

        7 directories, 6 files
        ```
      ]
      - `defaults/main.yml` : `nginx_hello_world_port: 8080`
    ],
    bloc(role: "pratique", poids: 1.05)[`site-web.yml`][
      #terminal(titre: none, taille: px(20))[
        ```
        ---
        - name: Installer les serveurs web de l’infrastructure
          hosts: web_server
          tasks:
            - name: Déployer le rôle nginx_hello_world
              ansible.builtin.import_role:
                name: nginx_hello_world
        ```
      ]
      - Un rôle : les tâches, fichiers, gabarits, handlers et variables d’un service
      - `ansible-galaxy role init` crée l’arborescence
      - *Ansible Galaxy* partage rôles et *collections* (rôles, modules, plugins versionnés ensemble)
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html")[docs.ansible.com, Roles] · #link("https://galaxy.ansible.com")[galaxy.ansible.com]],
  note: _note,
)

== Bonnes pratiques, et ansible-lint pour les rappeler <bonnes-pratiques>
#let _note = [Sortie réelle d’ansible-lint 26.11.0 (option --offline : sans téléchargement), sur un playbook qui reprend deux erreurs du cours ; une ligne vide et le texte d’aide sont retirés. package-latest : state: latest met à jour à chaque passage, le résultat dépend du jour (profil safety, étiquette idempotency) ; préférer present, et des versions épinglées mises à jour délibérément. no-changed-when : command ou shell sans garde. Une dérogation s’écrit et se versionne : skip\_list dans .ansible-lint, ou un commentaire « \# noqa: package-latest » sur la ligne. Ansible Vault (ansible-vault encrypt, puis --ask-vault-pass) chiffre un fichier de variables secrètes dans le dépôt. ansible-playbook --check --diff simule et montre les écarts sans rien modifier (un module qui ne prend pas en charge ce mode est sauté). Molecule teste un rôle dans des instances jetables : sujet du TP. Sources : la page « Tips and tricks » de la documentation, et la liste des règles d’ansible-lint.]
#anime(
  rang(
    bloc(role: "pratique", poids: 1.15)[Terminal][
      #terminal(titre: none, taille: px(18))[
        ```
        $ ansible-lint --offline preparer-naif.yml
        WARNING  Listing 2 violation(s) that are fatal
        package-latest: Package installs should not use latest.
        preparer-naif.yml:5 Task/Handler: Installer tree
        no-changed-when: Commands should not change things
        if nothing needs doing.
        preparer-naif.yml:10 Task/Handler: Noter la date du déploiement
        # …
        # Rule Violation Summary
          1 package-latest profile:safety tags:idempotency
          1 no-changed-when profile:safety tags:command-shell,idempotency
        Failed: 2 failure(s), 0 warning(s) in 1 files processed of 1 encountered.
        ```
      ]
    ],
    bloc(role: "retenir", taille: px(23))[À faire][
      - Un `name` par tâche, le nom complet du module (`ansible.builtin.apt`)
      - Un `state` explicite ; `present` plutôt que `latest`
      - Un module dédié plutôt que `shell` ou `command`
      - Le tout dans Git, contrôlé par `ansible-lint`
      - `--check --diff` avant d’appliquer ; un second passage à `changed=0`
      - Les secrets chiffrés par Ansible Vault
    ],
  ),
  source-de: [#link("https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html")[docs.ansible.com, General tips] · #link("https://docs.ansible.com/projects/lint/rules/")[ansible-lint, Rules]],
  note: _note,
)

// ======================================================================
= Pour rappel

== Pour rappel · liste non exhaustive
#anime(
  rang(bloc(role: "retenir", taille: px(26))[L’essentiel du cours][
    - On décrit un *état voulu* ; Ansible constate l’état réel et ne fait que l’écart
    - Un nœud de contrôle, des nœuds gérés sans agent : SSH et Python suffisent
    - L’inventaire range les hôtes en groupes ; un motif (`:`, `:&`, `:!`) choisit les hôtes visés
    - Un module agit, un playbook enchaîne des tâches ; `changed` si le nœud est modifié, `ok` sinon
    - Idempotence : second passage à `changed=0` ; `shell` et `command` en dernier recours, gardés
    - Précédence : un ordre fixe de sources ; dans l’inventaire, enfant > parent, puis priorité, puis alphabet
    - Gabarits Jinja2, handlers notifiés, rôles réutilisables ; `ansible-lint` et Git pour la qualité
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

== Sources
#anime(
  rang(bloc(taille: px(24))[Documentation officielle (docs.ansible.com)][
    - #link("https://docs.ansible.com/ansible/latest/getting_started/introduction.html")[Introduction to Ansible] ; #link("https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html")[How to build your inventory] ; #link("https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html")[Patterns]
    - #link("https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html")[Ad hoc commands] ; #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html")[Playbooks] ; #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html")[Handlers] ; #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html")[Roles]
    - #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html")[Using variables, Understanding variable precedence] ; #link("https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html")[General tips]
    - #link("https://docs.ansible.com/projects/lint/rules/")[ansible-lint, Rules] ; #link("https://jinja.palletsprojects.com/en/stable/templates/")[Jinja, Template Designer Documentation]
  ]),
  rang(bloc(role: "pratique", taille: px(24))[Pour pratiquer][
    - TP Ansible : le même labo, de l’inventaire aux rôles
    - Vidéos : #link("https://www.youtube.com/playlist?list=PLn6POgpklwWoCpLKOSw3mXCqbRocnhrh-")[Xavki, playlist Ansible] (en français)
  ]),
  note: [La documentation est la source à consulter en premier, au TP comme ici : chaque diapositive renvoie à sa page. Contenus relus dans les sources de la documentation (dépôt ansible/ansible-documentation, branche devel) : le site docs.ansible.com n’était pas joignable depuis la machine de préparation ; ouvrir chaque lien avant le cours.],
)

#cloture(illustration: "noeuds")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
