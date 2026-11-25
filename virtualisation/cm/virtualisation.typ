// Cours « Fondements de la virtualisation de machines » — Typst + Touying.
// Compilation (depuis la racine du dépôt) : typst compile --root . --font-path commun/fonts virtualisation/cm/virtualisation.typ build/virtualisation.pdf
// Une diapo = un titre `==` ; une section (surtitre bleu) = un titre `=`.
// Structure : règles de .claude/skills/structurer-diapos-cours ; apparence : charte de commun/.

#import "../../commun/theme-cours.typ": *

#show: cours-theme.with(
  auteur: [Jean-Mathieu Chantrein],
  titre-court: [Fondements de la virtualisation de machines],
)

#couverture[Virtualisation][Fondements de la virtualisation de machines][Jean-Mathieu Chantrein][12 novembre 2026]
#speaker-note[À droite : trois VM (violet) sur un hyperviseur (bleu), lui-même sur le matériel (gris). Cours compagnon : Docker, fondements de la conteneurisation.]

// ======================================================================
= Sommaire

== Plan du cours

#plan-cours(
  ([Introduction], [Machine physique, système d’exploitation, machine virtuelle]),
  ([Concepts], [Émulation et virtualisation, assistance matérielle, types d’hyperviseur, paravirtualisation, QEMU et KVM]),
  ([Usages], [Bilan, migration à chaud, virtualisation imbriquée, image ISO et empreintes, mini TP]),
  ([Administrer avec libvirt], [XML, connexions, cycle de vie, réseaux, stockage et qcow2, instantanés]),
  ([Pour aller plus loin], [Outils de gestion, microVM, VM et conteneurs ; pour rappel]),
)

// ======================================================================
= Introduction

== Le vocabulaire : machine, OS, VM, hyperviseur

#anime(
  rang(
    bloc(taille: px(26))[Machine physique][
      - L’ordinateur : serveur, PC, Mac…
      - Programmable : on lui fait exécuter des programmes
      - Très puissante en calcul binaire, mais elle ne sait faire que cela
    ],
    bloc(taille: px(26))[Système d’exploitation (OS, _operating system_)][
      - Le programme qui fait communiquer les logiciels et les composants (mémoire vive ou RAM, disque, carte réseau…)
      - Organise et planifie l’exécution des autres programmes
      - Son noyau seul accède directement au matériel (mode privilégié)
    ],
  ),
  rang(bloc(taille: px(26))[Machine virtuelle (VM, _virtual machine_) et hyperviseur][
    - Une *VM* : un ordinateur simulé par logiciel, avec son propre système d’exploitation, dit *invité*
    - L’*hyperviseur* : le logiciel qui crée et exécute les VM, et leur partage le matériel de la machine physique, dite *hôte*
  ]),
)

// ======================================================================
= Concepts

== Émuler traduit, virtualiser exécute

#anime(
  rang(
    bloc[Émulation][
      - Le logiciel interprète ou traduit chaque instruction d’un autre processeur
      - Universel : du code ARM sur un PC x86
      - Lent : chaque instruction coûte plusieurs instructions réelles
    ],
    bloc[Virtualisation][
      - Les instructions de la VM s’exécutent directement sur le vrai processeur
      - Seules les opérations privilégiées sont interceptées par l’hyperviseur
      - Proche du natif, mais même architecture que l’hôte
    ],
  ),
  rang(bloc(role: "retenir")[À retenir][
    Une VM n’est pas, en général, une machine émulée. *QEMU* (_Quick EMUlator_, « émulateur rapide », Fabrice Bellard, 2003) sait pourtant faire les deux : exemple à la diapositive suivante.
  ]),
  source-de: link("https://www.qemu.org/docs/master/about/index.html")[qemu.org, documentation de QEMU],
  note: [QEMU sait faire les deux : sans KVM, il émule le processeur (TCG, traduction binaire dynamique) ; avec -accel kvm, il délègue l’exécution au processeur réel et n’émule plus que les périphériques.],
)

== QEMU sait émuler et virtualiser

#anime(
  rang(
    bloc(role: "pratique", taille: px(25))[Émulation : une machine ARM sur un PC x86][
      #terminal(taille: px(24))[
        ```
        # le processeur invité est émulé (TCG)
        $ qemu-system-aarch64 -M virt -cpu cortex-a57 …
        ```
      ]
      - *`qemu-system-aarch64`* : émule une machine complète à processeur ARM 64 bits (un binaire qemu-system-\* par architecture invitée)
      - *`-M virt`* : type de machine (alias de -machine) ; « virt » est une carte générique, sans équivalent matériel réel
      - *`-cpu cortex-a57`* : processeur présenté à l’invité : ARM Cortex-A57, 64 bits (AArch64)
      - *`…`* : reste de la commande : mémoire, disque, noyau ou micrologiciel
    ],
    bloc(role: "pratique", taille: px(25))[Virtualisation : une machine x86 sur un PC x86][
      #terminal(taille: px(24))[
        ```
        # le processeur invité est le vrai processeur
        $ qemu-system-x86_64 -accel kvm -m 2048 …
        ```
      ]
      - *`qemu-system-x86_64`* : fournit une machine PC à processeur x86 64 bits, la même architecture que l’hôte
      - *`-accel kvm`* : confie l’exécution du code invité à *KVM* (_Kernel-based Virtual Machine_, module du noyau Linux, détaillé plus loin) ; ancienne syntaxe : `-enable-kvm`. Sans accélérateur, QEMU émule le processeur avec *TCG* (_Tiny Code Generator_)
      - *`-m 2048`* : mémoire vive de la VM, en Mio par défaut : ici 2 Gio
      - *`…`* : reste de la commande : disque, réseau, affichage
    ],
  ),
  source-de: link("https://www.qemu.org/docs/master/system/invocation.html")[qemu.org, options de qemu-system],
  note: [Le même logiciel fait les deux. À gauche, l’hôte x86 ne sait pas exécuter du code ARM : QEMU traduit chaque bloc d’instructions (TCG, Tiny Code Generator). Le Cortex-A57 (2012) est un des premiers cœurs ARMv8-A 64 bits ; -cpu max donne toutes les fonctions émulables. À droite, -accel kvm exige /dev/kvm et une architecture invitée identique à celle de l’hôte ; -enable-kvm, encore très répandu dans les tutoriels, en est l’ancienne forme. -m accepte un suffixe : -m 2G. Les commandes sont volontairement abrégées (« … ») : seules les options étudiées sont montrées.],
)

== Le x86 virtualisable : de 1974 à 2008

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  lignes(uncover: uncover,
    ([1974], [Popek et Goldberg : conditions pour qu’une architecture soit virtualisable]),
    ([1999], [VMware : le x86 ne les remplit pas, traduction binaire des instructions sensibles]),
    ([2003], [Xen : paravirtualisation, le noyau invité est modifié pour coopérer]),
    ([2005–2006], [Intel VT-x, puis AMD-V : extensions matérielles de virtualisation]),
    ([2007], [KVM intégré au noyau Linux (2.6.20) : Linux devient hyperviseur]),
    ([2007–2008], [AMD RVI (_Rapid Virtualization Indexing_) puis Intel EPT (_Extended Page Tables_) : la traduction d’adresses de la VM aussi en matériel]),
  )
  source[G. Popek, R. Goldberg, « Formal Requirements for Virtualizable Third Generation Architectures », _Communications of the ACM_, 1974 · #link("https://kernelnewbies.org/Linux_2_6_20")[kernelnewbies.org, Linux 2.6.20]]
  utils.speaker-note(self: self)[Une date par clic. Popek et Goldberg (1974) définissent les instructions « sensibles » qui doivent être interceptées ; le x86 d’origine en exécute certaines sans piège, d’où la traduction binaire de VMware (1999) puis la paravirtualisation de Xen (2003), avant que VT-x et AMD-V ne règlent le problème en matériel. RVI est aussi appelé NPT (Nested Page Tables).]
})

== Type 1 ou type 2 : une frontière floue

#anime(
  rang(
    bloc[Type 1 : natif (_bare metal_)][
      - S’exécute directement sur le matériel
      - Xen, VMware ESXi, Microsoft Hyper-V
      - KVM : un module qui fait du noyau Linux l’hyperviseur
    ],
    bloc[Type 2 : hébergé (_hosted_)][
      - Application lancée sur un OS hôte
      - VirtualBox, VMware Workstation, Parallels Desktop
      - Pratique sur un poste de travail ; même VT-x, mais ressources et entrées-sorties partagées avec l’OS hôte
    ],
  ),
  rang(bloc(role: "retenir")[Ce qu’il faut bien comprendre][
    - La frontière est floue : KVM et Hyper-V sont classés en type 1, alors qu’ils s’appuient sur un système d’exploitation complet (Linux pour KVM, Windows pour Hyper-V)
    - Le type ne dit pas si l’invité se sait virtualisé : c’est la paravirtualisation, deux diapositives plus loin
  ]),
)

== KVM et Xen : deux places pour l’hyperviseur

#slide(repeat: 2, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1fr, 1fr), column-gutter: px(64),
    pile-archi([KVM : Linux est l’hyperviseur], [Espace utilisateur de l’hôte],
      [*Gestion* (crée, démarre, arrête) : libvirt, bibliothèque et service de gestion des VM],
      (vm[VM 1 : QEMU], vm[VM 2 : QEMU]),
      [Noyau Linux de l’hôte], ([module kvm],), [Matériel (VT-x / AMD-V)]),
    uncover("2-", pile-archi([Xen : l’hyperviseur sous Linux], [Domaines (VM)],
      [Toutes les VM, dom0 compris, sont au-dessus de Xen],
      (vm(couleur: c.bleu, haut: [Gestion : xl], bas: [Linux + pilotes], taille: px(26))[dom0 (privilégié)],
       vm[domU 1 : VM], vm[domU 2 : VM]),
      [Hyperviseur Xen (type 1)], ([processeurs], [mémoire]),
      [Matériel (VT-x / AMD-V)])),
  )
  utils.speaker-note(self: self)[KVM : le noyau Linux devient l’hyperviseur ; chaque VM est un processus QEMU de l’hôte, gérée par libvirt. Xen : l’hyperviseur démarre en premier, directement sur le matériel, et ne gère que les processeurs et la mémoire. Linux tourne au-dessus, dans dom0, une VM privilégiée qui porte les pilotes de périphériques et les outils de gestion (xl, ou libvirt). Les VM ordinaires sont des domU. Xen peut faire tourner des VM paravirtualisées classiques (PV) sans VT-x / AMD-V ; les VM complètes (HVM) et le mode PVH, recommandé aujourd’hui, en ont besoin : en pratique un hôte Xen actuel les utilise. Exemples : XCP-ng et XenServer (ex-Citrix Hypervisor) reposent sur Xen ; AWS a utilisé Xen avant de passer à son hyperviseur Nitro, fondé sur KVM (à partir de 2017) ; Proxmox VE et OpenStack reposent le plus souvent sur KVM. Les VM complètes de Xen (HVM, _hardware virtual machine_) et le mode PVH (invité paravirtualisé dans un conteneur HVM) exigent VT-x / AMD-V.]
})

== Paravirtualiser : l’invité coopère

#anime(
  rang(
    bloc[Virtualisation complète][
      - Le système invité n’est pas modifié : il croit tourner sur une vraie machine et ignore qu’il est virtualisé
      - Périphériques émulés (carte réseau e1000, disque IDE) : compatibles mais lents
    ],
    bloc[Paravirtualisation][
      - Le système invité sait qu’il est virtualisé : il coopère en appelant directement l’hyperviseur (_hypercalls_)
      - Xen PV : noyau invité modifié
      - Aujourd’hui : pilotes paravirtualisés (virtio) dans des VM complètes
    ],
  ),
  rang(bloc(role: "retenir")[Ce qu’il faut bien comprendre][
    Que l’invité se sache virtualisé ou non ne dépend pas du type d’hyperviseur : une VM sous KVM (type 1) comme sous VirtualBox (type 2) peut utiliser des pilotes virtio.
  ]),
  source-de: link("https://docs.oasis-open.org/virtio/virtio/v1.2/virtio-v1.2.html")[OASIS, spécification virtio 1.2],
  note: [Correction par rapport à l’ancienne version du cours, qui associait « VM aware » au type 1 et « no aware » au type 2.],
)

== QEMU fournit la machine, KVM la vitesse

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  let b-qemu = bloc(taille: px(26))[QEMU][
    - Espace utilisateur : fournit la machine (périphériques, mémoire, micrologiciel de démarrage BIOS/UEFI)
    - Seul, il émule aussi le processeur (TCG) : lent, toute architecture
  ]
  let b-kvm = bloc(taille: px(26))[KVM][
    - Module du noyau : le processeur exécute le code de la VM
    - Aucun périphérique : il faut un programme comme QEMU
  ]
  let b-ens = bloc(role: "retenir", taille: px(26))[Ensemble][
    QEMU pour la machine, KVM pour la vitesse.
  ]
  grid(columns: (1fr, 1.3fr), column-gutter: px(40),
    stack(spacing: px(8),
      block(width: 100%, stroke: px(3) + c.invite, radius: px(12), inset: px(12), stack(spacing: px(8),
        align(center, text(size: px(24), weight: 600, fill: c.invite)[Processus QEMU (espace utilisateur)]),
        block(width: 100%, height: px(72), fill: c.invite-clair, radius: px(8),
          align(center + horizon, text(weight: 600)[VM : OS invité et applis])),
        block(width: 100%, height: px(72), fill: c.appli, radius: px(8),
          align(center + horizon, text(size: px(26), weight: 600)[Périphériques émulés, mémoire])),
      )),
      align(center, text(size: px(24), weight: 600, fill: c.gris)[appels à /dev/kvm]),
      couche([Noyau Linux : module kvm], taille: px(28)),
      couche([Processeur avec VT-x / AMD-V], fond: c.ardoise, taille: px(28)),
    ),
    stack(spacing: px(20),
      bloc-anime(b-qemu, 2, uncover),
      bloc-anime(b-kvm, 4, uncover),
      bloc-anime(b-ens, 6, uncover),
    ),
  )
  source[#link("https://www.linux-kvm.org/page/Main_Page")[linux-kvm.org] · #link("https://www.qemu.org/docs/master/system/introduction.html")[qemu.org, introduction]]
  utils.speaker-note(self: self)[Une VM sous Linux, c’est un processus QEMU : ps sur l’hôte la montre (qemu-system-x86\_64). QEMU demande au module kvm, via /dev/kvm, d’exécuter le code de la VM directement sur le processeur ; le processeur rend la main au noyau (sortie de VM) pour les opérations privilégiées et les accès aux périphériques, que QEMU émule (ou que des pilotes virtio rendent rapides). KVM sert aussi sans QEMU : Firecracker (AWS Lambda), crosvm (ChromeOS), Cloud Hypervisor.]
})

// ======================================================================
= Usages

== Une VM : isolée et portable, mais coûteuse

// 10 étapes : schéma seul, puis un point par clic (5 avantages, 4 inconvénients).
#slide(repeat: 10, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (px(800), 1fr), column-gutter: px(72),
    stack(spacing: px(8),
      grid(columns: (1fr,) * 3, column-gutter: px(16),
        ..range(1, 4).map(i => vm(haut: [Applis], case: px(64))[VM #i])),
      couche[Hyperviseur],
      couche(fond: c.ardoise)[Machine physique],
    ),
    {
      uncover("2-", colonnes(bloc[Avantages][
        #utils.item-by-item(self: self, start: 2)[
          - Portabilité des VM
          - Isolation forte des applications
          - Mutualisation des ressources, à la demande
          - Instantanés (_snapshots_) et migration à chaud
          - Démarrage plus rapide qu’une machine réelle
        ]
      ]))
      espace
      uncover("7-", colonnes(bloc(role: "precaution")[Inconvénients][
        #utils.item-by-item(self: self, start: 7)[
          - Performance inférieure à l’exécution native
          - Forte consommation de mémoire vive
          - Forte consommation de disque
          - Démarrage plus lent qu’un conteneur
        ]
      ]))
    },
  )
  utils.speaker-note(self: self)[Comme dans le cours d’origine, les avantages puis les inconvénients apparaissent un par un (un clic par point).]
})

== Migrer une VM à chaud, sans l’arrêter

#let hote(nom) = block(width: px(600), height: px(408), fill: rgb("#FCFCFA"),
  stroke: px(1) + rgb("#DDE1E6"), radius: px(16), inset: px(24), text(size: px(32), weight: 600, nom))
#let mvm(nom, fond: c.appli, couleur: c.encre, bas: [OS + appli], trait: none) = block(
  width: px(176), height: px(100), fill: fond, stroke: trait, radius: px(12),
  align(center + horizon, stack(spacing: px(6),
    text(size: px(28), weight: 600, fill: couleur, nom), text(size: px(24), fill: couleur, bas))))
#let barre(t, fond) = block(width: px(552), height: px(80), fill: fond, radius: px(12),
  align(center + horizon, text(size: px(32), weight: 600, fill: c.fond, t)))
#let etape(n, t) = block(width: px(440),
  align(center, text(size: px(28))[#text(weight: 600, fill: c.invite)[#n.] #t]))
#let fleche = polygon(fill: c.invite, (0pt, px(27)), (px(156), px(27)), (px(156), 0pt),
  (px(240), px(45)), (px(156), px(90)), (px(156), px(63)), (0pt, px(63)))

// 8 étapes, comme le schéma au tableau : hôte A, hôte B, stockage, pré-copie,
// pages modifiées, bascule, puis l'encadré final. Coordonnées en px de la maquette.
#slide(repeat: 8, self => {
  let (uncover,) = utils.methods(self)
  // Canevas un peu moins haut que son contenu : les éléments posés peuvent déborder
  // dans la marge basse, comme dans le deck HTML, sans créer de page supplémentaire.
  block(width: 100%, height: px(640), {
    uncover("2-", {
      pose(0, 0, hote[Hôte A])
      pose(24, 88, mvm[VM 1])
      pose(212, 88, mvm[VM 2])
      pose(24, 212, barre([Hyperviseur], c.nuit))
      pose(24, 304, barre([Matériel (CPU, RAM)], c.ardoise))
    })
    uncover("2-6", pose(400, 88, mvm(fond: c.invite-clair)[VM 3]))
    uncover("3-", {
      pose(1064, 0, hote[Hôte B])
      pose(1088, 88, mvm[VM 4])
      pose(1464, 88, mvm[VM 5])
      pose(1088, 212, barre([Hyperviseur], c.nuit))
      pose(1088, 304, barre([Matériel (CPU, RAM)], c.ardoise))
    })
    uncover("4-", {
      pose(297, 408, rect(width: px(6), height: px(80), fill: c.gris))
      pose(1361, 408, rect(width: px(6), height: px(80), fill: c.gris))
      pose(0, 488, block(width: px(1664), height: px(100), fill: c.nuit, radius: px(16),
        align(center + horizon, text(size: px(32), weight: 600, fill: c.fond)[Stockage partagé (baie SAN, partage NFS, Ceph) : le disque de la VM reste en place])))
    })
    uncover("5-", pose(612, 28, etape(1)[Copie de la mémoire, la VM continue de tourner]))
    uncover("5-6", {
      pose(712, 318, fleche)
      pose(1276, 88, mvm(fond: none, couleur: c.invite, bas: [copie],
        trait: (paint: c.invite, thickness: px(2), dash: "dashed"))[VM 3])
    })
    uncover("6-", pose(612, 124, etape(2)[Recopie des pages modifiées entre-temps]))
    uncover("7-", {
      pose(612, 220, etape(3)[Bascule : pause très brève, reprise sur B])
      pose(1276, 88, mvm(fond: c.invite-clair)[VM 3])
    })
    uncover("8-", pose(0, 612, block(width: px(1664), rangee(gouttiere: px(28), poids: (1, 1.35),
      h => encadre(role: "retenir", libelle: [Intérêt :], hauteur: h)[maintenir ou rééquilibrer un hôte sans coupure de service.],
      h => encadre(role: "precaution", libelle: [En vrai :], hauteur: h)[un cluster fait au moins *3 hôtes* (quorum → pas de _split-brain_ si un hôte tombe). *Avant de basculer*, vérifier que l’hôte cible a assez de *CPU/RAM libres*.],
    ))))
  })
  utils.speaker-note(self: self)[Schéma dessiné pas à pas, un clic par étape (comme au tableau). 1. Hôte A : matériel, hyperviseur, trois VM. 2. Hôte B. 3. Stockage partagé : le disque de la VM n’a pas à être copié (sans stockage partagé, il faut aussi migrer les disques). 4. Pré-copie : la mémoire de VM 3 est envoyée vers B pendant que la VM continue de tourner. 5. Les pages modifiées entre-temps sont recopiées, en boucle, jusqu’à ce qu’il en reste très peu. 6. Bascule : la VM est brièvement suspendue, son dernier état est transféré, elle reprend sur B et disparaît de A. 7. Usage : maintenance ou équilibrage de charge sans coupure. Réalité d’un cluster : au moins 3 hôtes pour le quorum (Proxmox VE, vSphere HA : une majorité de nœuds doit rester jointe pour éviter le split-brain et relancer les VM d’un hôte défaillant). La migration à chaud elle-même ne demande que 2 hôtes, mais la haute disponibilité qui l’entoure en demande 3. Avant chaque bascule (manuelle ou automatique via DRS/HA), l’ordonnanceur vérifie que l’hôte cible a les ressources CPU/RAM libres ; on garde donc une marge sur chaque hôte pour absorber la panne d’un autre. Côté conteneurs : le conteneur est sans état et jetable, on le recrée ailleurs plutôt que de le migrer ; le checkpoint/restore (CRIU) existe mais reste un cas particulier.]
})


== Virtualisation imbriquée : des VM dans une VM

#slide(repeat: 7, self => {
  let (uncover,) = utils.methods(self)
  let b-gauche = bloc(taille: px(26))[Virtualisation imbriquée (_nested_)][
    - L’hyperviseur expose les extensions VT-x / AMD-V à la VM, qui peut à son tour lancer des VM
    - Usages : formation, laboratoires, intégration continue, cloud
    - Coût : chaque niveau ajoute des passages par l’hyperviseur
    - On imbrique aussi des conteneurs dans une VM : très courant (Docker Desktop, cloud)
  ]
  let b-droite = bloc(role: "pratique", poids: 1.25)[Avec KVM : trois niveaux][
    #terminal(titre: none)[
      #cadre([Hôte (niveau 0)], niveau: 0)[
        ```
        # l’imbrication est-elle permise par le module kvm ?
        $ cat /sys/module/kvm_intel/parameters/nested
        Y
        # -cpu host : la VM reçoit les extensions VT-x
        $ qemu-system-x86_64 -accel kvm -cpu host …
        ```
        #uncover("6-", cadre([VM (niveau 1)], niveau: 1)[
          ```
          # KVM est disponible dans la VM
          $ ls /dev/kvm
          /dev/kvm
          $ qemu-system-x86_64 -accel kvm …
          ```
          #uncover("7-", cadre([VM imbriquée (niveau 2)], niveau: 2)[
            ```
            $ systemd-detect-virt
            kvm
            ```
          ])
        ])
      ]
    ]
    #text(size: px(22))[Chaque cadre est une machine lancée par la commande `qemu` juste au-dessus.]
  ]
  rangee(poids: (1, 1.25),
    h => bloc-anime(b-gauche, 1, uncover, hauteur: h),
    h => bloc-anime(b-droite, 5, uncover, hauteur: h),
  )
  source[#link("https://www.kernel.org/doc/html/latest/virt/kvm/x86/running-nested-guests.html")[kernel.org, Running nested guests with KVM]]
  utils.speaker-note(self: self)[Lecture des cadres : bleu à trait plein = terminal de l’hôte physique (niveau 0) ; violet à tirets = terminal de la VM lancée par la première commande qemu (niveau 1) ; rose à pointillés = terminal de la VM lancée depuis cette VM (niveau 2). -cpu host transmet les extensions vmx/svm à la VM, d’où la présence de /dev/kvm au niveau 1. Sur AMD : /sys/module/kvm\_amd/parameters/nested (affiche 1). Sorties types, à rejouer sur le poste de démonstration avec virtualisation/cm/rejouer-tp.sh, qui note aussi les versions employées.]
})

== Choisir l’image Debian à installer

#anime(
  rang(
    bloc(taille: px(26))[Où la trouver, quoi prendre][
      - *Source officielle uniquement* : debian.org/download, qui renvoie vers cdimage.debian.org
      - Image *netinst amd64* (756 Mio), une image ISO (image de CD ou DVD) : installateur minimal, les paquets viennent ensuite du réseau
      - Le dossier « current » suit la dernière version (13.7.0 en novembre 2026) : le nom du fichier change à chaque mise à jour
    ],
    bloc(role: "pratique", taille: px(24))[Trois fichiers à télécharger][
      - *debian-13.7.0-amd64-netinst.iso* : l’image elle-même
      - *SHA256SUMS* : les empreintes des images
      - *SHA256SUMS.sign* : la signature de ce fichier par Debian
    ],
  ),
  rang(bloc(role: "danger", taille: px(26))[Attention : une image téléchargée se vérifie avant usage][
    - *Intégrité* : le fichier est-il arrivé intact (téléchargement interrompu, disque, miroir défaillant) ? → empreinte
    - *Authenticité* : est-ce bien l’image publiée par Debian, et pas une image piégée ? → signature
  ]),
  source-de: [#link("https://www.debian.org/download")[debian.org/download] · #link("https://www.debian.org/CD/verify")[debian.org/CD/verify]],
  note: [Les trois fichiers — image, SHA256SUMS, SHA256SUMS.sign — sont dans le même dossier du dépôt, d’où le préfixe \$URL\_BASE commun ; on les met dans un répertoire local dédié (ici \~/iso-debian). Le mini TP installe une VM Debian : il faut d’abord l’image d’installation. debian.org/download pointe vers l’image netinst amd64 et vers SHA256SUMS et SHA256SUMS.sign. Le 16 novembre 2026, l’image fait 792 723 456 octets (756 Mio). Une image piégée installe un système compromis dès le départ : exemple réel, le site de Linux Mint a distribué une ISO modifiée en février 2016. La diapositive suivante définit la somme de contrôle ; le téléchargement et la vérification sont regroupés sur la diapositive « Télécharger l’ISO, puis la vérifier ».],
)

== Une empreinte résume un fichier

#anime(
  rang(
    bloc(taille: px(26))[Définition][
      - Une *fonction de hachage* calcule, à partir d’un fichier de taille quelconque, une *empreinte* de taille fixe
      - SHA-256 (_Secure Hash Algorithm_, famille SHA-2) : 256 bits, soit 64 chiffres hexadécimaux (128 pour SHA-512)
      - Même contenu : toujours la même empreinte
      - Un seul bit modifié : une empreinte complètement différente
    ],
    bloc(role: "pratique", poids: 1.1, taille: px(24))[Démonstration][
      #terminal[
        ```
        # … empreintes tronquées à 40 chiffres sur 64
        $ echo bonjour | sha256sum
        9cec0af545144159bac85c7b908d5e0b9b0ef961  -
        $ echo Bonjour | sha256sum
        8dc2a6966f1be1644ec6b1f7223f47e53de5ad05  -
        $ sha256sum debian-13.7.0-amd64-netinst.iso
        a7ef94ac2fb9a7fec454552abd629b7cc9d5155c  debian-…
        ```
      ]
      Une lettre change, toute l’empreinte change. 756 Mio ou 8 octets : même longueur d’empreinte.
    ],
  ),
  rang(bloc(taille: px(26))[À quoi ça sert][
    On calcule l’empreinte du fichier reçu et on la compare à l’empreinte publiée par l’éditeur. Identiques : le fichier est *intact*. Somme de contrôle, empreinte, condensat, _hash_ : synonymes ici.
  ]),
  source-de: link("https://csrc.nist.gov/pubs/fips/180-4/upd1/final")[NIST, FIPS 180-4 (famille SHA-2)],
  note: [Sorties de sha256sum (GNU coreutils 9.4), tronquées à 40 chiffres hexadécimaux pour tenir sur la diapositive, comme l’annonce la première ligne du terminal. Le tiret final signifie « entrée standard ». Empreintes complètes : bonjour = 9cec0af545144159bac85c7b908d5e0b9b0ef961497401c5ad8da26f065ad926 ; Bonjour = 8dc2a6966f1be1644ec6b1f7223f47e53de5ad05e1c976736d948e7977a13dd3 ; ISO 13.7.0 = a7ef94ac2fb9a7fec454552abd629b7cc9d5155c886165a45649f5ce6167e355. Deux fichiers différents peuvent en théorie avoir la même empreinte (collision) ; une fonction cryptographique rend cette recherche impraticable.],
)

== Télécharger l’ISO, puis la vérifier <iso-verifier>

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  let b-deux = bloc(taille: px(22), taille-titre: px(24))[Deux contrôles, deux fichiers][
    - *Intégrité* → `SHA256SUMS` : l’image est-elle intacte ?
    - *Authenticité* → `SHA256SUMS.sign` : vient-elle bien de Debian ?
  ]
  let b-algo = bloc(role: "avertissement", taille: px(22), taille-titre: px(24))[Quel algorithme d’empreinte ?][
    - *MD5* (_Message Digest 5_), *SHA-1* : cassés, on sait fabriquer deux fichiers de même empreinte (collisions)
    - *SHA-256 / SHA-512* (SHA-2) : standard actuel, aucune collision connue ; Debian publie les deux
    - Contre une image *substituée*, il faut la résistance aux collisions → SHA-2
  ]
  rangee(poids: (1.35, 1),
    h => terminal(titre: [Terminal — télécharger, puis vérifier], taille: px(19), hauteur: h)[
      ```
      # 1. un répertoire dédié, tout au même endroit
      $ mkdir -p ~/iso-debian
      $ cd ~/iso-debian
      $ URL_BASE=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
      $ wget $URL_BASE/debian-13.7.0-amd64-netinst.iso
      $ wget $URL_BASE/SHA256SUMS
      $ wget $URL_BASE/SHA256SUMS.sign
      ```
      #uncover("2-")[
        ```
        # 2. authenticité : ces empreintes viennent-elles de Debian ?
        # (gpgv : vérificateur de signatures de GnuPG)
        $ sudo apt install debian-keyring
        $ gpgv --keyring /usr/share/keyrings/debian-role-keys.pgp \
               SHA256SUMS.sign SHA256SUMS
        gpgv: Good signature from "Debian CD signing key"
        ```
      ]
      #uncover("3-")[
        ```
        # 3. intégrité : l’image correspond-elle à son empreinte ?
        $ sha256sum -c --ignore-missing SHA256SUMS
        debian-13.7.0-amd64-netinst.iso: OK
        ```
      ]
    ],
    h => block(height: h, stack(spacing: px(20),
      bloc-anime(b-deux, 4, uncover),
      bloc-anime(b-algo, 5, uncover),
      uncover("6-", note[Ordre logique : *signature d’abord*, puis empreinte. Si la signature échoue, on s’arrête là.]),
    )),
  )
  source[#link("https://www.debian.org/CD/verify")[debian.org/CD/verify]]
  utils.speaker-note(self: self)[Une phase du terminal par clic, puis les deux encadrés et la note. Le 18 novembre 2026, sur l’image 13.7.0 (792 723 456 octets) : gpgv → Good signature (clé DF9B 9C49 EAA9 2984 3258 9D76 DA87 E80D 6294 BE9B, trousseau debian-role-keys.pgp du paquet debian-keyring) ; sha256sum -c → OK, puis FAILED après modification d’un seul octet. Les trois fichiers partent du même \$URL\_BASE : image, sommes et signature sont au même endroit du dépôt. --ignore-missing : SHA256SUMS liste aussi d’autres images non téléchargées. Sur le choix de l’algorithme : MD5 (collisions pratiques depuis \~2008) et SHA-1 (collision « SHAttered », Google 2017) sont cassés ; SHA-256/512 (famille SHA-2) n’ont pas de collision connue. La résistance aux collisions importe face à un attaquant qui voudrait faire passer une autre image pour l’officielle ; pour une simple corruption de transfert, même un hachage faible suffirait. L’anti-falsification vient en dernier ressort de la signature GPG, qui protège le fichier d’empreintes lui-même. Sans machine Debian : gpg --verify SHA256SUMS.sign SHA256SUMS après import de la clé, puis comparer son empreinte à celle de debian.org/CD/verify.]
})

== Mini TP : une VM, puis une VM dans la VM <mini-tp>

#anime(
  rang(bloc(role: "pratique", taille: px(24))[Prérequis][
    - Un PC Linux (Debian ou Ubuntu) avec VT-x / AMD-V activé dans l’UEFI ; être membre du groupe kvm
    - Paquets `qemu-system-x86` et `qemu-utils` ; l’ISO Debian vérifiée (diapositive « Télécharger l’ISO, puis la vérifier »)
    - Question 6 : l’image Alpine « Virtual » x86\_64 (#link("https://alpinelinux.org/downloads/")[alpinelinux.org/downloads]), téléchargée dans la VM Debian
  ]),
  rang(bloc(role: "question")[À vous][
    + Votre processeur expose-t-il les extensions de virtualisation (VT-x ou AMD-V) ?
    + KVM est-il utilisable sur votre hôte ?
    + Installez Debian dans une VM (QEMU et KVM, ISO + disque, périphériques virtio), puis montrez que cette VM est un *processus de l’hôte*
    + Relancez-la *sans KVM* : que constatez-vous ? Comment le vérifier depuis le moniteur QEMU ?
    + Dans l’invité : l’OS sait-il qu’il est virtualisé ?
    + Virtualisation imbriquée : dans votre VM Debian, lancez une VM Alpine
  ]),
  note: [À faire en direct, une question par clic. Laisser chercher avant de passer au corrigé. Aide : man qemu-system-x86\_64 ; Ctrl+Alt+2 ouvre le moniteur QEMU.],
)

== Mini TP : corrigé (1/4) <mini-tp-corrige-1>

// Les questions restent affichées ; une réponse par clic.
#slide(repeat: 3, self => {
  let (uncover,) = utils.methods(self)
  corrige(1, [Votre processeur expose-t-il les extensions de virtualisation (VT-x ou AMD-V) ?],
    uncover("2-", reponse(terminal(titre: none, taille: px(22))[
      ```
      $ lscpu | grep -E 'Virtualization|Virtualisation'
      Virtualisation :    VT-x
      # processeurs logiques qui annoncent vmx (Intel) ou svm (AMD)
      $ grep -cE 'vmx|svm' /proc/cpuinfo
      8
      # → oui : extensions VT-x présentes
      ```
    ])))
  v(px(8)); filet-corrige; v(px(8))
  corrige(2, [KVM est-il utilisable sur votre hôte ?],
    uncover("3-", reponse(terminal(titre: none, taille: px(22))[
      ```
      # modules du noyau chargés pour KVM
      $ ls /sys/module | grep kvm
      kvm
      kvm_intel
      # droits sur le périphérique de KVM
      $ stat -c '%A %U %G %n' /dev/kvm
      crw-rw---- root kvm /dev/kvm
      # → oui, pour les membres du groupe kvm
      ```
    ])))
  utils.speaker-note(self: self)[Question 1 : un résultat 0 signifie extensions absentes ou désactivées dans l’UEFI ; lscpu affiche « Virtualization » ou « Virtualisation » selon la langue. Question 2 : /dev/kvm est un périphérique caractère (c), lisible et inscriptible par root et par le groupe kvm ; sur AMD, le module s’appelle kvm\_amd. Sorties types, à rejouer avec virtualisation/cm/rejouer-tp.sh, qui note aussi les versions.]
})

== Mini TP : corrigé (2/4)

#slide(repeat: 2, self => {
  let (uncover,) = utils.methods(self)
  corrige(3, [Installez Debian dans une VM (QEMU et KVM, ISO + disque, périphériques virtio), puis montrez que cette VM est un *processus de l’hôte*],
    uncover("2-", reponse(terminal(titre: none, taille: px(22))[
      ```
      # disque de 20 Gio, alloué au fil de l’eau
      $ qemu-img create -q -f qcow2 debian.qcow2 20G
      $ ls -sh debian.qcow2
      196K debian.qcow2
      # disque et carte réseau paravirtualisés (virtio)
      $ qemu-system-x86_64 -accel kvm -m 2048 \
        -cdrom debian-13.7.0-amd64-netinst.iso \
        -drive file=debian.qcow2,format=qcow2,if=virtio \
        -nic user,model=virtio-net-pci &
      # nom du processus, tronqué à 15 caractères
      $ pgrep -l qemu
      4242 qemu-system-x86
      # → la VM est le processus 4242 de l’hôte
      ```
    ])))
  utils.speaker-note(self: self)[qemu-img réserve 20 Gio sans les allouer : le fichier ne pèse d’abord que 196 Kio (QEMU 8.2.2) et grossit avec les données écrites. if=virtio et model=virtio-net-pci donnent à l’invité un disque et une carte réseau paravirtualisés, que la question 5 retrouve ; sans eux, QEMU présente un disque IDE et une carte e1000. On installe Debian sur le disque, puis on relance sans -cdrom. pgrep -l affiche le PID et le nom du processus ; ps -o pid,user,args -C qemu-system-x86\_64 montre en plus son propriétaire. Le PID varie d’une machine à l’autre.]
})

== Mini TP : corrigé (3/4)

#slide(repeat: 3, self => {
  let (uncover,) = utils.methods(self)
  corrige(4, [Relancez-la *sans KVM* : que constatez-vous ? Comment le vérifier depuis le moniteur QEMU ?],
    uncover("2-", reponse(terminal(titre: none, taille: px(22))[
      ```
      # tcg : le processeur est émulé, sans KVM
      $ qemu-system-x86_64 -accel tcg -m 2048 \
        -drive file=debian.qcow2,format=qcow2,if=virtio \
        -nic user,model=virtio-net-pci
      # → la VM démarre, mais bien plus lentement
      ```
      #encart[Moniteur QEMU (Ctrl+Alt+2)][
        ```
        (qemu) info kvm
        kvm support: disabled
        ```
      ]
    ])))
  v(px(8)); filet-corrige; v(px(8))
  corrige(5, [Dans l’invité : l’OS sait-il qu’il est virtualisé ?],
    uncover("3-", reponse(terminal(titre: none, taille: px(22))[
      #encart[Invité][
        ```
        $ systemd-detect-virt
        kvm
        # périphériques paravirtualisés vus par l’invité
        $ lspci | grep -i virtio
        # … une ligne par périphérique virtio (disque, réseau)
        # → oui : l’invité sait qu’il tourne sous KVM
        ```
      ]
    ])))
  utils.speaker-note(self: self)[Question 4 : avec -accel tcg (l’accélérateur par défaut quand on n’en précise aucun), QEMU émule le processeur ; la VM est nettement plus lente. Dans le moniteur QEMU (Ctrl+Alt+2, retour à l’affichage par Ctrl+Alt+1), info kvm affiche « kvm support: disabled » (sortie de QEMU 8.2.2). Question 5 : systemd-detect-virt renvoie kvm sous KVM, qemu en émulation pure ; lspci liste le disque et la carte réseau virtio ajoutés à la question 3. Sorties de la question 5 à rejouer sur le poste de démonstration.]
})

== Mini TP : corrigé (4/4)

#slide(repeat: 3, self => {
  let (uncover,) = utils.methods(self)
  corrige(6, [Virtualisation imbriquée : dans votre VM Debian, lancez une VM Alpine],
    reponse(terminal(titre: none, taille: px(20))[
      #cadre([Hôte (niveau 0)], niveau: 0)[
        ```
        $ cat /sys/module/kvm_intel/parameters/nested
        Y
        # -cpu host : transmet VT-x / AMD-V à la VM
        $ qemu-system-x86_64 -accel kvm -cpu host -m 2048 -smp 2 \
          -drive file=debian.qcow2,format=qcow2,if=virtio
        ```
        #uncover("2-", cadre([VM Debian (niveau 1)], niveau: 1)[
          ```
          $ ls /dev/kvm
          /dev/kvm
          $ sudo apt install qemu-system-x86 wget
          # URL_ALPINE : lien « Virtual x86_64 » de alpinelinux.org/downloads
          $ wget "$URL_ALPINE"
          $ qemu-system-x86_64 -accel kvm -cpu host -m 512 \
            -cdrom alpine-virt-*-x86_64.iso
          ```
          #uncover("3-", cadre([VM Alpine (niveau 2)], niveau: 2)[
            ```
            # identifiant root, sans mot de passe
            $ dmesg | grep -i hypervisor
            Hypervisor detected: KVM
            # → la VM Alpine tourne sous le KVM de la VM Debian
            ```
          ])
        ])
      ]
    ]))
  utils.speaker-note(self: self)[Prérequis : la VM Debian installée sur debian.qcow2 à la question 3. Clic 1, hôte : nested doit valoir Y (Intel) ou 1 (AMD, /sys/module/kvm\_amd/parameters/nested) ; sinon, recharger le module avec l’option nested=1. La VM de niveau 1 doit être relancée avec -cpu host : sans cette option, le processeur virtuel n’expose pas vmx/svm, /dev/kvm est absent dans la VM et la VM imbriquée tourne en émulation pure (TCG), très lentement. Prévoir assez de mémoire au niveau 1 pour héberger le niveau 2. Clic 2, niveau 1 : /dev/kvm présent ; on installe QEMU, on télécharge l’image Alpine « Virtual » (quelques dizaines de Mio, nom de fichier versionné, d’où le motif alpine-virt-\*) et on lance l’invité. Clic 3, niveau 2 : Alpine démarre sur l’ISO en mode live, identifiant root sans mot de passe ; dmesg montre l’hyperviseur KVM (ici celui de la VM de niveau 1). Sorties types, à rejouer sur le poste de démonstration.]
})

// ======================================================================
= Administrer avec libvirt

== libvirt décrit chaque objet en XML <libvirt-xml>

#anime(
  rang(
    bloc(taille: px(25))[Ce que fait libvirt][
      - Une bibliothèque et un service (démon `libvirtd`, ou `virtqemud`) placés entre les outils et l’hyperviseur
      - Ses clients : `virsh` (ligne de commande), `virt-install` (création), virt-manager (interface graphique)
      - Un pilote par hyperviseur (QEMU/KVM, Xen, LXC…), et les mêmes commandes au-dessus
      - Chaque objet est décrit par un document XML, sa *définition*, que libvirt conserve
    ],
    bloc(role: "pratique", poids: 1.15, taille: px(24))[Quatre objets, quatre définitions XML][
      #table(columns: (auto, auto, 1fr), stroke: none, inset: (x: px(8), y: px(8)),
        fill: (x, y) => if y == 0 or calc.even(y) { c.bleu-clair } else { c.fond },
        table.header(..([Objet], [Élément], [Commandes virsh]).map(strong)),
        [*Domaine* : une VM], [`<domain>`], [`define`, `start`, `dumpxml`],
        [*Réseau* virtuel], [`<network>`], [`net-define`, `net-start`],
        [*Pool* : où ranger les disques], [`<pool>`], [`pool-define`, `pool-start`],
        [*Volume* : un disque], [`<volume>`], [`vol-create-as`, `vol-delete`],
      )
    ],
  ),
  rang(bloc(role: "retenir")[À retenir][
    Un *domaine* est le nom que libvirt donne à une VM. Lire sa définition (`virsh dumpxml`), c’est lire la VM : processeurs, mémoire, disques, cartes réseau.
  ]),
  source-de: [#link("https://libvirt.org/format.html")[libvirt.org, XML format] · #link("https://libvirt.org/manpages/virsh.html")[virsh(1)]],
  note: [Le mini TP lançait QEMU à la main : une ligne de commande par VM, à retaper à chaque démarrage. libvirt garde la définition et lance QEMU à notre place. Les définitions des domaines de qemu:\/\/\/system sont rangées sous /etc/libvirt/qemu/ : on ne les modifie pas directement, on passe par virsh edit (qui valide le XML) ou virsh define. libvirt a été lancé par Red Hat ; libvirtd est le démon historique, que certaines distributions remplacent par des démons par pilote (virtqemud pour QEMU). Une confusion fréquente : KVM n’est pas un fork de QEMU. KVM est un module du noyau ; c’est qemu-kvm, programme en espace utilisateur, qui était un fork de QEMU, refusionné dans QEMU 1.3.],
)

== Deux connexions : system ou session <connexions-libvirt>

#anime(
  rang(
    bloc(taille: px(22), taille-titre: px(26))[`qemu:///system` : les VM du système][
      - Démon en root ; chaque QEMU sous un compte dédié (`libvirt-qemu`)
      - Pool `default` (`/var/lib/libvirt/images`), réseau `default` (NAT, traduction d’adresses)
      - Pour root et le groupe `libvirt` ; celle des serveurs et de ce cours
    ],
    bloc(taille: px(22), taille-titre: px(26))[`qemu:///session` : les VM de votre compte][
      - Un démon à votre nom, lancé à la demande, avec vos droits
      - Disques sous `~/.local/share/libvirt/images` ; réseau en mode utilisateur
      - Ne voit aucune VM du système, et réciproquement
    ],
  ),
  rang(
    bloc(role: "pratique", poids: 1.35, taille: px(22), taille-titre: px(26))[Démonstration][
      #terminal(titre: none, taille: px(19))[
        ```
        # compte ordinaire, sans réglage : la session
        $ virsh uri
        qemu:///session
        $ echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> ~/.bashrc
        $ export LIBVIRT_DEFAULT_URI=qemu:///system
        $ virsh uri
        qemu:///system
        ```
      ]
    ],
    bloc(role: "precaution", taille: px(22), taille-titre: px(26))[Une VM a disparu ?][
      `virsh list --all` ne montre pas une VM qui existe : vérifier d’abord la connexion, avec `virsh uri`. Root, donc `sudo virsh`, parle par défaut au système.
    ],
  ),
  source-de: [#link("https://libvirt.org/uri.html")[libvirt.org, Connection URIs] · #link("https://libvirt.org/drvqemu.html")[libvirt.org, QEMU/KVM driver]],
  note: [Sorties de virsh (libvirt 10.0.0) : virsh uri vaut qemu:\/\/\/session pour un compte ordinaire, même membre du groupe libvirt, et qemu:\/\/\/system pour root. Le groupe libvirt n’ouvre que qemu:\/\/\/system : sans -c qemu:\/\/\/system ou LIBVIRT\_DEFAULT\_URI, virsh et virt-install d’un compte ordinaire créent leurs VM dans la session, où le réseau default et le pool default n’existent pas. Autre réglage possible : uri\_default dans \~/.config/libvirt/libvirt.conf. Le cours et le TP travaillent en qemu:\/\/\/system, sans sudo, grâce au groupe libvirt. Le réseau en mode utilisateur de la session (SLIRP ou passt) donne l’accès sortant, mais aucune VM n’y est joignable depuis l’hôte sans redirection de port.],
)

== Créer une VM : virt-install, puis virsh <virt-install>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.35)[Démonstration][
      #terminal(taille: px(20))[
        ```
        $ sudo apt install qemu-system-x86 \
          libvirt-daemon-system virtinst virt-viewer
        # accès à qemu:///system ; puis fermer et rouvrir la session
        $ sudo adduser "$USER" libvirt
        $ export LIBVIRT_DEFAULT_URI=qemu:///system
        # VM : 2 Gio de mémoire, 2 processeurs, disque de 10 Gio
        $ virt-install --name ma-premiere-vm --memory 2048 \
          --vcpus 2 --disk size=10 --osinfo detect=on \
          --network network=default \
          --cdrom debian-13.7.0-amd64-netinst.iso
        # virt-viewer ouvre la console : on y fait l’installation
        # toutes les VM, même arrêtées
        $ virsh list --all
         Id   Name             State
        --------------------------------
         7    ma-premiere-vm   running
        ```
      ]
    ],
    bloc(role: "retenir")[À retenir][
      - virt-install crée la VM, virsh la gère : tous deux passent par libvirt
      - virt-viewer affiche la console graphique de l’installateur
      - Prérequis : un hôte prêt (questions 1 et 2 du mini TP) et le groupe `libvirt` ; le groupe `kvm` ne sert qu’à lancer QEMU soi-même
    ],
  ),
  source-de: [#link("https://libvirt.org/docs.html")[libvirt.org] · #link("https://github.com/virt-manager/virt-manager/blob/main/man/virt-install.rst")[virt-install(1)]],
  note: [L’ISO est celle téléchargée et vérifiée à la diapositive « Télécharger l’ISO, puis la vérifier ». Piège : sur qemu:\/\/\/system, QEMU tourne sous le compte libvirt-qemu, et le dossier personnel de Debian 13 est en mode 0700 ; une ISO rangée sous \~ donne « Permission denied » au démarrage (libvirt change le propriétaire du fichier, pas les droits des dossiers parents). Remède : setfacl -m u:libvirt-qemu:x ~ ~/iso-debian, ou ranger l’ISO hors du dossier personnel. Les disques créés par virt-install vont dans le pool default, déjà lisible. Commandes pour Debian/Ubuntu ; --osinfo existe depuis virt-install 4.0 ; detect=on identifie l’OS à partir de l’ISO ; --disk size=10 s’exprime en Gio et crée le volume ma-premiere-vm.qcow2 dans le pool default, que virt-install crée lui-même s’il n’existe pas. --network network=default passe par le réseau libvirt plutôt que de nommer son pont (virbr0). Le micrologiciel reste le BIOS : virt-install (4.1 et 5.0) ne choisit l’UEFI pour un invité x86 que si l’OS l’exige, ce qui garde possibles les instantanés internes (plus loin). Par défaut virt-install choisit un affichage graphique (SPICE ou VNC) et lance virt-viewer (--autoconsole graphical) ; sans virt-viewer, aucune console ne s’ouvre et l’installation interactive est impossible. Alternative en mode texte : --graphics none avec une console série (virsh console). virsh list --all : identifiant (numéro attribué à chaque démarrage, - si la VM est arrêtée), nom, état. Sortie de virsh 10.0.0, en anglais (LC\_ALL=C), rejouée par virtualisation/cm/rejouer-libvirt.sh sur une VM sans système ; à rejouer sur un poste avec KVM et l’ISO.],
)

== Le cycle de vie d’un domaine <cycle-de-vie>

#let etat(t, sous, fond: c.invite-clair, trait: none) = block(width: 100%, height: px(150), fill: fond,
  stroke: trait, radius: px(12), inset: px(12), align(center + horizon, stack(spacing: px(10),
    text(size: px(30), weight: 600, t), text(size: px(24), fill: c.ardoise, sous))))
#let transition(haut, bas: none) = align(center + horizon, stack(spacing: px(10),
  text(size: px(26), weight: 600, fill: c.invite, haut),
  if bas != none { text(size: px(26), weight: 600, fill: c.invite, bas) }))

#slide(repeat: 6, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1fr, px(250), 1fr, px(330), 1fr), row-gutter: px(20), align: horizon,
    etat([Un fichier XML], [`ma-premiere-vm.xml`], fond: c.appli),
    uncover("2-", transition([`define` →], bas: [← `dumpxml`])),
    uncover("2-", etat([Définie, éteinte], [`shut off`])),
    uncover("3-", transition([`start` →], bas: uncover("4-")[← `shutdown`, `destroy`])),
    uncover("3-", etat([En marche], [`running`], trait: px(4) + c.invite)),
    [], [], uncover("5-", transition([↓ `undefine`])), [], [],
    [], [], uncover("5-", etat([Plus de définition], [disques conservés, sauf `--remove-all-storage`], fond: c.fond,
      trait: (paint: c.invite, thickness: px(2), dash: "dashed"))), [], [],
  )
  v(px(28))
  uncover("6-", rendre-bloc(bloc(role: "retenir")[À retenir][
    Définir n’est pas démarrer : une VM définie existe, éteinte, et `virsh list --all` la montre. `virt-install` fait les deux d’un coup : `define`, puis `start`.
  ]))
  source[#link("https://libvirt.org/manpages/virsh.html")[virsh(1), Domain commands]]
  utils.speaker-note(self: self)[Un clic par transition. define enregistre la définition (domaine persistant) ; start lance le processus QEMU ; shutdown demande à l’invité de s’éteindre, destroy arrête le processus net (diapositive suivante) ; undefine efface la définition. dumpxml relit la définition : c’est le chemin inverse de define, d’où le TP qui crée une VM à partir du XML d’une autre. Hors du schéma : virsh create lance une VM sans la définir (domaine transitoire, qui disparaît à l’arrêt) ; suspend et resume la mettent en pause ; autostart la démarre avec l’hôte. États affichés par virsh 10.0.0 en anglais : running, shut off, paused.]
})

== Éteindre, débrancher, effacer : trois commandes <arreter-effacer>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.2, taille: px(24))[Démonstration][
      #terminal(titre: none, taille: px(20))[
        ```
        # demande à l’invité de s’éteindre
        $ virsh shutdown ma-premiere-vm
        Domain 'ma-premiere-vm' is being shutdown
        # arrêt immédiat du processus QEMU
        $ virsh destroy ma-premiere-vm
        Domain 'ma-premiere-vm' destroyed
        $ virsh list --all
         Id   Name             State
        ---------------------------------
         -    ma-premiere-vm   shut off
        ```
      ]
    ],
    bloc(taille: px(23), taille-titre: px(26))[Trois commandes, trois effets][
      - `shutdown` : l’invité reçoit l’événement ACPI (gestion de l’alimentation) du bouton et s’éteint proprement
      - `destroy` : on débranche la prise. Le nom trompe : définition et disque restent, `start` relance la VM
      - `undefine` : efface la définition ; avec `--remove-all-storage`, aussi les volumes de ses disques
    ],
  ),
  rang(
    bloc(role: "avertissement", taille: px(23), taille-titre: px(26))[`destroy` : un arrêt brutal][
      Comme une coupure de courant : ce que l’invité n’a pas écrit sur le disque est perdu. On l’emploie quand `shutdown` ne répond pas.
    ],
    bloc(role: "danger", taille: px(23), taille-titre: px(26))[`undefine --remove-all-storage` : sans retour][
      La VM et ses disques disparaissent. Avant : `virsh dumpxml ma-premiere-vm > ma-premiere-vm.xml`.
    ],
  ),
  source-de: [#link("https://libvirt.org/manpages/virsh.html")[virsh(1)]],
  note: [Sorties de virsh 10.0.0, sur une VM sans système : shutdown n’y a aucun effet (aucun invité n’écoute l’ACPI), d’où le destroy ; sur une VM Debian installée, shutdown l’éteint en quelques secondes. Le domaine doit déclarer \<acpi/> dans ses features (virt-install le fait). --remove-all-storage ne supprime que les volumes connus d’un pool (diapositive « Pools et volumes ») ; un disque posé ailleurs reste en place. Les notes d’origine du cours écrivaient virsh undefined : la commande est undefine.],
)

== Trois façons de brancher une VM <reseaux-libvirt>

#anime(
  rang(
    bloc(taille: px(22), taille-titre: px(26))[NAT : le réseau `default`][
      #raw("<forward mode='nat'/>", lang: none)
      - Les VM sortent par l’adresse de l’hôte ; de l’extérieur, on ne les joint pas
      - Pont `virbr0` de l’hôte (192.168.122.1) ; libvirt y sert le DHCP (adresses automatiques) et le DNS (noms)
      - Pour : une VM de travail. C’est le réseau par défaut
    ],
    bloc(taille: px(22), taille-titre: px(26))[Pont (_bridge_) vers le réseau local][
      #raw("<forward mode='bridge'/>", lang: none) \
      #raw("<bridge name='br0'/>", lang: none)
      - La VM est branchée sur le réseau local : elle y a sa propre adresse
      - Le réseau local la joint comme une machine de plus : à protéger comme telle
      - Pour : un serveur. Demande un pont `br0` sur une carte filaire de l’hôte
    ],
    bloc(taille: px(22), taille-titre: px(26))[Isolé : un réseau de laboratoire][
      _pas d’élément_ #raw("<forward>", lang: none)
      - Les VM se joignent entre elles et joignent l’hôte ; rien ne sort
      - Pont et DHCP servis par libvirt, comme en NAT
      - Pour : un laboratoire (cluster, attaque, configuration réseau) sans fuite
    ],
  ),
  rang(bloc(role: "retenir", taille: px(26))[À retenir][
    Un réseau libvirt est un XML (`virsh net-define`, puis `net-start`) ; d’un mode à l’autre, l’élément `<forward>` change. Une VM peut avoir plusieurs cartes, sur plusieurs réseaux.
  ]),
  source-de: [#link("https://libvirt.org/formatnetwork.html")[libvirt.org, Network XML format] · #link("https://wiki.libvirt.org/Networking.html")[wiki.libvirt.org, Networking]],
  note: [Le réseau default est livré par libvirt (/usr/share/libvirt/networks/default.xml) : \<forward/> y est écrit sans mode, et nat est le mode par défaut ; virsh net-dumpxml default l’affiche en clair (mode='nat'). Tant qu’aucune VM n’y est branchée, ip addr show virbr0 affiche NO-CARRIER : le pont existe, rien n’y est relié. Pont vers le réseau local : on crée d’abord un pont de l’hôte (br0) qui englobe la carte filaire ; une carte Wi-Fi ne se met pas en pont (le point d’accès refuse les adresses MAC des VM). Le réseau isolé, avec deux cartes par VM (une sur default, une sur labo), est l’étape 8 du TP libvirt.],
)

== Pools et volumes : où vivent les disques <pools-volumes>

#anime(
  rang(
    bloc(taille: px(24))[Deux étages][
      - Un *pool* : un espace où ranger des disques (répertoire, volumes LVM, _Logical Volume Manager_, partage NFS, Ceph…)
      - Un *volume* : un disque dans un pool. Mêmes commandes quel que soit le pool : `vol-create-as`, `vol-clone`, `vol-delete`
      - Le pool `default` : le répertoire `/var/lib/libvirt/images`, créé par virt-install ou virt-manager à leur premier usage
    ],
  ),
  rang(
    bloc(role: "pratique", poids: 1.45, taille: px(24))[Démonstration][
      #terminal(titre: none, taille: px(19))[
        ```
        $ virsh pool-list
         Name      State    Autostart
        -------------------------------
         default   active   yes
        $ virsh vol-list default
         Name                   Path
        ----------------------------------------------------------------------
         ma-premiere-vm.qcow2   /var/lib/libvirt/images/ma-premiere-vm.qcow2
        ```
      ]
    ],
    bloc(role: "precaution", taille: px(23), taille-titre: px(26))[Hors des pools, libvirt n’efface rien][
      `undefine --remove-all-storage` supprime les volumes des pools. Un disque rangé ailleurs reste : « is not managed by libvirt. Remove it manually ».
    ],
  ),
  source-de: [#link("https://libvirt.org/storage.html")[libvirt.org, Storage management] · #link("https://libvirt.org/formatstorage.html")[Storage pool and volume XML format]],
  note: [Sorties de virsh 10.0.0. Le volume ma-premiere-vm.qcow2 est celui que virt-install a créé (--disk size=10). Un pool se définit en XML comme le reste (virsh pool-define-as … dir --target …, puis pool-start et pool-autostart). Un disque désigné par son pool et son volume (\<disk type='volume'>\<source pool='default' volume='…'/>) ne dépend plus de son chemin : c’est ce que fait le fichier vm-exemple.xml du TP. Message d’erreur relevé avec libvirt 10.0.0 sur un disque hors pool.],
)

== qcow2 : copie sur écriture et chaîne d’images <qcow2-backing>

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  let image(t, sous, fond, texte: c.encre, trait: none) = block(width: 100%, height: px(120), fill: fond,
    stroke: trait, radius: px(12), inset: px(14), align(center + horizon, stack(spacing: px(8),
      text(size: px(26), weight: 600, fill: texte, t), text(size: px(22), fill: texte, sous))))
  let b-modele = bloc(taille: px(24))[Le modèle][
    - Un disque qcow2 est découpé en grappes (_clusters_) de 64 Kio ; une grappe jamais écrite ne prend pas de place (allocation fine)
    - Une image peut s’appuyer sur une autre, son image de base (_backing file_), qui reste en lecture seule
    - *Écrire* : la grappe va dans l’image du haut, celle de la VM (copie sur écriture, _copy-on-write_)
    - *Lire* : la grappe est cherchée dans l’image du haut, puis dans chaque image de base, en descendant la chaîne ; introuvable, elle vaut zéro
  ]
  grid(columns: (px(620), 1fr), column-gutter: px(56),
    stack(spacing: px(14),
      uncover("3-", image([`troisieme-vm.qcow2`], [la VM : lecture-écriture], c.invite-clair,
        trait: (paint: c.invite, thickness: px(3), dash: "dashed"))),
      uncover("3-", align(center, text(size: px(24), weight: 600, fill: c.invite)[↓ s’appuie sur])),
      uncover("2-", image([`base-ma-premiere-vm.qcow2`], [image de base : lecture seule], c.nuit, texte: c.fond)),
    ),
    bloc-anime(b-modele, 1, uncover),
  )
  v(px(24))
  uncover("5-", rendre-bloc(bloc(role: "danger", taille: px(24))[Attention : la base est intouchable][
    Modifier ou démarrer l’image de base change ce que lisent toutes les VM qui s’appuient sur elle : leurs disques deviennent incohérents.
  ]))
  source[#link("https://www.qemu.org/docs/master/interop/qcow2.html")[qemu.org, qcow2 format] · #link("https://www.qemu.org/docs/master/system/images.html")[qemu.org, Disk images]]
  utils.speaker-note(self: self)[Modèle énoncé pour l’artefact « chaîne de backing files ». Un clic par puce du modèle, la chaîne se dessine avec la deuxième et la troisième puce. Grappe de 64 Kio : taille par défaut (cluster\_size: 65536 dans qemu-img info). L’allocation fine est celle du mini TP (196 Kio pour un disque de 20 Gio) ; qcow2 signifie QEMU Copy On Write, version 2. La chaîne peut compter plusieurs étages (base, image intermédiaire, VM) : qemu-img commit reverse une image dans sa base, qemu-img rebase change de base. C’est le mécanisme des couches d’images du cours Docker, au niveau des blocs d’un disque au lieu des fichiers. Danger, réalisé en démonstration à la diapositive suivante : une grappe écrite dans la base change sous les pieds des VM qui ne l’avaient pas réécrite.]
})

== Une VM de plus pour 196 Kio : le backing file <backing-file>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.5, taille: px(24))[Démonstration avec qemu-img][
      #terminal(titre: none, taille: px(19))[
        ```
        $ qemu-img create -q -f qcow2 base.qcow2 10G
        # 1 Mio écrit dans la base (octets 0xaa)
        $ qemu-io -c "write -P 0xaa 0 1M" base.qcow2 > /dev/null
        # -b : l’image de base ; -F : son format
        $ qemu-img create -q -f qcow2 -b base.qcow2 -F qcow2 vm1.qcow2
        $ ls -sh base.qcow2 vm1.qcow2
        1.3M base.qcow2
        196K vm1.qcow2
        # la VM écrit ses 64 premiers Kio (octets 0xbb)
        $ qemu-io -c "write -P 0xbb 0 64k" vm1.qcow2 > /dev/null
        # quelle image porte chaque plage du disque de vm1 ?
        $ qemu-img map vm1.qcow2
        Offset          Length          Mapped to       File
        0               0x10000         0x50000         vm1.qcow2
        0x10000         0xf0000         0x60000         base.qcow2
        ```
      ]
    ],
    bloc(taille: px(23), taille-titre: px(26))[Ce que montre `qemu-img map`][
      - Les 64 premiers Kio (`0x10000`) : écrits par la VM, donc dans `vm1.qcow2`
      - Les 960 Kio suivants : jamais réécrits, lus dans `base.qcow2`
      - Le reste des 10 Gio : écrit nulle part, absent de la carte, lu comme des zéros
      - Avec libvirt : `virsh vol-create-as` crée ce disque dans un pool (`--backing-vol`) ; `qemu-img info --backing-chain` lit la chaîne
    ],
  ),
  source-de: [#link("https://www.qemu.org/docs/master/tools/qemu-img.html")[qemu-img(1)] · #link("https://libvirt.org/manpages/virsh.html")[virsh(1), vol-create-as]],
  note: [Sorties de qemu-img 8.2.2. qemu-io (paquet qemu-utils) lit et écrit dans une image sans VM : write -P 0xaa remplit la plage de l’octet 0xaa. Sans -F, qemu-img refuse désormais une image de base dont le format n’est pas donné (deviner le format d’une image est un risque de sécurité). L’ancien sujet du site donnait qemu-img info … | tail -2 pour voir l’image de base : avec QEMU 8.2, ces deux lignes sont file length et disk size ; on cherche les lignes backing file (grep backing) ou on lit toute la chaîne (--backing-chain). Le TP crée ainsi une troisième VM sur une base copiée de la première (étape 7) : quelques Kio au lieu d’une copie complète.],
)

== Instantanés : revenir en arrière <instantanes>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.4, taille: px(24))[Démonstration][
      #terminal(titre: none, taille: px(19))[
        ```
        $ virsh snapshot-create-as ma-premiere-vm avant-tp \
          --description "état sain"
        Domain snapshot avant-tp created
        $ virsh snapshot-list ma-premiere-vm
         Name       Creation Time               State
        -------------------------------------------------
         avant-tp   2026-11-25 09:57:10 +0000   running
        # … une fausse manœuvre dans l’invité, puis :
        $ virsh snapshot-revert ma-premiere-vm avant-tp
        Domain snapshot avant-tp reverted
        ```
      ]
    ],
    bloc(taille: px(23), taille-titre: px(26))[Un instantané interne][
      - Rangé dans le fichier qcow2 lui-même : le format raw n’en a pas
      - VM en marche : disque *et* mémoire ; la VM repart dans l’état exact de la photo
      - Ce qui s’est passé depuis est perdu : c’est le but
    ],
  ),
  rang(bloc(role: "precaution", taille: px(23), taille-titre: px(26))[UEFI : pas d’instantané interne][
    Une VM en UEFI (micrologiciel en mémoire flash, _pflash_) refuse : « internal snapshots of a VM with pflash based firmware are not supported ». Pour Debian, virt-install choisit le BIOS : les instantanés internes fonctionnent.
  ]),
  source-de: [#link("https://libvirt.org/formatsnapshot.html")[libvirt.org, Snapshot XML format] · #link("https://libvirt.org/kbase/snapshots.html")[libvirt.org, Snapshots]],
  note: [Sorties de virsh 10.0.0 en TCG ; le refus en UEFI est relevé avec libvirt 10.0.0 et OVMF (firmware='efi'), à rejouer sur Debian 13 (libvirt 11). Le code de virt-install le dit : pour un invité x86, il garde le BIOS « since it is faster and doesn’t break QEMU internal snapshots », sauf si l’OS exige l’UEFI. Parade pour une VM en UEFI : un instantané externe (virsh snapshot-create-as --disk-only), qui crée un nouveau fichier qcow2 au-dessus de l’ancien, exactement la chaîne de la diapositive qcow2.],
)

== À vous : effacer une VM qui a un instantané <a-vous-effacer>

#anime(
  rang(bloc(role: "pratique", taille: px(26))[La situation][
    - `ma-premiere-vm` est en marche ; elle a l’instantané `avant-tp`
    - Vous voulez la faire disparaître, disque compris
  ]),
  rang(bloc(role: "question")[À vous][
    + `virsh destroy ma-premiere-vm` : que reste-t-il de la VM ?
    + Puis `virsh undefine ma-premiere-vm` : que se passe-t-il ?
    + Quelle commande efface la VM, son instantané et son disque ?
  ]),
  note: [Laisser chercher, avec man virsh (commande undefine). Le corrigé est sur la diapositive suivante.],
)

== Effacer une VM : corrigé

#corriges(note: [Sorties de virsh 10.0.0. Question 2 : libvirt refuse d’effacer une définition dont les instantanés ont des métadonnées ; le code de retour vaut 1. --snapshots-metadata efface ces métadonnées (les instantanés internes disparaissent avec le volume). Une VM en UEFI demande en plus --nvram (« cannot undefine domain with nvram »). L’ancien sujet du site enseignait undefine --remove-all-storage après un instantané : il échoue tel quel.],
  (1, [`virsh destroy ma-premiere-vm` : que reste-t-il de la VM ?],
    reponse(terminal(titre: none, taille: px(19))[
      ```
      $ virsh destroy ma-premiere-vm
      Domain 'ma-premiere-vm' destroyed
      $ virsh list --all
       Id   Name             State
      ---------------------------------
       -    ma-premiere-vm   shut off
      # → tout : définition, disque, instantané ; seul le processus est arrêté
      ```
    ])),
  (2, [Puis `virsh undefine ma-premiere-vm` : que se passe-t-il ?],
    reponse(terminal(titre: none, taille: px(19))[
      ```
      $ virsh undefine ma-premiere-vm
      error: Failed to undefine domain 'ma-premiere-vm'
      error: Requested operation is not valid: cannot delete inactive domain with 1 snapshots
      # → refus : l’instantané protège la définition
      ```
    ])),
  (3, [Quelle commande efface la VM, son instantané et son disque ?],
    reponse(terminal(titre: none, taille: px(19))[
      ```
      $ virsh undefine ma-premiere-vm --snapshots-metadata --remove-all-storage
      Domain 'ma-premiere-vm' has been undefined
      Volume 'vda'(/var/lib/libvirt/images/ma-premiere-vm.qcow2) removed.
      ```
    ])),
)

== virt-manager : libvirt en interface graphique

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - L’*interface graphique de libvirt* : même moteur que la ligne de commande `virsh`
      - Créer, démarrer, arrêter, cloner une VM ; console graphique intégrée (protocoles VNC ou SPICE)
      - Gère l’hôte local, ou un hôte distant via SSH : `qemu+ssh://serveur/system`
    ],
    bloc(role: "pratique", taille: px(27))[Bon à savoir][
      - Application de *bureau, mono-poste* : ni cluster, ni haute disponibilité, ni multi-utilisateur
      - Sur Debian/Ubuntu : paquet `virt-manager`, l’outil graphique de référence
      - Sous Red Hat, déprécié au profit de la console web *Cockpit* (`cockpit-machines`)
    ],
  ),
  bandeau[*Origine* : projet *libvirt / virt-manager*, développé par *Red Hat* et sa communauté · logiciel libre (GPL) · pilote KVM/QEMU au travers de libvirt · #link("https://virt-manager.org")[virt-manager.org]],
  note: [Fin de la partie libvirt : l’équivalent graphique de virsh et de virt-install. virt-manager (Virtual Machine Manager) et virsh s’appuient tous deux sur libvirt ; ce qui est fait dans l’un se retrouve dans l’autre. Console distante via SSH : virt-manager -c qemu+ssh:\/\/user\@hote/system. Statut au 18 novembre 2026 : toujours maintenu en amont et standard sur Debian/Ubuntu ; Red Hat l’a déprécié dans RHEL (annoncé dès RHEL 8) et pousse la console web Cockpit avec le module cockpit-machines.],
)

// ======================================================================
= Pour aller plus loin

== Incus : conteneurs et VM, un seul outil

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - Un gestionnaire *unique* pour des *conteneurs système* (LXC, _Linux Containers_) *et* des *machines virtuelles* (QEMU/KVM), en ligne de commande (`incus`) ou par API
      - Conteneur « système » : un OS complet avec son init, persistant ; à distinguer des conteneurs *applicatifs* de Docker
      - Fondé sur des *images*, API REST, instantanés, migration à chaud
    ],
    bloc(role: "pratique", taille: px(27))[Bon à savoir][
      - *Cluster* de plusieurs nœuds, projets et profils, quotas de ressources
      - Une VM : `incus launch images:debian/13 v1 --vm`
      - Un conteneur : la même commande *sans* `--vm`
    ],
  ),
  bandeau[*Incus* : fork communautaire de *LXD* (créé par *Canonical*, éditeur d’Ubuntu), passé sous le projet *Linux Containers* (Stéphane Graber) · Apache-2.0 · paquet `incus` dans Debian 13 · #link("https://linuxcontainers.org/incus/")[linuxcontainers.org/incus]],
  note: [Incus prolonge la logique de virtualisation vers les conteneurs système, pont naturel vers le cours Docker (conteneurs applicatifs). Au 18 novembre 2026 : Incus est un fork de LXD lancé par Stéphane Graber en 2023 sous le projet Linux Containers (dépôt lxc/incus) ; il gère conteneurs LXC et VM QEMU/KVM par une même ligne de commande et une même API ; licence Apache-2.0 ; empaqueté dans Debian 13 (paquet incus) ; version 6.21 fin 2025 / début 2026. Conteneur système ≠ conteneur applicatif : le premier fait tourner un OS complet (comme une VM légère, en partageant le noyau de l’hôte), le second un seul processus applicatif.],
)

== Proxmox VE : la virtualisation clé en main

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - Une *distribution complète* (basée sur Debian) : hyperviseur + interface web, installée directement sur le serveur
      - *KVM* pour les machines virtuelles, *LXC* pour les conteneurs système
      - Tout se pilote depuis l’interface web : création, console, modèles, sauvegardes
    ],
    bloc(role: "pratique", taille: px(27))[Pour la production][
      - Cluster de plusieurs nœuds, *haute disponibilité*, migration à chaud
      - Stockage et réseau définis par logiciel : *Ceph* intégré, réseau SDN (_software-defined networking_)
      - Sauvegardes avec Proxmox Backup Server
    ],
  ),
  bandeau[*Proxmox VE* : édité par *Proxmox Server Solutions GmbH* (Vienne, Autriche) · base Debian · open source AGPL, abonnement entreprise payant · s’appuie sur KVM et LXC · #link("https://pve.proxmox.com/pve-docs/")[pve.proxmox.com]],
  note: [À la différence de virt-manager (application de bureau sur un poste), Proxmox s’installe sur le serveur lui-même (bare metal) et fournit l’hyperviseur ET son interface. Positionné comme alternative à VMware vSphere/ESXi. Au 18 novembre 2026 : Proxmox VE 9.2, base Debian 13, noyau 7.0 (sources Proxmox). Licence AGPLv3 ; le logiciel est gratuit, l’abonnement donne accès au dépôt entreprise (mises à jour stabilisées) et au support.],
)

== oVirt : gérer un datacenter KVM

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - Plateforme *web* de gestion de la virtualisation *KVM* à l’échelle d’un *datacenter* (moteur _oVirt Engine_)
      - Pilote un *cluster d’hôtes* KVM/libvirt : création de VM, *migration à chaud*, haute disponibilité
      - Stockage, réseaux, modèles et instantanés depuis une seule interface ; alternative libre à VMware vSphere
    ],
    bloc(role: "pratique", taille: px(27))[Statut aujourd’hui][
      - Était l’*amont* de Red Hat Virtualization (RHV)
      - Red Hat a *arrêté RHV* et bascule vers *OpenShift Virtualization* (KubeVirt)
      - oVirt continue surtout en *communautaire* ; *Oracle Linux Virtualization Manager* (OLVM) en est un dérivé maintenu
    ],
  ),
  bandeau[Projet *oVirt*, lancé par *Red Hat* (2012) comme amont de RHV · Apache-2.0 · fondé sur *KVM/libvirt* · depuis l’arrêt de RHV, projet surtout communautaire, poursuivi par *Oracle* (OLVM) · #link("https://www.ovirt.org")[ovirt.org]],
  note: [Même famille que virt-manager et Proxmox (tous fondés sur KVM/libvirt), mais à l’échelle datacenter avec un moteur de gestion centralisé (oVirt Engine, en Java) et des hôtes exécutant KVM via l’agent VDSM. Au 18 novembre 2026 : oVirt lancé par Red Hat vers 2011-2012 comme amont de Red Hat Virtualization (RHV/RHEV) ; licence Apache-2.0 ; fondé sur KVM et libvirt. Red Hat a mis fin à RHV et oriente ses clients vers OpenShift Virtualization (fondée sur KubeVirt) : oVirt est donc devenu surtout communautaire, avec une sortie 4.5.7 après environ deux ans ; Oracle maintient un dérivé, Oracle Linux Virtualization Manager (OLVM). Fil conducteur : la gestion de VM KVM « datacenter » de Red Hat est passée d’oVirt/RHV à OpenShift Virtualization.],
)

== OpenShift (hors cadre) : Kubernetes

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - Distribution *Kubernetes* de Red Hat pour orchestrer des *conteneurs applicatifs* sur un cluster de serveurs
      - Ajoute à Kubernetes : console web, intégration et déploiement continus (CI/CD), registre d’images, contrôle d’accès par rôles (RBAC), contraintes de sécurité des conteneurs (SCC)
      - *OKD* en est la version communautaire libre
    ],
    bloc(role: "precaution", taille: px(27))[Hors cadre][
      - Ce cours s’arrête à la VM sur *un hôte* ; OpenShift gère un *cluster* qui ordonnance des conteneurs
      - Seul lien : *OpenShift Virtualization* (KubeVirt) fait tourner des VM *à côté* des conteneurs
      - La conteneurisation est le sujet du cours suivant
    ],
  ),
  bandeau[*OpenShift* : édité par *Red Hat* (groupe IBM), bâti sur *Kubernetes* (créé par Google en 2014, aujourd’hui projet de la *CNCF*, _Cloud Native Computing Foundation_) · VM + conteneurs via KubeVirt · #link("https://docs.openshift.com")[docs.openshift.com]],
  note: [Diapositive d’ouverture, hors du cadre du cours : elle situe la virtualisation par rapport à l’orchestration de conteneurs. Au 18 novembre 2026 : OpenShift 4.20 en disponibilité générale depuis le 11 novembre 2025 (Red Hat) ; plateforme bâtie sur Kubernetes ; socle RHEL CoreOS ; build source-to-image et Operators ; OpenShift Virtualization (fondé sur le projet KubeVirt) exécute des machines virtuelles aux côtés des conteneurs ; OKD est la distribution communautaire en amont. Les conteneurs applicatifs sont le sujet du cours Docker qui suit.],
)

== Xen Orchestra : la console web de XCP-ng

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - L’*interface web de gestion de XCP-ng* (et de XenServer), hyperviseur de *type 1* fondé sur Xen
      - Développé par *Vates*, l’éditeur de XCP-ng
      - Gère un ou plusieurs *pools* de serveurs depuis une seule interface
    ],
    bloc(role: "pratique", taille: px(27))[Fonctions][
      - Sauvegarde et réplication des VM, migration à chaud
      - Ordonnancement des tâches, statistiques
      - Multi-utilisateur : rôles et délégation de droits
    ],
  ),
  bandeau(taille: px(24))[Édités par *Vates* (France) : *XCP-ng* (l’hyperviseur) et *Xen Orchestra* (sa console web), fondés sur *Xen*, créé à l’université de Cambridge (2003), aujourd’hui Xen Project / Linux Foundation · XCP-ng est un fork libre de Citrix *XenServer* · cœur open source, édition commerciale XOA · #link("https://docs.xen-orchestra.com")[docs.xen-orchestra.com]],
  note: [Après KVM (virt-manager, Proxmox, oVirt), l’écosystème Xen. Lien avec la diapositive sur KVM et Xen : XCP-ng est une distribution hyperviseur fondée sur Xen (type 1), Xen Orchestra en est la console web. Vates, éditeur français de XCP-ng et Xen Orchestra, positionne l’ensemble (Vates VMS, Virtualization Management Stack) comme alternative à VMware vSphere. Xen Orchestra : cœur open source, édition commerciale XOA (Xen Orchestra Appliance) avec support et fonctions avancées ; on peut aussi le construire depuis les sources. Source : documentation Vates, au 18 novembre 2026.],
)

== Qubes OS : la sécurité par compartimentage

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - Un *système de bureau* qui applique la *sécurité par compartimentage* : chaque activité tourne dans sa propre VM, un « *qube* »
      - Repose sur l’hyperviseur *Xen* (type 1) : c’est tout le *poste de travail* qui est virtualisé, pas un serveur
      - Fenêtres *bordées de couleur* selon le niveau de confiance (travail, perso, non fiable)
    ],
    bloc(role: "pratique", taille: px(27))[Comment ça marche][
      - *dom0* administrateur, sans réseau ; réseau et USB isolés dans des qubes dédiés (`sys-net`, `sys-usb`)
      - *Qubes jetables* : ouvrir une pièce jointe douteuse, puis tout détruire
      - VM dérivées de *modèles* (Fedora, Debian, Whonix/Tor) : mises à jour centralisées
    ],
  ),
  bandeau[Projet *Qubes OS*, lancé en 2010 par *Joanna Rutkowska* (Invisible Things Lab) · logiciel libre (GPL) · bâti sur l’hyperviseur *Xen* · ici la virtualisation sert la *sécurité*, pas la consolidation de serveurs · #link("https://www.qubes-os.org/doc/")[qubes-os.org/doc]],
  note: [Exemple marquant d’usage de la virtualisation de type 1 côté poste de travail, pour la sécurité et non la consolidation. Chaque qube est une VM Xen ; le compromis d’une application reste confiné à son qube. dom0 (le domaine d’administration Xen) n’a pas d’accès réseau ; des qubes de service dédiés portent le réseau (sys-net), le pare-feu (sys-firewall) et l’USB (sys-usb). Les VM applicatives dérivent de modèles en lecture seule (Fedora, Debian, Whonix pour Tor), ce qui centralise les mises à jour. Les qubes jetables (DisposableVM) servent à ouvrir un fichier à risque puis disparaissent. Au 18 novembre 2026 : projet fondé par Joanna Rutkowska (Invisible Things Lab), première version stable 1.0 en 2012 ; série stable 4.2 depuis fin 2023 ; licence GPL ; fondé sur Xen. Rendu célèbre notamment par le soutien public d’Edward Snowden.],
)

== MicroVM : une VM réduite à l’essentiel

#anime(
  rang(bloc(taille: px(26))[L’idée][
    - Une vraie VM, exécutée par KVM : son propre noyau, l’isolation du matériel
    - Une machine virtuelle minimale : quelques périphériques virtio, ni micrologiciel de démarrage (BIOS) ni matériel hérité (USB, carte graphique…)
    - Démarrage direct du noyau invité : rapide, peu de mémoire, donc des milliers de microVM par hôte
  ]),
  rang(bloc(taille: px(24))[Où se place la microVM ?][
    #table(columns: (1fr, 1.2fr, 1.2fr, 1.2fr), stroke: none, inset: (x: px(8), y: px(6)),
      fill: (x, y) => if y == 0 or calc.even(y) { rgb("#DCE5F3") } else { c.fond },
      table.header([], ..([VM classique], [MicroVM], [Conteneur]).map(t => align(center, strong(t)))),
      ..(
        ([Noyau], [le sien], [le sien], [celui de l’hôte]),
        ([Isolation], [matérielle (VT-x)], [matérielle (VT-x)], [par le noyau de l’hôte]),
        ([Machine], [complète, émulée], [minimale, virtio], [aucune]),
        ([Démarrage], [secondes], [fraction de seconde], [fraction de seconde]),
      ).map(((k, ..v)) => (text(fill: c.bleu, k), ..v)).flatten(),
    )
  ]),
  note: [La microVM répond au besoin du cloud multi-locataire : exécuter le code de clients différents sur un même hôte avec l’isolation d’une VM, au rythme et à la densité des conteneurs (fonctions serverless, bacs à sable). Le tableau est qualitatif : les temps dépendent du noyau invité et de la charge. Les conteneurs sont détaillés à la dernière diapositive et dans le cours Docker.],
)

== MicroVM : les technologies

#slide(repeat: 5, self => {
  let (uncover,) = utils.methods(self)
  lignes(largeur: px(420), taille: px(26), uncover: uncover,
    ([Firecracker], [AWS, 2018, écrit en Rust : derrière Lambda et Fargate ; annonce moins de 125 ms de démarrage et moins de 5 Mio de surcoût par microVM]),
    ([Cloud Hypervisor], [2019, en Rust, projet de la Linux Foundation : charges cloud, plus de périphériques que Firecracker]),
    ([QEMU microvm], [Le type de machine « microvm » de QEMU (depuis la 4.2) : le même QEMU, sans le matériel hérité]),
    ([Kata Containers], [Chaque conteneur dans sa microVM : s’utilise comme moteur d’exécution avec containerd et Kubernetes]),
  )
  espace
  bloc-anime(bloc(role: "precaution")[À ne pas confondre][
    gVisor n’est pas une microVM : c’est un noyau réécrit en espace utilisateur, qui intercepte les appels système du conteneur.
  ], 5, uncover)
  source[#link("https://firecracker-microvm.github.io")[firecracker-microvm.github.io] · #link("https://www.cloudhypervisor.org")[cloudhypervisor.org] · #link("https://www.qemu.org/docs/master/system/i386/microvm.html")[qemu.org, microvm] · #link("https://katacontainers.io")[katacontainers.io]]
  utils.speaker-note(self: self)[Tous s’appuient sur KVM (rappel : KVM exécute, un programme en espace utilisateur fournit la machine ; ici ce programme remplace QEMU ou l’allège). Firecracker : publié en open source par AWS en novembre 2018 ; les chiffres de démarrage et de mémoire sont ceux annoncés par le projet (firecracker-microvm.github.io). Cloud Hypervisor : lancé par Intel en 2019. QEMU : machine microvm introduite en version 4.2 (décembre 2019). Kata Containers : fusion d’Intel Clear Containers et de Hyper runV (2017), fondation OpenInfra (rattachée à la Linux Foundation depuis 2025) ; peut utiliser QEMU, Cloud Hypervisor ou Firecracker comme hyperviseur. crosvm (Google, ChromeOS et Android) est de la même famille.]
})

== VM et conteneurs : deux façons d’isoler

#slide(repeat: 2, self => {
  let (uncover,) = utils.methods(self)
  grid(columns: (1fr, 1fr), column-gutter: px(64),
    pile-archi([Machines virtuelles (KVM)], [Espace utilisateur de l’hôte],
      [*Gestion* (crée, démarre, arrête) : libvirt],
      range(1, 4).map(i => vm[VM #i : QEMU]),
      [Noyau Linux de l’hôte], ([module kvm],), [Matériel (VT-x / AMD-V)]),
    uncover("2-", pile-archi([Conteneurs], [Espace utilisateur de l’hôte],
      [*Gestion* (crée, démarre, arrête) : dockerd, containerd, runc],
      range(1, 4).map(i => vm(bas: [Bibliothèques], fond-bas: rgb("#FBFBF8"))[Conteneur #i]),
      [Noyau Linux de l’hôte], ([namespaces], [cgroups], [capabilities], [seccomp], [AppArmor]),
      [Matériel])),
  )
  utils.speaker-note(self: self)[Représentation fidèle (cas KVM). Une VM est un processus QEMU de l’hôte qui contient un OS invité complet, noyau compris : son code s’exécute directement sur le processeur (mode VT-x / AMD-V), le module kvm du noyau n’intervient que sur les opérations privilégiées, QEMU émule les périphériques. Un conteneur est un ensemble de processus ordinaires de l’hôte : ils appellent directement le noyau de l’hôte, qui les isole (namespaces), les limite (cgroups) et restreint leurs droits (capabilities, seccomp, AppArmor : le module de sécurité actif par défaut sur Debian et Ubuntu). Le moteur (dockerd, containerd, runc) et libvirt sont à côté : ils créent et gèrent, ils ne sont pas traversés. Un hyperviseur de type 1 comme ESXi ou Xen se place, lui, directement sur le matériel (cours Virtualisation). Suite : cours Docker, fondements de la conteneurisation.]
})

// ======================================================================
= Pour rappel

== Pour rappel · liste non exhaustive

#anime(
  rang(bloc(role: "retenir", taille: px(28))[L’essentiel du cours][
    - Émuler traduit les instructions ; virtualiser les exécute sur le vrai processeur, grâce à VT-x / AMD-V
    - Sous Linux : KVM exécute, QEMU fournit la machine, libvirt gère (virsh, virt-install, virt-manager)
    - Type 1 ou type 2 : une frontière floue ; la paravirtualisation (virtio) est une autre question
    - Une image téléchargée se vérifie : signature (authenticité), puis empreinte SHA-256 (intégrité)
    - Une VM est un processus de l’hôte ; avec `-cpu host`, elle peut à son tour lancer des VM
    - libvirt décrit domaines, réseaux, pools et volumes en XML ; connexion `qemu:///system`, avec le groupe `libvirt`
    - `shutdown` éteint, `destroy` débranche, `undefine` efface ; un instantané interne (qcow2, BIOS) permet de revenir en arrière
    - Réseau NAT, pont ou isolé ; un disque qcow2 peut s’appuyer sur une image de base, qui devient intouchable
    - MicroVM et conteneurs isolent plus légèrement : machine minimale pour l’une, noyau partagé pour les autres
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

#cloture(illustration: "vm")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
