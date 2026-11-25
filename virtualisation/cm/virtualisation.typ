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
  ([Usages], [Bilan, migration à chaud, virtualisation imbriquée, image ISO et empreintes, libvirt, mini TP ; Incus, TP, trois étages sur QEMU/KVM ; autres outils de gestion, Qubes OS]),
  ([Pour aller plus loin], [MicroVM, VM et conteneurs ; pour rappel]),
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

== Télécharger l’ISO, puis la vérifier

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

== Créer une VM : virt-install, puis virsh <virsh>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.3)[Démonstration][
      #terminal(taille: px(21))[
        ```
        # extensions de virtualisation exposées ?
        $ grep -cE 'vmx|svm' /proc/cpuinfo
        8
        # modules KVM chargés
        $ ls /sys/module | grep kvm
        kvm
        kvm_intel
        $ sudo apt install qemu-system-x86 \
          libvirt-daemon-system virtinst virt-viewer
        # VM : 2 Gio de mémoire, 2 processeurs, disque de 10 Gio
        $ virt-install --name test --memory 2048 \
          --vcpus 2 --disk size=10 --osinfo detect=on \
          --cdrom debian-13.7.0-amd64-netinst.iso
        # virt-viewer ouvre la console : on y fait l’installation
        # toutes les VM, même arrêtées
        $ virsh list --all
        ```
      ]
    ],
    bloc(role: "retenir")[À retenir][
      - virt-install crée la VM, virsh la gère : tous deux passent par libvirt
      - virt-viewer affiche la console graphique de l’installateur
      - Prérequis : être membre des groupes kvm et libvirt
    ],
  ),
  source-de: [#link("https://libvirt.org/docs.html")[libvirt.org] · #link("https://github.com/virt-manager/virt-manager/blob/main/man/virt-install.rst")[virt-install(1)]],
  note: [L’ISO est celle téléchargée et vérifiée aux diapositives précédentes. grep -c compte une ligne par processeur logique : un nombre non nul indique que les extensions sont exposées. Commandes pour Debian/Ubuntu ; --osinfo existe depuis virt-install 4.0 ; detect=on identifie l’OS à partir de l’ISO ; --disk size=10 s’exprime en Gio. Par défaut virt-install choisit un affichage graphique (protocoles SPICE ou VNC) et lance virt-viewer (--autoconsole graphical) pour interagir avec l’installateur ; sans virt-viewer, aucune console ne s’ouvre et l’installation interactive est impossible. Alternative en mode texte : --graphics none avec une console série (virsh console). virsh list --all affiche une ligne par VM : identifiant, nom, état (en cours d’exécution, fermé). Proxmox VE, OpenStack et oVirt s’appuient aussi sur KVM. Sorties types, à rejouer avec virtualisation/cm/rejouer-tp.sh.],
)

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

== Mini TP : corrigé (1/4)

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

== virt-manager : libvirt en interface graphique <virt-manager>

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
  note: [Suite directe de la diapositive sur virt-install et virsh : l’équivalent graphique. virt-manager (Virtual Machine Manager) et virsh s’appuient tous deux sur libvirt ; ce qui est fait dans l’un se retrouve dans l’autre. Console distante via SSH : virt-manager -c qemu+ssh:\/\/user\@hote/system. Statut au 18 novembre 2026 : toujours maintenu en amont et standard sur Debian/Ubuntu ; Red Hat l’a déprécié dans RHEL (annoncé dès RHEL 8) et pousse la console web Cockpit avec le module cockpit-machines.],
)

// ======================================================================
= Usages · Incus

// Fil rouge des diapos Incus : un serveur web nginx, dans la VM v1 puis dans le conteneur système c1.
// Commandes d’Incus 6.0.4 (paquet de Debian 13), lues dans ses sources et sa documentation au tag v6.0.4.
#let doc-incus(chemin, texte) = link("https://github.com/lxc/incus/blob/v6.0.4/doc/" + chemin, texte)
#let _non-execute = [Commandes d’Incus 6.0.4 (Debian 13), lues dans ses sources et sa documentation, non exécutées : à rejouer sur le poste de démonstration.]

// Tableau à lignes révélées une à une : la ligne i (à partir de 0) apparaît au clic debut + i, avec son fond.
// Une cellule (signe, texte) porte un « + » (atout) ou un « − » (limite) devant son texte.
#let tableau-anime(self, colonnes, entete, ..lignes-t, debut: 1, taille: px(22), marge: px(8)) = {
  let (uncover,) = utils.methods(self)
  let cellule(x, corps) = {
    if x == 0 { text(fill: c.bleu, weight: 600, corps) }
    else if type(corps) == array { grid(columns: (px(26), 1fr), text(weight: 700, corps.at(0)), corps.at(1)) }
    else { corps }
  }
  set text(size: taille)
  table(columns: colonnes, stroke: none, inset: (x: px(12), y: marge), align: horizon,
    fill: (x, y) => if y > 0 and self.subslide < debut + y - 1 { none }
      else if y == 0 or calc.even(y) { c.bleu-clair } else { c.fond },
    table.header(..entete.map(t => text(weight: 600, t))),
    ..lignes-t.pos().enumerate().map(((i, l)) =>
      l.enumerate().map(((x, corps)) => uncover(str(debut + i) + "-", cellule(x, corps)))).flatten(),
  )
}

// Démonstration à gauche, visible d’emblée ; à droite, des blocs empilés, révélés bloc par bloc puis puce par puce.
// Le premier bloc de droite s’aligne en haut de la démonstration, le dernier en bas.
#let demo-et-blocs(gauche, ..droite, poids: (1.2, 1), source-de: none, note: none) = {
  let bs = droite.pos()
  let debuts = ()
  let s = 2
  for b in bs { debuts.push(s); s += etapes-bloc(b) }
  slide(repeat: s - 1, self => {
    let (uncover,) = utils.methods(self)
    rangee(poids: poids,
      h => rendre-bloc(gauche, hauteur: h),
      h => block(height: h, stack(..bs.zip(debuts).map(((b, d)) => bloc-anime(b, d, uncover)).intersperse((px(20), 1fr)).flatten())),
    )
    if source-de != none { source(source-de) }
    if note != none { utils.speaker-note(self: self, note) }
  })
}

== Incus : conteneurs et VM, un seul outil <incus>

#anime(
  rang(
    bloc(taille: px(27))[Ce que c’est][
      - Un gestionnaire *unique* d’*instances* : des *conteneurs système*, réalisés par LXC (_Linux Containers_), *et* des *machines virtuelles*, exécutées par QEMU/KVM
      - Conteneur système : un système complet avec son init (son premier processus, systemd), persistant, administré comme une machine ; à distinguer du conteneur *applicatif* de Docker
      - Un démon, piloté par la commande `incus` ou par son API (interface de programmation)
    ],
    bloc(role: "pratique", taille: px(27))[Bon à savoir][
      - Une VM : `incus launch images:debian/13 v1 --vm`
      - Un conteneur système : la même commande *sans* `--vm`
      - Fournis avec l’outil : images prêtes à démarrer, instantanés, profils, réseau, stockage ; cluster de plusieurs hôtes
    ],
  ),
  bandeau[*Incus* : fork communautaire de *LXD* (créé par *Canonical*, éditeur d’Ubuntu), porté par le projet *Linux Containers* (Stéphane Graber) · Apache-2.0 · Debian 13 : paquet `incus` 6.0.4, la version de ce cours · #link("https://linuxcontainers.org/incus/")[linuxcontainers.org/incus]],
  note: [Incus prolonge la logique de virtualisation vers les conteneurs système, pont naturel vers le cours Docker (conteneurs applicatifs). Vocabulaire : une instance est ce qu’Incus crée et gère, conteneur système ou VM ; LXC nomme la technologie qui réalise les conteneurs système, pas l’objet manipulé. Conteneur système ≠ conteneur applicatif : le premier fait tourner un système complet (comme une VM légère, en partageant le noyau de l’hôte), le second un seul service. Au 25 novembre 2026 : Incus est un fork de LXD apparu en 2023, porté par le projet Linux Containers (dépôt lxc/incus), que dirige Stéphane Graber ; licence Apache-2.0. Versions : Debian 13 livre la 6.0.4 (paquet incus 6.0.4-2+deb13u12, branche LTS 6.0, correctifs de sécurité reportés) : c’est la version des diapositives suivantes et du TP. En amont : 7.6.0 (dernière version stable), 7.0.2 (LTS), 6.0.7 (LTS précédente) ; trixie-backports propose la 7.0.2. La documentation en ligne (linuxcontainers.org/incus/docs/main) décrit la version la plus récente : quelques comportements diffèrent de la 6.0.4, d’où les liens des diapositives suivantes vers la documentation du tag v6.0.4.],
)

== Installer et initialiser Incus <incus-installation>

#demo-et-blocs(
  bloc(role: "pratique")[Sur Debian 13][
    #terminal(taille: px(21))[
      ```
      # conteneurs et VM (incus-base : conteneurs seuls)
      $ sudo apt install incus
      # réglages par défaut : un stockage, un réseau
      $ sudo incus admin init --minimal
      # piloter Incus sans sudo : groupe incus-admin
      $ sudo usermod -aG incus-admin $USER
      # prendre ce groupe sans se reconnecter
      $ newgrp incus-admin
      # la liste des instances : vide pour l’instant
      $ incus list
      ```
    ]
  ],
  bloc(taille: px(25))[Ce que l’initialisation crée][
    - Un *pool de stockage* (_storage pool_) `default` : un dossier de l’hôte, où Incus range images et disques des instances
    - Un *pont réseau* `incusbr0`, qui relie les instances entre elles et à l’extérieur
    - Un *profil* `default`, qui donne à chaque instance un disque dans ce pool et une carte réseau sur ce pont
  ],
  bloc(role: "danger", taille: px(25))[Attention : le groupe `incus-admin` vaut root][
    Ses membres pilotent un démon qui tourne en root : ils peuvent monter n’importe quel dossier de l’hôte dans une instance. Le groupe `libvirt` donne le même pouvoir.
  ],
  poids: (1.1, 1),
  source-de: [Incus 6.0.4 : #doc-incus("installing.md")[installation] · #doc-incus("howto/initialize.md")[initialisation] · #doc-incus("explanation/security.md")[sécurité]],
  note: [Prérequis : Debian 13, droits sudo ; pour les VM, KVM utilisable (/dev/kvm, voir le mini TP). Paquet incus 6.0.4-2+deb13u12 : il dépend de incus-base (le démon incusd et les conteneurs), de incus-agent et de qemu-system-x86 (les VM) ; incus-base seul suffit pour les conteneurs. Le paquet démarre incus.service et incus.socket, et crée deux groupes : incus-admin (socket principal, contrôle total) et incus (socket restreint : un projet par utilisateur, pas de commande incus admin). Message affiché à l’installation : lancer sudo incus admin init, ajouter les utilisateurs à l’un des groupes, puis se reconnecter ; newgrp ouvre un shell qui a déjà le groupe, ce qui évite la reconnexion dans ce terminal. --minimal ne pose aucune question : pool default au pilote dir (/var/lib/incus/storage-pools/default), ou au pilote btrfs quand /var/lib/incus est sur un système de fichiers Btrfs et que ce pilote est disponible (fonction RunAuto, cmd/incus/admin\_init\_auto.go) ; pont incusbr0, profil default avec la carte eth0 et le disque root. Sans --minimal, incus admin init pose les questions une à une. Avertissement sur le groupe : le message d’installation du paquet incus-base parle d’un accès d’administration complet (« full administrative access »), sa documentation installée, /usr/share/doc/incus-base/packaging.md, d’un contrôle total d’Incus (« effectively grants full control over Incus »), et la page Security de la documentation conclut : « you should only give such access to users who you’d trust with root access to your system » ; même logique que le groupe docker du cours Conteneurisation. Le pool, le pont et les profils sont détaillés dans les diapositives suivantes. #_non-execute],
)

== Images et instances : lancer, observer, entrer <incus-instances>

#anime(
  rang(
    bloc(role: "pratique", poids: 1.2)[Démonstration][
      #terminal(taille: px(20))[
        ```
        # une image Debian 13 du serveur « images: », en VM
        $ incus launch images:debian/13 v1 --vm
        # la même commande sans --vm : un conteneur système
        $ incus launch images:debian/13 c1
        # toutes les instances : état, adresses, type
        $ incus list
        # une instance en détail : état, ressources consommées
        $ incus info v1
        # une commande dans l’instance : installer le serveur web nginx
        $ incus exec v1 -- apt-get update
        $ incus exec v1 -- apt-get install -y nginx
        # la console de la machine (pour la quitter : Ctrl+a, puis q)
        $ incus console v1
        # arrêter, puis supprimer le conteneur d’essai
        $ incus stop c1
        $ incus delete c1
        ```
      ]
    ],
    bloc(role: "retenir")[À retenir][
      - Une *image* : un système prêt à démarrer, sans installation ; `images:` désigne le serveur public du projet Linux Containers
      - Une *instance* : un conteneur système ou une VM, avec les mêmes commandes
      - Une VM d’Incus reste un *processus QEMU* de l’hôte, comme au mini TP
      - `incus exec` entre dans une VM par un agent qui tourne dans l’invité ; `incus console` s’en passe
    ],
  ),
  source-de: [Incus 6.0.4 : #doc-incus("tutorial/first_steps.md")[premiers pas] · #doc-incus("howto/instances_console.md")[console] · #link("https://images.linuxcontainers.org")[images.linuxcontainers.org]],
  note: [Suite du fil rouge du mini TP : même VM Debian, mais sans ISO ni installateur. images: est le serveur images.linuxcontainers.org ; debian/13 y est publiée en conteneur et en VM (deux images différentes sous le même nom ; alias debian/trixie) ; incus image list images: liste le catalogue. La première commande télécharge l’image, les suivantes la retrouvent dans le pool. incus list affiche une ligne par instance : nom, état, adresses IPv4 et IPv6, type (CONTAINER ou VIRTUAL-MACHINE), nombre d’instantanés. Sur l’hôte, pgrep -l qemu montre le processus de la VM ; un conteneur système, lui, est un ensemble de processus de l’hôte. incus exec sur une VM passe par incus-agent, lancé dans l’invité par les images du serveur images: ; juste après le lancement d’une VM, il faut attendre quelques secondes que l’agent réponde. incus console ouvre la console série, utile avant le démarrage de l’agent ou quand le réseau est cassé ; --type vga ouvre la console graphique (protocole SPICE). incus delete refuse une instance en marche : l’arrêter d’abord, ou ajouter --force. incus start la redémarre. Avec QEMU seul : télécharger une ISO, créer un disque, installer, puis se connecter par la fenêtre de la VM ou par ssh. #_non-execute],
)

== Instantanés : figer un état, y revenir <incus-instantanes>

#demo-et-blocs(
  bloc(role: "pratique")[Démonstration][
    #terminal(taille: px(21))[
      ```
      # figer l’état de v1, sous le nom « propre »
      $ incus snapshot create v1 propre
      # les instantanés de v1
      $ incus snapshot list v1
      # casser : supprimer les pages que sert nginx
      $ incus exec v1 -- rm -r /var/www/html
      # revenir à l’instantané : les pages sont de retour
      $ incus snapshot restore v1 propre
      # un instantané occupe de la place : le supprimer
      $ incus snapshot delete v1 propre
      ```
    ]
  ],
  bloc(taille: px(25))[Ce qu’il faut comprendre][
    - Un *instantané* (_snapshot_) fige le disque de l’instance à un instant donné ; `--stateful` y ajoute la mémoire d’une VM en marche, si elle a été préparée pour (`migration.stateful=true`)
    - Restaurer ramène *tout* le disque à cet état : ce qui a été écrit depuis est perdu
    - Mêmes commandes pour une VM et pour un conteneur système
  ],
  bloc(role: "precaution", taille: px(25))[Un instantané n’est pas une sauvegarde][
    Il est rangé dans le même pool que l’instance et disparaît avec le disque de l’hôte. Une sauvegarde sort de l’hôte : `incus export v1 v1.tar.gz`.
  ],
  poids: (1.1, 1),
  source-de: [Incus 6.0.4 : #doc-incus("howto/instances_backup.md")[sauvegarder une instance]],
  note: [Usage type : un instantané avant une mise à jour ou une manipulation risquée. Sans nom, incus snapshot create numérote : snap0, snap1… Autres sous-commandes : rename, show. --stateful (create et restore) enregistre aussi l’état d’exécution d’une VM, à trois conditions (driver\_qemu.go) : la VM tourne ; sa clé migration.stateful vaut true, posée VM arrêtée (la clé ne change pas à chaud) ; le size.state de son disque root est au moins égal à limits.memory. Par défaut, size.state vaut 500 Mio et la mémoire 1 Gio : sans réglage, Incus refuse (« Stateful snapshot requires migration.stateful to be set to true », puis « Stateful stop and snapshots require that the instance limits.memory is less than size.state on the root disk device »). Pour un conteneur, la documentation dit --stateful incomplet (limites de CRIU). Coût d’un instantané : avec le pilote dir du pool default, une copie complète du disque ; avec ZFS ou Btrfs, seulement les blocs modifiés ensuite. Rappel du cours Conteneurisation (« Où faire tourner Docker : hôte ou VM ? ») : restaurer ramène tout le disque en arrière, données comprises. Avec QEMU seul : arrêter la VM, puis qemu-img snapshot -c propre debian.qcow2 ; avec libvirt : virsh snapshot-create-as. #_non-execute],
)

== Limites : à chaud, ou au redémarrage <incus-limites>

#demo-et-blocs(
  bloc(role: "pratique")[Démonstration][
    #terminal(taille: px(21))[
      ```
      # sans réglage, une VM a 1 processeur et 1 Gio de mémoire
      $ incus exec v1 -- nproc
      # 2 processeurs : la VM continue de tourner
      $ incus config set v1 limits.cpu=2
      # plus de mémoire qu’au démarrage (6.0.4) : VM arrêtée
      $ incus stop v1
      $ incus config set v1 limits.memory=2GiB
      $ incus start v1
      # les clés posées sur l’instance
      $ incus config show v1
      # vu de l’invité : 2 processeurs, 2 Gio
      $ incus exec v1 -- nproc
      $ incus exec v1 -- free -m
      ```
    ]
  ],
  bloc(taille: px(25))[Ce qui change à chaud][
    - Une instance se règle par des *clés* de configuration : `limits.cpu`, `limits.memory`…
    - *Conteneur système* : processeurs et mémoire changent aussitôt ; ce sont des limites posées par le noyau de l’hôte
    - *VM* : processeurs ajoutés à chaud ; mémoire seulement *réduite* à chaud (Incus 6.0.4), l’invité rendant des pages
  ],
  bloc(role: "precaution", taille: px(25))[Sans limite, un conteneur système voit tout l’hôte][
    Il partage le noyau de l’hôte : tous ses processeurs, toute sa mémoire. Une VM reçoit toujours une quantité fixée.
  ],
  poids: (1.1, 1),
  source-de: [Incus 6.0.4 : #doc-incus("reference/instance_options.md")[options d’une instance] · #doc-incus("howto/instances_configure.md")[configurer une instance]],
  note: [Unités d’Incus : GiB et MiB sont les Gio et Mio (puissances de 2) ; GB et MB, les puissances de 10. Valeurs par défaut d’une VM : limits.cpu 1, limits.memory 1GiB (documentation des options). incus config show v1 n’affiche que la configuration propre à l’instance ; --expanded y ajoute ce qui vient des profils (diapositive suivante). Conteneur système : les limites sont celles des groupes de contrôle (cgroups) du noyau de l’hôte, modifiables à tout moment ; nproc et free les reflètent dans le conteneur. VM, en 6.0.4 : limits.cpu se change à chaud quand c’est un nombre de processeurs (branchement à chaud ; selon le système invité, il faut parfois mettre les nouveaux processeurs en ligne ou redémarrer) ; limits.memory se réduit à chaud par le ballon mémoire (l’invité rend des pages, lentement et parfois incomplètement), mais ne peut pas dépasser la mémoire du démarrage tant que la VM tourne : incus config set répond « Cannot increase memory size beyond boot time size when VM is running », d’où l’arrêt dans la démonstration. L’ajout de mémoire à chaud est venu avec Incus 6.12 (extension d’API memory\_hotplug), et la LTS 6.0 l’a reçu avec la 6.0.5 (updateMemoryLimit, driver\_qemu.go) : en 6.0.5 comme en 7.0 (7.0.2 dans trixie-backports), incus config set accepte et Incus branche à chaud une barrette de mémoire, dans la limite d’un maximum fixé au démarrage de QEMU (par défaut la mémoire de l’hôte ; clé limits.memory.hotplug, false pour refuser) ; la 6.0.4 de Debian 13 refuse. Avec QEMU seul : -smp et -m se fixent au lancement ; les changer demande de relancer la commande. #_non-execute],
)

== Profils : une configuration réutilisable <incus-profils-commandes>

#demo-et-blocs(
  bloc(role: "pratique")[Un profil `moyen`, puis une VM qui l’utilise][
    #terminal(taille: px(20))[
      ```
      # un profil : des clés et des périphériques, à réutiliser
      $ incus profile create moyen
      $ incus profile set moyen limits.cpu=2 limits.memory=2GiB
      $ incus profile device add moyen root disk \
        path=/ pool=default size=20GiB
      $ incus profile show moyen
      # deux profils, dans cet ordre, puis une clé de l’instance
      $ incus launch images:debian/13 v2 --vm \
        --profile default --profile moyen \
        --config limits.cpu=4
      # la configuration de v2, héritage compris
      $ incus config show v2 --expanded
      ```
    ]
  ],
  bloc(taille: px(25))[Ce qu’il faut comprendre][
    - Un *profil* : un jeu de clés de configuration et de *périphériques* (disque, carte réseau…), pour autant d’instances qu’on veut
    - Le profil `default`, appliqué quand on n’en nomme aucun, apporte le disque `root` et la carte réseau `eth0`
    - Modifier un profil modifie toutes les instances qui l’utilisent
  ],
  bloc(role: "question", taille: px(25))[À votre avis][
    `default`, `moyen` et l’instance disent chacun une part de la configuration. Combien de processeurs pour `v2` ? Quel disque `root` ?
  ],
  poids: (1.2, 1),
  source-de: [Incus 6.0.4 : #doc-incus("profiles.md")[profils]],
  note: [Un profil regroupe des clés de configuration et des périphériques ; une instance en reçoit autant qu’on veut (--profile répété, ou incus profile add v2 moyen après coup) ; sans --profile, elle reçoit default. Le profil default contient ce que incus admin init --minimal y a mis : la carte eth0 (type nic, network incusbr0) et le disque root (type disk, path /, pool default) ; incus profile show default l’affiche. Le profil moyen joue le rôle d’un gabarit : 2 processeurs, 2 Gio, un disque de 20 Gio. Ne pas donner la réponse ici : laisser proposer une valeur pour limits.cpu (2 ou 4 ?) et un disque (avec ou sans taille ?), la diapositive suivante énonce la règle et déroule l’exemple. incus config show v2 sans --expanded n’affiche que la part de l’instance : limits.cpu, des clés volatile.\* et image.\*. Avec QEMU seul : recopier les mêmes options (-smp, -m, -drive) dans la commande de chaque VM. #_non-execute],
)

== Héritage des profils : deux régimes <incus-profils>

#slide(repeat: 8, self => {
  let (uncover,) = utils.methods(self)
  bloc-anime(bloc(role: "retenir", taille: px(24), taille-titre: px(26))[La règle : chacun son tour, le dernier l’emporte][
    - *Ordre* : les profils, dans l’ordre donné, puis l’instance
    - *Clés* de configuration : remplacement *clé par clé* ; le dernier qui définit la clé l’emporte
    - *Périphériques* : à nom égal, le dernier remplace le périphérique *en entier* ; leurs clés ne fusionnent pas
  ], 1, uncover)
  v(px(14))
  uncover("4-", tableau-anime(self, (1.2fr, 1.15fr, 1.65fr, 0.8fr, 1.5fr), debut: 4, taille: px(23), marge: px(10),
    ([Qui définit quoi ?], [profil `default`], [profil `moyen`], [instance `v2`], [résultat (`--expanded`)]),
    ([clé `limits.cpu`], [], [`2`], [`4`], [`4` : l’instance, en dernier]),
    ([clé `limits.memory`], [], [`2GiB`], [], [`2GiB` : celle de `moyen`]),
    ([périphérique `eth0`], [`network=incusbr0`], [], [], [celui de `default`]),
    ([périphérique `root`], [`path=/ pool=default`], [`path=/ pool=default size=20GiB`], [], [celui de `moyen`, en entier]),
  ))
  v(px(10))
  uncover("8-", note(role: "precaution", taille: px(22))[Le `root` de `moyen` remplace celui de `default` en entier : il redonne `path`, `pool` et `size`. Un disque sans `path`, `size=20GiB` seul par exemple, est refusé par Incus. Pour une seule instance : `incus config device override v2 root size=30GiB` recopie `root` dans l’instance, puis y change la clé.])
  source[Incus 6.0.4 : #doc-incus("profiles.md")[profils] · #link("https://github.com/lxc/incus/blob/v6.0.4/internal/server/db/cluster/profiles.go")[code de l’héritage] · à manipuler : #link("../artefacts/heritage-des-profils/")[artefact « L’héritage des profils »]]
  utils.speaker-note(self: self)[Réponse à la question de la diapositive précédente : v2 a été lancée avec --profile default --profile moyen --config limits.cpu=4. Clics : la règle, une ligne par clic ; le tableau, une ligne par clic ; la précaution. Le tableau omet les clés type et name des périphériques. La règle est celle du code d’Incus 6.0.4 (fonctions ExpandInstanceConfig et ExpandInstanceDevices) : deux boucles identiques, l’une sur les clés de configuration, l’autre sur les périphériques indexés par leur nom ; un périphérique y est une valeur comme une autre, remplacée d’un bloc. La documentation n’énonce que la règle des clés. Conséquence démontrée par la dernière ligne : le root de moyen remplace celui de default, il doit donc être complet ; avec size=20GiB seul, Incus refuse le périphérique lui-même (« Disk entry is missing the required "source" or "path" property », disk.go) : la VM n’est pas créée sans disque racine, la commande échoue. De même, incus config device set v2 root size=30GiB est refusé, puisque root vient d’un profil (« Device from profile(s) cannot be modified for individual instance. Override device or modify profile instead ») : override copie d’abord le périphérique hérité dans l’instance. L’artefact « L’héritage des profils » fait manipuler cette règle. #_non-execute]
})

== cloud-init : s’installer au premier démarrage <incus-cloud-init>

#demo-et-blocs(
  bloc(role: "pratique")[Un profil `web` qui installe nginx][
    #terminal(taille: px(20))[
      ```
      # la description que lira cloud-init
      $ cat nginx.yaml
      #cloud-config
      packages:
        - nginx
      # un profil, dont une clé reçoit ce fichier
      $ incus profile create web
      # « - » : la valeur est lue sur l’entrée standard
      $ incus profile set web cloud-init.user-data - < nginx.yaml
      # image « /cloud » : cloud-init y est installé
      $ incus launch images:debian/13/cloud c1 \
        --profile default --profile web
      # attendre la fin de l’installation dans c1
      $ incus exec c1 -- cloud-init status --wait
      ```
    ]
  ],
  bloc(taille: px(25))[Ce qu’il faut comprendre][
    - *cloud-init* : un programme de l’image qui, au *premier démarrage*, applique une description : paquets, utilisateurs, fichiers, commandes
    - Incus lui transmet la clé `cloud-init.user-data` ; portée par un profil, elle vaut pour toutes ses instances
    - Avec `--vm`, le même profil configure une VM
  ],
  bloc(role: "precaution", taille: px(25))[Image `/cloud` ; clé modifiée, tout rejoue][
    Rien tout de suite ; au prochain démarrage, cloud-init voit une nouvelle instance et rejoue paquets, fichiers, commandes. Sans `/cloud`, pas de cloud-init : clé ignorée.
  ],
  poids: (1.2, 1),
  source-de: [Incus 6.0.4 : #doc-incus("cloud-init.md")[cloud-init] · #link("https://cloudinit.readthedocs.io")[documentation de cloud-init]],
  note: [cat affiche le fichier que la commande suivante utilise ; sa première ligne, \#cloud-config, est obligatoire : elle dit à cloud-init comment lire la suite. cloud-init vient du cloud public, où une même image sert à des milliers de machines : chacune se configure seule à son premier démarrage. Clés d’Incus : cloud-init.user-data, cloud-init.vendor-data, cloud-init.network-config. Autre écriture : incus profile edit web, qui ouvre le profil entier en YAML (la clé s’y écrit avec « | » pour garder les retours à la ligne). Modifier une clé cloud-init.\* (dans le profil web ou sur l’instance) fait tirer à Incus un nouvel identifiant, volatile.cloud-init.instance-id (fonction needsNewInstanceID, appelée à chaque modification de l’instance ou de ses profils) : rien ne se passe tout de suite ; au prochain démarrage de chaque instance concernée, cloud-init croit à une nouvelle machine et rejoue ses modules (packages, write\_files, runcmd). Renommer l’instance ou le nom d’une de ses cartes réseau a le même effet. Le profil web ne définit aucun périphérique : c1 reçoit eth0 et root de default, la clé cloud-init de web, selon la règle de la diapositive précédente. cloud-init status --wait rend la main quand tout est appliqué (status: done). Pour une VM : incus launch images:debian/13/cloud v3 --vm --profile default --profile web ; les données passent par l’agent incus-agent. Debian 13 : cloud-init 25.1.4 dans l’image /cloud. Avec QEMU seul : préparer soi-même un disque de configuration (cloud-localds) ou installer à la main. #_non-execute],
)

== Réseau : un pont, des noms, un port publié <incus-reseau>

#anime(
  rang(
    bloc(taille: px(25))[Le pont `incusbr0`][
      - Chaque instance a une carte réseau sur ce *pont* (un commutateur logiciel de l’hôte) et y reçoit une adresse (DHCP)
      - Vers l’extérieur : l’hôte traduit les adresses (NAT) ; rien n’entre de l’extérieur
      - Entre instances, un nom suffit : `<instance>.incus`
    ],
    bloc(role: "pratique", poids: 1.3, taille: px(25))[Publier un port : le périphérique `proxy`][
      #terminal(taille: px(20))[
        ```
        # port 8080 de l’hôte → port 80 du conteneur système c1
        $ incus config device add c1 web proxy \
          listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:80
        # nginx répond sur le port 8080 de l’hôte
        $ wget -qO- http://localhost:8080
        # d’une instance à l’autre : le nom, résolu par le pont
        $ incus exec c1 -- getent hosts v1.incus
        ```
      ]
    ],
  ),
  rang(bloc(role: "precaution", taille: px(25))[Sur une VM, `proxy` n’accepte que la traduction d’adresses (`nat=true`)][
    - *Conteneur système* : ses processus sont des processus de l’hôte. Incus lance sur l’hôte un relais qui écoute sur le port 8080, puis entre dans le réseau du conteneur pour s’y connecter à `127.0.0.1:80`
    - *VM* : rien où entrer, son réseau vit dans le noyau invité, derrière QEMU. Seul le paquet peut être traduit (NAT) vers l’adresse de la VM, qui doit alors être fixe
  ]),
  source-de: [Incus 6.0.4 : #doc-incus("reference/devices_proxy.md")[périphérique proxy] · #doc-incus("reference/network_bridge.md")[réseau en pont]],
  note: [c1 est le conteneur de la diapositive précédente : nginx y écoute sur le port 80. Sigles : DHCP, attribution automatique des adresses ; DNS, résolution des noms ; NAT, traduction d’adresses. incusbr0 : pont créé par incus admin init, géré par Incus, qui y lance dnsmasq (DHCP et DNS) ; incus network show incusbr0 affiche son sous-réseau, incus network list-leases incusbr0 les adresses distribuées. Noms : dns.domain vaut incus et dns.mode vaut managed par défaut ; chaque instance du pont est enregistrée sous son nom. L’hôte n’interroge pas ce DNS par défaut : depuis l’hôte, on joint une instance par son adresse (colonne IPV4 de incus list). proxy sur un conteneur : le relais est un processus de l’hôte (forkproxy) qui garde une socket d’écoute côté hôte et entre dans l’espace de noms réseau du conteneur (sa vue isolée du réseau) pour la connexion ; listen=tcp:0.0.0.0:8080 écoute sur toutes les adresses de l’hôte, connect=tcp:127.0.0.1:80 est l’adresse vue de l’intérieur du conteneur. Sur une VM, Incus 6.0.4 refuse le périphérique sans nat=true (« Only NAT mode is supported for proxies on VM instances ») ; en mode NAT, il faut une adresse IPv4 fixe sur la carte de l’instance et une adresse d’écoute précise de l’hôte (le joker 0.0.0.0 est refusé). Méthode du corrigé du TP (étape 6, 6_reseau_volumes/proxy-vm.sh) : figer l’adresse que v1 a déjà reçue, sans redémarrage, puisque ipv4.address se modifie à chaud (nic\_bridged.go) ; incus config device override v1 eth0 ipv4.address=ADRESSE\_DE\_V1 (colonne IPV4 de incus list v1), puis incus config device add v1 web proxy nat=true listen=tcp:ADRESSE\_DE\_L\_HOTE:8081 connect=tcp:ADRESSE\_DE\_V1:80 (le port 8080 de l’hôte est déjà pris par c1). Parallèle avec Docker (cours Conteneurisation, mode bridge) : -p 8080:80 publie un port de la même façon, par NAT. Avec QEMU seul : -nic user,hostfwd=tcp::8080-:80. #_non-execute],
)

== Volumes : les données hors de l’instance <incus-volumes>

#demo-et-blocs(
  bloc(role: "pratique")[Démonstration][
    #terminal(taille: px(20))[
      ```
      # les pools de stockage : default, créé à l’initialisation
      $ incus storage list
      # un volume « site » dans le pool default
      $ incus storage volume create default site
      # attaché à c1, monté sur le dossier des pages de nginx
      $ incus storage volume attach default site c1 /var/www/html
      $ incus exec c1 -- sh -c \
        'echo Bonjour > /var/www/html/index.html'
      # le conteneur disparaît, le volume et sa page restent
      $ incus delete c1 --force
      $ incus storage volume list default
      ```
    ]
  ],
  bloc(taille: px(25))[Pool et volumes][
    - Le *pool de stockage* `default` contient les images et le disque racine de chaque instance, supprimé avec elle
    - Un *volume* existe à part des instances : il s’attache à l’une, lui survit, et peut passer à une autre
  ],
  bloc(role: "retenir", taille: px(25))[À retenir][
    Une instance se recrée en une commande (image, profil, cloud-init) ; ses données, non. Elles vont sur un volume, qui se sauvegarde et se déplace sans elle.
  ],
  poids: (1.2, 1),
  source-de: [Incus 6.0.4 : #doc-incus("howto/storage_volumes.md")[volumes de stockage] · #doc-incus("explanation/storage.md")[pools et volumes]],
  note: [Même idée que les volumes de Docker (cours Conteneurisation, « Persistance ») : séparer ce qui se reconstruit de ce qui se garde. Le pool default utilise le pilote dir : un dossier de l’hôte (/var/lib/incus/storage-pools/default). Autres pilotes : ZFS, Btrfs, LVM, Ceph, avec instantanés et copies sans recopie complète. incus storage volume list default montre aussi les volumes des instances (types container et virtual-machine) et des images ; le volume site est de type custom. La commande attach est un raccourci : elle ajoute à c1 un périphérique de type disk (pool=default source=site path=/var/www/html), visible dans incus config show c1. Pour retrouver la page : lancer un nouveau conteneur avec le profil web et lui attacher le même volume. Un volume de contenu « système de fichiers » peut être attaché à plusieurs instances. Pour une VM, attacher le volume instance arrêtée : incus create, incus storage volume attach, puis incus start (ou incus stop avant d’attacher). La documentation 6.0.4 l’exige (« File system storage volumes can't be attached to virtual machines while they're running ») ; le code tente pourtant un ajout à chaud par virtiofs (deviceAttachPath, driver\_qemu.go), sur lequel ne pas compter. incus delete --force supprime une instance en marche. Avec QEMU seul : un second disque créé par qemu-img, ajouté par une option -drive, puis formaté et monté dans l’invité. #_non-execute],
)

== Travaux pratiques : découvrir Incus <tp-incus>

#anime(
  rang(
    bloc(role: "question", poids: 1.2, taille: px(26))[Une fonctionnalité d’Incus par étape (3 h)][
      + *Instances et images* : une VM Debian 13
      + *Administrer comme une machine* : WordPress dans la VM
      + *Instantanés et limites* : casser, restaurer, redimensionner
      + *Conteneur système* : la même commande sans `--vm`
      + *Profils et cloud-init* : une instance installée dès son lancement
      + Pour aller plus loin : *réseau et volumes*
      + Facultative : *Docker dans une VM* Incus
    ],
    bloc(role: "pratique", taille: px(26))[Prérequis][
      - Un PC sous Debian 13, avec KVM utilisable (mini TP, questions 1 et 2)
      - Les droits root (`sudo`), pour installer le paquet `incus`
      - Le support du TP : #link("../tp/incus/")[`virtualisation/tp/incus/`]
    ],
  ),
  note(role: "question")[À chaque étape, la même question : avec QEMU seul, qu’auriez-vous dû faire ? Le TP se termine par un tableau des trois étages, corrigé au retour du TP.],
  source-de: [#link("https://github.com/jmchantrein/Cours")[github.com/jmchantrein/Cours] · licence CC BY-NC-SA 4.0],
  note: [Une séance de 3 h, sur Debian 13 native, après le mini TP QEMU/KVM. WordPress (paquets wordpress et mariadb-server de Debian 13) sert de prétexte : chaque étape porte le nom d’une fonctionnalité d’Incus, dans l’ordre des diapositives précédentes. Étapes de l’énoncé : installation ; 1. instances et images ; 2. administrer comme une machine ; 3. instantanés et limites ; 4. conteneur système ; 5. profils et cloud-init ; 6. réseau et volumes (pour aller plus loin) ; 7. Docker dans une VM Incus (facultative), qui peut servir de poste au TP WordPress du cours Conteneurisation ; pour finir, le tableau des trois étages à remplir, dont le corrigé est la diapositive suivante : ne la projeter qu’au retour du TP. Version : incus 6.0.4 de Debian 13, pas les backports. Licence : CC BY-NC-SA 4.0, celle du fichier LICENSE.md à la racine du dépôt.],
)

== QEMU, libvirt, Incus : trois étages, un moteur <trois-etages>

#slide(repeat: 10, self => {
  let (uncover,) = utils.methods(self)
  question("TP", [Le tableau qui termine le TP : un « + » pour un atout, un « − » pour une limite])
  v(px(8))
  uncover("2-", reponse(tableau-anime(self, (1.05fr, 1.1fr, 1.4fr, 1.3fr), debut: 2, taille: px(22), marge: px(7),
    ([], [QEMU nu (mini TP)], [libvirt : `virsh`, virt-manager], [Incus]),
    ([Mécanisme transparent], ("+", [chaque option est écrite]), ("−", [du XML ; libvirt lance QEMU]), ("−", [caché : le démon lance QEMU])),
    ([Images prêtes], ("−", [ISO, ou image à préparer]), ("+", [image cloud, `--cloud-init`]), ("+", [serveur `images:`, une commande])),
    ([Réseau et stockage gérés], ("−", [à la main : `-nic`, `qemu-img`]), ("+", [réseau `default`, pools]), ("+", [pont `incusbr0`, pool `default`])),
    ([Conteneurs et VM ensemble], ("−", [des VM seulement]), ("−", [des VM, en pratique]), ("+", [les deux : avec ou sans `--vm`])),
    ([API et automatisation], ("+", [QMP : une API JSON]), ("+", [une API, du XML]), ("+", [une API REST, profils])),
    ([Outils bâtis dessus], ("+", [libvirt, Incus, Proxmox VE…]), ("+", [OpenStack, oVirt, Cockpit, Boxes]), ("−", [surtout ses propres outils])),
    ([Poste de travail graphique], ("−", [la fenêtre de la VM]), ("+", [virt-manager]), ("−", [la ligne de commande d’abord])),
    ([Sans démon root], ("+", [aucun démon ; groupe `kvm`]), ("+", [possible : `qemu:///session`]), ("−", [groupe `incus-admin` = root])),
  )))
  v(px(6))
  couche([Le même moteur sous les trois : QEMU fournit la machine, KVM exécute], hauteur: px(48), taille: px(26))
  v(px(8))
  uncover("10-", encadre(role: "retenir", libelle: [À retenir :])[plus l’étage est haut, plus l’outil fait à notre place, et moins le mécanisme se voit. Incus ne passe pas par libvirt : il lance QEMU lui-même. Savoir lire une commande QEMU reste ce qui permet de comprendre les deux autres, et de les dépanner.])
  source[#link("https://www.qemu.org/docs/master/system/invocation.html")[qemu.org, options de qemu-system] · #link("https://www.qemu.org/docs/master/interop/qmp-spec.html")[QMP] · #link("https://libvirt.org/docs.html")[libvirt.org] · #link("https://github.com/virt-manager/virt-manager/blob/main/man/virt-install.rst")[virt-install(1)] · Incus 6.0.4 : #doc-incus("explanation/instances.md")[instances]]
  utils.speaker-note(self: self)[Corrigé du tableau qui termine le TP Incus : à projeter au retour du TP, pas avant, puisqu’il donne les réponses. Synthèse du fil suivi depuis le mini TP : la même VM Debian, créée de trois façons. Clic 1, la question seule ; puis une ligne par clic, et l’encadré ; « + » marque un atout, « − » une limite. Mécanisme : avec QEMU nu, la commande dit tout (mémoire, disque, réseau) ; libvirt garde une description XML par VM (virsh dumpxml) et lance QEMU ; Incus engendre la configuration de QEMU et le lance : ps sur l’hôte montre toujours un processus qemu-system-x86\_64. Images : QEMU part d’une ISO, ou d’une image cloud à qui l’on prépare soi-même un disque de configuration (cloud-localds) ; virt-install 5.0 démarre sur une image cloud téléchargée (--import) et engendre lui-même ce disque cloud-init (--cloud-init) ; Incus télécharge l’image prête depuis son catalogue. Réseau et stockage : -nic user et qemu-img au mini TP ; libvirt gère un réseau default (pont virbr0, NAT) et des pools de stockage ; Incus, incusbr0 et le pool default, appliqués par le profil default. Conteneurs : libvirt possède un pilote de conteneurs distinct (lxc:\/\/\/), peu employé ; en pratique il gère des VM. Automatisation : QEMU a sa propre API, QMP (QEMU Machine Protocol), du JSON sur une socket, une par VM lancée : libvirt et Incus pilotent QEMU par elle ; l’API de libvirt est une bibliothèque (liaisons Python, Go…) pilotée localement ou à travers ssh ; celle d’Incus est une API REST, que la commande incus utilise elle-même. Outils : Proxmox VE pilote QEMU directement ; OpenStack (Nova), oVirt (VDSM), Cockpit (cockpit-machines) et GNOME Boxes passent par libvirt ; Incus a surtout ses propres clients (commande incus, interface web). Graphique : incus console --type vga ouvre la console graphique d’une VM, mais Incus n’a pas d’équivalent de virt-manager sur le poste de travail. Droits : pour QEMU nu, le groupe kvm ne donne que /dev/kvm ; libvirt a deux modes : qemu:\/\/\/system, un démon root dont le groupe libvirt donne le contrôle, donc celui de l’hôte, et qemu:\/\/\/session, un démon lancé sous l’utilisateur (celui de GNOME Boxes), avec ses droits seulement et un réseau plus limité ; le groupe incus-admin donne le contrôle d’un démon root. Versions de Debian 13 : qemu-system-x86 10.0, libvirt-daemon-system 11.3.0, virt-manager 5.0.0, incus 6.0.4. Les outils des diapositives suivantes montent encore d’un étage : Proxmox VE et oVirt livrent une interface web d’administration, toujours sur KVM ; le cluster de plusieurs hôtes, Incus le sait aussi (diapositive « Incus : conteneurs et VM, un seul outil »).]
})

// ======================================================================
= Usages · Autres outils

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

// ======================================================================
= Pour aller plus loin

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

== Docker Sandboxes : une microVM par agent IA

#slide(repeat: 11, self => {
  let (uncover,) = utils.methods(self)
  // Schéma dans le vocabulaire de pile-archi : appli en bleu clair, invité en violet, gestion en tirets.
  let case(fond: c.appli, hauteur: px(52), corps) = block(width: 100%, height: hauteur, fill: fond, radius: px(8),
    inset: (x: px(6)), align(center + horizon, text(size: px(22), weight: 600, corps)))
  let tirets(corps) = block(width: 100%, stroke: (paint: c.gris, thickness: px(2), dash: "dashed"),
    radius: px(10), inset: (x: px(10), y: px(8)), align(center, text(size: px(20), fill: c.ardoise, corps)))
  let microvm(nom, cases, bas) = block(width: 100%, stroke: px(3) + c.invite, radius: px(12), inset: px(8), fill: c.fond,
    stack(spacing: px(8),
      align(center, text(fill: c.invite, size: px(22), weight: 600, nom)),
      cases,
      case(fond: c.invite-clair, hauteur: px(44), bas)))
  let schema = stack(spacing: px(8),
    block(width: 100%, fill: c.espace, radius: px(12), inset: (x: px(12), top: px(10), bottom: px(14)),
      stack(spacing: px(8),
        text(size: px(22), weight: 600, fill: c.gris)[Espace utilisateur de l’hôte],
        uncover("6-", grid(columns: (1fr, 1fr), column-gutter: px(12),
          tirets[*Proxy* : filtre le réseau sortant],
          tirets[*Dossier du projet* : partagé])),
        grid(columns: (3fr, 1fr), column-gutter: px(12),
          microvm([microVM 1],
            uncover("5-", grid(columns: (0.75fr, 1.5fr, 1.15fr), column-gutter: px(8),
              case[Agent 1], case[Docker Engine privé], case[Ses conteneurs])),
            [Noyau Linux invité]),
          microvm([microVM 2], case[Agent 2], [Noyau invité]),
        ),
      )),
    couche(hauteur: px(84), taille: px(26), stack(spacing: px(8), [Hyperviseur de l’hôte],
      text(size: px(20), weight: 400)[KVM (Linux) · Hypervisor.framework (macOS) · Windows Hypervisor Platform])),
    couche([Matériel], fond: c.ardoise, hauteur: px(52), taille: px(26)),
  )
  let besoin = bloc(taille: px(22), taille-titre: px(24))[Le besoin : isoler un agent IA][
    - Un *agent IA de programmation* : un programme piloté par un modèle de langage, qui lance des commandes et modifie des fichiers de lui-même (Claude Code, Codex…)
    - Le besoin : lui laisser lancer Docker sans lui donner la machine
    - *Docker Sandboxes* (30 janvier 2026, Docker Desktop 4.58) : un *bac à sable* (_sandbox_) par agent, dans une microVM ; avril 2026 : l’outil autonome `sbx` (cours Conteneurisation)
  ]
  let concurrents = bloc(role: "pratique", taille: px(22), taille-titre: px(24))[Les concurrents, par technique d’isolation][
    - *MicroVM* : E2B, Vercel Sandbox (dans le cloud de l’éditeur, sur Firecracker) ; `container` d’Apple (local, macOS)
    - *Noyau en espace utilisateur* : Agent Sandbox de Kubernetes, sur gVisor (ou sur Kata Containers, une microVM)
    - *Filtrage par le noyau de l’hôte* : `sandbox-runtime` d’Anthropic
    - *Conteneur*, noyau partagé : `container-use` de Dagger
  ]
  grid(columns: (1fr, 1fr), column-gutter: px(32),
    stack(spacing: px(20), bloc-anime(besoin, 1, uncover), bloc-anime(concurrents, 7, uncover)),
    stack(spacing: px(16),
      uncover("4-", schema),
      uncover("5-", text(size: px(22), fill: c.ardoise)[Des conteneurs dans une microVM ; la machine est fournie par un programme de Docker, pas par Firecracker.]),
      uncover("11-", encadre(role: "retenir", libelle: [À retenir :])[la microVM seule ne distingue pas Docker Sandboxes (E2B et Vercel Sandbox en ont une) ; ses atouts : local sur macOS, Windows et Linux, un Docker Engine privé par agent.]),
    ),
  )
  source[#link("https://docs.docker.com/ai/sandboxes/")[docs.docker.com/ai/sandboxes] · #link("https://docs.docker.com/ai/sandboxes/architecture/")[architecture] · #link("https://docs.docker.com/ai/sandboxes/security/isolation/")[isolation] · #link("https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/")[docker.com/blog, 30/01/2026]]
  utils.speaker-note(self: self)[Lu le 25 novembre 2026 : documentation docs.docker.com/ai/sandboxes (pages Get started, Install, Architecture, Isolation), notes de version de Docker Desktop, billets du blog de Docker. Chronologie : Docker Desktop 4.58.0 (26 janvier 2026) introduit la nouvelle version de Docker Sandboxes, fondée sur des microVM (commande expérimentale docker sandbox) ; billet d’annonce du 30 janvier 2026 (macOS et Windows, Linux annoncé pour la suite) ; 16 avril 2026 : billet d’architecture (docker.com/blog, why-microvms) et outil autonome sbx, pour macOS, Windows et Linux ; Docker Desktop 4.80.0 (29 juin 2026) retire le plugin docker sandbox au profit de sbx ; 24 septembre 2026 : Cloud Sandboxes, la même microVM sur des machines gérées par Docker (payant). Dernière version stable de sbx au 25 novembre 2026 : 0.54.1 (24 novembre), toujours en 0.x. sbx est propriétaire, gratuit y compris en usage commercial ; un compte Docker est obligatoire ; ni Docker Desktop ni Docker Engine ne sont requis sur l’hôte. Hyperviseur : KVM sous Linux, Hypervisor.framework sous macOS (Apple silicon), Windows Hypervisor Platform sous Windows 11. Le programme qui fournit la machine (VMM, virtual machine monitor, le rôle de QEMU) est écrit par Docker, « purpose-built » : ce n’est pas Firecracker. Des conteneurs dans une VM ne sont pas de la virtualisation imbriquée (une VM dans une VM) ; celle-ci n’intervient que si l’on lance sbx depuis une VM. Dans la microVM : l’agent (utilisateur non root, avec sudo) et un Docker Engine privé, à qui s’adressent docker build et docker compose up ; aucun chemin vers le démon Docker de l’hôte, aucun socket de l’hôte monté ; chaque bac à sable a son démon et son cache d’images, rien n’est partagé entre bacs à sable. Dossier du projet : monté par virtiofs, en lecture-écriture, au même chemin absolu que sur l’hôte ; c’est la seule partie de la machine que l’agent voit. Limite dite par la doc : l’agent peut y lire, modifier et supprimer tout, hooks Git compris ; l’option --clone monte le dépôt en lecture seule et fait travailler l’agent sur un clone privé. Réseau : tout le trafic TCP sortant passe par un proxy sur l’hôte, qui applique la politique réseau ; par défaut tout est refusé sauf règle explicite (préréglage Balanced : services de développement courants) ; UDP désactivé, ICMP bloqué. Le proxy injecte aussi les identifiants dans les en-têtes HTTP : l’agent n’en lit pas la valeur. Surcoût : une VM plus son démon. La doc compare avec un conteneur à socket monté (démon de l’hôte partagé), Docker-in-Docker (conteneur privilégié) et l’exécution directe (aucune isolation). Concurrents, lus sur les dépôts GitHub des éditeurs : E2B, microVM Firecracker, hébergé ou auto-hébergeable, Apache-2.0 (github.com/e2b-dev/infra) ; Vercel Sandbox, microVM Firecracker, hébergé (github.com/vercel/sandbox) ; container d’Apple, macOS 26 sur Apple silicon, chaque conteneur Linux dans une VM légère, Apache-2.0 (github.com/apple/container) ; microsandbox, microVM locale, Apache-2.0 (github.com/zerocore-ai/microsandbox) ; Agent Sandbox, Kubernetes SIG Apps, à l’initiative de Google : des pods sur gVisor ou sur Kata Containers (github.com/kubernetes-sigs/agent-sandbox) ; sandbox-runtime d’Anthropic, le bac à sable de Claude Code : bubblewrap et seccomp sous Linux, Seatbelt (sandbox-exec) sous macOS, proxy réseau à liste de domaines, Apache-2.0 (github.com/anthropic-experimental/sandbox-runtime) ; Gemini CLI, au choix Seatbelt, conteneur Docker ou Podman, gVisor (github.com/google-gemini/gemini-cli) ; Cloudflare Sandbox SDK, conteneur hébergé (github.com/cloudflare/sandbox-sdk) ; container-use de Dagger, un conteneur et une branche Git par agent (github.com/dagger/container-use). Ce qui distingue Docker Sandboxes : local sur les trois OS, VMM maison, Docker Engine privé dans la microVM, identifiants gardés hors de la VM. Mise en place (installation, sbx login, sbx run, politique réseau) : cours Conteneurisation.]
})

== VM et conteneurs : deux façons d’isoler <vm-et-conteneurs>

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
    - Incus : conteneurs système et VM sous une même commande ; la configuration s’hérite des profils
    - QEMU nu, libvirt, Incus : trois étages sur le même moteur ; plus l’outil automatise, moins le mécanisme se voit
    - MicroVM et conteneurs isolent plus légèrement : machine minimale pour l’une, noyau partagé pour les autres
    - Docker Sandboxes : une microVM par agent IA, avec son propre Docker Engine
  ]),
  note: [Récapitulatif, une idée par clic, dans l’ordre du cours.],
)

#cloture(illustration: "vm")[Merci][Des questions ?][Jean-Mathieu Chantrein][Supports : github.com/jmchantrein/cours]
#speaker-note[Page de clôture, dans le même design que la couverture.]
