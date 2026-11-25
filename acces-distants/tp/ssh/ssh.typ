// TP « SSH : clés, bastion, tunnel, durcissement » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     acces-distants/tp/ssh/ssh.typ build/ssh.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/acces-distants-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [SSH : clés, bastion, tunnel, durcissement],
  surtitre: [Accès distants · travaux pratiques],
  sous-titre: [Se connecter sans mot de passe, rebondir par un bastion, copier, rediriger un port, fermer la porte à clé],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tunnel",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/acces-distants/tp/ssh/corrige"),
    ([Manuel d’OpenSSH], "https://man.openbsd.org/ssh"),
  ),
)

= Avant de commencer <avant>

Ada administre un serveur qu’elle ne voit pas : #d("ssh-intro")[Administrer une machine qu’on ne voit pas]. Ce TP
suit le fil rouge du cours, de la première connexion par mot de passe jusqu’à un serveur qui n’accepte plus que
les clés : une paire de clés, l’empreinte du serveur, le dépôt de la clé, l’agent, `~/.ssh/config`, le rebond par
un bastion, `scp` et `rsync`, une redirection de port, puis le durcissement de `sshd`.

#bloc(role: "precaution")[Des conteneurs qui jouent des machines][
  Le cours Conteneurisation enseigne de ne *pas* lancer `sshd` dans un conteneur : on se connecte à un
  conteneur par `docker exec`, jamais par SSH. Ici, trois conteneurs Debian 13 tiennent lieu de *machines
  distantes* pour s’exercer, avec un compte d’exercice (`ada`, mot de passe `motdepasse`) que l’on ne
  créerait jamais sur une vraie machine. Dans le labo, la « console » d’une machine est `docker compose exec` ;
  sur un vrai serveur, ce serait l’écran de l’hébergeur ou un accès hors bande.
]

#bloc(role: "pratique")[Prérequis][
  - Docker avec le plugin Compose v2, et un accès au réseau (l’image de base et les paquets Debian se téléchargent).
  - Le labo (`compose.yaml` et le dossier `machine/`) est fourni dans le dossier
    #link("https://github.com/jmchantrein/Cours/tree/main/acces-distants/tp/ssh/corrige")[`corrige/`] : la commande
    ci-dessous en extrait le contenu de l’archive du dépôt des cours, dans `~/tp-ssh`, où vous travaillez. Les autres
    fichiers ne servent qu’une fois l’étape faite, comme corrigés.
  - Deux terminaux ouverts dans `~/tp-ssh` : un pour le poste d’Ada, un pour la console des machines.
]

#terminal[```console
$ mkdir -p ~/tp-ssh && cd ~/tp-ssh
$ curl -fsSL https://github.com/jmchantrein/Cours/archive/refs/heads/main.tar.gz | tar -xz --strip-components=5 Cours-main/acces-distants/tp/ssh/corrige
$ ls
```]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, rejoués
  à chaque modification dans un labo neuf : les trois machines sont montées, les dix étapes déroulées dans l’ordre
  de la page, et les résultats vérifiés (clé chiffrée, empreinte, `authorized_keys`, rebond, `rsync`, tunnel,
  durcissement). Au clavier, `ssh` vous demande le mot de passe et la phrase de passe ; les scripts du corrigé,
  eux, n’ont pas de clavier : ils donnent ces réponses par `SSH_ASKPASS`, un détail du harnais. Les sorties
  montrées viennent d’OpenSSH 10.0 (Debian 13). Différence avec les diapos : le bastion écoute ici sur le port 2222 (au
  lieu de 22), pour s’exercer à `-p` et à `Port`.
]

#schema([Le labo : trois machines, deux réseaux. Le poste ne voit pas le serveur.], ch => {
  let c = ch.c
  let m(nom, role, fond: c.invite-clair) = case(fond: fond, largeur: 120pt, [*#nom* \ #text(size: 8.5pt)[#role]])
  boite([Réseau `public`], trait: c.gris, tirets: "dashed", stack(spacing: 8pt,
    grid(columns: 3, column-gutter: 14pt, align: horizon,
      m[poste][ssh seulement, pas de sshd],
      text(size: 9pt)[← ssh, port 2222 →],
      boite([Réseau `prive` (interne, sans sortie)], trait: c.gris, tirets: "dashed",
        grid(columns: 3, column-gutter: 10pt, align: horizon,
          m[bastion][sshd, port 2222],
          text(size: 9pt)[← ssh, port 22 →],
          m[serveur][sshd, port 22 \ supervision : 127.0.0.1:8000],
        )),
    ),
  ))
})

= Étape 1 : monter le labo <etape-1>

#bloc(role: "question")[Consignes][
  - Construisez l’image des trois machines et démarrez-les en arrière-plan.
  - Lisez le journal de `sshd` du bastion et du serveur : sur quels ports écoutent-ils ?
  - Ouvrez une session sur le poste, en tant qu’`ada` : c’est d’ici que partent les étapes 2 à 10.
]

#indice(titre: [Indice : les trois machines])[
  `compose.yaml` décrit trois services : `poste`, `bastion` (sur les deux réseaux) et `serveur` (réseau privé
  seulement). `docker compose up -d --build` construit et démarre ; `docker compose logs` montre les journaux ;
  `docker compose exec -u ada poste bash` ouvre un shell dans un service qui tourne.
]

#corrige[
  #terminal[```console
  $ docker compose up -d --build
  $ docker compose ps --format 'table {{.Service}}\t{{.Status}}'
  $ docker compose logs bastion serveur
  # le poste d’Ada : tout ce qui suit s’y tape, sauf mention contraire
  $ docker compose exec -u ada poste bash
  ```]
  #f("etape-1-labo.sh")
  Le labo : #f("compose.yaml") #f("machine/Dockerfile") #f("machine/demarrer.sh")
  Chaque machine fabrique ses clés d’hôte à son premier démarrage (`ssh-keygen -A`) : deux machines, deux
  identités. Le journal annonce `Server listening on 0.0.0.0 port 2222` pour le bastion, `22` pour le serveur.
]

= Étape 2 : la paire de clés <etape-2>

#bloc(role: "question")[Consignes][
  - Sur le poste, créez une paire de clés *Ed25519*, protégée par une phrase de passe.
  - Quels fichiers sont apparus dans `~/.ssh`, avec quels droits ? Lequel ne doit jamais quitter le poste ?
  - Prouvez que la clé privée est chiffrée : comment le voir ?
]

#indice(titre: [Indice : la commande])[
  #d("ssh-keygen")[Générer la paire de clés : ssh-keygen]. Acceptez l’emplacement par défaut ; tapez la phrase de
  passe deux fois (elle ne s’affiche pas). Avec une clé chiffrée, `ssh-keygen -y -f ~/.ssh/id_ed25519` réclame la phrase
  pour recalculer la clé publique.
]

#corrige[
  #terminal[```console
  $ ssh-keygen -t ed25519
  $ ls -l ~/.ssh
  # la phrase de passe est demandée : une clé chiffrée ne se laisse pas lire sans elle
  $ ssh-keygen -y -f ~/.ssh/id_ed25519
  ```]
  La clé privée `id_ed25519` est en `rw-------` (600) ; la clé publique `id_ed25519.pub` peut circuler :
  #d("cle-ssh")[Clé SSH : qui détient quoi, qui prouve quoi]. Le script du corrigé tente de lire la clé avec une
  phrase vide : la tentative doit échouer, ce qui prouve le chiffrement.
  #f("etape-2-cles.sh")
]

= Étape 3 : vérifier l’empreinte du bastion <etape-3>

#bloc(role: "question")[Consignes][
  - Lisez l’empreinte de la clé d’hôte Ed25519 du bastion *sur sa console*, c’est-à-dire par un autre canal que SSH.
  - Connectez-vous au bastion (`ada`, port 2222) par mot de passe : `ssh` affiche l’empreinte qu’il reçoit.
    Comparez-la à celle de la console, et répondez `yes` seulement si elles sont identiques.
  - Où `ssh` a-t-il mémorisé la clé du bastion ?
]

#indice(titre: [Indice : la console du bastion])[
  Sur *votre machine*, dans le dossier du labo : `docker compose exec bastion ssh-keygen -lf
  /etc/ssh/ssh_host_ed25519_key.pub`. L’empreinte est le mot qui commence par `SHA256:`.
  #d("empreinte-serveur")[Première connexion : vérifier l’empreinte].
]

#corrige[
  #terminal[```console
  # sur votre machine, dans un second terminal
  $ docker compose exec bastion ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
  # sur le poste : comparer l’empreinte affichée, puis répondre yes
  $ ssh -p 2222 ada@bastion hostname
  $ ssh-keygen -lF '[bastion]:2222'
  ```]
  Le port 2222 est enregistré avec le nom : `[bastion]:2222`. Le script ne répond pas `yes` à la place de
  l’étudiant : il récupère la clé d’hôte avec `ssh-keyscan`, compare son empreinte à celle de la console, et
  s’arrête si elles diffèrent. Il ne l’ajoute à `known_hosts` qu’en cas d’égalité. Si l’empreinte change plus tard,
  `ssh` refuse de se connecter : #d("cle-hote-changee")[La clé d’hôte a changé : ssh refuse].
  #f("etape-3-empreinte.sh")
]

= Étape 4 : déposer la clé publique <etape-4>

#bloc(role: "question")[Consignes][
  - Installez votre clé publique sur le bastion avec `ssh-copy-id`, sans modifier le fichier à la main.
  - Reconnectez-vous : que demande `ssh` maintenant ?
  - Sur le bastion, quels droits doivent avoir `~/.ssh` et `authorized_keys`, et que se passe-t-il s’ils sont trop larges ?
]

#indice(titre: [Indice : ssh-copy-id])[
  `ssh-copy-id` se connecte par mot de passe, ajoute la clé publique à `~/.ssh/authorized_keys` du serveur, et
  règle les droits. Le port se donne avec `-p`, comme pour `ssh` :
  #d("ssh-copy-id")[Déployer la clé publique : ssh-copy-id].
]

#corrige[
  #terminal[```console
  $ ssh-copy-id -p 2222 ada@bastion
  $ ssh -p 2222 ada@bastion 'hostname; ls -l ~/.ssh'
  ```]
  Le mot de passe d’`ada` n’est demandé qu’à `ssh-copy-id`. Ensuite `ssh` demande la *phrase de passe de la clé*,
  non plus le mot de passe du compte. `authorized_keys` est en `rw-------` ; avec des droits trop larges, `sshd`
  ignore le fichier (`StrictModes`) : #d("strictmodes")[Plus de mot de passe… si les droits sont stricts].
  #f("etape-4-deposer-cle.sh")
]

= Étape 5 : l’agent <etape-5>

#bloc(role: "question")[Consignes][
  - Démarrez un `ssh-agent` et confiez-lui votre clé : la phrase de passe se tape une fois.
  - Connectez-vous au bastion avec `-o BatchMode=yes`, qui interdit toute question : cela doit réussir.
  - Faites en sorte que les nouveaux terminaux du poste retrouvent l’agent.
]

#indice(titre: [Indice : l’adresse de l’agent])[
  `ssh` retrouve l’agent par la variable `SSH_AUTH_SOCK`. `eval "$(ssh-agent)"` la définit pour le shell courant
  seulement. `ssh-agent -a <chemin>` fixe l’adresse de la socket : un autre terminal peut alors exporter la même
  variable. #d("agent-ssh")[Protéger la clé privée : passphrase, agent].
]

#corrige[
  #terminal[```console
  $ export SSH_AUTH_SOCK=~/.ssh/agent.sock
  $ eval "$(ssh-agent -a "$SSH_AUTH_SOCK")"
  $ ssh-add
  $ ssh-add -l
  $ ssh -o BatchMode=yes -p 2222 ada@bastion hostname
  $ echo 'export SSH_AUTH_SOCK=~/.ssh/agent.sock' >> ~/.bashrc
  ```]
  #f("etape-5-agent.sh")
]

= Étape 6 : `~/.ssh/config` <etape-6>

#bloc(role: "question")[Consignes][
  - Écrivez dans `~/.ssh/config` l’entrée `bastion` : machine `bastion`, compte `ada`, port 2222. Vérifiez que seul
    le propriétaire peut lire le fichier.
  - Vérifiez ce que `ssh` retient, *sans vous connecter*, puis connectez-vous par `ssh bastion`.
]

#indice(titre: [Indice : les mots-clés])[
  `Host` (l’alias tapé), `HostName`, `User`, `Port` : #d("ssh-config")[~/.ssh/config : le carnet d’adresses du
  client]. `ssh -G bastion` affiche la configuration retenue sans ouvrir de connexion.
]

#corrige[
  #terminal[```console
  $ nano ~/.ssh/config
  $ chmod 600 ~/.ssh/config
  $ ssh -G bastion | grep -E '^(hostname|user|port) '
  $ ssh bastion hostname
  ```]
  Le fichier `config` du corrigé contient déjà l’entrée `serveur` de l’étape 7 ; le script copié ici ne s’en sert
  pas encore.
  #f("config")
  #f("etape-6-config.sh")
]

= Étape 7 : le rebond par le bastion <etape-7>

#bloc(role: "question")[Consignes][
  - Depuis le poste, le serveur existe-t-il ? Pourquoi ?
  - Ajoutez l’entrée `serveur` à `~/.ssh/config` pour qu’un simple `ssh serveur` passe par le bastion.
  - Vérifiez l’empreinte du serveur (sa console, comme à l’étape 3), déposez votre clé sur lui et connectez-vous.
  - D’où le serveur voit-il venir la connexion ? Que contient `~/.ssh` sur le bastion ?
]

#indice(titre: [Indice : ProxyJump])[
  `ProxyJump bastion` dans l’entrée `serveur` : #d("proxyjump")[Le rebond par un bastion : ProxyJump]. La variable
  `SSH_CONNECTION`, lue sur le serveur, donne l’adresse du client telle que le serveur la voit.
]
#indice(titre: [Indice : l’empreinte du serveur])[
  Le poste ne joint pas le serveur : `ssh-keyscan` s’exécute donc *sur le bastion* (`ssh bastion ssh-keyscan …`).
  La console du serveur donne l’empreinte attendue : `docker compose exec serveur ssh-keygen -lf …`.
]

#corrige[
  #terminal[```console
  $ getent hosts serveur || echo "le poste ne résout pas serveur"
  # sur votre machine : l’empreinte du serveur
  $ docker compose exec serveur ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
  # sur le poste, après avoir ajouté l’entrée serveur à ~/.ssh/config
  $ ssh-copy-id serveur
  $ ssh serveur hostname
  $ ssh serveur 'echo $SSH_CONNECTION'
  ```]
  Le poste n’est que sur le réseau `public` : le nom `serveur` ne s’y résout pas. L’adresse affichée par
  `SSH_CONNECTION` est celle du bastion sur le réseau privé : le serveur ne voit jamais le poste. La session
  SSH va pourtant du poste au serveur, et la clé privée reste sur le poste : le bastion ne fait que relayer des
  octets chiffrés, et son `~/.ssh` ne contient que `authorized_keys`. #d("agent-transfert")[Transfert d’agent (-A) : un risque réel]
  explique pourquoi on préfère `ProxyJump` à `-A`.
  #f("etape-7-rebond.sh")
]

= Étape 8 : `scp` et `rsync` <etape-8>

#bloc(role: "question")[Consignes][
  - Créez `rapport.txt` et un dossier `site/` de deux pages sur le poste. Copiez `rapport.txt` dans `/tmp` du serveur avec `scp`.
  - Envoyez `site/` sur le serveur avec `rsync`. Modifiez une page et recommencez : que se passe-t-il ?
  - Quelle différence fait la barre finale de `site/` dans la commande `rsync` ?
]

#indice(titre: [Indice : les options])[
  #d("scp-rsync")[Copier des fichiers : scp et rsync]. `scp` et `rsync` lisent `~/.ssh/config` : `serveur:` suffit,
  le rebond est automatique. `rsync -a` copie récursivement en gardant droits et dates, `-v` détaille ; `-n`
  montre ce qui serait fait sans rien faire.
]

#corrige[
  #terminal[```console
  $ cd ~
  $ echo "Rapport du poste d’Ada" > rapport.txt
  $ mkdir -p site && echo accueil > site/index.html && echo contact > site/contact.html
  $ scp rapport.txt serveur:/tmp/
  $ rsync -av site/ serveur:site/
  $ echo "accueil, version 2" > site/index.html
  $ rsync -av site/ serveur:site/
  ```]
  Au second passage, seul `index.html` repart. Avec `site/` (barre finale), `rsync` copie le *contenu* de
  `site` dans `site/` du serveur ; sans la barre, il copierait le dossier lui-même et créerait `site/site/`.
  #f("etape-8-copier.sh")
]

= Étape 9 : une redirection de port <etape-9>

#bloc(role: "question")[Consignes][
  - Sur le serveur, la page de supervision n’écoute que sur `127.0.0.1:8000`. Vérifiez-le, et vérifiez qu’elle est
    injoignable depuis le poste.
  - Faites apparaître cette page sur le port 8080 du poste, avec une redirection locale, sans ouvrir de shell sur le serveur.
  - Que veulent dire `-f` et `-N` ? Dans `-L 8080:localhost:8000`, qui résout `localhost` ?
]

#indice(titre: [Indice : -L])[
  #d("redirections-port")[Trois redirections de port] : `-L port_local:hôte:port_hôte`, et `hôte` est résolu *par
  le serveur*, donc `localhost` y est le serveur lui-même. `-N` n’exécute aucune commande, `-f` passe en arrière-plan.
  #d("redirections-demo")[Les trois redirections à l’œuvre].
]

#corrige[
  #terminal[```console
  $ ssh serveur 'ss -ltn | grep ":8000 "'
  $ curl -sS localhost:8080 || echo "rien sur le port 8080"
  $ ssh -f -N -o ExitOnForwardFailure=yes -L 8080:localhost:8000 serveur
  $ curl -sS localhost:8080
  Supervision : tout va bien
  ```]
  `ss` montre une écoute sur `127.0.0.1:8000` seulement : le service est fermé au reste du réseau. `-f -N` ouvre le
  tunnel en arrière-plan sans commande ; `ExitOnForwardFailure` fait échouer `ssh` si le port 8080 est déjà pris.
  Le tunnel reste ouvert tant que son processus `ssh` tourne : `pkill -f 'ssh -f -N'` le ferme.
  #f("etape-9-tunnel.sh")
]

= Étape 10 : durcir `sshd` sans se couper l’accès <etape-10>

#bloc(role: "danger")[Gardez une porte ouverte][
  Un durcissement raté enferme dehors. Avant de toucher à la configuration, ouvrez dans un *autre terminal* une
  session `ssh serveur` et laissez-la ouverte : elle survit au rechargement de `sshd`, et c’est par elle que vous
  réparerez en cas d’erreur. #d("durcir-sshd")[Interdire le mot de passe, proprement].
]

#bloc(role: "question")[Consignes][
  - Sur la console du serveur, lisez la configuration effective de `sshd` : mot de passe, connexion de `root`.
  - Le labo n’installe aucune clé pour `root` : autorisez la vôtre sur le serveur (par la console), et constatez que
    `root` entre *avant* le durcissement. Sans cela, `root` serait refusé avant comme après : la vérification
    ne prouverait rien.
  - Interdisez le mot de passe et la connexion de `root`, par un *fichier à vous* dans `sshd_config.d`. Pourquoi
    pas une ligne de plus dans `sshd_config` ?
  - Vérifiez la syntaxe *avant* de recharger, puis rechargez.
  - Depuis le poste, ouvrez une *nouvelle* connexion : le mot de passe est refusé, `root` aussi (alors qu’il entrait
    tout à l'heure), la clé d’`ada` passe.
]

#indice(titre: [Indice : l’ordre de lecture])[
  Pour chaque mot-clé, `sshd` garde la *première* valeur lue, et `sshd_config` inclut `sshd_config.d/*.conf` en tête,
  dans l’ordre alphabétique. Le labo pose `50-cloud-init.conf` (`PasswordAuthentication yes`), comme bien des
  images cloud : votre fichier doit s’appeler `10-…` pour être lu avant lui. #d("piege-sshd")[Modifier sshd_config… sans effet].
]
#indice(titre: [Indice : vérifier, recharger])[
  `sshd -T` affiche la configuration effective, `sshd -t` ne vérifie que la syntaxe. Sur un vrai serveur :
  `systemctl reload ssh`. Le labo n’a pas systemd : `sshd` relit sa configuration sur le signal `SIGHUP`
  (`pkill -HUP -x sshd`).
]

#corrige[
  #terminal[```console
  # sur votre machine : la console du serveur
  $ docker compose exec serveur sh -c "sshd -T | grep -E '^(passwordauthentication|permitrootlogin) '"
  # votre clé, déjà autorisée pour ada, l'est aussi pour root
  $ docker compose exec serveur sh -c 'install -d -m 700 /root/.ssh && cp /home/ada/.ssh/authorized_keys /root/.ssh/authorized_keys'
  # sur le poste : avant le durcissement, root entre
  $ ssh -o BatchMode=yes root@serveur hostname
  serveur
  # sur votre machine : la console du serveur
  $ docker compose cp 10-durcissement.conf serveur:/etc/ssh/sshd_config.d/10-durcissement.conf
  $ docker compose exec serveur sshd -t
  $ docker compose exec serveur pkill -HUP -x sshd
  # sur le poste : une nouvelle connexion
  $ ssh -o BatchMode=yes -o PubkeyAuthentication=no serveur hostname
  $ ssh -o BatchMode=yes root@serveur hostname
  $ ssh serveur hostname
  ```]
  Avant : `passwordauthentication yes` et `permitrootlogin without-password` (l’ancien nom de `prohibit-password` :
  `root` entre par clé, mais seulement si une clé est autorisée pour lui : d’où la copie d’`authorized_keys` vers
  `/root/.ssh`, faite par la console). Une ligne ajoutée à `sshd_config` n’aurait rien changé : le fichier inclus en tête l’emporte.
  Après : le serveur ne propose plus que `publickey`, `root` est refusé même avec une clé autorisée, et la session
  ouverte avant le rechargement est toujours vivante. Le bastion, lui, n’est pas durci : il accepte encore le mot de passe.
  #f("10-durcissement.conf")
  #f("etape-10-root.sh")
  #f("etape-10-durcir.sh")
  #f("etape-10-verifier.sh")
]

= Nettoyer <nettoyer>

#corrige(titre: [Corrigé : supprimer le labo])[
  #terminal[```console
  $ docker compose down --volumes --rmi local
  ```]
  Les clés d’hôte disparaissent avec les conteneurs : au prochain labo, les machines auront de nouvelles
  identités, et le `known_hosts` d’un ancien poste signalerait un changement de clé.
]
