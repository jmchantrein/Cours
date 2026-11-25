// TP « Ansible, séance 3 : un rôle » — page web compilée par Typst
// (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     ansible/tp/roles/roles.typ build/ansible/tp-roles.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/ansible-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Ansible, séance 3 : un rôle, nginx_hello_world],
  surtitre: [Ansible : automatiser les configurations · travaux pratiques],
  sous-titre: [Ranger un service dans un rôle : variable par défaut, gabarit, handler, et la précédence à l’épreuve],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "vm",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/ansible/tp/roles/corrige"),
    ([Séance 2 : playbooks], "../playbooks/index.html"),
    ([Documentation d’Ansible], "https://docs.ansible.com/"),
  ),
)

= Avant de commencer <avant>

Cette dernière séance range un service dans un *rôle* : le serveur web nginx, qui publie une page « Hello world ! »
sur un port réglable (#d("roles")[Rôles : ranger un service, le réutiliser]). Vous l’appliquez au groupe
`web_server`, vous changez son port de trois façons pour voir laquelle l’emporte, et vous constatez que le
redémarrage de nginx n’a lieu que si sa configuration a changé (#d("handlers")[Handlers : redémarrer seulement si besoin]).
Elle reprend le labo et le dossier de travail des deux séances précédentes : #link("../inventaire/index.html")[inventaire]
et #link("../playbooks/index.html")[playbooks].

#bloc(role: "pratique")[Reprendre le labo][
  Si les conteneurs tournent encore et que votre shell est ouvert dans `control-node`, passez à l’étape 1. Sinon,
  depuis le dossier du labo :
  #terminal[```console
  $ cd ~/Cours/ansible/cm/labo
  $ export ANSIBLE_PROJET="$HOME/tp-ansible"
  $ docker compose up --detach --build
  $ ./cabler-ssh.sh   # votre script de la séance 1, rangé dans ce dossier, à côté de compose.yaml
  $ docker compose exec control-node bash
  ```]
  Dans `control-node`, le dossier de départ est `/etc/ansible` : c’est `~/tp-ansible` de votre machine. Toutes
  les commandes de l’énoncé, sauf mention contraire, s’y lancent.
]

#bloc(role: "precaution")[La documentation d’abord][
  Comme aux séances précédentes : #link("https://docs.ansible.com/")[docs.ansible.com] et `ansible-doc <module>`
  d’abord. Les corrigés vérifient votre travail, ils ne le remplacent pas.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification : le rôle est contrôlé par `ansible-lint`, joué sur le labo avec chaque
  surcharge de port, la page est lue avec `curl`, et le handler est compté. Les sorties viennent d’ansible-core
  2.19.4 sur des nœuds Debian 13.
]

#schema([Ce que vous aurez construit à l’étape 8 : un rôle appliqué au groupe `web_server`, c’est-à-dire à `managed-node-1` seul.], ch => {
  let c = ch.c
  grid(columns: (auto, 50pt, auto), align: horizon, column-gutter: 0pt,
    boite([control-node · `/etc/ansible`], trait: c.bleu, largeur: 250pt, stack(spacing: 5pt,
      case(fond: c.appli, largeur: 210pt)[`site-web.yml` : `hosts: web_server`],
      case(largeur: 210pt)[rôle `nginx_hello_world`],
      case(largeur: 210pt)[`defaults/` : port 8080],
      case(largeur: 210pt)[`group_vars/web_server.yaml` : port 80],
      case(largeur: 210pt)[`site-local.yml` : localhost],
    )),
    align(center, text(size: 9pt, fill: c.gris)[SSH \ #sym.arrow.r]),
    stack(spacing: 8pt,
      boite([managed-node-1 · `web_server`], trait: c.distant, largeur: 190pt, stack(spacing: 5pt,
        case(largeur: 150pt)[nginx, une page],
        case(largeur: 150pt, fond: ch.roles.retenir.fond)[`/etc/nginx/sites-available/default`])),
      boite([managed-node-2 · hors du groupe], trait: c.gris, tirets: "dashed", largeur: 190pt,
        text(size: 9pt)[rien : le rôle ne le vise pas]),
    ),
  )
})

= Étape 1 : le labo, et les fichiers de départ <etape-1>

#bloc(role: "question")[Consignes][
  - Vérifiez que vous joignez les deux nœuds : `ansible all -m ansible.builtin.ping`.
  - Vérifiez que `web_server` vise le seul `managed-node-1` : `ansible web_server --list-hosts`.
  - Vérifiez que nginx n’est installé sur aucun nœud : `ansible all -m ansible.builtin.shell -a "command -v nginx || echo aucun"`
    doit répondre `aucun` pour les deux.
]

#indice(titre: [Indice : si le ping échoue])[
  Le câblage SSH est dans les conteneurs : un `docker compose down` l’efface. Relancez votre `cabler-ssh.sh` depuis
  le dossier du labo, sur votre machine (pas dans `control-node`).
]

#corrige[
  #terminal[```console
  $ ansible all -m ansible.builtin.ping
  managed-node-1 | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3.13"
      },
      "changed": false,
      "ping": "pong"
  }
  # … managed-node-2 : même réponse
  $ ansible web_server --list-hosts
    hosts (1):
      managed-node-1
  $ ansible all -m ansible.builtin.shell -a "command -v nginx || echo aucun"
  managed-node-1 | CHANGED | rc=0 >>
  aucun
  # … managed-node-2 : de même
  ```]
  Le rôle n’a pas encore tourné : nginx n’existe nulle part. Le play visera `web_server`, donc `managed-node-1`
  seulement ; `managed-node-2` ne recevra rien.
]

= Étape 2 : le squelette d’un rôle <etape-2>

#bloc(role: "question")[Consignes][
  - Créez le rôle `nginx_hello_world` dans `roles/`, avec la commande que fournit Ansible pour cela (la
    documentation de `ansible-galaxy` l’appelle `role init`).
  - Listez l’arborescence créée avec `tree`. Que contient chaque dossier ? Lesquels ne serviront pas à un rôle qui
    installe nginx, déploie une page et un gabarit, et redémarre le service ? Supprimez-les.
  - Gardez `defaults`, `files`, `handlers`, `meta`, `tasks` et `templates` : vous les remplirez aux étapes 3 et 4.
]

#indice(titre: [Indice : la commande])[
  `ansible-galaxy role init --help` donne l’option qui choisit le dossier où créer le rôle (`--init-path`). Le
  nom du rôle est un identifiant : lettres, chiffres, soulignés. La structure complète est décrite par
  #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html")[Roles] dans la
  documentation, et par #d("roles")[Rôles : ranger un service, le réutiliser].
]

#corrige[
  #terminal[```console
  $ ansible-galaxy role init --init-path roles nginx_hello_world
  - Role nginx_hello_world was created successfully
  $ tree roles/nginx_hello_world
  roles/nginx_hello_world
  ├── README.md
  ├── defaults
  │   └── main.yml
  ├── files
  ├── handlers
  │   └── main.yml
  ├── meta
  │   └── main.yml
  ├── tasks
  │   └── main.yml
  ├── templates
  ├── tests
  │   ├── inventory
  │   └── test.yml
  └── vars
      └── main.yml

  9 directories, 8 files
  $ rm -r roles/nginx_hello_world/tests roles/nginx_hello_world/vars roles/nginx_hello_world/README.md
  ```]
  `defaults/` porte les variables par défaut, de précédence la plus faible : faites pour être surchargées ;
  `vars/` porte celles du rôle, qui l’emportent presque sur tout (étape 6) : on n’y met que ce qu’on ne veut pas voir
  surcharger. `tests/` est un exemple d’essai, `README.md` la documentation ; le rôle de ce TP n’en a pas
  besoin. `files/` et `templates/` sont cherchés par `copy` et `template` sans qu’on écrive leur chemin.
]

= Étape 3 : une variable et un gabarit <etape-3>

#bloc(role: "question")[Consignes][
  - Dans `defaults/main.yml`, déclarez `nginx_hello_world_port`, de valeur 8080. Le nom de la variable commence par
    celui du rôle : pourquoi ?
  - Écrivez le gabarit `templates/etc_nginx_sites_available_default.j2`, la configuration du site par défaut de
    nginx : un seul serveur, qui écoute sur le port du rôle, déclaré `default_server`, sert le dossier
    `/var/www/html` (`root`), avec pour fichier d’accueil `index.html` (`index`), pour tous les noms (`server_name _`),
    et répond `404` pour ce qui n’existe pas (`try_files $uri $uri/ =404`).
  - Le gabarit commence par un commentaire qui reprend la variable `ansible_managed`.
  - N’écrivez *pas* de ligne `listen [::]:…` (IPv6). Pourquoi ?
]

#indice(titre: [Indice : la syntaxe nginx])[
  Le site par défaut que Debian installe est `/etc/nginx/sites-available/default`. La documentation de
  #link("https://nginx.org/en/docs/http/ngx_http_core_module.html")[nginx] décrit `server`, `listen`, `root`, `index`
  et `location`. Dans le gabarit, la valeur du port s’écrit `{{ nginx_hello_world_port }}` :
  #d("gabarits")[Gabarits Jinja2 : un fichier à trous].
]
#indice(titre: [Indice : ansible_managed])[
  `ansible_managed` est une variable spéciale d’Ansible, dont la valeur par défaut est `Ansible managed`. Un
  commentaire `# {{ ansible_managed }}` en tête d’un fichier généré prévient qui le lit qu’il est produit, et
  qu’il ne faut pas l’éditer à la main.
]

#corrige[
  #f("roles/nginx_hello_world/defaults/main.yml")
  #f("roles/nginx_hello_world/templates/etc_nginx_sites_available_default.j2", lang: none)
  Le préfixe `nginx_hello_world_` évite les collisions : toutes les variables d’un playbook vivent dans le même
  espace de noms, et deux rôles qui déclareraient chacun `port` s’écraseraient. Le fichier d’origine de Debian
  contient aussi une ligne `listen [::]:80 default_server;`, pour l’IPv6. Sur une machine dont le noyau n’a pas
  IPv6, nginx refuse alors de démarrer
  (`socket() [::]:8080 failed (97: Address family not supported by protocol)`) : le gabarit ne garde que
  l’écoute en IPv4, pour fonctionner aussi sur un hôte sans IPv6.
]

= Étape 4 : la page, les tâches et le handler <etape-4>

#bloc(role: "question")[Consignes][
  - Écrivez la page `files/index.html` : `<h1>Hello world !</h1>`.
  - Écrivez `tasks/main.yml`, quatre tâches dans cet ordre, chacune avec un nom et un module de nom complet :
    + installer le paquet `nginx` ;
    + publier la page dans `/var/www/html/index.html` avec le module `copy`, propriétaire et groupe `www-data`,
      droits `0644` ;
    + déposer le gabarit dans `/etc/nginx/sites-available/default` avec le module `template`, droits `0644`, et
      *notifier* un handler ;
    + démarrer nginx avec le module `ansible.builtin.service`.
  - Écrivez `handlers/main.yml` : un handler `Redémarrer nginx`, qui redémarre le service.
  - Renseignez `meta/main.yml` : l’auteur, la licence (`CC-BY-NC-SA-4.0`, celle de ce dépôt), une description, la
    plateforme Debian.
  - Quel est l’intérêt de `notify` et des handlers, par rapport à une tâche « redémarrer nginx » ordinaire ?
]

#indice(titre: [Indice : notify et handlers])[
  Une tâche porte `notify: <nom du handler>` ; le handler ne s’exécute que si cette tâche répond `changed`, et une
  seule fois, après toutes les tâches du play :
  #d("handlers")[Handlers : redémarrer seulement si besoin]. Le nom dans `notify` doit être exactement celui du
  handler. Documentation :
  #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html")[Handlers: running operations on change].
]
#indice(titre: [Indice : les modules])[
  `ansible-doc ansible.builtin.apt`, `ansible.builtin.copy`, `ansible.builtin.template`, `ansible.builtin.service` :
  les paramètres `src`, `dest`, `owner`, `group`, `mode`, `state`. `copy` cherche `src` dans `files/` du rôle,
  `template` dans `templates/`. Un `name` de tâche peut contenir une variable : `"… {{ nginx_hello_world_port }}"`.
]
#indice(titre: [Indice : meta/main.yml])[
  Le fichier a été créé à l’étape 2 : lisez ses clés, et `ansible-lint` vous dira lesquelles il attend. Un
  rôle n’a pas besoin de dépendances : `dependencies: []`.
]

#corrige[
  #f("roles/nginx_hello_world/files/index.html", lang: "html")
  #f("roles/nginx_hello_world/tasks/main.yml")
  #f("roles/nginx_hello_world/handlers/main.yml")
  #f("roles/nginx_hello_world/meta/main.yml")
  Une tâche ordinaire `restarted` redémarrerait nginx à chaque passage, même sans changement : une coupure du
  service pour rien. Le handler ne redémarre le service que si sa configuration a réellement changé, et une fois
  par play même si plusieurs tâches le notifient : c’est l’idempotence appliquée aux redémarrages. Au premier
  passage, nginx est démarré par la dernière tâche, puis redémarré par le handler en fin de play : cette
  redondance est sans conséquence. La tâche `service` vérifie, elle, que nginx tourne à chaque passage.
]

= Étape 5 : jouer le rôle <etape-5>

#bloc(role: "question")[Consignes][
  - Écrivez `site-web.yml` : un play qui vise le groupe `web_server` et applique le rôle `nginx_hello_world` avec
    `ansible.builtin.import_role`.
  - Lintez le playbook avec `ansible-lint --offline site-web.yml` : il lit aussi le rôle qu’il importe. Sans
    argument, `ansible-lint` lirait tout le dossier, donc aussi les contre-exemples volontairement fautifs de la
    séance 2 (`write_hello_world_naif.yaml`, `install-common-software-latest.yaml`, le brouillon), et les refuserait.
  - Jouez le playbook. Combien de tâches changent ? Le handler tourne-t-il ?
  - Lisez la page avec `curl` depuis `control-node`. Sur quel port ? Que contient la première ligne du fichier
    déployé sur le nœud ?
  - Jouez-le une seconde fois. Qu’est-ce qui a changé au bilan ? Le handler tourne-t-il ?
  - `managed-node-2` est-il touché ?
]

#indice(titre: [Indice : importer un rôle])[
  `ansible.builtin.import_role` prend `name:`, le nom du dossier du rôle : le rôle est lu à l’analyse du
  playbook. `include_role` serait évalué à l’exécution, et peut dépendre d’une condition. On peut aussi écrire
  `roles:` au niveau du play.
]
#indice(titre: [Indice : lire sur le nœud])[
  `curl -s http://managed-node-1:<port>/` interroge nginx depuis `control-node`. Pour lire un fichier d’un nœud :
  `ansible web_server -a "head -4 /etc/nginx/sites-available/default"`.
]

#corrige[
  #f("site-web.yml")
  #terminal[```console
  $ ansible-lint --offline site-web.yml
  Passed: 0 failure(s), 0 warning(s) in 5 files processed of 5 encountered. Last profile that met the validation criteria was 'production'.
  $ ansible-playbook site-web.yml
  PLAY [Installer les serveurs web de l’infrastructure] **************************

  TASK [Gathering Facts] *********************************************************
  ok: [managed-node-1]

  TASK [nginx_hello_world : Installer le paquet nginx] ***************************
  changed: [managed-node-1]

  TASK [nginx_hello_world : Publier la page Hello world] *************************
  changed: [managed-node-1]

  TASK [nginx_hello_world : Configurer nginx sur le port 8080] *******************
  changed: [managed-node-1]

  TASK [nginx_hello_world : Démarrer nginx] **************************************
  changed: [managed-node-1]

  RUNNING HANDLER [nginx_hello_world : Redémarrer nginx] *************************
  changed: [managed-node-1]

  PLAY RECAP *********************************************************************
  managed-node-1             : ok=6    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ curl -s http://managed-node-1:8080/
  <h1>Hello world !</h1>
  $ ansible web_server -a "head -4 /etc/nginx/sites-available/default"
  managed-node-1 | CHANGED | rc=0 >>
  # Ansible managed

  server {
          listen 8080 default_server;
  $ ansible-playbook site-web.yml
  # … (aucune tâche changed, aucun handler)
  managed-node-1             : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  ```]
  Cinq tâches changent au premier passage (le paquet, la page, la configuration, le démarrage, puis le handler),
  `Gathering Facts` n’y compte pas. Au second, `changed=0` et aucun handler : le rôle est idempotent, et nginx n’a
  pas été redémarré pour rien. Seul `managed-node-1` figure dans la sortie : `managed-node-2` n’est pas dans
  `web_server`.
]

= Étape 6 : surcharger le port, et la précédence <etape-6>

#bloc(role: "question")[Consignes][
  - Faites servir la page sur le port 80, sans modifier le rôle : déclarez `nginx_hello_world_port: 80` dans
    `group_vars/web_server.yaml`. Rejouez, puis lisez la page. Que fait le handler ? Que devient le port 8080 ?
  - Rejouez avec `-e nginx_hello_world_port=8081`, puis lisez la page. Rejouez enfin sans `-e` : quel port ?
  - Classez les trois sources de la variable : `defaults/` du rôle, `group_vars/web_server.yaml`, `-e`. Laquelle
    l’emporte, et pourquoi ? Est-ce « le plus spécifique gagne » ?
  - Si le port était dans `vars/main.yml` du rôle plutôt que dans `defaults/`, que vaudrait la valeur de `group_vars` ?
]

#indice(titre: [Indice : la liste de la documentation])[
  #link("https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence")[Understanding variable precedence]
  numérote les sources du plus faible au plus fort ; le cours en donne un résumé :
  #d("precedence-variables")[Précédence : un ordre fixe de sources]. Cherchez-y `defaults`, `inventory group_vars`
  et `extra vars`.
]
#indice(titre: [Indice : vérifier plutôt que croire])[
  Pour la dernière question, essayez : créez `roles/nginx_hello_world/vars/main.yml` avec une autre valeur, rejouez,
  lisez le port, puis supprimez le fichier.
]

#corrige[
  #f("group_vars/web_server.yaml")
  #terminal[```console
  $ ansible-playbook site-web.yml --diff
  # … TASK [nginx_hello_world : Configurer nginx sur le port 80]
  -        listen 8080 default_server;
  +        listen 80 default_server;
  changed: [managed-node-1]
  # … RUNNING HANDLER [nginx_hello_world : Redémarrer nginx]
  changed: [managed-node-1]
  managed-node-1             : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ curl -s http://managed-node-1/
  <h1>Hello world !</h1>
  $ curl -s --max-time 3 http://managed-node-1:8080/ || echo "pas de réponse"
  pas de réponse
  $ ansible-playbook site-web.yml -e nginx_hello_world_port=8081
  # … Configurer nginx sur le port 8081 : changed ; le handler : changed
  $ curl -s http://managed-node-1:8081/
  <h1>Hello world !</h1>
  $ ansible-playbook site-web.yml
  # … retour au port 80 : changed=2 (la configuration, puis le handler)
  ```]
  À chaque changement de port, la configuration change (`changed`) et le handler redémarre nginx : `changed=2`.
  Le port 8080 ne répond plus, puisque nginx a relu sa configuration. L’ordre est : `defaults/` du rôle (niveau 2) <
  `group_vars/web_server.yaml` (niveaux 3 à 10 ; ici, à côté du playbook : niveau 7) < `-e` (niveau 22, il gagne toujours). Ce n’est pas une affaire de
  « spécificité » : c’est un ordre fixe de sources, dans lequel `defaults/` est volontairement le plus faible, pour
  que tout le monde puisse surcharger un rôle sans l’éditer. Un `vars/main.yml` de rôle (niveau 15) bat au contraire
  `group_vars` : avec `nginx_hello_world_port: 9090` dedans, le playbook sert la page sur 9090 malgré `group_vars`
  (essayé ici ; seul `-e` passe encore devant). D’où la règle : ce qu’on veut voir surcharger va dans
  `defaults/`, ce qu’on veut protéger dans `vars/`.
]

= Étape 7 : signer le fichier <etape-7>

#bloc(role: "question")[Consignes][
  - Lisez la première ligne du fichier déployé sur `managed-node-1` : `head -1 /etc/nginx/sites-available/default`.
  - Personnalisez le message de `ansible_managed` pour tous les nœuds : « Ce fichier est géré par Ansible : ne le
    modifiez pas ici, vos modifications seraient perdues. » Déclarez-le sans toucher au rôle, dans
    `group_vars/all.yaml`, où `welcome_msg` de la séance précédente peut rester.
  - Rejouez : quelles tâches changent, et le handler tourne-t-il ? Relisez la première ligne.
  - Rejouez : le bilan revient-il à `changed=0` ?
]

#indice(titre: [Indice : où déclarer])[
  `ansible_managed` se lit dans le gabarit, comme n’importe quelle variable ; `group_vars/all.yaml` vaut pour
  tous les hôtes : #d("variables")[Où déclarer une variable]. Une valeur YAML qui contient « : » (deux-points
  puis espace) doit être entre guillemets.
]

#corrige[
  #f("group_vars/all.yaml")
  #terminal[```console
  $ ansible web_server -a "head -1 /etc/nginx/sites-available/default"
  managed-node-1 | CHANGED | rc=0 >>
  # Ansible managed
  $ ansible-playbook site-web.yml
  # … Configurer nginx sur le port 80 : changed ; Redémarrer nginx : changed
  managed-node-1             : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ ansible web_server -a "head -1 /etc/nginx/sites-available/default"
  managed-node-1 | CHANGED | rc=0 >>
  # Ce fichier est géré par Ansible : ne le modifiez pas ici, vos modifications seraient perdues.
  $ ansible-playbook site-web.yml
  # … changed=0
  ```]
  Le gabarit est identique, mais la valeur de `ansible_managed` a changé : le fichier déployé diffère, donc `template`
  répond `changed` et notifie le handler. Un avertissement honnête pour les collègues qui ouvriraient le fichier à
  la main : ils savent qu’il est généré, et par quoi.
]

= Étape 8 : le nœud de contrôle se configure lui-même <etape-8>

#bloc(role: "question")[Consignes][
  - Écrivez `site-local.yml`, un playbook qui configure le *nœud de contrôle* lui-même, sans SSH : il vise
    `localhost` avec la connexion `local`, sans relever les facts. Une tâche ajoute à `/root/.bashrc` un bloc de
    trois lignes, qui ouvre chaque shell de `root` dans `/etc/ansible` et définit les alias `ap` (pour
    `ansible-playbook`) et `al` (pour `ansible-lint --offline`).
  - Jouez-le deux fois. Combien de tâches ? Le bloc est-il ajouté deux fois ?
  - Ouvrez un nouveau shell : `bash -i`, puis `pwd` et `type ap`.
  - Pourquoi `localhost` n’est-il pas dans l’inventaire, et pourquoi `connection: local` ?
]

#indice(titre: [Indice : un bloc de lignes])[
  Le module `ansible.builtin.blockinfile` insère un bloc de lignes entre deux marqueurs, et ne le réécrit que si
  son contenu change : c’est ce qui le rend idempotent. `marker` personnalise les deux lignes de marque
  (`{mark}` devient `BEGIN` puis `END`). `gather_facts: false` saute `Gathering Facts` : ici, on n’en a pas besoin.
]

#corrige[
  #f("site-local.yml")
  #terminal[```console
  $ ansible-playbook site-local.yml
  # … TASK [Ouvrir chaque shell de root dans /etc/ansible, avec des raccourcis]
  changed: [localhost]
  localhost                  : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ ansible-playbook site-local.yml
  # … ok: [localhost]
  localhost                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ bash -ic 'pwd; type ap'
  /etc/ansible
  ap is aliased to `ansible-playbook'
  ```]
  Une seule tâche : le bloc est ajouté une fois, et le second passage répond `ok` (les marqueurs permettent de
  retrouver le bloc). `localhost` est connu d’Ansible sans être déclaré, comme l’hôte de la machine qui exécute
  la commande ; avec `connection: local`, il agit directement, sans ouvrir de SSH vers lui-même. Le nœud de
  contrôle est configuré comme les autres, par un playbook : c’est de l’infrastructure décrite par du code,
  versionnable.
]

#bloc(role: "retenir")[Ce que cette séance a montré][
  - Un rôle range un service : `defaults/` (variables surchargeables), `tasks/`, `handlers/`, `templates/`, `files/`,
    `meta/` ; `ansible-galaxy role init` crée l’arborescence.
  - Un gabarit Jinja2 produit la configuration depuis les variables ; `ansible_managed` la signe.
  - Un handler notifié ne redémarre le service que si sa configuration a changé : `changed=2` au changement de
    port, `changed=0` sinon.
  - La précédence est un ordre fixe : `defaults/` de rôle < inventaire < `vars/` de rôle < `-e`. Ce qu’on veut
    surcharger va dans `defaults/`.
  - Le nœud de contrôle se configure par un playbook sur `localhost`, comme n’importe quelle machine.
]

#bloc(role: "pratique")[Pour aller plus loin][
  Ansible Galaxy (#link("https://galaxy.ansible.com")[galaxy.ansible.com]) partage des rôles et des collections ;
  un `requirements.yml` liste ce qu’un projet en emprunte, et `ansible-galaxy install -r requirements.yml` les
  installe. Lire le code d’un rôle éprouvé est un bon exercice. Pour tester un rôle dans des instances jetables,
  voir #link("https://ansible.readthedocs.io/projects/molecule/")[Molecule]. Pour chiffrer des secrets dans le dépôt :
  #link("https://docs.ansible.com/ansible/latest/vault_guide/index.html")[Ansible Vault].
]
