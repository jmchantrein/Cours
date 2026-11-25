// Cours « Accès distants : SSH, tmux, WireGuard » — Typst + Touying.
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts acces-distants/cm/acces-distants.typ build/acces-distants/acces-distants.pdf
// Une diapo = un titre `==` ; une section (surtitre bleu) = un titre `=`.
// Structure : règles de .claude/skills/structurer-diapos-cours ; apparence : charte de commun/.
// Sorties des terminaux : acces-distants/cm/rejouer.sh (laboratoire de conteneurs jetables).

#import "../../commun/theme-cours.typ": *

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Accès distants : SSH, tmux, WireGuard],
)

// ---------- Schémas du cours ----------
// Une machine : le poste d’Ada (client) en bleu, une machine où l’on entre à distance en violet,
// comme les cadres des terminaux (niveau 0 : poste local, niveau 1 : session distante).
#let machine(nom, role: none, distant: true, taille: px(28)) = {
  let couleur = if distant { c.invite } else { c.bleu }
  block(width: 100%, fill: if distant { c.invite-clair } else { c.appli }, stroke: px(3) + couleur,
    radius: px(12), inset: (x: px(12), y: px(10)),
    align(center, {
      text(size: taille, weight: 600, fill: couleur, nom)
      if role != none { linebreak(); text(size: px(20), fill: c.encre, role) }
    }))
}
// Flèche horizontale, avec un libellé au-dessus et au-dessous.
#let fleche(haut: none, bas: none, vers: "droite", couleur: c.gris, taille: px(20)) = {
  let trait = layout(t => box(width: t.width, height: px(18), {
    if vers == "droite" {
      place(left + horizon, line(length: t.width - px(14), stroke: px(3) + couleur))
      place(right + horizon, polygon(fill: couleur, (0pt, 0pt), (px(18), px(9)), (0pt, px(18))))
    } else {
      place(right + horizon, line(length: t.width - px(14), stroke: px(3) + couleur))
      place(left + horizon, polygon(fill: couleur, (px(18), 0pt), (0pt, px(9)), (px(18), px(18))))
    }
  }))
  stack(spacing: px(6),
    ..(
      if haut != none { align(center, text(size: taille, fill: couleur, haut)) },
      trait,
      if bas != none { align(center, text(size: taille, fill: couleur, bas)) },
    ).filter(x => x != none))
}
// Une ligne de fichier dans un schéma : chemin en police mono, puis son rôle.
#let fichier-cle(chemin, role) = block(width: 100%, fill: c.fond, radius: px(8), inset: (x: px(12), y: px(8)),
  { text(font: mono, size: px(20), fill: c.bleu, chemin); linebreak(); text(size: px(21), role) })

#couverture(illustration: "vm")[Accès distants][SSH, tmux, WireGuard][Jean-Mathieu Chantrein][25 novembre 2026]
#speaker-note[Trois outils pour travailler sur des machines qu’on ne voit pas : SSH pour y entrer, tmux pour ne pas perdre son travail quand la connexion tombe, WireGuard pour relier des réseaux. L’illustration de couverture est provisoire (celle du cours Virtualisation) : la charte n’a pas encore d’illustration propre à ce cours.]

// ======================================================================
= Sommaire

== Plan du cours

#anime(plan-anime(
  ([SSH : accès distants sécurisés], [Clés, configuration du client, bastion, redirections de port, transferts, durcissement du serveur]),
  ([tmux : le terminal qui survit à la déconnexion], [Session, fenêtre, panneau ; détacher, rattacher ; piloter par script]),
  ([WireGuard : le VPN moderne], [Pairs et clés, wg-quick, AllowedIPs : routage et filtrage]),
  ([Pour rappel], [L’essentiel des trois parties]),
), note: [Une partie par clic. Chaque partie se termine par un exercice fait en séance, puis son corrigé. Durée d’origine dans le cours de l’auteur : SSH 2 h, WireGuard 2 h ; tmux y était une digression de la partie SSH.])

// ======================================================================
= SSH · accès distants sécurisés

== Administrer une machine qu’on ne voit pas <ssh-intro>

#anime(
  rang(
    bloc(taille: px(26))[SSH (_Secure Shell_)][
      - Un protocole réseau qui ouvre une session *chiffrée* sur une machine distante : shell, commandes, fichiers, tunnels
      - Le client `ssh` contacte le serveur `sshd`, qui écoute par défaut sur le port 22 en TCP (_Transmission Control Protocol_)
      - Implémentation de référence : *OpenSSH*, livrée avec Linux, macOS et Windows
    ],
    bloc(role: "pratique", taille: px(26))[Le fil rouge : Ada et trois machines][
      - `client` : le poste d’Ada, d’où partent toutes les commandes
      - `bastion` : la seule machine joignable depuis l’extérieur
      - `serveur` : sur un réseau privé, joignable seulement depuis le bastion
    ],
  ),
  grid(columns: (1fr, px(250), 1fr, px(250), 1fr), align: horizon, column-gutter: px(12),
    machine(distant: false, role: [poste d’Ada])[client],
    fleche(haut: [réseau public]),
    machine(role: [porte d’entrée])[bastion],
    fleche(haut: [réseau privé]),
    machine(role: [la machine à administrer])[serveur],
  ),
  source-de: [#link("https://man.openbsd.org/ssh")[man.openbsd.org/ssh] · #link("https://man.openbsd.org/sshd")[man.openbsd.org/sshd]],
  note: [Pour les démonstrations, client, bastion et serveur sont des conteneurs jetables reliés par deux réseaux (public, privé) : un laboratoire. Le cours Conteneurisation enseigne de ne pas faire tourner sshd dans un conteneur en production ; ici, les conteneurs jouent le rôle de machines. Toutes les sorties viennent de `acces-distants/cm/rejouer.sh`, rejoué le 25 novembre 2026 avec OpenSSH 9.6p1 (Ubuntu 24.04 : les miroirs Debian étaient inaccessibles depuis l’environnement de rédaction). À rejouer sur Debian 13 (OpenSSH 10.0p1) : les messages peuvent changer légèrement.],
)

== Le mot de passe, maillon faible

#anime(
  rang(
    bloc(role: "avertissement", taille: px(26))[Trois faiblesses d’un mot de passe][
      - *Force brute* : un attaquant essaie un grand nombre de combinaisons sur le port 22 d’une machine exposée
      - *Vol* : hameçonnage, enregistreur de frappe, ou saisie sur un service non chiffré (web en HTTP, annuaire LDAP sans TLS)
      - *Réutilisation* : le même mot de passe sert ailleurs ; compromis une fois, compromis partout
    ],
    bloc(role: "precaution", taille: px(26))[Ce que SSH protège déjà][
      - Le mot de passe traverse le réseau *chiffré* : un espion du réseau ne le lit pas
      - Mais le serveur le reçoit, et il se devine ou se vole ailleurs
    ],
  ),
  rang(bloc(role: "retenir", taille: px(26))[À retenir][
    Remplacer le mot de passe par une *paire de clés* : la partie secrète ne quitte jamais le poste.
  ]),
  source-de: link("https://man.openbsd.org/ssh#AUTHENTICATION")[man ssh, section AUTHENTICATION],
  note: [Cours d’origine : « Attente d’un mot de passe = potentiel problème de sécurité ! À voir en fonction de l’usage du serveur ». man ssh : « the password is sent to the remote host for checking; however, since all communications are encrypted, the password cannot be seen by someone listening on the network ». TLS : Transport Layer Security, le chiffrement du web (HTTPS) et des annuaires (LDAPS).],
)

== Clé SSH : qui détient quoi, qui prouve quoi <cle-ssh>

#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (px(560), 1fr, px(560)), column-gutter: px(24), align: horizon,
    block(width: 100%, stroke: px(3) + c.bleu, radius: px(12), inset: px(14), fill: c.appli, stack(spacing: px(10),
      align(center, text(size: px(30), weight: 600, fill: c.bleu)[client (Ada)]),
      fichier-cle("~/.ssh/id_ed25519", [clé *privée* d’Ada : secrète, ne quitte jamais le poste]),
      fichier-cle("~/.ssh/known_hosts", [clés *publiques* des serveurs déjà rencontrés]),
    )),
    stack(spacing: px(36),
      uncover("2-", fleche(vers: "gauche", couleur: c.invite, haut: [① le serveur prouve son identité], bas: [signature par sa clé d’hôte ; le client la compare à `known_hosts`])),
      uncover("3-", fleche(couleur: c.bleu, haut: [② Ada prouve qu’elle détient sa clé privée], bas: [signature de données propres à cette connexion ; vérifiée avec `authorized_keys`])),
    ),
    block(width: 100%, stroke: px(3) + c.invite, radius: px(12), inset: px(14), fill: c.invite-clair, stack(spacing: px(10),
      align(center, text(size: px(30), weight: 600, fill: c.invite)[bastion (serveur sshd)]),
      fichier-cle("~/.ssh/authorized_keys", [clés *publiques* autorisées à entrer sur le compte `ada`]),
      fichier-cle("/etc/ssh/ssh_host_ed25519_key", [clé *privée* d’hôte du serveur : secrète]),
    )),
  )
  v(px(32))
  uncover("4-", colonnes(bloc(role: "retenir", taille: px(26))[À retenir][
    Chacun garde sa clé privée ; seules des *signatures* traversent le réseau. Une clé publique volée ne permet pas d’entrer : elle sert seulement à vérifier.
  ]))
  source[#link("https://man.openbsd.org/ssh#AUTHENTICATION")[man ssh, AUTHENTICATION] · #link("https://www.rfc-editor.org/rfc/rfc4252#section-7")[RFC 4252, § 7] · #link("https://www.rfc-editor.org/rfc/rfc4253#section-8")[RFC 4253, § 8]]
  utils.speaker-note(self: self)[Un clic par étape. Ordre réel du protocole : d’abord l’échange de clés, où le serveur signe avec sa clé d’hôte (RFC 4253, § 8) ; le client vérifie cette clé contre known\_hosts. Ensuite l’authentification de l’utilisateur (RFC 4252, § 7) : le client signe des données qui contiennent l’identifiant de session, propre à cette connexion ; le serveur vérifie la signature avec la clé publique trouvée dans authorized\_keys. Le cours d’origine parlait d’un « défi cryptographique que seule la clé privée peut résoudre » : c’est l’idée, la signature de données propres à la session en est la forme exacte (man ssh : « The client proves that it has access to the private key and the server checks that the corresponding public key is authorized »). Diapo de référence pour l’artefact « décision de connexion SSH » et le TP SSH.]
})

== Générer la paire de clés : ssh-keygen <ssh-keygen>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.45, taille: px(24))[Sur le poste d’Ada][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        $ ssh-keygen -t ed25519
        Generating public/private ed25519 key pair.
        Enter file in which to save the key (/home/ada/.ssh/id_ed25519):
        Created directory '/home/ada/.ssh'.
        Enter passphrase (empty for no passphrase):
        Enter same passphrase again:
        Your identification has been saved in /home/ada/.ssh/id_ed25519
        Your public key has been saved in /home/ada/.ssh/id_ed25519.pub
        The key fingerprint is:
        SHA256:+Zy9p3f5oJM7JE3rg1LrKHzZJXqTK9GBy7zIdV2/P6E ada@client
        # … puis le dessin de l’empreinte (randomart, 11 lignes)
        $ ls -l ~/.ssh
        total 8
        -rw------- 1 ada ada 399 Nov 25 10:17 id_ed25519
        -rw-r--r-- 1 ada ada  92 Nov 25 10:17 id_ed25519.pub
        ```
      ]
    ],
    bloc(taille: px(24))[Lire la sortie][
      - Entrée : l’emplacement par défaut, `~/.ssh/id_ed25519`
      - Passphrase laissée vide ici : voir la diapositive suivante
      - `id_ed25519` : la clé *privée*, lisible par Ada seule (`rw-------`)
      - `id_ed25519.pub` : la clé *publique*, à copier sur les serveurs
      - `SHA256:…` : l’*empreinte*, un résumé court qui identifie la clé
    ],
  ),
  note(role: "precaution", taille: px(22))[*Ed25519 plutôt que RSA 4096* : la version d’origine de ce cours conseillait `ssh-keygen -t rsa -b 4096`. OpenSSH crée aujourd’hui une clé Ed25519 par défaut : courte, rapide, sans taille à choisir. RSA reste pour un très vieux serveur qui ignore Ed25519.],
  source-de: link("https://man.openbsd.org/ssh-keygen")[man ssh-keygen],
  note: [OpenSSH 9.6p1 (Ubuntu 24.04) ; à rejouer sur Debian 13 (OpenSSH 10.0p1). man ssh-keygen : « If invoked without any arguments, ssh-keygen will generate an Ed25519 key ». Les trois Entrée : emplacement par défaut, puis passphrase vide deux fois. Le commentaire ada\@client est rempli par défaut avec utilisateur\@machine. Le dessin (randomart) sert à comparer deux empreintes d’un coup d’œil ; il est omis faute de place.],
)

== Protéger la clé privée : passphrase, agent <agent-ssh>

#anime(
  rang(
    bloc(taille: px(25))[Trois façons de protéger la clé privée][
      - *Passphrase* : la clé est chiffrée sur le disque ; volée, elle est inutilisable sans la phrase. Mais elle se tape à chaque usage : gênant pour un script
      - *Disque entièrement chiffré* (LUKS, _Linux Unified Key Setup_) : la clé est protégée quand le poste est éteint ou volé, et les scripts restent possibles : le choix conseillé dans ce cours pour l’administration
      - *Agent* : `ssh-agent` garde la clé déchiffrée en mémoire ; la passphrase se tape une fois par session
    ],
    bloc(role: "pratique", poids: 1.1, taille: px(24))[L’agent en pratique][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        # démarre l’agent et exporte son adresse
        $ eval "$(ssh-agent)"
        Agent pid 253
        # confie la clé à l’agent (passphrase demandée s’il y en a une)
        $ ssh-add
        Identity added: /home/ada/.ssh/id_ed25519 (ada@client)
        # clés détenues par l’agent
        $ ssh-add -l
        256 SHA256:+Zy9p3f5oJM7JE3rg1LrKHzZJXqTK9GBy7zIdV2/P6E ada@client (ED25519)
        ```
      ]
      `ssh` demande ensuite chaque signature à l’agent, sans relire la clé.
    ],
  ),
  source-de: [#link("https://man.openbsd.org/ssh-agent")[man ssh-agent] · #link("https://man.openbsd.org/ssh-add")[man ssh-add]],
  note: [Choix de l’auteur dans le cours d’origine : la passphrase est peu pratique en administration système (scripts, cron) ; on préfère chiffrer tout le stockage du poste ou du serveur, ce qui protège la clé en cas de vol du disque. Le site ajoutait « à défaut, passphrase + agent ». La clé de la démonstration n’a pas de passphrase : ssh-add ne demande rien. L’agent écoute sur une socket Unix dont eval exporte le chemin (variable SSH\_AUTH\_SOCK). Sur un bureau Linux, un agent tourne souvent déjà (GNOME Keyring, KeePassXC).],
)

== Déployer la clé publique : ssh-copy-id <ssh-copy-id>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.55, taille: px(24))[Première connexion au bastion][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        $ ssh-copy-id ada@bastion
        /usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/ada/.ssh/id_ed25519.pub"
        The authenticity of host 'bastion (172.18.0.3)' can't be established.
        ED25519 key fingerprint is SHA256:tyfoZhF/lIT3fCB704iqukU924CaAI+Nb5t24lT8nlY.
        This key is not known by any other names.
        Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
        /usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), […]
        /usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- […]
        ada@bastion's password:

        Number of key(s) added: 1

        Now try logging into the machine, with:   "ssh 'ada@bastion'"
        and check to make sure that only the key(s) you wanted were added.
        ```
      ]
    ],
    bloc(taille: px(24))[Trois étapes][
      + Le bastion est inconnu : ssh montre l’*empreinte de sa clé d’hôte* ; on la vérifie (diapositive suivante), puis `yes`
      + Le mot de passe d’`ada`, *une dernière fois*
      + La clé publique est ajoutée à `~/.ssh/authorized_keys` sur le bastion
    ],
  ),
  source-de: link("https://man.openbsd.org/ssh-copy-id")[man ssh-copy-id],
  note: [Sortie réelle (OpenSSH 9.6p1) ; deux lignes INFO trop longues sont coupées et signalées par […] : « attempting to log in with the new key(s), to filter out any that are already installed » et « 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys ». ssh-copy-id suppose que le mot de passe est encore accepté : c’est l’amorçage. Sans ssh-copy-id : copier le contenu de id\_ed25519.pub à la fin de \~/.ssh/authorized\_keys sur le serveur, avec les droits 700 sur \~/.ssh et 600 sur le fichier.],
)

== Première connexion : vérifier l’empreinte <empreinte-serveur>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.4, taille: px(24))[Comparer les deux empreintes][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        # affichée par ssh à la première connexion :
        ED25519 key fingerprint is SHA256:tyfoZhF/lIT3fCB704iqukU924CaAI+Nb5t24lT8nlY.
        ```
        #cadre([bastion · root, sur la console de la machine], niveau: 1)[
          ```
          # empreinte de la clé d’hôte, lue sur le bastion lui-même
          $ ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
          256 SHA256:tyfoZhF/lIT3fCB704iqukU924CaAI+Nb5t24lT8nlY root@bastion (ED25519)
          ```
        ]
        ```
        # après « yes », la clé est mémorisée (nom de machine haché)
        $ head -c 60 ~/.ssh/known_hosts; echo
        |1|3vM/QS8QmAyORGoq59+mzDxAGbI=|i/M3rqCSxUPxrQFBa3zPCPPJDzM=
        ```
      ]
    ],
    bloc(taille: px(24))[Pourquoi comparer][
      - La première fois, ssh ne peut rien vérifier : seul un *autre canal* (console, documentation de l’équipe) dit quelle est la bonne empreinte
      - Accepter l’enregistre dans `~/.ssh/known_hosts`
      - Ensuite, ssh vérifie la clé d’hôte à *chaque* connexion, sans rien demander
    ],
  ),
  source-de: link("https://man.openbsd.org/ssh#AUTHENTICATION")[man ssh, AUTHENTICATION],
  note: [Les deux empreintes sont identiques : c’est bien le bastion. Répondre yes sans comparer revient à faire confiance à la première machine qui répond. Les noms de machine sont hachés dans known\_hosts (option HashKnownHosts, activée par défaut sur Debian et Ubuntu) : un voleur du fichier n’apprend pas la liste des serveurs. Lire cette ligne entière n’apprend rien de plus : 60 caractères suffisent à montrer le hachage.],
)

== La clé d’hôte a changé : ssh refuse <cle-hote-changee>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.55, taille: px(24))[Le bastion a été réinstallé… ou pas][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        $ ssh ada@bastion hostname
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
        Someone could be eavesdropping on you right now (man-in-the-middle attack)!
        It is also possible that a host key has just been changed.
        The fingerprint for the ED25519 key sent by the remote host is
        SHA256:h4HoJFT7dBBfeO/aR7fU5kSOAPPT5AWgu4syDqR2ZAc.
        Please contact your system administrator.
        Add correct host key in /home/ada/.ssh/known_hosts to get rid of this message.
        Offending ECDSA key in /home/ada/.ssh/known_hosts:3
          remove with:
          ssh-keygen -f '/home/ada/.ssh/known_hosts' -R 'bastion'
        Host key for bastion has changed and you have requested strict checking.
        Host key verification failed.
        ```
      ]
    ],
    bloc(role: "danger", taille: px(24))[Deux explications possibles][
      - Le serveur a été *réinstallé* : nouvelles clés d’hôte, alerte légitime
      - Une machine s’intercale entre le client et le serveur : *attaque de l’homme du milieu*
      - Avant tout : vérifier la nouvelle empreinte par un autre canal
      - Puis seulement : `ssh-keygen -R bastion` retire l’ancienne clé ; la connexion suivante redemande l’empreinte
    ],
  ),
  source-de: link("https://man.openbsd.org/ssh-keygen")[man ssh-keygen, option -R],
  note: [Démonstration : les clés d’hôte du bastion ont été régénérées (ssh-keygen -A), comme après une réinstallation. ssh refuse la connexion (code de retour 255) : la vérification stricte de la clé d’hôte est un refus, pas un avertissement. man ssh : si l’identification change, ssh avertit et désactive l’authentification par mot de passe, pour empêcher une usurpation du serveur. Après ssh-keygen -R bastion (trois lignes retirées : une par type de clé, Ed25519, RSA, ECDSA), la connexion suivante redemande l’empreinte SHA256:h4HoJ…ZAc, comme à la première connexion.],
)

== Plus de mot de passe… si les droits sont stricts <strictmodes>

#anime(
  rang(
    bloc(role: "pratique", taille: px(24))[Connexion par clé][
      #terminal(titre: [client · ada], taille: px(18))[
        #cadre([bastion · ada], niveau: 1)[
          ```
          $ ls -l ~/.ssh; cat ~/.ssh/authorized_keys
          total 4
          -rw------- 1 ada ada 92 Nov 25 10:17 authorized_keys
          ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJyuEKPbuNSr8gX…
          ```
        ]
        ```
        # plus de mot de passe demandé
        $ ssh ada@bastion hostname
        bastion
        ```
      ]
      La ligne d’`authorized_keys` est la copie exacte de `id_ed25519.pub`.
    ],
    bloc(role: "avertissement", taille: px(24))[StrictModes : des droits trop larges, et la clé est ignorée][
      #terminal(titre: [client · ada], taille: px(18))[
        #cadre([bastion · ada], niveau: 1)[
          ```
          $ ls -l ~/.ssh/authorized_keys
          -rw-----w- 1 ada ada 92 Nov 25 10:17 /home/ada/.ssh/authorized_keys
          ```
        ]
        ```
        # BatchMode : ne rien demander, échouer
        $ ssh -o BatchMode=yes ada@bastion hostname
        ada@bastion: Permission denied (publickey,password).
        ```
        #cadre([bastion · root, journal de sshd], niveau: 1)[
          ```
          Authentication refused: bad ownership or modes for file /home/ada/.ssh/authorized_keys
          ```
        ]
      ]
    ],
  ),
  source-de: link("https://man.openbsd.org/sshd_config#StrictModes")[man sshd_config, StrictModes],
  note: [Clé publique tronquée (…) pour tenir sur la diapositive. À droite, le fichier est devenu modifiable par tous (o+w) : n’importe quel utilisateur du bastion pourrait y ajouter sa clé, donc sshd l’ignore (StrictModes, activé par défaut) ; seul le message du journal dit pourquoi. Code de retour de ssh : 255. Sur Debian et Ubuntu, un correctif du paquet accepte un fichier modifiable par le groupe quand ce groupe ne contient que l’utilisateur (groupe privé) : d’où l’essai avec « o+w » plutôt que « g+w ». Droits attendus : \~/.ssh en 700, authorized\_keys et la clé privée en 600.],
)

== \~/.ssh/config : le carnet d’adresses du client <ssh-config>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.1, taille: px(24))[Le fichier, puis ce que ssh en retient][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        $ cat ~/.ssh/config
        Host bastion
            User ada

        Host serveur
            User ada
            ProxyJump bastion

        Host serveur1
            HostName serveur1.mon.domaine.fr
            User login1
            Port 2222
        $ ssh -G serveur1 | grep -E '^(hostname|user|port) '
        user login1
        hostname serveur1.mon.domaine.fr
        port 2222
        ```
      ]
    ],
    bloc(taille: px(24))[Un alias par machine][
      - `ssh serveur1` remplace `ssh -p 2222 login1@serveur1.mon.domaine.fr`
      - `Host` : le nom tapé ; `HostName` : la vraie adresse ; `User`, `Port`, `IdentityFile` (la clé)…
      - `scp` et `rsync` lisent le même fichier : `scp f serveur1:` fonctionne aussi
      - `ssh -G` affiche la configuration retenue, *sans se connecter*
      - *Le premier réglage lu l’emporte* : les entrées précises en tête, une entrée générale `Host *` à la fin
    ],
  ),
  source-de: link("https://man.openbsd.org/ssh_config")[man ssh_config],
  note: [Exemple serveur1 repris du cours d’origine, qui demandait : « Pour un cas simple comme celui-là, avez-vous une autre idée de raccourci ? » Réponse : un alias du shell (alias serveur1='ssh -p 2222 login1\@…') ; mais scp, rsync et les autres outils fondés sur ssh ne le verraient pas, alors qu’ils lisent \~/.ssh/config. man ssh\_config : « for each parameter, the first obtained value will be used […] more host-specific declarations should be given near the beginning of the file, and general defaults at the end ». ssh -G ne se connecte pas : serveur1.mon.domaine.fr n’existe pas, la commande fonctionne quand même. Les entrées bastion et serveur sont celles du fil rouge.],
)

== Le rebond par un bastion : ProxyJump <proxyjump>

#anime(
  grid(columns: (1fr, px(300), 1fr, px(300), 1fr), align: horizon, column-gutter: px(12),
    machine(distant: false)[client],
    fleche(haut: [① connexion ssh], bas: [au bastion]),
    machine[bastion],
    fleche(haut: [② transfert TCP], bas: [jusqu’au serveur]),
    machine[serveur],
  ),
  rang(
    bloc(role: "pratique", poids: 1.35, taille: px(24))[Démonstration][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        # le serveur est invisible depuis le poste
        $ ssh ada@serveur hostname
        ssh: Could not resolve hostname serveur: Name or service not known
        # -J : passer par le bastion
        $ ssh -J ada@bastion ada@serveur hostname
        serveur
        # d’où le serveur voit-il venir la connexion ?
        $ ssh -J ada@bastion ada@serveur 'echo $SSH_CONNECTION'
        172.19.0.2 40466 172.19.0.3 22
        # avec ProxyJump dans ~/.ssh/config
        $ ssh serveur hostname
        serveur
        ```
      ]
    ],
    bloc(taille: px(24))[Lire la démonstration][
      - `172.19.0.2` : l’adresse du bastion sur le réseau privé
      - La session ssh va *du client au serveur* : le bastion ne fait que relayer des octets chiffrés
      - La clé privée reste sur le poste : sur le bastion, `~/.ssh` ne contient que `authorized_keys`
    ],
  ),
  source-de: [#link("https://man.openbsd.org/ssh#J")[man ssh, option -J] · #link("https://man.openbsd.org/ssh_config#ProxyJump")[man ssh\_config, ProxyJump]],
  note: [man ssh, -J : « Connect to the target host by first making an ssh connection to the jump host described by destination and then establishing a TCP forwarding to the ultimate destination from there ». SSH\_CONNECTION contient : adresse et port du client vu par le serveur, adresse et port du serveur. hostname -I sur le bastion : 172.18.0.3 (réseau public) et 172.19.0.2 (réseau privé). Le serveur a reçu la clé publique par ssh-copy-id -o ProxyJump=ada\@bastion ada\@serveur. Un bastion (_jump host_) concentre les accès : un seul point à surveiller et à durcir.],
)

== Transfert d’agent (-A) : un risque réel <agent-transfert>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.5, taille: px(24))[Ce que peut faire root sur le bastion][
      #terminal(titre: [client · ada], taille: px(18))[
        ```
        # Ada ouvre une session vers le bastion en transférant son agent (-A)
        $ ssh -A bastion sleep 30
        ```
        #cadre([bastion · root, pendant la session d’Ada], niveau: 1)[
          ```
          # la socket de l’agent d’Ada, relayée sur le bastion
          $ ls -d /tmp/ssh-*/agent.*
          /tmp/ssh-RH2Z8T2ZHK/agent.216
          $ export SSH_AUTH_SOCK=$(ls /tmp/ssh-*/agent.*)
          $ whoami
          root
          $ ssh-add -l
          256 SHA256:+Zy9p3f5oJM7JE3rg1LrKHzZJXqTK9GBy7zIdV2/P6E ada@client (ED25519)
          $ ssh -o StrictHostKeyChecking=accept-new ada@serveur hostname
          Warning: Permanently added 'serveur' (ED25519) to the list of known hosts.
          serveur
          ```
        ]
      ]
    ],
    bloc(role: "danger", taille: px(24))[Risque réel][
      - Avec `-A`, quiconque contourne les droits sur le bastion (root, ou un intrus) utilise l’agent d’Ada *tant que sa session est ouverte*
      - Il ne copie pas la clé, mais il *signe avec* : il entre partout où Ada entre
      - À la place : `-J` (ProxyJump), qui laisse l’agent et la clé sur le poste
    ],
  ),
  source-de: link("https://man.openbsd.org/ssh#A")[man ssh, option -A],
  note: [man ssh, -A : « Agent forwarding should be enabled with caution. Users with the ability to bypass file permissions on the remote host (for the agent's UNIX-domain socket) can access the local agent through the forwarded connection. An attacker cannot obtain key material from the agent, however they can perform operations on the keys that enable them to authenticate using the identities loaded into the agent. A safer alternative may be to use a jump host (see -J). » Dans la démonstration, les commandes de root sont tapées une par une ; le script de rejeu les enchaîne sur une ligne. sleep 30 garde la session ouverte le temps de la démonstration.],
)

== Trois redirections de port <redirections-port>

#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  let ligne(n, option, exemple, nom, schema, sens) = uncover(str(n) + "-", grid(columns: (px(360), 1fr), column-gutter: px(24), align: horizon,
    stack(spacing: px(6),
      { text(size: px(34), weight: 600, fill: c.bleu, raw(option)); h(px(12)); text(size: px(26), weight: 600, nom) },
      text(size: px(21), fill: c.bleu, raw(exemple)),
      text(size: px(20), fill: c.ardoise, sens)),
    schema))
  let tunnel(t) = fleche(haut: t, couleur: c.gris)
  stack(spacing: px(26),
    ligne(1, "-L", "ssh -L 8080:localhost:8000 serveur", [Locale],
      grid(columns: (1fr, px(250), 1fr, px(170), 1fr), align: horizon, column-gutter: px(8),
        machine(distant: false, role: [`localhost:8080`])[client], tunnel[tunnel ssh], machine[serveur], fleche(haut: [connexion]), machine(role: [`localhost:8000`], taille: px(24))[service du serveur]),
      [Un port du *client* mène à un service joignable *depuis le serveur*]),
    ligne(2, "-R", "ssh -R 9000:localhost:9000 serveur", [Distante],
      grid(columns: (1fr, px(170), 1fr, px(250), 1fr), align: horizon, column-gutter: px(8),
        machine(distant: false, role: [`localhost:9000`], taille: px(24))[service du client], fleche(vers: "gauche", haut: [connexion]), machine(distant: false)[client], fleche(vers: "gauche", haut: [tunnel ssh]), machine(role: [`localhost:9000`])[serveur]),
      [Un port du *serveur* mène à un service joignable *depuis le client*]),
    ligne(3, "-D", "ssh -D 1080 bastion", [Dynamique],
      grid(columns: (1fr, px(250), 1fr, px(170), 1fr), align: horizon, column-gutter: px(8),
        machine(distant: false, role: [proxy SOCKS `:1080`])[client], tunnel[tunnel ssh], machine[bastion], fleche(haut: [connexion]), machine(role: [demandée par l’application], taille: px(24))[toute destination]),
      [Un *proxy SOCKS* (mandataire générique) sur le client ; chaque connexion sort par le serveur]),
    uncover("4-", note(role: "retenir", taille: px(24))[`-L` : j’apporte chez moi un service de là-bas · `-R` : j’expose là-bas un service de chez moi · `-D` : je sors sur le réseau par là-bas. Dans `-L port:hôte:port_hôte`, `hôte` est résolu *par le serveur* : `localhost` y désigne le serveur lui-même.]),
  )
  source[#link("https://man.openbsd.org/ssh#L")[man ssh, options -L, -R, -D]]
  utils.speaker-note(self: self)[Un clic par redirection, puis la synthèse. Les flèches indiquent le sens d’ouverture des connexions ; les données circulent ensuite dans les deux sens. -R est la symétrique de -L : c’est le serveur qui écoute, le client qui se connecte au service. SOCKS (_SOCKet Secure_) : protocole par lequel une application demande au proxy d’ouvrir une connexion pour elle, vers la destination de son choix ; ssh est serveur SOCKS 4 et 5 (man ssh, -D). Seul root peut ouvrir un port privilégié (inférieur à 1024). Diapo de référence pour un artefact ou un TP sur les redirections.]
})

== Les trois redirections à l’œuvre <redirections-demo>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.5, taille: px(24))[Démonstration][
      #terminal(titre: [client · ada], taille: px(18))[
        #cadre([serveur · ada], niveau: 1)[
          ```
          # supervision : seulement en local ; wiki : sur le réseau privé
          $ ss -ltn | grep -E ":(80|8000) "
          LISTEN 0      5          127.0.0.1:8000       0.0.0.0:*
          LISTEN 0      5            0.0.0.0:80         0.0.0.0:*
          ```
        ]
        ```
        $ curl -sS localhost:8080
        curl: (7) Failed to connect to localhost port 8080 after 0 ms: […]
        # -f : en arrière-plan ; -N : aucune commande, seulement le tunnel
        $ ssh -f -N -L 8080:localhost:8000 serveur
        $ curl -sS localhost:8080
        Supervision : tout va bien
        # la maquette du poste (localhost:9000) devient visible du serveur
        $ ssh -f -N -R 9000:localhost:9000 serveur
        $ ssh serveur curl -sS localhost:9000
        Maquette du site, sur le poste client
        $ ssh -f -N -D 1080 bastion
        $ curl -sS --socks5-hostname localhost:1080 http://serveur/
        Wiki interne du réseau privé
        ```
      ]
    ],
    bloc(taille: px(24))[Ce qui s’est passé][
      - `-L` : `curl` parle au port 8080 du poste ; ssh relaie jusqu’au port 8000 du serveur, fermé au reste du monde
      - `-R` : sur le serveur, `curl localhost:9000` atteint le petit serveur web du poste d’Ada
      - `-D` : `curl` demande `serveur` au proxy ; le nom est résolu et la connexion ouverte *par le bastion*
    ],
  ),
  source-de: [#link("https://man.openbsd.org/ssh#L")[man ssh] · #link("https://curl.se/docs/manpage.html#--socks5-hostname")[man curl, --socks5-hostname]],
  note: [Prérequis : curl sur le poste et le serveur ; trois serveurs web de démonstration (python3 -m http.server) : supervision sur 127.0.0.1:8000 du serveur, wiki sur le port 80 du serveur, maquette sur 127.0.0.1:9000 du poste. Le premier curl échoue (code 7 : « Couldn’t connect to server ») : rien n’écoute encore sur 8080. Sans proxy, curl http://serveur/ échoue aussi depuis le poste (code 6 : « Could not resolve host »). --socks5-hostname confie la résolution du nom au proxy, donc au bastion ; --socks5 seul résoudrait le nom sur le poste. Les tunnels passent par le bastion grâce à ProxyJump (\~/.ssh/config). Sortie de curl coupée par […] ; texte complet : « Couldn't connect to server ». Le script de rejeu enchaîne chaque tunnel et sa vérification sur une même ligne : un tunnel qui passe par le bastion (ProxyJump) s’arrête avec le terminal qui l’a lancé.],
)

== Copier des fichiers : scp et rsync

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  let b-copier = bloc(taille: px(23))[Copier ou synchroniser][
    - `scp` *copie*, simplement ; il utilise aujourd’hui le protocole SFTP (_SSH File Transfer Protocol_) (`-O` : l’ancien protocole SCP)
    - `rsync` *synchronise* : au second passage, seul `index.html` a changé, seul lui part
    - `-a` (archive) : récursif, garde droits, dates et liens ; `-v` : détaille ; `-z` : compresse, utile sur un lien lent
  ]
  let b-delete = bloc(role: "avertissement", taille: px(23))[rsync --delete][
    Supprime à la destination ce qui n’existe plus à la source : le lancer d’abord avec `-n` (`--dry-run`), qui montre sans rien faire. Une barre oubliée ou en trop change aussi la destination.
  ]
  rangee(poids: (1.25, 1),
    h => terminal(titre: [client · ada], taille: px(18), hauteur: h)[
      ```
      $ scp rapport.txt serveur:/tmp/
      rapport.txt                     100%    8    38.3KB/s   00:00
      # la barre finale de site/ : « le contenu de site »
      $ rsync -av site/ serveur:site/
      sending incremental file list
      created directory site
      ./
      contact.html
      index.html

      sent 205 bytes  received 84 bytes  578.00 bytes/sec
      total size is 16  speedup is 0.06
      # index.html modifié, puis on recommence
      $ rsync -av site/ serveur:site/
      sending incremental file list
      index.html

      sent 157 bytes  received 41 bytes  396.00 bytes/sec
      total size is 17  speedup is 0.09
      ```
    ],
    h => block(height: h, stack(spacing: px(20),
      bloc-anime(b-copier, 2, uncover),
      bloc-anime(b-delete, 5, uncover),
    )),
  )
  source[#link("https://man.openbsd.org/scp")[man scp] · #link("https://download.samba.org/pub/rsync/rsync.1")[man rsync]]
  utils.speaker-note(self: self)[Le terminal d’abord, puis une explication par clic, puis l’avertissement. Prérequis : rsync installé sur les deux machines. La barre de progression de scp se réécrit sur place ; seule sa dernière version est montrée (espaces réduits). Le cours d’origine proposait rsync -avz ; -z gagne surtout sur un lien lent, ici inutile. man rsync : « You can think of a trailing / on a source as meaning "copy the contents of this directory" as opposed to "copy the directory by name" ». La version du site ajoutait --delete sans avertissement : d’où l’encadré. scp et rsync passent par le bastion grâce à \~/.ssh/config.]
})

== Modifier sshd_config… sans effet <piege-sshd>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.35, taille: px(24))[Ada veut interdire le mot de passe][
      #terminal(titre: [client · ada], taille: px(18))[
        #cadre([serveur · root], niveau: 1)[
          ```
          # -T : la configuration effective de sshd
          $ sshd -T | grep -E '^(passwordauthentication|pubkeyauthentication|permitrootlogin|port) '
          port 22
          permitrootlogin without-password
          pubkeyauthentication yes
          passwordauthentication yes
          # première ligne utile du fichier principal
          $ head -n 13 /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"
          Include /etc/ssh/sshd_config.d/*.conf
          $ cat /etc/ssh/sshd_config.d/50-cloud-init.conf
          PasswordAuthentication yes
          $ echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
          $ sshd -T | grep -i '^passwordauthentication'
          passwordauthentication yes
          ```
        ]
      ]
    ],
    bloc(role: "avertissement", taille: px(24))[Pourquoi rien ne change][
      - Pour chaque mot-clé, sshd garde la *première* valeur lue
      - Debian et Ubuntu incluent `sshd_config.d/*.conf` *en tête* de `sshd_config`, dans l’ordre alphabétique
      - Un fichier de ce dossier l’emporte donc sur toute ligne ajoutée au fichier principal
    ],
  ),
  source-de: link("https://man.openbsd.org/sshd_config")[man sshd_config],
  note: [man sshd\_config (paquet Ubuntu 24.04, mêmes lignes dans Debian) : « Unless noted otherwise, for each keyword, the first obtained value will be used » et « /etc/ssh/sshd\_config.d/\*.conf files are included at the start of the configuration file, so options set there will override those in /etc/ssh/sshd\_config ». Le fichier 50-cloud-init.conf est créé ici pour l’exemple ; cloud-init en pose un de ce nom sur des images cloud (à vérifier sur l’image utilisée). Le cours d’origine modifiait sshd\_config avec sed et demandait : « Que manque-t-il à la commande ? » (l’option -i, pour écrire dans le fichier) ; même corrigée, elle se heurte à ce piège. permitrootlogin without-password est l’ancien nom de prohibit-password : root n’entre que par clé.],
)

== Interdire le mot de passe, proprement <durcir-sshd>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.35, taille: px(24))[Un fichier à soi, lu en premier][
      #terminal(titre: [client · ada], taille: px(18))[
        #cadre([serveur · root], niveau: 1)[
          ```
          # « 10- » : lu avant « 50- », donc prioritaire
          $ echo 'PasswordAuthentication no' > /etc/ssh/sshd_config.d/10-durcissement.conf
          $ ls /etc/ssh/sshd_config.d/
          10-durcissement.conf
          50-cloud-init.conf
          # -t : vérifier la syntaxe avant de recharger
          $ sshd -t && echo "syntaxe correcte"
          syntaxe correcte
          $ sshd -T | grep -i '^passwordauthentication'
          passwordauthentication no
          # puis : systemctl reload ssh
          ```
        ]
        ```
        $ ssh -o PubkeyAuthentication=no serveur hostname
        ada@serveur: Permission denied (publickey).
        $ ssh serveur hostname
        serveur
        ```
      ]
    ],
    bloc(role: "danger", taille: px(24))[Ne pas s’enfermer dehors][
      - Avant : vérifier que la connexion *par clé* fonctionne
      - Pendant : garder *une session ouverte* sur le serveur
      - Après : tester depuis une *autre* fenêtre, avant de fermer la première
    ],
  ),
  source-de: [#link("https://man.openbsd.org/sshd_config#PasswordAuthentication")[man sshd_config] · #link("https://man.openbsd.org/sshd#t")[man sshd, -t et -T]],
  note: [Le service s’appelle ssh.service sur Debian et Ubuntu (alias sshd.service, lu dans le fichier d’unité d’Ubuntu 24.04 ; à vérifier sur Debian 13) ; l’unité lance elle-même sshd -t avant de démarrer. Dans le laboratoire, sans systemd, sshd relit sa configuration sur le signal SIGHUP. Après rechargement, le serveur ne propose plus que publickey : « Permission denied (publickey) ». Une session ouverte n’est pas coupée par le rechargement, d’où le filet de sécurité. Le cours d’origine : « À voir en fonction de l’usage du serveur, ce n’est pas toujours possible… Mais toujours encourager les utilisateurs à utiliser une connexion par clé ».],
)

== Durcir encore : filtrer, bannir, double facteur

#anime(
  rang(
    bloc(taille: px(26))[Restreindre l’accès][
      - *Pare-feu* (nftables) : n’ouvrir le port 22 qu’aux adresses de confiance, quand on les connaît
      - `AllowUsers` / `AllowGroups` dans la configuration de sshd : seuls ces comptes entrent
    ],
    bloc(taille: px(26))[Ralentir les attaques][
      - *Fail2Ban* lit les journaux et bannit au pare-feu une adresse après plusieurs échecs
      - *Double facteur* : un code à usage unique en plus de la clé, par un module PAM (_Pluggable Authentication Modules_)
    ],
  ),
  rang(bloc(role: "precaution", taille: px(26))[Changer de port : du confort, pas de la sécurité][
    - Passer de 22 à 2222 réduit le *bruit* des essais automatiques dans les journaux
    - Un attaquant ciblé trouve le port d’un balayage : ce n’est jamais une protection
  ]),
  source-de: [#link("https://man.openbsd.org/sshd_config#AllowUsers")[man sshd_config, AllowUsers] · #link("https://github.com/fail2ban/fail2ban")[github.com/fail2ban]],
  note: [Repris de la diapositive « Sécurisation avancée de SSH » du cours d’origine (pare-feu iptables / nftables, 2FA avec Google Authenticator, Fail2Ban). La mise en place de chacun sort du cadre de ce cours. PAM : _Pluggable Authentication Modules_, la bibliothèque d’authentification de Linux ; module courant pour les codes TOTP (_Time-based One-Time Password_) : libpam-google-authenticator. Changer de port : le cours d’origine présentait cette mesure comme « réduisant les risques » ; elle n’en réduit que la visibilité.],
)

== À vous : SSH <exercice-ssh>

#anime(
  rang(bloc(role: "question", taille: px(27))[À vous][
    + Écrivez l’entrée de `~/.ssh/config` qui permet de taper `ssh bastion` pour joindre `bastion.example.org` en tant qu’`admin`, sur le port 2222. Quelle serait la commande sans ce fichier ?
    + Ajoutez l’entrée `base` : la machine `base.interne`, compte `admin`, joignable seulement par ce bastion
    + Vérifiez ces deux entrées *sans vous connecter*
    + Le tableau de bord de `base` écoute sur `127.0.0.1:3000` : rendez-le accessible sur le port 3000 de votre poste
    + Quel fichier de `~/.ssh` ne doit jamais quitter votre poste ? Avec quels droits ?
  ]),
  note(role: "pratique")[Prérequis : le client OpenSSH (paquet `openssh-client`). Les machines n’existent pas : la question 3 se fait quand même.],
  note: [À faire en direct, une question par clic ; laisser chercher avant de passer au corrigé. Aide : man ssh\_config, et l’option -G de ssh vue sur la diapositive « \~/.ssh/config ».],
)

== À vous : SSH, corrigé (1/2)

#corriges(
  note: [Sorties réelles (OpenSSH 9.6p1), sur un poste sans réseau : ssh -G ne se connecte pas. La question reste affichée ; un clic par réponse.],
  (1, [Entrée `bastion` : `bastion.example.org`, compte `admin`, port 2222 ; et sans le fichier ?],
    reponse(terminal(titre: [\~/.ssh/config, puis client · ada], taille: px(19))[```
  Host bastion
      HostName bastion.example.org
      User admin
      Port 2222
  # sans le fichier, la même configuration :
  $ ssh -G -p 2222 admin@bastion.example.org | grep -E '^(hostname|user|port) '
  user admin
  hostname bastion.example.org
  port 2222
  ```])),
  (2, [Entrée `base` : `base.interne`, compte `admin`, seulement par ce bastion],
    reponse(terminal(titre: [\~/.ssh/config, à la suite], taille: px(19))[```
  Host base
      HostName base.interne
      User admin
      ProxyJump bastion
  ```])),
)

== À vous : SSH, corrigé (2/2)

#corriges(
  note: [Question 4 : ssh -G vérifie que la redirection est comprise ([localhost]:3000, résolu côté base) ; la vraie commande est ssh -f -N -L 3000:localhost:3000 base, puis ouvrir http://localhost:3000 sur le poste. Question 5 : la clé publique, elle, peut circuler librement. Sorties réelles (OpenSSH 9.6p1).],
  (3, [Vérifiez ces deux entrées sans vous connecter],
    reponse(terminal(titre: none, taille: px(19))[```
  $ ssh -G bastion | grep -E '^(hostname|user|port) '
  user admin
  hostname bastion.example.org
  port 2222
  $ ssh -G base | grep -E '^(hostname|user|proxyjump) '
  user admin
  hostname base.interne
  proxyjump bastion
  ```])),
  (4, [Tableau de bord de `base` (`127.0.0.1:3000`) sur le port 3000 du poste],
    reponse(terminal(titre: none, taille: px(19))[```
  $ ssh -f -N -L 3000:localhost:3000 base
  # la redirection telle que ssh la comprend :
  $ ssh -G -L 3000:localhost:3000 base | grep -E '^localforward '
  localforward 3000 [localhost]:3000
  ```])),
  (5, [Quel fichier ne doit jamais quitter le poste ? Avec quels droits ?],
    reponse(text(size: px(24))[La clé *privée* `~/.ssh/id_ed25519`, en `rw-------` (600) ; le dossier `~/.ssh` en 700.])),
)

// ======================================================================
= tmux · le terminal qui survit

== Une coupure, et le travail est perdu <tmux-probleme>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Une mise à jour longue, lancée par ssh][
      #terminal(titre: [client · ada], taille: px(19))[
        ```
        # sleep 600 joue le rôle d’une mise à jour de dix minutes
        $ ssh -t serveur sleep 600
        ```
        #cadre([serveur · ada, dans une autre fenêtre], niveau: 1)[
          ```
          $ pgrep -afx "sleep 600"
          289 sleep 600
          ```
        ]
        ```
        # le terminal du client se ferme brutalement
        $ pkill -KILL -f "^ssh -t serveur"
        ```
        #cadre([serveur · ada], niveau: 1)[
          ```
          $ pgrep -afx "sleep 600"
          $ echo "code de retour : $?"
          code de retour : 1
          ```
        ]
      ]
    ],
    bloc(taille: px(24))[Ce qui s’est passé][
      - La session ssh tient un *pseudo-terminal* sur le serveur ; le travail lancé lui est attaché
      - La connexion tombe : le pseudo-terminal se ferme, ses processus reçoivent le signal *SIGHUP* (_hang-up_, raccroché) et s’arrêtent
      - Plus de `sleep 600` : la mise à jour est interrompue au milieu
    ],
  ),
  source-de: [#link("https://man7.org/linux/man-pages/man7/signal.7.html")[man 7 signal, SIGHUP] · #link("https://man.openbsd.org/ssh#t")[man ssh, -t]],
  note: [Démonstration : tuer le client ssh (kill -KILL) imite la fermeture brutale du terminal ou une coupure franche. Une coupure réseau silencieuse produit le même effet, plus tard, quand sshd constate que le client ne répond plus. -t force l’allocation d’un pseudo-terminal, comme dans une session interactive. pgrep ne trouve plus rien : code de retour 1. Le cours d’origine : « Si la connexion SSH se coupe, vos commandes et programmes continuent de s’exécuter en arrière-plan » : c’est vrai avec tmux, pas sans.],
)

== tmux : un serveur qui garde les terminaux <tmux-survie>

#anime(
  rang(
    bloc(taille: px(25))[Ce que c’est][
      - tmux (_terminal multiplexer_) crée et gère des terminaux, et les garde *après* la déconnexion
      - Un *serveur* tmux, processus de la machine distante, possède les terminaux et ce qui y tourne
      - Le terminal d’Ada n’est qu’un *client* qui les affiche : qu’il disparaisse, le serveur continue
    ],
    bloc(role: "pratique", poids: 1.25, taille: px(24))[La même coupure, avec tmux][
      #terminal(titre: [client · ada], taille: px(19))[
        ```
        # la mise à jour tourne dans une session tmux nommée « maj »
        $ ssh -t serveur tmux new -s maj sleep 600
        # le terminal du client se ferme brutalement
        $ pkill -KILL -f "^ssh -t serveur"
        $ ssh serveur tmux ls
        maj: 1 windows (created Wed Nov 25 10:18:34 2026)
        $ ssh serveur 'pgrep -afx "sleep 600"'
        317 sleep 600
        # pour reprendre la main : ssh -t serveur tmux attach -t maj
        ```
      ]
    ],
  ),
  rang(bloc(role: "retenir", taille: px(25))[Le réflexe][
    Sur un serveur, ouvrir tmux *avant* de lancer quoi que ce soit de long : un processus déjà lancé ne se rapatrie pas dans tmux.
  ]),
  source-de: link("https://man.openbsd.org/tmux#DESCRIPTION")[man tmux, DESCRIPTION],
  note: [man tmux : « Each session is persistent and will survive accidental disconnection (such as ssh(1) connection timeout) or intentional detaching ». « all sessions are managed by a single server. The server and each client are separate processes which communicate through a socket in /tmp ». tmux 3.4 (Ubuntu 24.04) ; à rejouer sur Debian 13 (tmux 3.5a). La session reste jusqu’à la fin de sleep 600, ou jusqu’à tmux kill-session -t maj. Réponse au cours d’origine (digression tmux de la partie SSH) : « sessions persistantes, multiplexage des terminaux, organisation, travail collaboratif ».],
)

== Serveur, session, fenêtre, panneau <tmux-hierarchie>

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  let boite(titre, couleur, corps, fond: c.fond) = block(width: 100%, stroke: px(2) + couleur, radius: px(10), fill: fond,
    inset: (x: px(12), y: px(10)), stack(spacing: px(10), text(size: px(24), weight: 600, fill: couleur, titre), corps))
  let panneau(nom) = block(width: 100%, height: px(96), fill: c.nuit, radius: px(6),
    align(center + horizon, text(font: mono, size: px(24), fill: c.texte-term, nom)))
  let fenetre(nom, panneaux) = uncover("3-", boite(nom, c.ardoise, uncover("4-",
    grid(columns: (1fr,) * panneaux.len(), column-gutter: px(8), ..panneaux.map(panneau)))))
  let client(nom, role) = uncover("5-", grid(columns: (1fr, px(90)), column-gutter: px(8), align: horizon,
    machine(distant: false, role: role, taille: px(24), nom), fleche()))
  grid(columns: (px(380), 1fr, px(520)), column-gutter: px(16), align: top,
    stack(spacing: px(24), v(px(70)),
      client([client 1], [terminal d’Ada, par ssh]),
      client([client 2], [un second terminal]),
      uncover("5-", align(center, text(size: px(20), fill: c.gris)[tous deux attachés à `admin`])),
    ),
    boite([serveur tmux (un processus sur `serveur`)], c.invite, fond: c.invite-clair, stack(spacing: px(12),
      uncover("2-", boite([session `admin`], c.bleu, grid(columns: (1.6fr, 1fr), column-gutter: px(10),
        fenetre([fenêtre 0 : `edition`], ([0.0], [0.1])),
        fenetre([fenêtre 1 : `journaux`], ([1.0],)),
      ))),
      uncover("2-", boite([session `perso`], c.bleu, grid(columns: (1fr, 1.6fr), column-gutter: px(10),
        fenetre([fenêtre 0 : `bash`], ([0.0],)), []))),
    )),
    stack(spacing: px(14),
      uncover("2-", note(role: "notion", taille: px(23))[*Session* : un ensemble de terminaux, un par contexte de travail ; elle survit à la déconnexion]),
      uncover("3-", note(role: "notion", taille: px(23))[*Fenêtre* : occupe tout l’écran, comme un onglet ; numérotée à partir de 0]),
      uncover("4-", note(role: "notion", taille: px(23))[*Panneau* : une découpe rectangulaire d’une fenêtre ; chacun est un terminal à part. Cible : `session:fenêtre.panneau`]),
      uncover("5-", note(role: "notion", taille: px(23))[*Clients* : plusieurs terminaux peuvent afficher la même session ; tmux s’arrête quand la dernière session est fermée]),
    ),
  )
  source[#link("https://man.openbsd.org/tmux#DESCRIPTION")[man tmux, DESCRIPTION]]
  utils.speaker-note(self: self)[Un clic par niveau : serveur, sessions, fenêtres, panneaux, puis clients. L’arbre est exactement celui que construit la diapositive suivante (sortie de list-panes : admin:0.0, admin:0.1, admin:1.0, perso:0.0). man tmux : « A session is a single collection of pseudo terminals under the management of tmux. Each session has one or more windows linked to it. A window occupies the entire screen and may be split into rectangular panes, each of which is a separate pseudo terminal. Any number of tmux instances may connect to the same session ». Diapo de référence pour l’artefact « arbre tmux » et le TP tmux.]
})

== Construire l’arbre en commandes <tmux-commandes>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.35, taille: px(24))[Démonstration][
      #terminal(titre: [client · ada], taille: px(19))[
        #cadre([serveur · ada], niveau: 1)[
          ```
          # -d : créer sans s’attacher ; -s : session ; -n : fenêtre
          $ tmux new -d -s admin -n edition
          # -h : coupe en deux panneaux côte à côte
          $ tmux split-window -h -t admin:edition
          $ tmux new-window -t admin -n journaux
          $ tmux new -d -s perso
          $ tmux ls
          admin: 2 windows (created Wed Nov 25 10:18:42 2026)
          perso: 1 windows (created Wed Nov 25 10:18:42 2026)
          $ tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{window_name}'
          admin:0.0 edition
          admin:0.1 edition
          admin:1.0 journaux
          perso:0.0 bash
          ```
        ]
      ]
    ],
    bloc(taille: px(24))[Lire la sortie][
      - `tmux ls` : une ligne par session, avec son nombre de fenêtres
      - `list-panes -a` : tous les panneaux de toutes les sessions ; `-F` choisit les champs
      - `admin:0.1` : session `admin`, fenêtre 0, panneau 1 ; la même écriture sert de *cible* (`-t`)
      - La fenêtre de `perso`, sans nom donné, porte le nom du programme qu’elle exécute : `bash`
    ],
  ),
  source-de: link("https://man.openbsd.org/tmux#COMMANDS")[man tmux, COMMANDS],
  note: [tmux 3.4 ; à rejouer sur Debian 13 (tmux 3.5a). new est l’alias de new-session. Les dates de création viennent de l’horloge du serveur. Ces commandes, tapées hors de tmux, s’adressent au serveur tmux de l’utilisateur (socket /tmp/tmux-1000/default) ; tapées dans tmux, elles agissent sur la session courante.],
)

== Au clavier : le préfixe Ctrl+b

#anime(
  rang(
    bloc(taille: px(25))[Dans tmux : préfixe, puis une touche][
      - On presse *Ctrl+b*, on relâche, puis la touche : « préfixe d » = Ctrl+b, puis d
      - `d` : se *détacher* ; la session continue · `c` : nouvelle fenêtre · `,` : la renommer
      - `n` / `p` : fenêtre suivante / précédente · `0` à `9` : aller à une fenêtre
      - `%` : couper gauche / droite · `"` : couper haut / bas · flèches : changer de panneau
      - `z` : agrandir le panneau (et revenir) · `x` : fermer le panneau · `?` : toutes les touches
    ],
    bloc(role: "pratique", taille: px(25))[Hors de tmux : le cycle de vie][
      - `tmux new -s admin` : créer la session et s’y attacher
      - `tmux ls` : lister les sessions
      - `tmux attach -t admin` : se rattacher, même après une coupure
      - `tmux attach -t admin -r` : regarder sans pouvoir taper (lecture seule)
      - `tmux kill-session -t admin` : fermer la session et ses programmes
    ],
  ),
  source-de: link("https://man.openbsd.org/tmux#DEFAULT_KEY_BINDINGS")[man tmux, DEFAULT KEY BINDINGS],
  note: [Touches relevées dans la section DEFAULT KEY BINDINGS de man tmux 3.4. Attention à une confusion fréquente : % coupe en deux panneaux côte à côte (gauche et droite), " en deux panneaux superposés (haut et bas). Préfixe : puis une commande ouvre l’invite de tmux : chaque touche a sa commande longue (split-window -h pour %). Partage : deux personnes connectées au même compte s’attachent à la même session et voient la même chose ; -r est un alias de -f read-only,ignore-size : seules les touches de détachement agissent (man tmux, attach-session).],
)

== Piloter tmux par script : send-keys, capture-pane <tmux-script>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3, taille: px(24))[Taper et lire dans un panneau, sans s’y attacher][
      #terminal(titre: [client · ada], taille: px(19))[
        #cadre([serveur · ada], niveau: 1)[
          ```
          # taper une commande dans la fenêtre « journaux »
          $ tmux send-keys -t admin:journaux 'hostname; whoami' Enter
          # lire ce que le panneau affiche (lignes vides retirées)
          $ tmux capture-pane -p -t admin:journaux | grep -v "^$"
          ada@serveur:~$ hostname; whoami
          serveur
          ada
          ada@serveur:~$
          ```
        ]
      ]
    ],
    bloc(taille: px(24))[À quoi ça sert][
      - `send-keys` envoie des touches comme si on les tapait ; `Enter` est le nom d’une touche
      - `capture-pane -p` écrit le contenu du panneau sur la sortie standard
      - Usage : préparer un poste de travail, lancer une tâche dans une session qui survivra, vérifier un résultat depuis un script
    ],
  ),
  source-de: link("https://man.openbsd.org/tmux#send-keys")[man tmux, send-keys et capture-pane],
  note: [Sortie réelle (tmux 3.4). capture-pane -p : « the output goes to stdout » ; sans -p, le contenu va dans un tampon de tmux. -J recolle les lignes qu’un panneau étroit a coupées (corrigé de l’exercice). Ces deux commandes permettent aussi de tester un TP tmux sans terminal attaché.],
)

== Configurer tmux : \~/.tmux.conf <tmux-conf>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.25, taille: px(24))[Le fichier, puis la vérification][
      #terminal(titre: [client · ada], taille: px(19))[
        #cadre([serveur · ada], niveau: 1)[
          ```
          $ cat ~/.tmux.conf
          set -g mouse on
          set -g history-limit 50000
          setw -g mode-keys vi
          set -g base-index 1
          setw -g pane-base-index 1
          bind | split-window -h
          bind _ split-window -v
          $ tmux new -d -s essai
          $ tmux show -g base-index; tmux show -gw mode-keys
          base-index 1
          mode-keys vi
          $ tmux list-keys | grep -E "split-window( -[hv])?\$"
          bind-key    -T prefix       \"                     split-window
          bind-key    -T prefix       \%                     split-window -h
          bind-key    -T prefix       _                      split-window -v
          bind-key    -T prefix       |                      split-window -h
          ```
        ]
      ]
    ],
    bloc(taille: px(24))[Une habitude par ligne][
      - `mouse on` : cliquer pour choisir un panneau, faire défiler à la molette
      - `history-limit` : lignes gardées par panneau (2 000 par défaut)
      - `mode-keys vi` : le *mode copie* (préfixe `[`) se parcourt avec les touches de Vim ; `/` cherche, Espace puis Entrée copient, `q` sort ; préfixe `]` colle
      - `base-index 1` : fenêtres numérotées à partir de 1
      - `|` et `_` : des touches qui *dessinent* la coupure ; `%` et `"` restent
    ],
  ),
  source-de: link("https://man.openbsd.org/tmux#OPTIONS")[man tmux, OPTIONS et WINDOW AND PANE COMMANDS],
  note: [Lu au démarrage du serveur tmux ; à chaud : préfixe : puis source-file \~/.tmux.conf. Sortie réelle (tmux 3.4) ; show -g mouse affiche aussi « mouse on » (omis ici, dans le script de rejeu). Touches du mode copie en mode vi d’après man tmux : begin-selection (Espace), copy-selection-and-cancel (Entrée), search-forward (/), cancel (q) ; v ne sélectionne pas, il bascule la sélection rectangulaire : le commentaire du fichier du site (« v to select, y to yank ») était faux. « \_ » plutôt que « - » : la touche - est déjà liée par défaut (supprimer le dernier tampon copié). Aller plus loin (hors cadre) : tmuxp décrit une session complète dans un fichier YAML.],
)

== À vous : tmux <exercice-tmux>

#anime(
  rang(bloc(role: "question", taille: px(27))[À vous, sur une machine avec tmux][
    + Créez, sans vous y attacher, une session `atelier` dont la première fenêtre s’appelle `edition`, coupée en deux panneaux côte à côte
    + Ajoutez une fenêtre `surveillance` qui exécute `top`
    + Listez les panneaux de la session, avec la commande qui tourne dans chacun
    + Depuis un script, faites taper `echo bonjour depuis le panneau de droite` dans le panneau de droite d’`edition`, puis lisez ce qu’il affiche
    + Fermez brutalement votre terminal : que reste-t-il ? Comment reprendre ?
  ]),
  note(role: "pratique")[Prérequis : le paquet `tmux` ; `man tmux`, section FORMATS, pour le nom du champ « commande en cours ».],
  note: [À faire en direct, une question par clic ; sur le poste ou sur une machine distante par ssh. Laisser chercher avant de passer au corrigé.],
)

== À vous : tmux, corrigé (1/2)

#corriges(
  note: [Sorties réelles (tmux 3.4). -s de list-panes : tous les panneaux de la session ciblée. pane\_current\_command : le programme au premier plan du panneau. La question reste affichée ; un clic par réponse.],
  (1, [Session `atelier`, fenêtre `edition` coupée en deux côte à côte],
    reponse(terminal(titre: none, taille: px(19))[```
  $ tmux new -d -s atelier -n edition
  $ tmux split-window -h -t atelier:edition
  ```])),
  (2, [Une fenêtre `surveillance` qui exécute `top`],
    reponse(terminal(titre: none, taille: px(19))[```
  $ tmux new-window -t atelier -n surveillance top
  ```])),
  (3, [Les panneaux, avec la commande qui tourne dans chacun],
    reponse(terminal(titre: none, taille: px(19))[```
  $ tmux list-panes -s -t atelier -F '#{window_index}.#{pane_index} #{window_name} #{pane_current_command}'
  0.0 edition bash
  0.1 edition bash
  1.0 surveillance top
  ```])),
)

== À vous : tmux, corrigé (2/2)

#corriges(
  note: [Sortie réelle (tmux 3.4). Sans -J, la ligne de commande, plus large que le panneau (40 colonnes), apparaît coupée en deux. Question 5 : la session survit à la fermeture du terminal (diapositive « tmux : un serveur qui garde les terminaux ») ; top tourne toujours.],
  (4, [Taper une commande dans le panneau de droite d’`edition`, puis lire ce qu’il affiche],
    reponse(terminal(titre: none, taille: px(19))[```
  $ tmux send-keys -t atelier:edition.1 'echo bonjour depuis le panneau de droite' Enter
  # -J : recolle les lignes coupées par la largeur du panneau
  $ tmux capture-pane -pJ -t atelier:edition.1 | grep -v "^$"
  ada@serveur:~$ echo bonjour depuis le panneau de droite
  bonjour depuis le panneau de droite
  ada@serveur:~$
  ```])),
  (5, [Fermez brutalement votre terminal : que reste-t-il ? Comment reprendre ?],
    reponse(terminal(titre: none, taille: px(19))[```
  # tout : la session et ses programmes appartiennent au serveur tmux
  $ tmux ls
  atelier: 2 windows (created Wed Nov 25 10:18:46 2026)
  $ tmux attach -t atelier
  ```])),
)

// ======================================================================
= WireGuard · le VPN moderne

== Au-delà d’une machine : relier des réseaux

#anime(
  rang(
    bloc(taille: px(25))[Ce que fait SSH, ce qu’il ne fait pas][
      - SSH ouvre une session vers *une* machine, et transporte des connexions *une par une* (`-L`, `-R`, `-D`)
      - Pour atteindre tout un réseau privé (wiki, supervision, base de données…), il faut une redirection par service, ou des applications qui savent parler SOCKS
    ],
    bloc(taille: px(25))[Un VPN (_Virtual Private Network_)][
      - Une *interface réseau virtuelle* sur chaque machine, reliée aux autres par un *tunnel chiffré*
      - Tout le trafic IP vers le réseau distant y passe : n’importe quelle application fonctionne, sans réglage
    ],
  ),
  rang(bloc(role: "retenir", taille: px(25))[À retenir][
    SSH : entrer sur une machine. VPN : faire comme si les réseaux étaient branchés l’un à l’autre.
  ]),
  note: [Le VPN agit au niveau IP (couche 3) : ping, DNS, partages de fichiers, navigateurs passent sans configuration particulière. SSH agit au niveau des connexions TCP. Les deux se complètent : on entre souvent en SSH sur une machine atteinte par le VPN.],
)

== WireGuard : petit, moderne, dans le noyau

#anime(
  rang(
    bloc(taille: px(25))[Ce que c’est][
      - Un VPN conçu pour être *simple* : une interface, une paire de clés par pair, quelques lignes de configuration
      - *Dans le noyau Linux* depuis la version 5.6 (2020) ; aussi sur Windows, macOS, Android, iOS
      - Peu de code (environ 4 000 lignes à sa publication) : plus facile à relire et à auditer qu’OpenVPN ou IPsec
    ],
    bloc(taille: px(25))[Une cryptographie fixée][
      - Des algorithmes récents et *non négociables* : Curve25519, ChaCha20-Poly1305, BLAKE2s
      - Aucune « suite de chiffrement » à choisir : pas de mauvais choix d’algorithme possible
    ],
  ),
  rang(bloc(role: "precaution", taille: px(25))[Simple ne veut pas dire sans erreur][
    Les clés, les `AllowedIPs`, le pare-feu et l’adressage restent à régler ; une erreur y ouvre ou coupe le tunnel.
  ]),
  source-de: [#link("https://www.wireguard.com/")[wireguard.com] · #link("https://www.wireguard.com/protocol/")[wireguard.com/protocol] · #link("https://www.wireguard.com/papers/wireguard.pdf")[J. Donenfeld, « WireGuard », NDSS 2017]],
  note: [Faits à revérifier en ligne (wireguard.com était inaccessible depuis l’environnement de rédaction) : intégration au noyau 5.6 (mars 2020 ; README.Debian du paquet wireguard-tools : « probably be built in for Linux 5.6 and later ») ; « environ 4 000 lignes » est le chiffre du papier de 2017 pour l’implémentation Linux, valeur datée ; liste des primitives (wireguard.com/protocol : Noise\_IKpsk2, Curve25519, ChaCha20-Poly1305, BLAKE2s, SipHash24, HKDF). Le cours d’origine parlait d’un outil « audité par des cryptographes » : source à préciser avant de le réaffirmer. Le site disait « pas de mauvaise configuration possible » : faux, d’où l’encadré.],
)

== Le modèle : des pairs, des clés, une interface <wireguard-modele>

#anime(
  rang(
    bloc(taille: px(25))[Des pairs, pas de client ni de serveur][
      - Le tunnel passe dans des datagrammes UDP (_User Datagram Protocol_)
      - Chaque machine a une interface `wg0`, une *paire de clés* et une *adresse dans le tunnel* (`10.9.9.1/24`)
      - Elle connaît chacun de ses *pairs* par sa *clé publique*, comme `authorized_keys` en SSH
      - Pour chaque pair : `Endpoint` (son adresse réelle, facultative) et `AllowedIPs` (les adresses du tunnel qui sont à lui)
    ],
  ),
  grid(columns: (1fr, px(720), 1fr), column-gutter: px(16), align: horizon,
    machine(role: [`wg0` : 10.9.9.1], taille: px(26))[pair-a],
    stack(spacing: px(8),
      align(center, block(stroke: px(2) + c.gris, radius: px(10), inset: px(12), text(size: px(23))[
        *datagramme UDP* `172.20.0.2:51820 → 172.20.0.3:51820` \
        #box(fill: c.nuit, radius: px(6), inset: (x: px(10), y: px(6)), text(fill: c.texte-term, size: px(22))[contenu chiffré : le paquet IP #text(font: mono)[10.9.9.1 → 10.9.9.2]])])),
      fleche(bas: [le réseau ordinaire ne voit que de l’UDP chiffré]),
    ),
    machine(role: [`wg0` : 10.9.9.2], taille: px(26))[pair-b],
  ),
  source-de: [#link("https://www.wireguard.com/#conceptual-overview")[wireguard.com, Conceptual Overview] · #link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8")[man wg]],
  note: [Le fil rouge change d’échelle : trois pairs, pair-a, pair-b et pair-c, sur un réseau ordinaire (172.20.0.0/16), le réseau « porteur ». Les adresses 10.9.9.x n’existent que dans le tunnel. Le port 51820 est la convention de la documentation, pas une obligation (ListenPort). Le cours d’origine : « Chaque pair dans WireGuard utilise une clé publique et une clé privée pour s’authentifier. Les paquets IP sont encapsulés dans des paquets UDP, qui sont ensuite chiffrés et transmis à l’autre pair » (plus exactement : le paquet IP est chiffré, puis placé dans un datagramme UDP).],
)

== Générer les clés : wg genkey, wg pubkey

#anime(
  rang(
    bloc(role: "pratique", poids: 1.4, taille: px(24))[Sur chaque pair][
      #terminal(titre: [pair-a · root], taille: px(19))[
        ```
        $ mkdir -p /etc/wireguard
        $ cd /etc/wireguard
        # fichiers lisibles par root seul
        $ umask 077
        $ wg genkey | tee prive.key | wg pubkey > public.key
        $ ls -l
        total 8
        -rw------- 1 root root 45 Nov 25 10:18 prive.key
        -rw------- 1 root root 45 Nov 25 10:18 public.key
        $ cat public.key
        tEh1d84TszzWv5aYCs4D1Teirirh0uzqMtMnwGUXsQk=
        ```
      ]
    ],
    bloc(taille: px(24))[Lire les commandes][
      - `wg genkey` : une clé privée aléatoire, en base64
      - `tee` la garde dans `prive.key` et la passe à `wg pubkey`, qui en calcule la clé publique
      - La clé publique se donne aux autres pairs ; la privée ne quitte jamais la machine
      - Même idée qu’en SSH, autres clés : Curve25519
    ],
  ),
  source-de: link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8")[man wg, genkey et pubkey],
  note: [Commande donnée par man wg : « umask 077 ; wg genkey | tee private.key | wg pubkey > public.key » (noms de fichiers francisés ici). Sortie réelle (wireguard-tools v1.0.20210914) ; le script de rejeu enchaîne ces commandes sur une ligne, sur pair-a, pair-b et pair-c. Clés publiques : pair-a tEh1…sQk=, pair-b v0uv…tQ4=, pair-c di89…M2Bg=. Les pairs sont des conteneurs jetables avec la capacité NET\_ADMIN (créer des interfaces réseau) : un laboratoire, pas une architecture de production.],
)

== wg0.conf et wg-quick : monter le tunnel <wireguard-labo>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.25, taille: px(24))[Le fichier de pair-a, puis la commande][
      #terminal(titre: [pair-a · root], taille: px(18))[
        ```
        $ cat /etc/wireguard/wg0.conf
        [Interface]
        PrivateKey = (clé privée de pair-a)
        Address = 10.9.9.1/24
        ListenPort = 51820

        [Peer]
        # pair-b
        PublicKey = v0uvY9+JmEna+DIQ8fnrtecWYgPrCwONSVoE2K/YtQ4=
        AllowedIPs = 10.9.9.2/32
        Endpoint = 172.20.0.3:51820
        $ wg-quick up wg0
        [#] ip link add wg0 type wireguard
        # … (laboratoire sans module noyau : repli sur wireguard-go, 12 lignes)
        [#] wg setconf wg0 /dev/fd/63
        [#] ip -4 address add 10.9.9.1/24 dev wg0
        [#] ip link set mtu 1420 up dev wg0
        ```
      ]
    ],
    bloc(taille: px(24))[Lire le fichier][
      - `[Interface]` : la machine elle-même ; `Address` est lu par `wg-quick` seul
      - `[Peer]` : un bloc par pair, reconnu à sa clé publique
      - `Endpoint` : où envoyer les datagrammes ; pair-b, lui, n’en a pas pour pair-a
      - `wg-quick` crée l’interface, applique la configuration, l’adresse, puis ajoute les routes déduites des `AllowedIPs`
    ],
  ),
  source-de: [#link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8")[man wg-quick] · #link("https://www.wireguard.com/quickstart/")[wireguard.com/quickstart]],
  note: [Clé privée masquée à l’affichage (le script lit le fichier avec sed). Le noyau de la machine de rédaction n’a pas le module WireGuard : wg-quick l’a signalé (« Missing WireGuard kernel module. Falling back to slow userspace implementation ») et a lancé wireguard-go 0.0.20230223, implémentation en espace utilisateur, qui s’emploie avec les mêmes commandes wg. Lignes omises : « Error: Unknown device type », l’avertissement, « [\#] wireguard-go wg0 » et le bandeau de wireguard-go. Sur Debian 13 avec le module : à rejouer (la commande ip link add réussit, sans repli). man wg-quick : Address, DNS, MTU, Table, PreUp/PostUp… sont propres à wg-quick ; le reste passe à wg setconf. Le cours d’origine ne montait pas de tunnel (« il faudrait que chaque étudiant ait une machine root avec une adresse IP publique ») : deux machines qui se joignent en UDP suffisent, comme ici.],
)

== Le tunnel fonctionne, et ce que voit le réseau

#anime(
  rang(
    bloc(role: "pratique", poids: 1.45, taille: px(24))[Ping dans le tunnel, capture sur le réseau porteur][
      #terminal(titre: [pair-a · root], taille: px(18))[
        ```
        $ ping -c 3 10.9.9.2
        PING 10.9.9.2 (10.9.9.2) 56(84) bytes of data.
        64 bytes from 10.9.9.2: icmp_seq=1 ttl=64 time=9.03 ms
        # … deux réponses de plus
        3 packets transmitted, 3 received, 0% packet loss, time 2004ms
        $ wg show
        # … (clés et port d’écoute)
        peer: v0uvY9+JmEna+DIQ8fnrtecWYgPrCwONSVoE2K/YtQ4=
          endpoint: 172.20.0.3:51820
          allowed ips: 10.9.9.2/32
          latest handshake: 3 seconds ago
          transfer: 476 B received, 532 B sent
        ```
        #cadre([pair-b · root : tcpdump -lni eth0 -c 6 udp, pendant le ping], niveau: 1)[
          ```
          10:18:57.240756 IP 172.20.0.2.51820 > 172.20.0.3.51820: UDP, length 148
          10:18:57.241505 IP 172.20.0.3.51820 > 172.20.0.2.51820: UDP, length 92
          10:18:57.241924 IP 172.20.0.2.51820 > 172.20.0.3.51820: UDP, length 128
          # … trois datagrammes de 128 octets de plus
          ```
        ]
      ]
    ],
    bloc(taille: px(24))[Ce que voit chacun][
      - Dans le tunnel : un ping ordinaire entre 10.9.9.1 et 10.9.9.2
      - Sur le réseau porteur : de l’UDP entre les ports 51820, rien de lisible
      - 148 puis 92 octets : la *poignée de main* ; puis 128 octets par paquet de ping, chiffré
      - pair-b n’avait pas d’`Endpoint` : il a *appris* l’adresse de pair-a au premier paquet authentifié
    ],
  ),
  source-de: [#link("https://www.wireguard.com/protocol/")[wireguard.com/protocol] · #link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8")[man wg, Endpoint]],
  note: [Sorties réelles, abrégées aux endroits marqués « \# … » (trois réponses de ping, rtt, en-tête de wg show, trois datagrammes). Tailles : 148 octets, message d’initiation ; 92, réponse (wireguard.com/protocol) ; 128 = 16 d’en-tête + 96 (paquet IP de 84 octets complété à un multiple de 16) + 16 d’étiquette d’authentification. Le site affirmait, sans l’avoir mesuré, qu’un tcpdump ne verrait que de l’UDP chiffré : c’est ici capturé. pair-b : wg show wg0 endpoints affiche 172.20.0.2:51820 pour pair-a ; man wg : « This endpoint will be updated automatically to the most recent source IP address and port of correctly authenticated packets from the peer ».],
)

== AllowedIPs : une table de routage et un filtre <wireguard-allowedips>

#slide(repeat: 4, self => {
  let (uncover,) = utils.methods(self)
  let cellule(t, gras: false) = text(size: px(22), weight: if gras { 600 } else { 400 }, t)
  grid(columns: (1fr, 1fr), column-gutter: px(40),
    stack(spacing: px(16),
      bloc-anime(bloc(taille: px(23))[Les pairs de pair-a][
        #table(columns: (px(170), 1fr), stroke: none, inset: (x: px(8), y: px(8)),
          fill: (x, y) => if y == 0 { c.bleu-clair } else { none },
          cellule([Pair], gras: true), cellule([AllowedIPs], gras: true),
          cellule([pair-b]), cellule[`10.9.9.2/32`],
          cellule([pair-c]), cellule[`10.9.9.3/32`, `192.168.50.0/24`],
        )
      ], 1, uncover),
      bloc-anime(bloc(taille: px(23))[Sortant : à qui chiffrer ?][
        - Le paquet va vers `192.168.50.7` : le pair dont les `AllowedIPs` contiennent cette adresse, au préfixe *le plus précis* : pair-c
        - Chiffré pour sa clé publique, envoyé à son `Endpoint`
        - Aucun pair ne couvre l’adresse : le paquet est *rejeté*
      ], 2, uncover),
    ),
    stack(spacing: px(16),
      bloc-anime(bloc(taille: px(23))[Entrant : qui a le droit d’envoyer quoi ?][
        - Un paquet arrive, déchiffré avec la clé de pair-b
        - Son adresse *source* doit appartenir aux `AllowedIPs` de pair-b : sinon il est *jeté*
        - pair-b ne peut donc pas se faire passer pour `192.168.50.7`
      ], 3, uncover),
      uncover("4-", colonnes(bloc(role: "retenir", taille: px(23))[À retenir][
        `AllowedIPs` sert deux fois : *routage* des paquets sortants, *filtrage* des paquets entrants, les deux attachés à une clé publique (_cryptokey routing_). Au plus étroit : seulement les adresses qui sont vraiment derrière ce pair.
      ])),
    ),
  )
  source[#link("https://www.wireguard.com/#cryptokey-routing")[wireguard.com, Cryptokey Routing] · #link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8")[man wg, AllowedIPs]]
  utils.speaker-note(self: self)[Un clic par bloc. man wg, AllowedIPs : « a comma-separated list of IP (v4 or v6) addresses with CIDR masks from which incoming traffic for this peer is allowed and to which outgoing traffic for this peer is directed. The catch-all 0.0.0.0/0 may be specified for matching all IPv4 addresses ». 0.0.0.0/0 : tout le trafic IPv4 passe dans le tunnel (le « VPN complet ») ; wg-quick règle alors la route par défaut. Le choix du préfixe le plus précis est démontré dans le corrigé de l’exercice (question 4). Les trois points sont rejoués aux diapositives suivantes. Diapo de référence pour l’artefact « table AllowedIPs » et le TP WireGuard.]
})

== AllowedIPs à l’épreuve : sortant, puis entrant

#anime(
  rang(
    bloc(role: "pratique", taille: px(24))[Sortant : pair-b ne couvre plus 10.9.9.2][
      #terminal(titre: [pair-a · root], taille: px(18))[
        ```
        # clé publique de pair-b abrégée : v0uv…tQ4=
        $ wg set wg0 peer v0uv…tQ4= allowed-ips 10.9.9.3/32
        $ ping -c 2 -W 1 10.9.9.2
        PING 10.9.9.2 (10.9.9.2) 56(84) bytes of data.

        --- 10.9.9.2 ping statistics ---
        2 packets transmitted, 0 received, 100% packet loss, time 1003ms
        $ wg set wg0 peer v0uv…tQ4= allowed-ips 10.9.9.2/32
        ```
      ]
      Aucun pair pour 10.9.9.2 : rien ne part.
    ],
    bloc(role: "pratique", taille: px(24))[Entrant : pair-b refuse la source 10.9.9.1][
      #terminal(titre: [pair-b · root], taille: px(18))[
        ```
        # clé publique de pair-a abrégée : tEh1…sQk=
        $ wg set wg0 peer tEh1…sQk= allowed-ips 10.9.9.100/32
        # octets reçus, puis envoyés, pour pair-a
        $ wg show wg0 transfer
        tEh1…sQk=    532    476
        ```
        #cadre([pair-a · root], niveau: 1)[
          ```
          $ ping -c 2 -W 1 10.9.9.2
          PING 10.9.9.2 (10.9.9.2) 56(84) bytes of data.

          --- 10.9.9.2 ping statistics ---
          2 packets transmitted, 0 received, 100% packet loss, time 1010ms
          ```
        ]
        ```
        $ wg show wg0 transfer
        tEh1…sQk=    788    476
        ```
      ]
      256 octets reçus (deux paquets), aucune réponse : jetés.
    ],
  ),
  source-de: link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8")[man wg, set et show],
  note: [Sorties réelles ; clés publiques abrégées, tabulations remplacées par des espaces. Les commandes wg set modifient l’interface en marche, sans toucher au fichier. À gauche : avec le module noyau, ping affiche en plus « ping: sendmsg: Required key not available » (à rejouer sur Debian 13) ; wireguard-go jette le paquet sans message. Après rétablissement des AllowedIPs, le ping repasse : « 1 packets transmitted, 1 received ».],
)

== Limites, et bonnes pratiques

#anime(
  rang(
    bloc(role: "precaution", taille: px(25))[Limites (cours d’origine)][
      - Créer une interface demande les droits *root* (la capacité `NET_ADMIN`)
      - Pas d’adresses attribuées dynamiquement (pas de DHCP, _Dynamic Host Configuration Protocol_) : chaque pair est configuré à la main
      - Ni certificats ni annuaire d’identités : d’autres outils les ajoutent par-dessus
    ],
    bloc(role: "retenir", taille: px(25))[Bonnes pratiques][
      - Clés privées en `600`, sur un disque chiffré, comme en SSH
      - `AllowedIPs` *au plus étroit* : seulement les adresses derrière chaque pair
      - Pare-feu : n’ouvrir que le port UDP d’écoute (51820 par défaut)
    ],
  ),
  source-de: [#link("https://www.wireguard.com/quickstart/")[wireguard.com/quickstart] · #link("https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8")[man wg-quick]],
  note: [Repris des diapositives « Inconvénients et limitations » et « Bonnes pratiques de sécurité » du cours d’origine. Exemples d’outils qui gèrent des réseaux WireGuard (hors cadre) : Headscale, Netbird, Tailscale. man wg-quick montre aussi comment garder la clé privée chiffrée (PostUp = wg set %i private-key \<(pass …)).],
)

== À vous : WireGuard <exercice-wireguard>

#anime(
  rang(
    bloc(taille: px(24))[pair-a et ses pairs][
      #table(columns: (px(150), 1fr), stroke: none, inset: (x: px(8), y: px(8)),
        fill: (x, y) => if y == 0 { c.bleu-clair } else { none },
        text(weight: 600)[Pair], text(weight: 600)[AllowedIPs],
        [pair-b], [`10.9.9.2/32`],
        [pair-c], [`10.9.9.3/32`, `192.168.50.0/24`],
      )
      pair-b n’a pas d’`Endpoint` pour pair-a.
    ],
    bloc(role: "question", poids: 1.8, taille: px(24))[À vous][
      + pair-a envoie un paquet à `192.168.50.7` : quel pair le reçoit ?
      + Et un paquet pour `10.9.9.4` ?
      + pair-b envoie à pair-a un paquet de source `192.168.50.7` : est-il accepté ?
      + On donne `10.9.9.0/24` à pair-b : où partent les paquets pour `10.9.9.3` ? pour `10.9.9.5` ?
      + Comment pair-b a-t-il pu joindre pair-a sans `Endpoint` ?
    ],
  ),
  note: [À faire en direct, une question par clic, sur le papier, en s’appuyant sur la diapositive « AllowedIPs : une table de routage et un filtre ». Le corrigé vérifie chaque réponse dans le laboratoire avec wg show wg0 transfer. Laisser chercher avant de passer au corrigé.],
)

== À vous : WireGuard, corrigé (1/3)

#corriges(
  note: [Sorties réelles (wireguard-go, voir la diapositive wg-quick) ; clés abrégées, tabulations remplacées par des espaces. Colonnes de wg show wg0 transfer : octets reçus, octets envoyés. Question 1 : pour pair-c, 276 octets envoyés (poignée de main de 148 + paquet de 128) et 92 reçus (réponse de la poignée de main) ; pair-c n’a pas de route vers 192.168.50.7, il ne répond pas. Question 2 : une route existe (le /24 de wg0), mais aucun pair : paquet rejeté ; avec le module noyau, ping afficherait « Required key not available » (à rejouer). Une route vers 192.168.50.0/24 a été ajoutée à la main (ip route add 192.168.50.0/24 dev wg0) : wg-quick ne l’ajoute qu’au démarrage.],
  (1, [Un paquet pour `192.168.50.7` : quel pair le reçoit ?],
    reponse(terminal(titre: none, taille: px(19))[```
  # avant : pair-b (v0uv…) puis pair-c (di89…)
  $ wg show wg0 transfer
  v0uv…tQ4=    604    916
  di89…M2Bg=   0      0
  $ ping -c 1 -W 1 192.168.50.7 >/dev/null; wg show wg0 transfer
  v0uv…tQ4=    604    916
  di89…M2Bg=   92     276
  # → pair-c : seul son compteur a bougé
  ```])),
  (2, [Et un paquet pour `10.9.9.4` ?],
    reponse(terminal(titre: none, taille: px(19))[```
  $ ping -c 1 -W 1 10.9.9.4 | grep received
  1 packets transmitted, 0 received, 100% packet loss, time 0ms
  # → aucun pair ne couvre 10.9.9.4 : rejeté
  ```])),
)

== À vous : WireGuard, corrigé (2/3)

#corriges(
  note: [Question 3 : pair-a a reçu 128 octets de pair-b (604 → 732) et n’a rien répondu : la source 192.168.50.7 n’est pas dans les AllowedIPs de pair-b. Préparation, sur pair-b : ip address add 192.168.50.7/32 dev wg0. Question 4 : 10.9.9.3 appartient à 10.9.9.0/24 (pair-b) et à 10.9.9.3/32 (pair-c) : le /32, plus précis, gagne ; 10.9.9.5 part chez pair-b (128 octets envoyés), qui ne répond pas, faute de machine 10.9.9.5.],
  (3, [pair-b envoie un paquet de source `192.168.50.7` : est-il accepté ?],
    reponse(terminal(titre: none, taille: px(19))[
      #encart([pair-b])[```
  $ ping -c 1 -W 1 -I 192.168.50.7 10.9.9.1 | grep received
  1 packets transmitted, 0 received, 100% packet loss, time 0ms
  ```]
      #encart([pair-a])[```
  $ wg show wg0 transfer
  v0uv…tQ4=    732    916
  di89…M2Bg=   92     276
  # → reçu de pair-b (604 → 732), puis jeté : source hors de ses AllowedIPs
  ```]])),
  (4, [pair-b reçoit `10.9.9.0/24` : où partent `10.9.9.3` et `10.9.9.5` ?],
    reponse(terminal(titre: none, taille: px(19))[```
  $ wg set wg0 peer v0uv…tQ4= allowed-ips 10.9.9.0/24
  $ ping -c 1 -W 1 10.9.9.3 | grep received; wg show wg0 transfer
  1 packets transmitted, 1 received, 0% packet loss, time 0ms
  v0uv…tQ4=    732    916
  di89…M2Bg=   220    404
  $ ping -c 1 -W 1 10.9.9.5 | grep received; wg show wg0 transfer
  1 packets transmitted, 0 received, 100% packet loss, time 0ms
  v0uv…tQ4=    732    1044
  di89…M2Bg=   220    404
  # → 10.9.9.3 : pair-c (/32, plus précis) ; 10.9.9.5 : pair-b
  ```])),
)

== À vous : WireGuard, corrigé (3/3)

#corriges(
  note: [Sortie réelle, clé abrégée. man wg, Endpoint : « This endpoint will be updated automatically to the most recent source IP address and port of correctly authenticated packets from the peer ». C’est aussi ce qui permet à un portable qui change de réseau de garder son tunnel (_roaming_).],
  (5, [Comment pair-b a-t-il joint pair-a sans `Endpoint` ?],
    reponse({
      terminal(titre: [pair-b · root], taille: px(19))[```
  # aucune ligne Endpoint dans sa configuration
  $ grep -c Endpoint /etc/wireguard/wg0.conf
  0
  # l’adresse de pair-a, apprise
  $ wg show wg0 endpoints
  tEh1…sQk=    172.20.0.2:51820
  ```]
      text(size: px(23))[Il ne l’a pas fait : pair-a a parlé le premier. pair-b a *appris* l’adresse de pair-a au premier paquet authentifié. Il suffit qu’un des deux sache où joindre l’autre.]
    })),
)

// ======================================================================
= Pour rappel

== Pour rappel · liste non exhaustive

#anime(
  rang(bloc(role: "retenir", taille: px(27))[L’essentiel du cours][
    - SSH : le client prouve qu’il détient la clé privée, le serveur prouve son identité par sa clé d’hôte ; une empreinte inconnue ou changée se vérifie
    - `~/.ssh/config` nomme les machines ; `ProxyJump` traverse un bastion sans y laisser de clé (pas de `-A`)
    - `-L` apporte un service distant, `-R` expose un service local, `-D` sort par la machine distante
    - Durcir sshd : un fichier de `sshd_config.d` lu en premier, `sshd -t`, une session de secours ouverte
    - tmux : un serveur garde sessions, fenêtres et panneaux ; la coupure n’est qu’un détachement
    - WireGuard : des pairs, des clés ; `AllowedIPs` route les paquets sortants et filtre les paquets entrants
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

#cloture(illustration: "vm")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
