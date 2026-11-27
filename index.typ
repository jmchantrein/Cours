// Page d’accueil du site des cours — compilée en index.html par la CI.
//   typst compile --root . --font-path commun/fonts --features html --format html index.typ index.html

#import "commun/theme-tp.typ": *

#show: page-web.with(
  titre: [Cours],
  surtitre: [Cours],
  sous-titre: [Diapositives, travaux pratiques et artefacts interactifs],
  auteur: [Jean-Mathieu Chantrein],
  racine: "",
  sommaire: false,
  liens: (([Sources], depot),),
)

// Les diapos d’un cours : le rendu de projection en bouton, les rendus adaptés en liens.
#let pdf(cours, v) = cours + "/cm/" + cours + "-" + v + ".pdf"
#let rendus(cours) = html.elem("p", attrs: (class: "variantes"))[
  Diapositives en rendu adapté :
  #variantes.filter(v => v != "projection").map(v => link(pdf(cours, v), v)).join([, ]).
]

// Les cours se lisent dans l’ordre de la page, du plus fondamental au plus avancé : chaque groupe s’appuie
// sur le précédent.
Sept cours, à lire dans l’ordre de la page : les outils de l’administrateur d’abord, puis les machines
(accès, virtualisation, conteneurs), enfin l’automatisation, qui les suppose tous.

= Les outils de l’administrateur

#cartes(
  {
    // Le cours shell : sa page, tirée de son index, mène à ses modules ; deux liens directs vers son début.
    let index = yaml("shell/progression.yaml")
    let premier = module-de(index, index.modules.sorted(key: m => m.ordre).first().id)
    carte([#index.titre], illustration: "tube")[
      Une suite de modules, du premier terminal ouvert aux scripts robustes, à sed et à awk ; chacun tient pour
      acquis les précédents.
      #actions(
        bouton(principal: true, [Parcourir le cours, module par module], "shell/index.html"),
        bouton([Module #premier.numero : #premier.titre], "shell/pages/" + premier.id + "/"),
        bouton([TP : Premiers pas dans le shell], "shell/tp/premiers-pas/"),
      )
    ]
  },
  carte([Éditer et structurer du texte], illustration: "texte")[
    Vim, Markdown, YAML et JSON : l’administrateur travaille en texte brut.
    #actions(
      bouton(principal: true, [Diapositives], pdf("edition-formats", "projection")),
      bouton([TP : Dojo Vim], "edition-formats/tp/vim/"),
      bouton([TP : Décrire des livres en YAML et en JSON], "edition-formats/tp/yaml-json/"),
      bouton([Artefact : Le typage des scalaires YAML], "edition-formats/artefacts/typage-yaml/"),
    )
    #rendus("edition-formats")
  ],
  carte([Git : versionner et collaborer], illustration: "graphe")[
    Commits, branches, conflits, retour en arrière, puis le travail à plusieurs autour d’un dépôt central.
    #actions(
      bouton(principal: true, [Diapositives], pdf("git", "projection")),
      bouton([TP : Git en local], "git/tp/git-local/"),
      bouton([TP : Git à plusieurs, sans forge], "git/tp/git-distant/"),
      bouton([Artefact : Le graphe des commits], "git/artefacts/graphe-git/"),
    )
    #rendus("git")
  ],
)

= Les machines : accès, virtualisation, conteneurs

#cartes(
  carte([Accès distants : SSH, tmux, WireGuard], illustration: "tunnel")[
    Entrer sur une machine sans mot de passe, y travailler dans des sessions qui survivent à la coupure, relier
    deux réseaux par un tunnel chiffré.
    #actions(
      bouton(principal: true, [Diapositives], pdf("acces-distants", "projection")),
      bouton([TP : SSH : clés, bastion, tunnel, durcissement], "acces-distants/tp/ssh/"),
      bouton([TP : Travailler dans tmux], "acces-distants/tp/tmux/"),
      bouton([TP : Un tunnel WireGuard], "acces-distants/tp/wireguard/"),
    )
    #rendus("acces-distants")
  ],
  carte([Fondements de la virtualisation de machines], illustration: "vm")[
    Émulation et virtualisation, assistance matérielle, hyperviseurs, QEMU et KVM, libvirt, avec un mini TP :
    une VM, puis une VM dans la VM.
    #actions(
      bouton(principal: true, [Diapositives], pdf("virtualisation", "projection")),
      bouton([TP : Administrer des VM avec libvirt], "virtualisation/tp/libvirt/"),
      bouton([Artefact : La chaîne d’images qcow2], "virtualisation/artefacts/chaine-qcow2/"),
    )
    #rendus("virtualisation")
  ],
  carte([Fondements de la conteneurisation], illustration: "couches")[
    Du chroot à Docker : images, conteneurs, persistance, sécurité, réseau, Dockerfile, Compose, puis les
    orchestrateurs.
    #actions(
      bouton(principal: true, [Diapositives], pdf("conteneurisation", "projection")),
      bouton([TP : Conteneuriser WordPress], "conteneurisation/tp/wordpress/"),
      bouton([Artefact : Le cache de build], "conteneurisation/artefacts/cache-de-build/"),
      bouton([Artefact : CMD × ENTRYPOINT], "conteneurisation/artefacts/cmd-entrypoint/"),
    )
    #rendus("conteneurisation")
  ],
)

= Automatiser

#cartes(
  carte([Ansible : automatiser les configurations], illustration: "noeuds")[
    Un nœud de contrôle, des nœuds gérés : inventaire, playbooks, idempotence et rôles.
    #actions(
      bouton(principal: true, [Diapositives], pdf("ansible", "projection")),
      bouton([TP, séance 1 : inventaire et commandes ad hoc], "ansible/tp/inventaire/"),
      bouton([TP, séance 2 : playbooks, variables et idempotence], "ansible/tp/playbooks/"),
      bouton([TP, séance 3 : un rôle, nginx_hello_world], "ansible/tp/roles/"),
      bouton([Artefact : Quelle valeur gagne ?], "ansible/artefacts/precedence-variables/"),
    )
    #rendus("ansible")
  ],
)

#note(role: "notion")[Le menu *Accessibilité*, en haut de chaque page, propose les rendus adaptés des
  diapositives : palettes pour les daltonismes et l’achromatopsie, mise en page pour la dyslexie. Votre choix
  est mémorisé.]
