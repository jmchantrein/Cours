// TP « Administrer des VM avec libvirt » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     virtualisation/tp/libvirt/libvirt.typ build/libvirt.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/virtualisation-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)

#show: page-web.with(
  titre: [Administrer des VM avec libvirt],
  surtitre: [Fondements de la virtualisation de machines · travaux pratiques],
  sous-titre: [Une VM installée avec virt-install, puis clonée, photographiée, branchée et effacée avec virsh],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "vm",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/virtualisation/tp/libvirt/corrige"),
    ([Documentation de libvirt], "https://libvirt.org/docs.html"),
  ),
)

= Avant de commencer <avant>

Le mini TP du cours lançait QEMU à la main : #d("mini-tp")[Mini TP : une VM, puis une VM dans la VM]. Ce TP confie
les VM à libvirt, qui les décrit en XML, les démarre, les arrête, gère leurs réseaux et leurs disques :
#d("libvirt-xml")[libvirt décrit chaque objet en XML]. Vous créez trois VM Debian, de trois façons : par
l’installateur, par une copie complète, puis par un disque en copie sur écriture.

#bloc(role: "pratique")[Prérequis][
  - Un PC sous Debian 13 dont le processeur expose VT-x ou AMD-V, avec 15 Gio de disque libre.
  - L’image netinst de Debian, téléchargée et vérifiée (signature, puis empreinte) :
    #d("iso-verifier")[Télécharger l’ISO, puis la vérifier]. Le TP la suppose dans `~/iso-debian/`, et le paquet `acl` (`setfacl`) doit être installé : `sudo apt install acl`.
  - Un dossier de travail pour les fichiers du TP (XML, scripts).
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, vérifiés
  automatiquement à chaque modification : validation des XML contre les schémas de libvirt, analyse des scripts,
  puis cycle complet d’une VM (définir, démarrer, instantané, retour, arrêt, effacement) sur une machine sans
  KVM. Les sorties montrées viennent de libvirt 10.0.0, en anglais ; sur un système en français, `virsh` traduit
  une partie des messages et des en-têtes de colonnes.
]

#schema([Ce que vous aurez construit à l’étape 9 : trois VM, deux réseaux, quatre volumes dans le pool `default`.], ch => {
  let c = ch.c
  let vm(nom) = case(fond: c.invite-clair, largeur: 110pt, nom)
  let vol(nom) = case(largeur: 150pt, nom)
  boite([Hôte · connexion `qemu:///system`], stack(spacing: 10pt,
    grid(columns: 3, column-gutter: 10pt, vm[`ma-premiere-vm`], vm[`deuxieme-vm`], vm[`troisieme-vm`]),
    grid(columns: 2, column-gutter: 10pt,
      boite([réseau `default` : NAT, pont `virbr0`], trait: c.gris, tirets: "dashed", largeur: 230pt,
        text(size: 9pt)[les trois VM ; sortie vers l’extérieur]),
      boite([réseau `labo` : isolé, pont `virbr1`], trait: c.gris, tirets: "dashed", largeur: 230pt,
        text(size: 9pt)[`ma-premiere-vm` et `deuxieme-vm` ; aucune sortie]),
    ),
    boite([pool `default` : `/var/lib/libvirt/images`], fond: c.bleu-clair, trait: c.bleu, grid(columns: 2, column-gutter: 8pt, row-gutter: 6pt,
      vol[`ma-premiere-vm.qcow2`], vol[`deuxieme-vm.qcow2` (copie)],
      vol[`base-ma-premiere-vm.qcow2`], vol[`troisieme-vm.qcow2` → base],
    )),
  ))
})

= Étape 1 : préparer l’hôte <etape-1>

#bloc(role: "question")[Consignes][
  - Vérifiez que le processeur expose les extensions de virtualisation et que `/dev/kvm` existe : questions 1 et 2
    du mini TP, #d("mini-tp-corrige-1")[corrigé (1/4)].
  - Installez QEMU, libvirt, virt-install et virt-viewer, sans interface graphique de gestion.
  - Donnez à votre compte l’accès à la connexion `qemu:///system`, sans `sudo`.
  - Faites de `qemu:///system` la connexion par défaut de `virsh` et de `virt-install`, pour ce terminal et les
    suivants. Vérifiez avec `virsh uri`.
  - Écrivez un script `verifier-hote.sh` qui contrôle tout cela et dont le code de sortie vaut 0 si l’hôte est prêt.
]

#indice(titre: [Indice : les paquets et le groupe])[
  La démonstration de #d("virt-install")[Créer une VM : virt-install, puis virsh] donne la liste des paquets.
  Le groupe `libvirt` ouvre la connexion `qemu:///system` ; il ne compte qu’après une nouvelle connexion à
  votre session (`id` le montre).
]
#indice(titre: [Indice : la connexion par défaut])[
  Un compte ordinaire parle à `qemu:///session`, où n’existent ni le réseau ni le pool `default` :
  #d("connexions-libvirt")[Deux connexions : system ou session]. La variable `LIBVIRT_DEFAULT_URI` change ce
  choix.
]

#corrige[
  #terminal[```console
  $ sudo apt install qemu-system-x86 libvirt-daemon-system virtinst virt-viewer
  $ sudo adduser "$USER" libvirt
  # … fermer la session, puis la rouvrir
  $ echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> ~/.bashrc
  $ export LIBVIRT_DEFAULT_URI=qemu:///system
  $ virsh uri
  qemu:///system
  $ ./verifier-hote.sh
  ```]
  Le script interroge libvirt par `virsh version` plutôt que de tester le nom d’un service : selon la
  distribution, le démon s’appelle `libvirtd` ou `virtqemud`.
  #f("verifier-hote.sh")
]

= Étape 2 : le réseau default <etape-2>

#bloc(role: "question")[Consignes][
  - Listez les réseaux libvirt, actifs et inactifs.
  - Démarrez le réseau `default` s’il ne l’est pas, et faites-le démarrer avec l’hôte.
  - Affichez sa définition, et retrouvez le fichier que libvirt a installé.
  - Observez l’interface réseau qu’il a créée sur l’hôte.
]

#indice(titre: [Indice : les commandes])[
  Les commandes des réseaux commencent par `net-` : `virsh help network` les liste. Le pont se lit avec
  `ip addr show`. Les trois modes de réseau : #d("reseaux-libvirt")[Trois façons de brancher une VM].
]

#corrige[
  #terminal[```console
  $ virsh net-list --all
   Name      State    Autostart   Persistent
  --------------------------------------------
   default   active   yes         yes
  # s’il est inactif, ou s’il ne démarre pas avec l’hôte :
  $ virsh net-start default
  $ virsh net-autostart default
  $ virsh net-dumpxml default
  $ ip addr show virbr0
  6: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
      link/ether 52:54:00:fa:3b:cc brd ff:ff:ff:ff:ff:ff
      inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
         valid_lft forever preferred_lft forever
  ```]
  Le réseau `default` est un pont, `virbr0`, porté par l’hôte (192.168.122.1) : libvirt y sert le DHCP et fait
  sortir les VM par l’adresse de l’hôte (NAT). `NO-CARRIER` : aucune VM n’y est encore branchée. Le fichier
  installé par libvirt écrit `<forward/>` sans mode ; `nat` est le mode par défaut, que `net-dumpxml` affiche.
  #f("reseau-default.xml", lang: "xml")
]

= Étape 3 : créer la première VM <etape-3>

#bloc(role: "question")[Consignes][
  - Écrivez un script `premiere-vm.sh` qui crée avec `virt-install` la VM `ma-premiere-vm` : 2 Gio de mémoire,
    2 processeurs, un disque de 10 Gio, branchée sur le réseau `default`, démarrée sur l’image netinst.
  - Lancez-le, puis installez Debian dans la fenêtre de virt-viewer : *pas d’environnement de bureau*, mais un
    *serveur SSH*.
  - Où est rangé le disque de la VM ? Quel micrologiciel virt-install a-t-il choisi ?
]

#indice(titre: [Indice : virt-install])[
  La diapositive #d("virt-install")[Créer une VM : virt-install, puis virsh] donne presque toute la commande.
  `--network network=default` passe par le réseau libvirt plutôt que de nommer son pont. Le disque :
  `virsh domblklist`, puis `virsh vol-list default`. Le micrologiciel : cherchez `loader` ou `firmware` dans
  `virsh dumpxml`. Si l'installateur ne démarre pas (`Permission denied` sur l'image ISO) : QEMU ne tourne pas
  sous votre compte, voyez le corrigé.
]

#corrige[
  #f("premiere-vm.sh")
  Avec `qemu:///system`, QEMU tourne sous le compte `libvirt-qemu`. libvirt lui donne le fichier de l'ISO, mais
  pas les dossiers qui y mènent : sur Debian 13, votre dossier personnel est en mode `0700`, et `libvirt-qemu`
  ne peut pas le traverser. Sans la ligne `setfacl` du script, qui lui accorde le seul droit de traverser
  (`x`, ni lire ni lister), `virt-install` échoue en `Permission denied`. Le disque de la VM n'a pas ce
  problème : il va dans le pool `default`, sous `/var/lib/libvirt/images`, que `libvirt-qemu` sait lire. Rangez
  de même tout disque ou toute image que vous créez à la main dans un dossier que `libvirt-qemu` peut
  traverser, jamais sous votre dossier personnel.
  Une VM de serveur s’administre à distance, en texte : un bureau consommerait mémoire et disque pour un écran
  que personne ne regarde. La console de virt-viewer reste le recours quand le réseau ne répond plus.
  Le disque est le volume `ma-premiere-vm.qcow2` du pool `default`, c’est-à-dire
  `/var/lib/libvirt/images/ma-premiere-vm.qcow2` : #d("pools-volumes")[Pools et volumes]. Aucun `loader` dans
  le XML : la VM démarre en BIOS, ce que virt-install choisit pour Debian, et qui permet les instantanés de
  l’étape 7.
]

= Étape 4 : se connecter à la VM <etape-4>

#bloc(role: "question")[Consignes][
  - L’installation finie, démarrez la VM si elle est arrêtée.
  - Trouvez son adresse IP sans ouvrir sa console.
  - Connectez-vous en SSH et prouvez que vous êtes dans la VM : processeurs, mémoire, disque, hyperviseur.
]

#indice(titre: [Indice : l’adresse])[
  `virsh domifaddr` lit les baux que le DHCP du réseau `default` a distribués. Dans l’invité,
  `systemd-detect-virt` nomme l’hyperviseur : question 5 du mini TP.
]

#corrige[
  #terminal[```console
  $ virsh start ma-premiere-vm
  Domain 'ma-premiere-vm' started
  $ virsh domifaddr ma-premiere-vm
  # une ligne : vnet0, l’adresse MAC de la VM, une adresse en 192.168.122.x/24
  $ ssh utilisateur@192.168.122.x
  ```]
  Dans la VM, `nproc` affiche 2, `free -h` environ 2 Gio, `df -h /` une partition de `/dev/vda` (le `v` de virtio), un peu
  moins de 10 Gio et `systemd-detect-virt` répond `kvm` : ce ne sont pas les ressources de l’hôte.
]

= Étape 5 : un domaine est un XML <etape-5>

#bloc(role: "question")[Consignes][
  - Affichez la définition de `ma-premiere-vm`, et retrouvez-y le squelette du fichier `vm-exemple.xml`
    ci-dessous : nom, mémoire, processeurs, disque, carte réseau.
  - Éteignez la VM, puis créez `deuxieme-vm`, une copie complète de `ma-premiere-vm`.
  - Comparez les définitions des deux VM : quels champs ont changé, et pourquoi devaient-ils changer ?
]

#f("vm-exemple.xml", lang: "xml")

#indice(titre: [Indice : à la main ou avec virt-clone])[
  À la main : `virsh dumpxml ma-premiere-vm > deuxieme-vm.xml`, modifier le fichier, copier le disque, puis
  `virsh define deuxieme-vm.xml`. `virt-clone` fait les mêmes retouches et la copie du disque, sans risque
  d’oubli. Dans les deux cas, la VM d’origine doit être éteinte : un disque copié pendant que la VM écrit dessus
  est incohérent.
]

#corrige[
  #f("deuxieme-vm.sh")
  #terminal[```console
  $ virsh shutdown ma-premiere-vm
  # … attendre qu’elle soit « shut off » (virsh list --all)
  $ ./deuxieme-vm.sh ma-premiere-vm deuxieme-vm
  Allocating 'deuxieme-vm.qcow2'                              |    0 B  00:00 ...

  Clone 'deuxieme-vm' created successfully.
  == ma-premiere-vm
  1c60f5b5-b194-42d6-b692-a3da409e02b4

   Interface   Type      Source    Model    MAC
  -------------------------------------------------------------
   -           network   default   virtio   52:54:00:e4:8a:bf

   Target   Source
  --------------------------------------------------------
   vda      /var/lib/libvirt/images/ma-premiere-vm.qcow2

  == deuxieme-vm
  e3bb6267-6b76-497c-a731-21f4a6c8a154

   Interface   Type      Source    Model    MAC
  -------------------------------------------------------------
   -           network   default   virtio   52:54:00:c2:a5:89

   Target   Source
  -----------------------------------------------------
   vda      /var/lib/libvirt/images/deuxieme-vm.qcow2
  ```]
  Quatre champs changent : le nom (unique), l’uuid (l’identité de la VM pour libvirt), l’adresse MAC (deux
  cartes de même adresse sur un réseau se volent leurs paquets) et le disque. À la main, on supprime `<uuid>` et
  `<mac>` : `virsh define` en génère de neufs. Le système copié garde le nom d’hôte, l’identifiant de machine
  (`/etc/machine-id`) et les clés SSH d’hôte de la première VM : `virt-sysprep` (paquet `guestfs-tools`) les
  réinitialise.
]

= Étape 6 : démarrer, éteindre, débrancher <etape-6>

#bloc(role: "question")[Consignes][
  - Démarrez les deux VM, listez-les, affichez les informations de l’une d’elles et celles de l’hôte.
  - Arrêtez `deuxieme-vm` de deux façons : proprement, puis brutalement après l’avoir relancée. Qu’est-ce qui
    les distingue, et que reste-t-il de la VM après chacune ?
  - Faites démarrer `ma-premiere-vm` avec l’hôte, puis annulez ce réglage.
]

#indice(titre: [Indice : le vocabulaire])[
  #d("cycle-de-vie")[Le cycle de vie d’un domaine] et #d("arreter-effacer")[Éteindre, débrancher, effacer].
  Commandes : `list --all`, `dominfo`, `nodeinfo`, `shutdown`, `destroy`, `autostart`.
]

#corrige[
  #terminal[```console
  $ virsh start ma-premiere-vm
  Domain 'ma-premiere-vm' started
  $ virsh start deuxieme-vm
  Domain 'deuxieme-vm' started
  $ virsh list --all
  $ virsh dominfo ma-premiere-vm
  $ virsh nodeinfo
  $ virsh shutdown deuxieme-vm
  Domain 'deuxieme-vm' is being shutdown
  # … attendre « shut off » : relancée avant, « Domain is already active »
  $ virsh start deuxieme-vm
  Domain 'deuxieme-vm' started
  $ virsh destroy deuxieme-vm
  Domain 'deuxieme-vm' destroyed
  $ virsh autostart ma-premiere-vm
  Domain 'ma-premiere-vm' marked as autostarted
  $ virsh autostart --disable ma-premiere-vm
  Domain 'ma-premiere-vm' unmarked as autostarted
  ```]
  `shutdown` envoie à l’invité l’événement ACPI du bouton d’alimentation : Debian s’éteint proprement, en
  quelques secondes. `destroy` arrête le processus QEMU sur-le-champ, comme une coupure de courant. Dans les deux
  cas, la définition et le disque restent : `virsh list --all` montre la VM `shut off`, et `start` la relance.
  `dominfo` affiche l’état, la mémoire, le nombre de processeurs et le démarrage automatique ; `nodeinfo` les
  processeurs et la mémoire de l’hôte, à connaître avant de lancer plusieurs VM.
]

= Étape 7 : les instantanés <etape-7>

#bloc(role: "question")[Consignes][
  - Prenez un instantané `avant-tp` de `ma-premiere-vm` en marche.
  - Dans l’invité, cassez quelque chose : supprimez un paquet, ou un fichier de configuration.
  - Revenez à l’instantané. Que devient ce qui s’est passé entre les deux ? Où l’instantané est-il rangé ?
]

#indice(titre: [Indice : les commandes])[
  `virsh help snapshot` ; la diapositive #d("instantanes")[Instantanés : revenir en arrière].
]

#corrige[
  #terminal[```console
  $ virsh snapshot-create-as ma-premiere-vm avant-tp --description "état sain"
  Domain snapshot avant-tp created
  $ virsh snapshot-list ma-premiere-vm
   Name       Creation Time               State
  -------------------------------------------------
   avant-tp   2026-11-25 09:57:10 +0000   running
  # … la fausse manœuvre, dans l’invité
  $ virsh snapshot-revert ma-premiere-vm avant-tp
  Domain snapshot avant-tp reverted
  ```]
  L’instantané est interne : il est rangé dans le fichier qcow2 de la VM, avec la mémoire de la VM en marche.
  Le retour rend le disque et la mémoire du moment de l’instantané ; tout ce qui a été fait depuis est perdu.
  Une VM en UEFI refuserait : « internal snapshots of a VM with pflash based firmware are not supported » (libvirt
  10.0) ; libvirt 11.3, celui de Debian 13, répond « … require QCOW2 nvram format », une NVRAM au format qcow2
  qui n’est pas celle par défaut. D’où le BIOS de l’étape 3.
]

= Étape 8 : une troisième VM en copie sur écriture <etape-8>

#bloc(role: "question")[Consignes][
  - Listez les pools de stockage et les volumes du pool `default`.
  - Créez `troisieme-vm`, dont le disque s’appuie sur une image de base, copie figée du disque de
    `ma-premiere-vm` : le disque de la troisième VM ne garde que ses différences.
  - Comparez la place occupée par les trois disques. Affichez la chaîne d’images du disque de `troisieme-vm`.
  - Démarrez `troisieme-vm`. Pourquoi l’image de base ne doit-elle plus jamais changer ?
]

#indice(titre: [Indice : le modèle])[
  #d("qcow2-backing")[qcow2 : copie sur écriture et chaîne d’images], puis la démonstration
  #d("backing-file")[Une VM de plus pour 196 Kio]. Pour voir qui fournit chaque grappe, ce que pèse chaque image
  et ce qu’une écriture dans la base change : l’artefact #link("../../artefacts/chaine-qcow2/")[La chaîne d’images qcow2].
]
#indice(titre: [Indice : les commandes])[
  `virsh vol-clone` copie un volume ; `virsh vol-create-as` crée un volume, et `--backing-vol` l’adosse à un
  autre. `virt-clone --preserve-data --file …` clone une définition en la branchant sur un disque existant, sans
  le copier. Les fichiers du pool appartiennent à root : lisez-les avec `sudo`.
]

#corrige[
  #f("troisieme-vm.sh")
  #terminal[```console
  $ virsh shutdown ma-premiere-vm
  # … attendre qu’elle soit « shut off »
  $ ./troisieme-vm.sh ma-premiere-vm troisieme-vm
  Vol base-ma-premiere-vm.qcow2 cloned from ma-premiere-vm.qcow2

  Vol troisieme-vm.qcow2 created


  Clone 'troisieme-vm' created successfully.
      <path>/var/lib/libvirt/images/base-ma-premiere-vm.qcow2</path>
      <format type='qcow2'/>
  $ virsh vol-list default
   Name                        Path
  --------------------------------------------------------------------------------
   base-ma-premiere-vm.qcow2   /var/lib/libvirt/images/base-ma-premiere-vm.qcow2
   deuxieme-vm.qcow2           /var/lib/libvirt/images/deuxieme-vm.qcow2
   ma-premiere-vm.qcow2        /var/lib/libvirt/images/ma-premiere-vm.qcow2
   troisieme-vm.qcow2          /var/lib/libvirt/images/troisieme-vm.qcow2
  $ cd /var/lib/libvirt/images
  $ sudo qemu-img info --backing-chain troisieme-vm.qcow2 | grep -E '^image|^backing file:|^disk size'
  $ sudo ls -sh base-ma-premiere-vm.qcow2 deuxieme-vm.qcow2 ma-premiere-vm.qcow2 troisieme-vm.qcow2
  $ virsh start troisieme-vm
  Domain 'troisieme-vm' started
  ```]
  Juste après sa création, le disque de `troisieme-vm` occupe environ 200 Kio, contre quelques Gio pour
  `ma-premiere-vm` et sa copie complète `deuxieme-vm` : il ne contient que les grappes que la VM a écrites, et
  lit les autres dans la base. `qemu-img info --backing-chain` affiche les deux images de la chaîne ; on n’y
  cherche pas l’image de base avec `tail` : la fin de la sortie (« Format specific information », « Child
  node ») dépend de la version de QEMU. La base est une copie : `ma-premiere-vm` peut continuer de vivre. La base
  elle-même ne doit plus changer, ni être démarrée : une grappe modifiée dans la base changerait sous les pieds
  de `troisieme-vm`, dont le disque deviendrait incohérent.
]

= Étape 9 : un réseau isolé <etape-9>

#bloc(role: "question")[Consignes][
  - Définissez un réseau isolé `labo` : pont `virbr1`, réseau 192.168.100.0/24, DHCP.
  - Ajoutez une seconde carte réseau, sur `labo`, à `ma-premiere-vm` et à `deuxieme-vm`, à chaud et dans leur
    définition.
  - Dans chaque invité, configurez la nouvelle carte en DHCP, puis vérifiez que les deux VM se joignent sur
    `labo`. Pourquoi une carte de plus, plutôt que de déplacer la carte existante ?
]

#indice(titre: [Indice : le XML])[
  Partez du fichier du réseau `default` de l’étape 2, sans l’élément `<forward>`. Puis `virsh net-define`,
  `net-start`, `net-autostart`.
]
#indice(titre: [Indice : la carte et l’invité])[
  `virsh attach-interface` ajoute une carte ; `--live` agit sur la VM en marche, `--config` sur sa définition.
  Dans l’invité, `ip -br link` donne le nom de la nouvelle carte ; l’installateur de Debian n’a configuré que la
  première, dans `/etc/network/interfaces`.
]

#corrige[
  #f("labo.xml", lang: "xml")
  #terminal[```console
  $ virsh net-define labo.xml
  Network labo defined from labo.xml
  $ virsh net-start labo
  Network labo started
  $ virsh net-autostart labo
  Network labo marked as autostarted
  # à chaud : les deux VM doivent tourner (éteintes aux étapes 6 et 8)
  $ virsh start ma-premiere-vm
  Domain 'ma-premiere-vm' started
  $ virsh start deuxieme-vm
  Domain 'deuxieme-vm' started
  $ virsh attach-interface ma-premiere-vm network labo --model virtio --live --config
  Interface attached successfully
  $ virsh attach-interface deuxieme-vm network labo --model virtio --live --config
  Interface attached successfully
  $ virsh domiflist ma-premiere-vm
   Interface   Type      Source    Model    MAC
  -------------------------------------------------------------
   vnet9       network   default   virtio   52:54:00:cf:a3:dc
   vnet10      network   labo      virtio   52:54:00:5b:2e:95
  ```]
  Une ligne par carte : `vnetN` est le nom, sur l’hôte, de l’interface branchée sur le pont du réseau.
  Dans chaque invité, ajoutez à `/etc/network/interfaces` deux lignes pour la nouvelle carte, en remplaçant
  `enp8s0` par le nom que donne `ip -br link` :
  #terminal[```console
  $ printf 'allow-hotplug enp8s0\niface enp8s0 inet dhcp\n' | sudo tee -a /etc/network/interfaces
  $ sudo ifup enp8s0
  ```]
  Puis, sur l’hôte, `virsh domifaddr` montre deux adresses par VM, l’une en 192.168.122.x, l’autre en
  192.168.100.x, et chaque VM joint l’autre par son adresse en 192.168.100.x (`ping`). Une carte de plus, parce
  que `labo` n’a aucune sortie : y déplacer la seule carte couperait l’accès SSH depuis le réseau `default` et
  les mises à jour. Un serveur a souvent ainsi une patte d’administration et une patte de service.
]

= Étape 10 (facultative) : virt-manager <etape-10>

#bloc(role: "question")[Consignes][
  - Installez le paquet `virt-manager`, ouvrez-le, et retrouvez-y vos trois VM, vos deux réseaux et votre pool.
  - Créez une quatrième VM avec l’assistant (Fichier, Nouvelle machine virtuelle), puis vérifiez-la en ligne de
    commande.
]

#corrige[
  virt-manager parle à libvirt comme `virsh` : #d("libvirt-xml")[libvirt décrit chaque objet en XML]. La
  quatrième VM apparaît dans `virsh list --all`, avec sa définition XML et son volume dans le pool `default`.
  L’interface graphique aide à découvrir et à dépanner ; pour dix VM identiques, un script `virt-install` ou
  `virt-clone` se relit, se rejoue et se versionne.
]

= Pour finir : effacer les VM <fin>

#bloc(role: "question")[Consignes][
  - Effacez `troisieme-vm` et son disque. L’image de base a-t-elle disparu ?
  - Effacez `ma-premiere-vm`, son instantané et son disque : la diapositive
    #d("a-vous-effacer")[À vous : effacer une VM qui a un instantané] pose la question.
  - Effacez `deuxieme-vm`, l’image de base, puis le réseau `labo`.
]

#corrige[
  #terminal[```console
  $ virsh destroy troisieme-vm
  Domain 'troisieme-vm' destroyed
  $ virsh undefine troisieme-vm --remove-all-storage
  Domain 'troisieme-vm' has been undefined
  Volume 'vda'(/var/lib/libvirt/images/troisieme-vm.qcow2) removed.
  $ virsh destroy ma-premiere-vm
  Domain 'ma-premiere-vm' destroyed
  $ virsh undefine ma-premiere-vm
  error: Failed to undefine domain 'ma-premiere-vm'
  error: Requested operation is not valid: cannot delete inactive domain with 1 snapshots
  $ virsh undefine ma-premiere-vm --snapshots-metadata --remove-all-storage
  Domain 'ma-premiere-vm' has been undefined
  Volume 'vda'(/var/lib/libvirt/images/ma-premiere-vm.qcow2) removed.
  $ virsh destroy deuxieme-vm
  Domain 'deuxieme-vm' destroyed
  $ virsh undefine deuxieme-vm --remove-all-storage
  Domain 'deuxieme-vm' has been undefined
  Volume 'vda'(/var/lib/libvirt/images/deuxieme-vm.qcow2) removed.
  $ virsh vol-delete --pool default base-ma-premiere-vm.qcow2
  Vol base-ma-premiere-vm.qcow2 deleted
  $ virsh net-destroy labo
  Network labo destroyed
  $ virsh net-undefine labo
  Network labo has been undefined
  ```]
  `--remove-all-storage` supprime le disque de la VM, pas l’image de base sur laquelle il s’appuie : elle reste
  dans le pool, jusqu’au `vol-delete`. Une VM qui a des instantanés ne s’efface qu’avec `--snapshots-metadata` ;
  une VM en UEFI demande en plus `--nvram`. Et `--remove-all-storage` ne supprime que des volumes de pools : un
  disque rangé hors de tout pool reste en place.
]

#bloc(role: "retenir")[Ce que ce TP a montré][
  - libvirt décrit chaque VM, réseau et disque en XML, sur la connexion `qemu:///system`.
  - `virt-install` crée une VM ; `virt-clone` la copie ; un disque qcow2 adossé à une base la crée en quelques Kio.
  - `shutdown` éteint, `destroy` débranche, `undefine` efface ; un instantané interne permet de revenir en arrière.
  - Un réseau libvirt est NAT, pont ou isolé ; une VM peut avoir une carte sur chacun.
]
