// TP « Découvrir Incus » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     virtualisation/tp/incus/incus.typ build/tp-incus/index.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/virtualisation-projection.pdf"
#let pdf-conteneurisation = "../../../conteneurisation/cm/conteneurisation-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Renvoi vers une diapositive du cours de conteneurisation.
#let dc(ancre, corps) = diapo(pdf-conteneurisation, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Découvrir Incus],
  surtitre: [Fondements de la virtualisation de machines · travaux pratiques],
  sous-titre: [Des machines virtuelles et des conteneurs système, pilotés par un seul outil],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "vm",
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/virtualisation/tp/incus/corrige"),
  ),
)

= Avant de commencer <avant>

Au #d("mini-tp")[mini TP], vous avez lancé une VM en écrivant vous-même la commande QEMU. Ce TP reprend le
même moteur, QEMU et KVM, piloté par Incus. Chaque étape fait découvrir une fonctionnalité d’Incus ; pour
avoir quelque chose à faire tourner, vous y installez WordPress. La séance dure trois heures : les étapes 1
à 5 en sont le cœur, l’étape 6 va plus loin, l’étape 7 est facultative
(#d("tp-incus")[Travaux pratiques : découvrir Incus]).

#bloc(role: "pratique")[Prérequis][
  - Un PC sous Debian 13, installé sur la machine même, avec KVM utilisable : ce sont les questions 1 et 2
    du #d("mini-tp")[mini TP].
  - Les droits root (`sudo`), une connexion au réseau, une dizaine de gigaoctets libres sur le disque.
  - Les ports 8080 et 8081 de votre machine libres.
]

#bloc(role: "question")[Installer et initialiser Incus][
  Les commandes sont celles du cours : #d("incus-installation")[Installer et initialiser Incus].
  #terminal[```console
  # conteneurs système et VM : le paquet incus de Debian 13 (version 6.0.4)
  $ sudo apt install incus
  # réglages par défaut : un pool de stockage, un pont réseau
  $ sudo incus admin init --minimal
  # piloter Incus sans sudo : groupe incus-admin
  $ sudo usermod -aG incus-admin $USER
  # prendre ce groupe dans ce terminal, sans se reconnecter
  $ newgrp incus-admin
  # la liste des instances : vide pour l'instant
  $ incus list
  ```]
  Relevez ensuite ce que l’initialisation a créé : `incus storage list`, `incus network list`,
  `incus profile show default`.
]

#bloc(role: "danger")[Le groupe `incus-admin` vaut root][
  Ses membres pilotent un démon qui tourne en root : ils peuvent monter n’importe quel dossier de l’hôte dans
  une instance. C’est la mise en garde du groupe `docker`
  (#dc("installation")[Contexte d’utilisation et installation]), pour la même raison. N’y inscrivez que des
  comptes à qui vous confieriez `sudo`.
]

#bloc(role: "precaution")[Si Docker est installé sur cette machine][
  Docker fait rejeter par le pare-feu de l’hôte le trafic qu’il ne connaît pas : vos instances démarrent, mais
  n’ont pas de réseau, et `apt` échoue. La documentation d’Incus
  (#link("https://github.com/lxc/incus/blob/v6.0.4/doc/howto/network_bridge_firewalld.md")[Prevent connectivity
  issues with Incus and Docker]) donne les deux règles qui autorisent le pont d’Incus ; elles sont à remettre
  après chaque redémarrage de l’hôte.
  #terminal[```console
  $ sudo iptables -I DOCKER-USER -i incusbr0 -j ACCEPT
  $ sudo iptables -I DOCKER-USER -o incusbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  ```]
  L’étape 7 propose l’autre solution : faire tourner Docker dans une VM d’Incus.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Ouvrez-les après avoir cherché : chaque étape
  repose sur ce que vous avez compris de la précédente. Les corrigés sont des scripts réels, joués et vérifiés
  automatiquement à chaque modification ; tapez leurs commandes une à une plutôt que de les lancer d’un bloc.
]

#schema([Les deux sortes d’instances du TP, sur le même hôte et le même pont : la VM `vm1` (étapes 1 à 4) a son noyau, le conteneur système `ct1` (étape 4) emploie celui de l’hôte.], ch => {
  let c = ch.c
  let large = 215pt
  boite([Hôte · Debian 13], largeur: 500pt, stack(spacing: 8pt,
    grid(columns: 2, column-gutter: 14pt,
      boite([VM `vm1` · un processus QEMU de l’hôte], fond: c.invite-clair, trait: c.invite, largeur: large + 14pt, stack(spacing: 5pt,
        case(largeur: large)[Apache, PHP, MariaDB],
        case(largeur: large)[systemd · agent d’Incus],
        case(largeur: large, fond: c.invite, texte: white)[noyau Linux de l’invité],
        case(largeur: large)[matériel virtuel fourni par QEMU],
      )),
      boite([conteneur système `ct1` · des processus de l’hôte], fond: c.bleu-clair, trait: c.bleu, largeur: large + 14pt, stack(spacing: 5pt,
        case(largeur: large)[Apache],
        case(largeur: large)[systemd],
        v(42pt),
        align(center, text(size: 9pt)[ni noyau, ni matériel virtuel]),
      )),
    ),
    boite([pont `incusbr0` · une adresse par instance, des noms `<instance>.incus`, NAT vers l’extérieur], trait: c.gris, tirets: "dashed", largeur: 100%,
      align(center, text(size: 9pt)[port 8080 de l’hôte → port 80 de `ct1` (périphérique `proxy`, étape 4)])),
    case(largeur: 100%)[démon Incus : lance QEMU pour une VM, isole des processus pour un conteneur système],
    case(largeur: 100%, fond: c.bleu, texte: white)[noyau Linux de l’hôte · KVM · espaces de noms, cgroups],
  ))
})

= Étape 1 : instances et images <etape-1>

Une *instance* est ce qu’Incus crée et gère : une machine virtuelle ou un conteneur système. Vous commencez
par une VM, pour retrouver ce que vous connaissez du mini TP.

#bloc(role: "question")[Consignes][
  - Lancez une VM Debian 13 nommée `vm1`, à partir de l’image `images:debian/13` :
    #d("incus-instances")[Images et instances].
  - Listez les instances ; relevez le type de `vm1`, son état, son adresse IPv4. Affichez son détail avec
    `incus info`.
  - Exécutez `uname -r`, puis `systemd-detect-virt`, dans la VM. Ouvrez-y un shell, puis quittez-le.
  - Ouvrez la console de la VM, puis quittez-la.
  - Sur l’hôte, retrouvez le processus QEMU de `vm1` : son PID, son utilisateur, sa ligne de commande.
]

#indice(titre: [Indice : `incus exec` échoue juste après le lancement])[
  « VM agent isn’t currently running » : `incus exec` entre dans une VM par un agent qui tourne dans
  l’invité, et qui ne répond qu’une fois le système démarré. Attendez quelques secondes ; `incus console vm1`
  montre le démarrage en cours.
]
#indice(titre: [Indice : un shell, la console])[
  `incus exec vm1 -- bash` ouvre un shell root dans la VM. `incus console vm1` ouvre sa console, comme un
  écran branché sur la machine ; pour la quitter : Ctrl+a, puis q.
]
#indice(titre: [Indice : trouver le processus])[
  `incus info vm1` donne le PID du processus qui porte l’instance. Au mini TP, vous l’aviez cherché avec
  `pgrep -l qemu` ; `ps -o pid,user,args -p PID` montre en plus son utilisateur et sa ligne de commande.
]

#corrige[
  #f("1_instances_images/lancer.sh")
]

== Questions

+ Combien de temps s’est écoulé entre votre commande et le premier shell dans la VM ? D’où vient le système
  qu’elle exécute ? `incus image list` vous aidera.
+ Sous quel utilisateur le processus QEMU tourne-t-il ? Sa ligne de commande ressemble-t-elle à celle que vous
  aviez écrite au mini TP ?
+ Que répond `systemd-detect-virt` dans la VM, et qu’aviez-vous obtenu au mini TP ?
+ Avec QEMU seul, comme au #d("mini-tp")[mini TP], qu’auriez-vous dû faire vous-même pour en arriver là ?

#corrige(titre: [Réponses])[
  + Une à deux minutes, dont l’essentiel est le téléchargement de l’image, fait une seule fois. Le système
    vient d’une *image* : un disque Debian 13 déjà installé, publié par le projet Linux Containers sur le
    serveur `images:`. Incus en garde une copie, que `incus image list` montre, et donne à chaque instance son
    propre disque à partir de cette copie.
  + Sous un compte sans privilège, `incus` ou `nobody` selon l’installation : le démon Incus tourne en root,
    pas les VM qu’il lance. La ligne de commande est courte : pas de `-m`, pas de `-drive`, pas de `-nic`, mais
    une option `-readconfig` qui désigne un fichier, `/run/incus/vm1/qemu.conf`. Incus y a écrit la
    description de la machine ; `sudo cat` vous le montre. C’est toujours QEMU, avec KVM : rien de neuf sous
    l’outil.
  + `kvm`, comme à la question 5 du mini TP : l’invité sait qu’il est virtualisé, et par quoi.
  + Télécharger une ISO et la vérifier, créer un disque avec `qemu-img`, écrire la commande QEMU (mémoire,
    disque et carte réseau virtio), dérouler l’installateur de Debian, puis trouver comment entrer dans la
    machine : sa fenêtre, ou un serveur SSH à installer. Incus remplace l’installation par une image, range
    le disque dans son pool de stockage, branche la carte réseau sur son pont, et entre dans la VM par son
    agent.
]

= Étape 2 : administrer comme une machine <etape-2>

Une instance d’Incus fait tourner un système complet, avec systemd : elle s’administre comme un serveur. Vous
y installez WordPress par les paquets de Debian.

#bloc(role: "question")[Consignes][
  - Dans `vm1`, installez les paquets `wordpress` et `mariadb-server`.
  - Créez une base `wordpress` et un utilisateur `wordpress`, mot de passe `tempo`, qui a tous les droits sur
    cette seule base.
  - Donnez à WordPress l’accès à sa base, dans le fichier `/etc/wordpress/config-default.php`.
  - Faites servir `/usr/share/wordpress` par Apache, à la place de son site par défaut.
  - Depuis l’hôte, ouvrez le site dans un navigateur, à l’adresse de la VM sur le pont, et menez
    l’installation de WordPress jusqu’au tableau de bord.
]

#note(role: "avertissement")[Un mot de passe écrit dans un corrigé public est un exemple d’école. Le fichier
  qui le contient n’est lisible, dans la VM, que par root et par le groupe du serveur web.]

#indice(titre: [Indice : deux façons de travailler dans la VM])[
  Ouvrez un shell (`incus exec vm1 -- bash`) et travaillez comme sur un serveur, ou restez sur l’hôte et
  préfixez chaque commande : `incus exec vm1 -- apt-get update`. Pour un fichier, écrivez-le sur l’hôte et
  poussez-le : `incus file push fichier vm1/chemin/dans/la/vm`.
]
#indice(titre: [Indice : le WordPress de Debian])[
  Le paquet range le code dans `/usr/share/wordpress` et les contenus dans `/var/lib/wordpress/wp-content`.
  Son `wp-config.php` charge vos réglages depuis `/etc/wordpress/config-default.php` : quatre constantes,
  `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`. Le paquet explique tout dans
  `/usr/share/doc/wordpress/README.Debian.gz` (lisez-le avec `zless`) et donne un exemple de site Apache dans
  `/usr/share/doc/wordpress/examples/apache.conf`.
]
#indice(titre: [Indice : la base])[
  Dans la VM, root se connecte à MariaDB sans mot de passe, par le socket local.
  #terminal[```console
  $ mariadb -e "CREATE DATABASE nom_base"
  $ mariadb -e "CREATE USER 'nom'@'localhost' IDENTIFIED BY 'mot_de_passe'"
  $ mariadb -e "GRANT ALL PRIVILEGES ON nom_base.* TO 'nom'@'localhost'"
  ```]
]
#indice(titre: [Indice : Apache])[
  Un site se décrit dans `/etc/apache2/sites-available/`, s’active avec `a2ensite`, se désactive avec
  `a2dissite` ; `systemctl reload apache2` applique le changement.
]

#corrige[
  #f("2_administrer/installer.sh")
  #f("2_administrer/config-default.php", lang: "php")
  #f("2_administrer/wordpress.conf", lang: "apache")
]

== Questions

+ Dans la VM, que montre `systemctl status apache2 mariadb` ? Qui a démarré ces services, et qui les
  relancera au prochain démarrage de la VM ?
+ L’adresse de la VM répond depuis l’hôte. Répondrait-elle depuis la machine de votre voisin ?
+ Vous n’avez écrit aucun Dockerfile et lancé aucun conteneur applicatif. En quoi cette façon d’installer
  WordPress diffère-t-elle de celle du cours de conteneurisation ?
+ Avec QEMU seul, comment auriez-vous joint le site depuis l’hôte ?

#corrige(titre: [Réponses])[
  + Deux services actifs et « enabled ». Les paquets les ont démarrés à l’installation, par systemd, qui les
    relancera à chaque démarrage : la VM est une machine entière, avec son init. Un conteneur applicatif, lui,
    n’a qu’un processus principal, que vous désignez.
  + Non. Le pont `incusbr0` est un réseau privé de votre hôte : les instances en sortent par traduction
    d’adresses (NAT), rien n’y entre de l’extérieur. L’étape 4 publie un port.
  + Ici vous administrez une machine : des paquets, des fichiers de configuration, des services, un état qui
    s’accumule sur son disque. Le cours de conteneurisation construit une image à partir d’un Dockerfile, puis
    jette et recrée ses conteneurs. Les deux approches coexistent ; l’étape 5 rapproche la première de la
    seconde.
  + Au mini TP, `-nic user` donnait à la VM un réseau privé simulé par QEMU, sans adresse joignable depuis
    l’hôte : il aurait fallu y ajouter une redirection de port (`hostfwd`), ou créer vous-même un pont, une
    interface TAP et un serveur DHCP. Incus fournit le pont, les adresses et la traduction vers l’extérieur.
]

= Étape 3 : instantanés et limites <etape-3>

#bloc(role: "question")[Consignes][
  - Prenez un instantané de `vm1`, nommé `propre` : #d("incus-instantanes")[Instantanés : figer un état, y
    revenir].
  - Cassez le site : dans la VM, supprimez le code de WordPress, `rm -r /usr/share/wordpress`. Constatez la
    panne dans le navigateur.
  - Restaurez l’instantané, puis vérifiez que le site est revenu, article et réglages compris.
  - Relevez le nombre de processeurs et la mémoire de la VM (`nproc`, `free -m`), puis donnez-lui 2 processeurs
    et 2 Gio de mémoire : #d("incus-limites")[Limites : à chaud, ou au redémarrage]. Essayez d’abord sans
    l’arrêter.
]

#indice(titre: [Indice : après la restauration])[
  Incus redémarre la VM : `incus exec` ne répond de nouveau qu’après quelques secondes.
]
#indice(titre: [Indice : les limites])[
  Ce sont des clés de configuration de l’instance : `incus config set vm1 limits.cpu=2`, de même pour
  `limits.memory` avec une valeur comme `2GiB`. `incus config show vm1` affiche les clés posées.
]

#corrige[
  #f("3_instantanes_limites/instantane.sh")
  #f("3_instantanes_limites/restaurer.sh")
  #f("3_instantanes_limites/limites.sh")
]

== Questions

+ Qu’est-il arrivé à la VM pendant la restauration ? Un article publié entre l’instantané et la restauration
  serait-il encore là ?
+ Que répond Incus quand vous demandez 2 Gio pour une VM en marche qui a démarré avec 1 Gio ? Et pour le
  second processeur : `lscpu --extended` le montre-t-il en ligne dans la VM ?
+ Un instantané est-il une sauvegarde ?
+ Avec QEMU seul, comment auriez-vous pris un instantané, et comment auriez-vous changé la mémoire de la VM ?

#corrige(titre: [Réponses])[
  + Incus l’a arrêtée, a remis son disque dans l’état de l’instantané, puis l’a redémarrée : `uptime` le
    montre. L’article serait perdu : restaurer ramène tout le disque, base de données comprise, à l’état
    figé. Un instantané pris avec `--stateful` fige en plus la mémoire d’une VM en marche.
  + Incus 6.0 refuse : « Cannot increase memory size beyond boot time size when VM is running ». La VM a reçu
    sa mémoire au démarrage de QEMU ; à chaud, Incus sait seulement lui en reprendre. Il faut l’arrêter,
    changer la clé, la redémarrer. Le processeur, lui, est branché à chaud, comme une carte dans une machine
    allumée : `lscpu --extended` l’affiche aussitôt, et sa colonne ONLINE dit si l’invité s’en sert déjà.
    S’il ne l’a pas mis en ligne, le redémarrage qui suit s’en charge. Après le redémarrage : 2 processeurs,
    2 Gio.
  + Non. Il est rangé dans le même pool de stockage que le disque de la VM : une panne du disque de l’hôte
    emporte les deux. Une sauvegarde sort de l’hôte : `incus export vm1 vm1.tar.gz`.
  + Un disque au format qcow2 sait porter des instantanés : `qemu-img snapshot -c propre debian.qcow2`, VM
    arrêtée, ou la commande `savevm` du moniteur QEMU. Pour la mémoire : arrêter la VM et relancer QEMU avec
    une autre valeur de `-m`. Incus garde ces réglages dans sa base, sous forme de clés, et écrit la commande
    à votre place.
]

= Étape 4 : conteneur système <etape-4>

La même image existe sous une autre forme : un *conteneur système*. Il fait tourner le même Debian, avec
systemd, mais sans noyau à lui : #d("vm-et-conteneurs")[VM et conteneurs : deux façons d’isoler]. Vous le
comparez à votre VM par des mesures faites sur votre machine.

#bloc(role: "question")[Consignes][
  - Lancez `ct1` avec la commande de l’étape 1, sans `--vm`. Installez-y le paquet `apache2`.
  - *Noyau.* Comparez `uname -r`, puis `cat /proc/cmdline`, sur l’hôte, dans `vm1` et dans `ct1`. Que répond
    `systemd-detect-virt` dans `ct1` ?
  - *Démarrage.* Dans chaque instance, `systemd-analyze` détaille la durée du démarrage : comparez les phases.
    Chronométrez aussi `incus restart ct1`, puis `incus restart vm1`.
  - *Mémoire.* Comparez le total qu’affiche `free -m` sur l’hôte, dans `vm1` et dans `ct1`. Limitez ensuite
    `ct1` à 512 Mio, sans l’arrêter.
  - *Processus.* Sur l’hôte, listez les processus `apache2` avec leur UID : `ps -o uid,pid,args -C apache2`.
    Apache tourne dans `vm1` et dans `ct1` : lesquels voyez-vous ? Comparez avec la même commande lancée
    dans `ct1`.
  - *Publier un port.* Ajoutez à `ct1` un périphérique `proxy` qui publie son port 80 sur le port 8080 de
    l’hôte : #d("incus-reseau")[Réseau : un pont, des noms, un port publié]. Vérifiez depuis l’hôte :
    `wget -qO- http://localhost:8080`.
]

#indice(titre: [Indice : la correspondance des UID])[
  `incus exec ct1 -- cat /proc/self/uid_map` donne trois nombres : le premier UID vu dans le conteneur, l’UID
  de l’hôte qui lui correspond, et l’étendue de la plage.
]
#indice(titre: [Indice : le périphérique `proxy`])[
  Un périphérique s’ajoute à une instance par `incus config device add instance nom type clé=valeur…`. Le
  type `proxy` prend deux clés : `listen`, l’adresse et le port où l’hôte écoute (`tcp:0.0.0.0:8080`), et
  `connect`, l’adresse et le port joints dans l’instance (`tcp:127.0.0.1:80`).
]

#corrige[
  #f("4_conteneur_systeme/conteneur.sh")
  #f("4_conteneur_systeme/comparer.sh")
  #f("4_conteneur_systeme/proxy.sh")
]

== Questions

+ Quel noyau le conteneur système exécute-t-il ? Et la VM ? Si `uname -r` donne la même version partout,
  qu’est-ce qui les départage ?
+ Quelles phases de démarrage la VM compte-t-elle, que le conteneur système n’a pas ?
+ Pourquoi `ct1` affichait-il toute la mémoire de l’hôte ? Sa limite s’est appliquée sans arrêt : pourquoi
  est-ce possible ici, et pas pour augmenter la mémoire de la VM à l’étape 3 ?
+ Sous quels UID l’hôte voit-il les processus d’Apache de `ct1` ? Où sont ceux de `vm1` ?
+ Ajoutez le même périphérique `proxy` à `vm1`. Que répond Incus, et pourquoi ?
+ Avec QEMU seul, auriez-vous pu obtenir un conteneur système ? Et publier un port de la VM ?

#corrige(titre: [Réponses])[
  + Celui de l’hôte : même version, même ligne de commande de démarrage dans `/proc/cmdline`, qui est celle
    de votre machine. La VM a démarré son propre noyau, avec sa propre ligne de commande. Les versions
    peuvent coïncider, hôte et image étant des Debian 13 : c’est `/proc/cmdline` qui tranche.
    `systemd-detect-virt` répond `lxc` dans le conteneur, du nom de la technologie qu’Incus emploie, et `kvm`
    dans la VM.
  + Le noyau (`kernel`), et selon les cas le micrologiciel et le chargeur de démarrage (`firmware`, `loader`),
    avant l’espace utilisateur. Le conteneur système ne compte que `userspace` : son noyau tournait déjà,
    celui de l’hôte. Son redémarrage est bien plus court que celui de la VM.
  + Un conteneur système est un groupe de processus de l’hôte : sans limite, il voit tous ses processeurs et
    toute sa mémoire. Une limite est un réglage du cgroup de ces processus, que le noyau de l’hôte applique
    aussitôt : `incus exec ct1 -- cat /sys/fs/cgroup/memory.max` la montre, et `free -m` en tient compte. La
    mémoire d’une VM, elle, est du matériel virtuel, fixé au lancement de QEMU.
  + Sous des UID décalés : le root du conteneur est l’UID 1000000 de l’hôte sur une installation par défaut,
    son `www-data` (33) l’UID 1000033. Vu de l’hôte, le root du conteneur n’a aucun privilège ; c’est le _user
    namespace_ du cours de conteneurisation, activé d’office. Les processus de `vm1` n’apparaissent pas :
    l’hôte n’en voit qu’un, QEMU, et ignore ce que le noyau invité exécute.
  + « Only NAT mode is supported for proxies on VM instances ». Pour un conteneur, Incus lance sur l’hôte un
    relais qui écoute sur le port 8080, puis entre dans le réseau du conteneur pour se connecter à
    `127.0.0.1:80` : possible, puisque ce réseau appartient au noyau de l’hôte. Le réseau d’une VM vit dans
    son noyau invité, où l’hôte n’entre pas. Reste la traduction d’adresses : une règle du pare-feu de l’hôte
    réécrit la destination des paquets vers l’adresse de la VM, qui doit alors être fixe. Le script ci-dessous
    publie ainsi le port 80 de `vm1` sur le port 8081 de l’hôte.
    #f("4_conteneur_systeme/proxy-vm.sh")
    #note(role: "precaution")[WordPress a enregistré à son installation l’adresse sous laquelle vous l’avez
      consulté : joint par une autre adresse, il vous y renvoie. Par le port 8081, votre navigateur est donc
      redirigé vers l’adresse de la VM sur le pont.]
  + Un conteneur système, non : QEMU fournit des machines, il ne sait pas isoler des processus de l’hôte.
    Publier un port, oui, par l’option `hostfwd` de `-nic user`, écrite au lancement de la VM.
]

#bloc(role: "retenir")[VM ou conteneur système ?][
  Les mêmes commandes, le même système, deux isolations. La VM a son noyau : elle coûte un démarrage et de la
  mémoire réservée, et isole par le matériel. Le conteneur système partage le noyau de l’hôte : il démarre en
  quelques secondes et ne consomme que ce que ses processus utilisent, mais tout repose sur ce noyau commun.
]

= Étape 5 : profils et cloud-init <etape-5>

Vous avez installé WordPress à la main, dans une machine que vous avez réglée clé par clé. Un *profil* rend
ces réglages réutilisables, et *cloud-init* rejoue l’installation au premier démarrage : la même
description produit une VM ou un conteneur système.

#bloc(role: "question")[Consignes][
  - Écrivez un fichier `cloud-init.yaml` qui refait l’étape 2 : paquets, fichiers de configuration, base,
    site Apache. #d("incus-cloud-init")[cloud-init : s’installer au premier démarrage].
  - Créez un profil `wordpress` qui porte ce fichier dans sa clé `cloud-init.user-data`, et deux limites :
    2 processeurs, 1 Gio de mémoire. #d("incus-profils-commandes")[Profils : une configuration réutilisable].
  - Lancez deux instances à partir de l’image `images:debian/13/cloud`, avec les profils `default` et
    `wordpress` : une VM `wp-vm`, un conteneur système `wp-ct`.
  - Attendez la fin de cloud-init dans chacune, puis ouvrez les deux sites dans un navigateur.
  - Affichez la configuration de `wp-ct` avec `incus config show wp-ct`, puis avec l’option `--expanded`.
]

#note(role: "pratique")[Pour prévoir ce qu’une instance hérite de ses profils, clé par clé et périphérique par
  périphérique, essayez l’artefact #link("../../artefacts/heritage-des-profils/")[L’héritage des profils].]

#indice(titre: [Indice : le format du fichier])[
  La première ligne est `#cloud-config`, la suite est du YAML. Quatre clés suffisent : `package_update` et
  `packages` pour les paquets, `write_files` pour les fichiers (`path`, `content`, `owner`, `permissions`), `runcmd`
  pour les commandes. cloud-init écrit les fichiers avant d’installer les paquets, sauf ceux qui portent
  `defer: true`.
]
#indice(titre: [Indice : suivre cloud-init])[
  `incus exec wp-ct -- cloud-init status --wait` rend la main quand tout est fini. En cas d’erreur, le
  journal est dans l’instance : `/var/log/cloud-init-output.log`.
]

#corrige[
  #f("5_profils_cloud_init/cloud-init.yaml")
  #f("5_profils_cloud_init/profil.sh")
]

== Questions

+ `incus config show wp-ct` ne montre ni limite ni cloud-init ; avec `--expanded`, tout y est. D’où viennent
  ces clés, et d’où viennent le disque `root` et la carte `eth0` ?
+ Posez `limits.memory=512MiB` sur `wp-ct`. Quelle valeur l’emporte, pour `wp-ct` et pour `wp-vm` ?
  #d("incus-profils")[Héritage des profils : deux régimes].
+ Relancez une instance avec `--profile wordpress` seul. Que répond Incus ?
+ À l’étape 4, `incus config device override vm1 eth0 ipv4.address=…` a recopié tout le périphérique `eth0`
  dans la configuration de la VM. Pourquoi ne pas y écrire la seule clé `ipv4.address` ?
+ Modifiez `cloud-init.yaml`, puis rechargez-le dans le profil. Les deux instances changent-elles ?
+ Avec QEMU seul, comment auriez-vous obtenu deux machines installées de la même façon ?

#corrige(titre: [Réponses])[
  + Des profils. La configuration d’une instance est le résultat de ses profils, appliqués dans l’ordre, puis
    de ses propres clés : `default` apporte `root` et `eth0`, `wordpress` les limites et cloud-init, et
    `wp-ct` n’a rien à elle.
  + 512 Mio pour `wp-ct` : sa propre clé passe après celles des profils. `wp-vm` garde 1 Gio, la valeur du
    profil. Les clés se remplacent une à une : `limits.cpu` vient toujours du profil.
  + « No root device could be found ». Nommer un profil remplace la liste des profils : `default` n’est
    appliqué d’office que si vous n’en nommez aucun. Sans lui, pas de disque `root`, pas de carte `eth0`.
  + Parce que les périphériques ne suivent pas la règle des clés : à nom égal, le dernier remplace l’autre
    en entier. Un `eth0` réduit à `ipv4.address` n’aurait plus ni type ni réseau. `override` recopie donc le
    périphérique du profil dans l’instance, avec la clé en plus.
  + Non. cloud-init n’agit qu’au premier démarrage d’une instance : le profil modifié vaut pour les
    prochaines. Les limites du profil, elles, valent pour toutes ses instances dès qu’on les modifie.
  + En refaisant l’installation dans chacune, ou en copiant le disque de la première. cloud-init fonctionne
    aussi sans Incus : c’est l’outil des images « cloud » de Debian, auxquelles on présente la description
    sur un second disque. Incus se charge de la lui transmettre.
]

= Étape 6 : réseau et volumes <etape-6>

_Pour aller plus loin._ WordPress et sa base vont dans deux instances, qui se joignent par leur nom ; les
données de la base vont sur un volume, hors de l’instance.

#bloc(role: "question")[Consignes][
  - Créez un volume `donnees` dans le pool de stockage `default` :
    #d("incus-volumes")[Volumes : les données hors de l’instance].
  - Lancez une instance `db`, attachez-lui le volume sur `/var/lib/mysql`, puis installez-y `mariadb-server`.
    Créez la base et l’utilisateur de l’étape 2 ; cet utilisateur se connecte depuis une autre machine.
  - Lancez une instance `web`, installez-y le paquet `wordpress`, et donnez-lui pour adresse de la base le
    nom `db.incus` : #d("incus-reseau")[Réseau : un pont, des noms, un port publié].
  - Installez WordPress depuis le navigateur.
  - Arrêtez `db`, supprimez-la, recréez-la avec le même volume. Le site est-il toujours installé ?
]

#indice(titre: [Indice : MariaDB n’écoute que localement])[
  Par défaut, le MariaDB de Debian n’accepte que les connexions de sa propre machine : c’est la ligne
  `bind-address` de `/etc/mysql/mariadb.conf.d/50-server.cnf`. Un fichier lu après lui, dans le même dossier,
  peut donner une autre valeur. Côté base, l’utilisateur se déclare `'wordpress'@'%'` : `%` vaut pour toute
  machine.
]
#indice(titre: [Indice : vérifier les noms])[
  `incus exec web -- getent hosts db.incus` interroge le serveur de noms du pont.
]

#corrige[
  Ces corrigés emploient deux conteneurs système ; avec `--vm`, les commandes sont les mêmes.
  #f("6_reseau_volumes/deployer.sh")
  #f("6_reseau_volumes/db.sh")
  #f("6_reseau_volumes/ecoute.cnf", lang: "ini")
  #f("6_reseau_volumes/config-default.php", lang: "php")
  Le site Apache, `wordpress.conf`, est celui de l’étape 2.
  #f("6_reseau_volumes/recreer-db.sh")
]

== Questions

+ La nouvelle instance `db` a-t-elle la même adresse que l’ancienne ? Pourquoi `web` la retrouve-t-elle ?
+ Qu’est-ce qui a survécu à la suppression de `db`, et qu’a-t-il fallu refaire ?
+ Comparez avec l’étape 5 du TP de conteneurisation, si vous l’avez fait : que retrouvez-vous ?
+ Avec QEMU seul, comment deux VM se seraient-elles jointes par leur nom ?

#corrige(titre: [Réponses])[
  + Pas forcément : le pont lui attribue une adresse à sa création. `web` la désigne par son nom, `db.incus`,
    que le serveur de noms du pont tient à jour pour chaque instance.
  + Les fichiers de `/var/lib/mysql`, donc la base, ses tables et son utilisateur : ils sont sur le volume.
    Tout le reste était sur le disque de l’instance, supprimé avec elle : le paquet et le réglage d’écoute
    sont à remettre. D’où l’intérêt de les décrire, dans un script ou par cloud-init.
  + Les mêmes idées sous d’autres noms : un réseau où les noms se résolvent, un volume qui survit à ce qui
    l’utilise, une base qui n’est pas publiée sur l’hôte. Docker les applique à des conteneurs applicatifs,
    Incus à des machines.
  + Il aurait fallu créer un pont et ses interfaces, y faire tourner un serveur DHCP et un serveur de noms, ou
    tenir à la main le fichier `/etc/hosts` de chaque VM.
]

= Étape 7 : imbrication <etape-7>

_Facultative._ Le cours de conteneurisation pose la question :
#dc("hote-ou-vm")[Où faire tourner Docker : hôte ou VM ?]. Une VM d’Incus y répond en une commande, et peut
servir de poste pour le TP #link("../../../conteneurisation/tp/wordpress/")[Conteneuriser WordPress].

#bloc(role: "question")[Consignes][
  - Lancez une VM `docker` avec 2 processeurs, 2 Gio de mémoire et un disque de 20 Gio.
  - Installez-y les paquets `docker.io` et `docker-compose`, puis lancez le conteneur `hello-world`.
  - Si vous enchaînez sur le TP de conteneurisation : travaillez dans un shell de la VM
    (`incus exec docker -- bash`) ; le site s’ouvre depuis l’hôte à l’adresse de la VM, port 8080.
]

#indice[
  Clés et périphériques se donnent dès le lancement : `--config limits.cpu=2`, et `--device root,size=20GiB`
  pour reprendre le disque du profil `default` en changeant sa taille.
]

#corrige[
  #f("7_imbrication/docker.sh")
]

== Questions

+ Dans cette VM, vous êtes root et vous pilotez Docker. Qu’atteint un processus qui s’échapperait d’un
  conteneur applicatif ?
+ Docker tourne-t-il aussi dans un conteneur système d’Incus ?
+ Combien de noyaux Linux tournent sur votre machine quand `hello-world` s’exécute ? Est-ce de la
  virtualisation imbriquée ?

#corrige(titre: [Réponses])[
  + La VM, pas votre machine : le noyau invité et la frontière de QEMU le séparent encore de l’hôte. Une VM
    compromise se supprime et se recrée ; c’est l’argument de la diapositive
    #dc("hote-ou-vm")[Où faire tourner Docker : hôte ou VM ?].
  + Oui, à condition d’autoriser l’imbrication par la clé `security.nesting=true`
    (#link("https://github.com/lxc/incus/blob/v6.0.4/doc/faq.md")[FAQ d’Incus]). Les conteneurs applicatifs
    partagent alors le noyau de l’hôte, comme le conteneur système qui les porte : l’isolation de la VM est
    perdue.
  + Deux : celui de l’hôte et celui de la VM. Le conteneur `hello-world` emploie le noyau de la VM. Ce n’est
    pas de la virtualisation imbriquée, qui lance une VM dans une VM, comme à la question 6 du mini TP : ici,
    des conteneurs tournent dans une VM.
]

= Pour finir <fin>

#bloc(role: "question")[Trois étages sur le même moteur][
  QEMU nu, libvirt (`virsh`, virt-manager) et Incus pilotent tous trois QEMU et KVM. Remplissez ce tableau à
  partir de ce que vous avez fait au mini TP et dans ce TP, et de ce que le cours dit de libvirt
  (#d("virsh")[virt-install et virsh], #d("virt-manager")[virt-manager]) : un « + » pour un atout, un « − »
  pour une limite, et quelques mots pour le justifier.
  #table(columns: 4,
    table.header[][QEMU nu (mini TP)][libvirt][Incus],
    [Mécanisme transparent], [], [], [],
    [Images prêtes], [], [], [],
    [Réseau et stockage gérés], [], [], [],
    [Conteneurs et VM ensemble], [], [], [],
    [API et automatisation], [], [], [],
    [Poste de travail graphique], [], [], [],
    [Sans démon root], [], [], [],
  )
  Comparez ensuite avec la diapositive #d("trois-etages")[QEMU, libvirt, Incus : trois étages, un moteur].
]

#bloc(role: "retenir")[Ce que ce TP a montré][
  - Une instance d’Incus est une VM ou un conteneur système, lancée depuis une image et pilotée par les mêmes
    commandes.
  - Une VM d’Incus reste un processus QEMU de l’hôte ; un conteneur système est un groupe de processus de
    l’hôte, sous des UID décalés.
  - Instantanés, limites, profils, cloud-init, pont, volumes : Incus garde la description de chaque machine
    et écrit les commandes à votre place.
  - Plus l’outil en fait, moins le mécanisme se voit : savoir lire une commande QEMU reste ce qui permet de
    comprendre une panne.
]

#bloc(role: "pratique")[Faire le ménage][
  Les instances arrêtées gardent leur disque. Pour tout supprimer :
  #terminal[```console
  $ incus delete --force vm1 ct1 wp-vm wp-ct web db docker
  $ incus profile delete wordpress
  $ incus storage volume delete default donnees
  ```]
]
