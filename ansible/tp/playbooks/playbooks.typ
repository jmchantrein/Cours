// TP « Ansible, séance 2 : playbooks, variables et idempotence » — page web compilée par Typst
// (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     ansible/tp/playbooks/playbooks.typ build/ansible/tp-playbooks.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/ansible-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Ansible, séance 2 : playbooks, variables et idempotence],
  surtitre: [Ansible : automatiser les configurations · travaux pratiques],
  sous-titre: [Écrire des playbooks, les contrôler avec ansible-lint et Git, constater puis réparer l’idempotence],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "vm",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/ansible/tp/playbooks/corrige"),
    ([Séance 1 : inventaire], "../inventaire/index.html"),
    ([Séance 3 : rôles], "../roles/index.html"),
    ([Documentation d’Ansible], "https://docs.ansible.com/"),
  ),
)

= Avant de commencer <avant>

Cette séance reprend le labo et le dossier de travail de la #link("../inventaire/index.html")[séance 1] : trois
conteneurs, SSH câblé, `ansible.cfg` et `inventory/hosts.yaml` dans `~/tp-ansible`. Vous y écrivez des
playbooks (#d("playbook")[Le playbook : un play, des tâches]), vous les contrôlez avec `ansible-lint` et Git, puis
vous constatez l’idempotence, vous la cassez exprès, et vous la réparez
(#d("idempotence")[L’idempotence : état voulu, état constaté]).

#bloc(role: "pratique")[Reprendre le labo][
  Si les conteneurs tournent encore et que votre shell est ouvert dans `control-node`, passez à l’étape 1. Sinon,
  depuis le dossier du labo : les fichiers de `~/tp-ansible` n’ont pas bougé, mais `docker compose down` efface
  les conteneurs, donc le câblage SSH.
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
  Comme à la séance 1 : cherchez à la source, #link("https://docs.ansible.com/")[docs.ansible.com] et
  `ansible-doc <module>`. Les corrigés vérifient votre travail, ils ne le remplacent pas.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification : chaque playbook est analysé, contrôlé par `ansible-lint`, joué deux
  fois, et l’état des nœuds est relevé. Les sorties viennent d’ansible-core 2.19.4 et d’ansible-lint 26.11.0 sur
  des nœuds Debian 13.
]

= Étape 1 : un premier playbook <etape-1>

#bloc(role: "question")[Consignes][
  - Écrivez `hello_world-1.yml`, un playbook d’un seul play qui vise *tous* les nœuds gérés. Une première tâche
    fait un ping (module `ansible.builtin.ping`), une seconde affiche « hello world » (module
    `ansible.builtin.debug`).
  - Jouez-le avec `ansible-playbook`. Combien de tâches la sortie affiche-t-elle, et pourquoi une de plus que
    vous n’en avez écrit ?
  - Donnez un nom (`name`) à chaque tâche et au play : qu’est-ce que cela change à la sortie ?
]

#indice(titre: [Indice : la forme d’un playbook])[
  Un playbook est une liste de plays (d’où le tiret initial) ; un play a un `hosts` et des `tasks` ; une tâche
  appelle un module par son nom complet : #d("playbook")[Le playbook : un play, des tâches]. Le module `debug` a un
  paramètre `msg`. Documentation :
  #link("https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html")[Ansible playbooks].
]

#corrige[
  #f("hello_world-1.yml")
  #terminal[```console
  $ ansible-playbook hello_world-1.yml
  PLAY [Hello world] *************************************************************

  TASK [Gathering Facts] *********************************************************
  ok: [managed-node-2]
  ok: [managed-node-1]

  TASK [Pinguer les nœuds gérés] *************************************************
  ok: [managed-node-2]
  ok: [managed-node-1]

  TASK [Afficher hello world] ****************************************************
  ok: [managed-node-1] => {
      "msg": "hello world"
  }
  ok: [managed-node-2] => {
      "msg": "hello world"
  }

  PLAY RECAP *********************************************************************
  managed-node-1             : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  managed-node-2             : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  ```]
  La tâche `Gathering Facts` s’ajoute d’elle-même : au début de chaque play, Ansible relève les facts de
  chaque nœud. Le `name` s’affiche dans `TASK […]` ; sans lui, la sortie nomme la tâche d’après son module
  (`ansible.builtin.ping`), et `ansible-lint` réclame un nom (étape 4). Les ordres d’affichage de `managed-node-1` et `managed-node-2` varient
  d’un passage à l’autre : les nœuds travaillent en parallèle.
]

= Étape 2 : des variables, et qui l’emporte <etape-2>

#bloc(role: "question")[Consignes][
  - Déclarez une variable `welcome_msg` valant « Bonjour le monde from group_vars » dans `group_vars/all.yaml`, et
    « Bonjour le monde from host_vars » dans `host_vars/managed-node-1.yaml`.
  - Copiez le playbook en `hello_world-2.yml`, et faites-lui afficher `welcome_msg` à la place de « hello world ».
  - Que constatez-vous sur chaque nœud ? Comment faire pour que ce soit la valeur de `group_vars` qui s’applique
    sur les deux ?
  - Sans toucher aux fichiers de variables, imposez une autre valeur, « from -e », aux deux nœuds. Quelle est
    cette valeur, parmi les sources de variables, et que dit-elle de la règle « le plus spécifique gagne » ?
]

#indice(titre: [Indice : où ranger les fichiers])[
  `group_vars/` et `host_vars/` se placent à côté du playbook ; un fichier porte le nom du groupe (`all`) ou de
  l’hôte : #d("variables")[Où déclarer une variable]. L’extension `.yaml` ou `.yml` est acceptée.
]
#indice(titre: [Indice : l’ordre des sources])[
  La documentation donne la liste complète :
  #link("https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence")[Understanding variable precedence].
  Le cours en résume l’ordre : #d("precedence-variables")[Précédence : un ordre fixe de sources]. L’option
  `-e` (_extra vars_) de `ansible-playbook` déclare une variable en ligne de commande ; une valeur qui contient
  une espace s’écrit `-e 'variable="deux mots"'`. Pour rejouer la règle et la mettre en défaut :
  l’artefact #link("../../artefacts/precedence-variables/index.html")[Quelle valeur gagne ?]
]

#corrige[
  #f("group_vars/all.yaml")
  #f("host_vars/managed-node-1.yaml")
  #f("hello_world-2.yml")
  #terminal[```console
  $ ansible-playbook hello_world-2.yml
  # … TASK [Afficher le message d’accueil]
  ok: [managed-node-1] => {
      "msg": "Bonjour le monde from host_vars"
  }
  ok: [managed-node-2] => {
      "msg": "Bonjour le monde from group_vars"
  }
  $ ansible-playbook hello_world-2.yml -e 'welcome_msg="from -e"'
  # …
  ok: [managed-node-1] => {
      "msg": "from -e"
  }
  # … managed-node-2 : de même
  ```]
  `managed-node-1` affiche la valeur de `host_vars`, `managed-node-2`, qui n’a pas de fichier `host_vars`, celle de
  `group_vars/all`. Ce n’est pas une affaire de « spécificité » en général : Ansible applique une liste fixe de
  22 niveaux, du plus faible au plus fort. Dans l’inventaire, un groupe passe avant `all`, un groupe enfant avant
  son parent, l’hôte avant ses groupes : `host_vars` bat donc `group_vars`. Mais ce n’est vrai que dans
  l’inventaire : un `vars:` de play, qui vise pourtant tous les hôtes, bat `host_vars`, et `-e` bat tout. Pour que la
  valeur de `group_vars` s’applique partout, on ne peut pas inverser l’ordre : on retire la déclaration de
  `host_vars` (ou on la renomme). L’option `-e` impose bien une valeur aux deux nœuds, mais c’est celle de la
  ligne de commande, pas celle du groupe. La démonstration, avec `vars:` de play :
  #d("precedence-demo")[Précédence : un vars de play bat host_vars].
]

= Étape 3 : les facts <etape-3>

#bloc(role: "question")[Consignes][
  - Dans un playbook `hello_world.yml`, repartez de l’étape 2 et ajoutez deux tâches : l’une affiche le nom d’hôte
    de chaque nœud, d’après les facts ; l’autre affiche sa distribution.
  - Pour la distribution, n’utilisez pas le fact déjà collecté : appelez le module `ansible.builtin.setup`,
    limité à `ansible_distribution`, gardez sa réponse dans une variable (`register`), puis affichez la
    valeur utile de cette variable.
  - Combien de tâches `hello_world.yml` compte-t-il maintenant ? Quel est son `ok=` dans le bilan ?
]

#indice(titre: [Indice : le nom d’hôte])[
  Le fact s’appelle `ansible_hostname`, comme l’affiche `ansible managed-node-1 -m ansible.builtin.setup`
  (séance 1). Dans un playbook, un fact est une variable ordinaire.
]
#indice(titre: [Indice : la réponse de setup])[
  Une tâche enregistrée par `register: ma_variable` garde la réponse JSON du module, que `ansible-playbook -v`
  ou un `debug: var=ma_variable` affiche en entier. Les facts y sont sous la clé `ansible_facts`.
]
#note(role: "avertissement")[Une valeur YAML qui *commence* par `{{` doit être entre guillemets :
  `msg: "{{ ansible_hostname }}"`. Sans eux, YAML lit un dictionnaire et Ansible refuse le playbook.]

#corrige[
  #f("hello_world.yml")
  #terminal[```console
  $ ansible-playbook hello_world.yml
  # … TASK [Afficher le nom d’hôte]
  ok: [managed-node-1] => {
      "msg": "managed-node-1"
  }
  ok: [managed-node-2] => {
      "msg": "managed-node-2"
  }
  # … TASK [Afficher la distribution]
  ok: [managed-node-1] => {
      "msg": "Debian"
  }
  # … managed-node-2 : de même
  managed-node-1             : ok=6    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  ```]
  Le playbook compte six tâches, `Gathering Facts` comprise, d’où `ok=6`. `ansible_hostname` est disponible
  directement parce que les facts sont relevés en début de play ; la version `setup` plus `register` montre le
  mécanisme général : garder la sortie d’un module dans une variable pour la réutiliser.
]

= Étape 4 : ansible-lint, Git et un crochet <etape-4>

#bloc(role: "question")[Consignes][
  - Lintez `hello_world.yml` avec `ansible-lint --offline` (sans téléchargement). Puis écrivez ce brouillon, lintez-le
    et corrigez-le jusqu’à ce que `ansible-lint` n’ait plus rien à dire :
    #terminal[```console
    $ printf -- '- hosts: all\n  tasks:\n  - ping:\n  - debug:\n      msg: "{{ welcome_msg }}"\n' > brouillon.yml
    $ ansible-lint --offline brouillon.yml
    ```]
  - Initialisez un dépôt Git dans `/etc/ansible` et faites un premier commit de vos playbooks.
  - Écrivez `hooks/pre-commit`, un crochet qui refuse le commit si `shellcheck` (fichiers `.sh` et `.bash`) ou
    `ansible-lint` (fichiers `.yaml` et `.yml`) échoue, et installez-le dans le dépôt.
  - Le crochet ne contrôle que les fichiers indexés pour ce commit, pas tout le dépôt. Pourquoi ?
  - Essayez-le : un commit propre passe-t-il, un commit d’un playbook fautif (le brouillon d’avant, par exemple) et
    d’un script shell fautif sont-ils refusés ? Le crochet nomme-t-il le fichier refusé ?
]

#indice(titre: [Indice : lire ansible-lint])[
  Chaque violation donne le nom de la règle (`fqcn[action-core]`, `name[missing]`, `yaml[indentation]`), le
  fichier et la ligne. La page
  #link("https://docs.ansible.com/projects/lint/rules/")[Rules] de la documentation d’`ansible-lint` explique
  chaque règle. Le code de retour de la commande vaut 0 s’il n’y a plus de violation :
  #d("bonnes-pratiques")[Bonnes pratiques, et ansible-lint pour les rappeler].
]
#indice(titre: [Indice : les fichiers du commit])[
  `git diff --cached --name-only --diff-filter=ACM` liste les fichiers indexés, ajoutés (A), copiés (C) ou
  modifiés (M). Git exécute `.git/hooks/pre-commit` avant chaque commit, et refuse le commit si le script sort
  avec un code différent de 0. Le fichier doit être exécutable.
]
#indice(titre: [Indice : les hooks ne sont pas versionnés])[
  `.git/` n’est pas versionné : le crochet que vous y installez ne suit pas le dépôt. D’où `hooks/pre-commit`,
  un fichier ordinaire du dépôt, que l’on copie dans `.git/hooks/`.
]

#corrige[
  #f("hooks/pre-commit")
  #terminal[```console
  $ ansible-lint --offline hello_world.yml
  Passed: 0 failure(s), 0 warning(s) in 1 files processed of 1 encountered. Last profile that met the validation criteria was 'production'.
  $ ansible-lint --offline brouillon.yml
  WARNING  Listing 6 violation(s) that are fatal
  name[play]: All plays should be named.
  brouillon.yml:1:3

  fqcn[action-core]: Use FQCN for builtin module actions (ping).
  brouillon.yml:3:5 Use `ansible.builtin.ping` or `ansible.legacy.ping` instead.
  # … name[missing] et fqcn pour debug, yaml[indentation] : expected at least 3
  Failed: 6 failure(s), 0 warning(s) in 1 files processed of 1 encountered. Last profile that met the validation criteria was 'min'.
  $ git init
  $ git config user.email "ada@exemple.org"
  $ git config user.name "Ada"
  $ cp hooks/pre-commit .git/hooks/pre-commit
  $ git add ansible.cfg inventory group_vars host_vars hello_world-1.yml hello_world-2.yml hello_world.yml hooks
  $ git commit -m "Premiers playbooks"
  $ git add brouillon.yml
  $ git commit -m "Un brouillon"
  ansible-lint refuse brouillon.yml : corrigez-le avant de commiter.
  $ git reset brouillon.yml
  ```]
  Le brouillon se corrige en nommant le play et les tâches, en écrivant `ansible.builtin.ping` et
  `ansible.builtin.debug`, et en indentant la liste de tâches de deux espaces de plus (`yaml[indentation]`).
  Le crochet ne regarde que les fichiers indexés parce que relire tout le dépôt à chaque commit ne passerait pas
  à l’échelle : il lui suffit de contrôler ce qui entre. Le crochet contrôle *tous* les fichiers indexés
  avant de sortir (la variable `statut`), au lieu de s’arrêter au premier refus. Le message du
  crochet nomme le fichier ; la sortie d’`ansible-lint` détaille les violations juste au-dessus.
]

= Étape 5 : apt, ou l’idempotence constatée <etape-5>

#bloc(role: "question")[Consignes][
  - Écrivez `install-common-software.yaml` : il installe `htop`, `ncdu` et `vim` sur tous les nœuds, avec le module
    `ansible.builtin.apt`.
  - Jouez-le deux fois de suite. Que dit `PLAY RECAP` à chaque passage ? Vérifiez ensuite sur un nœud que les
    paquets sont installés.
]

#indice(titre: [Indice : le module apt])[
  `ansible-doc ansible.builtin.apt` : le paramètre `name` accepte une liste, `state` dit l’état voulu. Les nœuds
  du labo gardent les listes de paquets de leur image, donc aucun `update_cache` n’est nécessaire.
  #d("idempotence-apt")[apt : changed, puis ok].
]

#corrige[
  #f("install-common-software.yaml")
  #terminal[```console
  $ ansible-playbook install-common-software.yaml
  # … TASK [Installer la liste de paquets communs]
  changed: [managed-node-1]
  changed: [managed-node-2]
  managed-node-1             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  managed-node-2             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ ansible-playbook install-common-software.yaml
  # … TASK [Installer la liste de paquets communs]
  ok: [managed-node-1]
  ok: [managed-node-2]
  managed-node-1             : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  managed-node-2             : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ ansible managed-node-2 -a "dpkg -s htop ncdu vim"
  ```]
  Au premier passage, les paquets manquent : `apt` les installe et répond `changed`. Au second, il constate qu’ils
  sont présents et ne fait rien : `ok`, `changed=0`. Le module compare l’état voulu (`state: present`) à l’état
  constaté et ne fait que l’écart. C’est l’idempotence, constatée.
]

= Étape 6 : shell et command, ou l’idempotence cassée <etape-6>

#bloc(role: "avertissement")[Consigne de section][
  Dans les étapes 6 et 7, n’exécutez pas `ansible-lint` avant que l’énoncé le demande, et ne commitez rien :
  vous écrivez exprès du mauvais code, que le crochet de l’étape 4 refuserait, et c’est toute la conclusion.
]

#bloc(role: "question")[Consignes][
  - Écrivez `write_hello_world_naif.yaml`, sur tous les nœuds, avec trois tâches :
    + écrire « hello » dans `/hello` avec le module `ansible.builtin.shell` ;
    + écrire « world » dans `/world` avec le module `ansible.builtin.command` ;
    + écrire la ligne « Hello world ! » dans `/hello_world` avec le module `ansible.builtin.lineinfile`.
  - Jouez-le deux fois. Que dit `PLAY RECAP` à chaque passage, et quelles tâches répondent `changed` au second ?
  - Relevez la date de modification des trois fichiers sur `managed-node-1` après chaque passage. Lesquels ont été
    réécrits sans raison ?
  - Si vous aviez écrit `>>` au lieu de `>` par erreur, Ansible serait-il encore idempotent ? Essayez.
]

#indice(titre: [Indice : command n’a pas de shell])[
  Le module `command` exécute un programme sans passer par un shell : ni redirection `>`, ni tube, ni variable.
  Pour qu’il écrive un fichier, il faut un programme qui sache écrire :
  `python3 -c "open('/world', 'w').write('world\n')"`. Si vous luttez contre un module, c’est que ce n’est pas
  le bon : #d("shell-command")[shell et command : changed à chaque passage].
]
#indice(titre: [Indice : les dates])[
  `stat -c '%y %n' /hello /world /hello_world` affiche la date de dernière modification de chaque fichier.
  `ansible managed-node-1 -a "…"` la lit depuis le nœud de contrôle.
]

#corrige[
  #f("write_hello_world_naif.yaml")
  #terminal[```console
  $ ansible-playbook write_hello_world_naif.yaml
  # … 1er passage : changed=3 sur chaque nœud
  $ ansible managed-node-1 -a "stat -c '%y %n' /hello /world /hello_world"
  $ ansible-playbook write_hello_world_naif.yaml
  # … TASK [Écrire /hello avec le module shell]
  changed: [managed-node-1]
  changed: [managed-node-2]
  # … TASK [Écrire /world avec le module command]
  changed: [managed-node-1]
  changed: [managed-node-2]
  # … TASK [Écrire /hello_world avec le module lineinfile]
  ok: [managed-node-1]
  ok: [managed-node-2]
  managed-node-1             : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  managed-node-2             : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ ansible managed-node-1 -a "stat -c '%y %n' /hello /world /hello_world"
  ```]
  Chaque passage affiche `changed=2` : Ansible ne peut pas connaître l’effet d’une commande arbitraire, donc il la
  rejoue et la déclare `changed`. Les dates de `/hello` et de `/world` avancent à chaque passage, celle de
  `/hello_world` non : `lineinfile` décrit un état (« cette ligne est présente dans ce fichier »), constate qu’il
  est atteint et n’y touche plus. Avec `>>`, le résultat lui-même diverge : le fichier gagne une ligne à chaque
  passage. Le détour par Python du module `command` est le signe que ce n’est pas le bon module.
]

= Étape 7 : réparer l’idempotence <etape-7>

#bloc(role: "question")[Consignes][
  - Effacez `/hello`, `/world` et `/hello_world` sur les deux nœuds, avec le module `ansible.builtin.file`
    (`state: absent`) : pourquoi pas avec `rm` ?
  - Écrivez `write_hello_world.yaml`, qui garde `shell` et `command` mais ne les exécute que si le fichier visé
    manque, de deux façons : pour `/hello`, avec le paramètre `creates` de `shell` ; pour `/world`, en constatant
    l’état avec `ansible.builtin.stat`, puis en décidant avec `when`. Gardez `lineinfile` pour `/hello_world`.
  - Lintez-le avec `ansible-lint --offline`, et suivez ses recommandations qui *conservent* l’idempotence. Puis
    lintez la version naïve : que lui reproche-t-il ?
  - Jouez deux fois `write_hello_world.yaml`. Le second passage doit afficher `changed=0`. Que devient la tâche
    `command` au second passage ?
  - Commitez les playbooks de l’étape 5 puis celui-ci, en deux commits : le crochet accepte-t-il ?
]

#indice(titre: [Indice : creates])[
  `creates: /chemin` : la commande ne s’exécute pas si ce fichier existe. `ansible-doc ansible.builtin.shell`
  décrit ce paramètre, dans la clé `args` ou au niveau de la tâche. Il ne regarde que l’existence du fichier,
  pas son contenu : #d("idempotence-reparer")[Réparer : un module dédié, sinon creates].
]
#indice(titre: [Indice : stat, register, when])[
  `ansible.builtin.stat` renvoie, pour un chemin, si le fichier existe (`stat.exists`). `register` garde la réponse,
  `when: not variable.stat.exists` conditionne la tâche suivante. Une tâche sautée s’affiche `skipping`.
]
#indice(titre: [Indice : la règle no-changed-when])[
  `ansible-lint` exige qu’une tâche `command` ou `shell` dise quand elle change quelque chose : un `creates`, un
  `removes`, ou un `changed_when`. Avec une garde `when`, la tâche ne s’exécute que si elle va écrire :
  `changed_when: true` est alors exact.
]

#corrige[
  #f("write_hello_world.yaml")
  #terminal[```console
  $ for f in /hello /world /hello_world; do ansible all -m ansible.builtin.file -a "path=$f state=absent"; done
  $ ansible-lint --offline write_hello_world_naif.yaml
  WARNING  Listing 2 violation(s) that are fatal
  no-changed-when: Commands should not change things if nothing needs doing.
  write_hello_world_naif.yaml:7 Task/Handler: Écrire /hello avec le module shell

  no-changed-when: Commands should not change things if nothing needs doing.
  write_hello_world_naif.yaml:11 Task/Handler: Écrire /world avec le module command
  $ ansible-lint --offline write_hello_world.yaml
  $ ansible-playbook write_hello_world.yaml
  # … 1er passage : changed=3 sur chaque nœud (ok=5)
  $ ansible-playbook write_hello_world.yaml
  # … TASK [Écrire /world, seulement s’il manque]
  skipping: [managed-node-1]
  skipping: [managed-node-2]
  managed-node-1             : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
  managed-node-2             : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
  $ git add install-common-software.yaml
  $ git commit -m "Installer les logiciels communs"
  $ git add write_hello_world.yaml
  $ git commit -m "Écrire hello world, de façon idempotente"
  ```]
  `file` avec `state: absent` décrit l’état voulu (« ce fichier n’existe pas ») : il répond `ok` sur le nœud où le
  fichier manquait déjà, alors qu’un `rm` aurait échoué. `creates` est la garde la plus simple, mais elle ne regarde
  que l’existence ; la garde `stat` plus `when` dit la même chose de façon explicite, et la tâche sautée affiche
  `skipping`. `ansible-lint` exige `changed_when` sur `command` et `shell` (règle `no-changed-when`) : `creates` en
  tient lieu, et avec `when`, `changed_when: true` est exact puisque la tâche n’a alors qu’une issue, écrire. La
  leçon tient en une ligne : *un module dédié d’abord ; `shell` et `command` gardés, en dernier ressort*.
]

= Étape 8 : state: latest, ou une règle qu’on peut discuter <etape-8>

#bloc(role: "question")[Consignes][
  - Copiez `install-common-software.yaml` en `install-common-software-latest.yaml`, remplacez `state: present` par
    `state: latest`, et lintez. Quelle règle refuse-t-il, et pourquoi ?
  - Si l’on est sûr de soi, peut-on outrepasser une règle d’`ansible-lint` ? Et une règle de `shellcheck` ?
    Essayez, sans modifier vos autres fichiers.
]

#indice(titre: [Indice : la dérogation])[
  Une dérogation s’écrit, se voit et se versionne. Pour `ansible-lint` : un commentaire `# noqa: <règle>` sur la
  ligne, ou une liste `skip_list` dans un fichier de configuration (option `-c`). Pour `shellcheck` : un commentaire
  `# shellcheck disable=SCxxxx` au-dessus de la commande concernée.
  #d("bonnes-pratiques")[Bonnes pratiques, et ansible-lint pour les rappeler].
]

#corrige[
  #f("install-common-software-latest.yaml")
  #terminal[```console
  $ ansible-lint --offline install-common-software-latest.yaml
  WARNING  Listing 1 violation(s) that are fatal
  package-latest: Package installs should not use latest.
  install-common-software-latest.yaml:6 Task/Handler: Installer la liste de paquets communs
  # … Failed: 1 failure(s), 0 warning(s) in 1 files processed of 1 encountered.
  ```]
  `latest` signifie « installe et mets à jour à chaque passage » : le résultat dépend du jour de l’exécution,
  l’idempotence et la reproductibilité s’en vont. La bonne pratique est `state: present`, et des versions épinglées
  que l’on met à jour délibérément. Oui, on peut déroger en connaissance de cause : `state: latest # noqa:
  package-latest` sur la ligne, ou `package-latest` dans la liste `skip_list:` d’un fichier passé à `ansible-lint -c`.
  Pour `shellcheck`, `# shellcheck disable=SC2048` au-dessus de la ligne. Ne commitez pas ce fichier : c’est un
  contre-exemple, le crochet le refuserait.
]

= Étape 9 : un gabarit Jinja2 <etape-9>

#bloc(role: "question")[Consignes][
  - Écrivez le gabarit `templates/motd.j2` : trois lignes, la première est le message d’accueil `welcome_msg`, la
    deuxième nomme la machine et sa distribution (`Machine managed-node-1, sous Debian 13.8.`), la troisième avertit
    qu’Ansible gère ce fichier.
  - Écrivez `motd.yml`, qui dépose le résultat dans `/etc/motd` des deux nœuds (module
    `ansible.builtin.template`, propriétaire et groupe `root`, droits `0644`).
  - Jouez-le deux fois. Lisez `/etc/motd` sur chaque nœud : les deux n’ont pas le même message, pourquoi ?
  - Simulez un changement du message avec `--check --diff`, sans rien modifier. Vérifiez que `/etc/motd` n’a pas
    changé.
]

#indice(titre: [Indice : le gabarit])[
  Les expressions `{{ … }}` du gabarit sont remplacées par les valeurs des variables de l’hôte : variables des
  fichiers, facts (`ansible_hostname`, `ansible_distribution`, `ansible_distribution_version`) :
  #d("gabarits")[Gabarits Jinja2 : un fichier à trous]. Le module `template` cherche `src` à côté du playbook.
]
#indice(titre: [Indice : simuler])[
  `ansible-playbook --check` simule sans rien modifier ; `--diff` affiche, pour chaque fichier, l’écart entre
  l’état constaté et l’état voulu. Une valeur de variable change pour une seule exécution avec `-e`.
]

#corrige[
  #f("templates/motd.j2", lang: none)
  #f("motd.yml")
  #terminal[```console
  $ ansible-playbook motd.yml
  # … TASK [Déposer /etc/motd depuis son gabarit]
  changed: [managed-node-1]
  changed: [managed-node-2]
  managed-node-1             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  managed-node-2             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
  $ ansible-playbook motd.yml
  # … changed=0 sur chaque nœud
  $ ansible all -a "cat /etc/motd"
  managed-node-1 | CHANGED | rc=0 >>
  Bonjour le monde from host_vars
  Machine managed-node-1, sous Debian 13.8.
  Configurée par Ansible : modifiez le gabarit, pas ce fichier.
  # … managed-node-2 : « Bonjour le monde from group_vars »
  $ ansible-playbook motd.yml --check --diff -e 'welcome_msg="Maintenance ce soir"'
  # … TASK [Déposer /etc/motd depuis son gabarit]
  --- before: /etc/motd
  +++ after: /root/.ansible/tmp/…/motd.j2
  @@ -1,3 +1,3 @@
  -Bonjour le monde from group_vars
  +Maintenance ce soir
   Machine managed-node-2, sous Debian 13.8.
   Configurée par Ansible : modifiez le gabarit, pas ce fichier.

  changed: [managed-node-2]
  # … managed-node-1 : de même
  $ ansible managed-node-2 -a "head -1 /etc/motd"
  managed-node-2 | CHANGED | rc=0 >>
  Bonjour le monde from group_vars
  ```]
  Un seul gabarit, un contenu par hôte : `welcome_msg` vaut la valeur de `host_vars` sur `managed-node-1`, celle de
  `group_vars` sur `managed-node-2` (étape 2), et les facts nomment la machine. Le second passage répond
  `changed=0` : comme `copy`, `template` ne réécrit le fichier que s’il diffère. `--check --diff` annonce
  `changed` (le fichier changerait) sans y toucher : sa date, son contenu sont intacts. La version `13.8` est celle
  de vos nœuds au jour de la construction : la vôtre peut différer.
]

#bloc(role: "retenir")[Ce que cette séance a montré][
  - Un playbook est une liste de plays ; chaque tâche appelle un module, nommé en entier, et `Gathering Facts`
    relève les facts du nœud.
  - La précédence des variables est un ordre fixe de sources, pas une affaire de spécificité : `host_vars` bat
    `group_vars`, un `vars:` de play bat `host_vars`, `-e` bat tout.
  - `ansible-lint` et un crochet Git contrôlent ce qui entre dans le dépôt.
  - Un module dédié (`apt`, `file`, `lineinfile`, `template`) est idempotent : `changed=0` au second passage ;
    `shell` et `command` répondent toujours `changed`, sauf gardés par `creates` ou `when`.
  - `state: latest` brise l’idempotence ; une dérogation se justifie, s’écrit et se versionne.
  - Suite : la #link("../roles/index.html")[séance 3] range un service dans un rôle, avec gabarit et handler.
]
