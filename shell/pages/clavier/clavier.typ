// Page de cours du module « Le clavier du shell » (shell/progression.yaml, module clavier) : la page où l’étudiant
// tape. Presque rien ne s’y clique : chaque geste dit ce qu’on tape, les touches, et ce qu’on doit voir ; « Écrire »
// dépose les lignes longues à l’invite, sur lesquelles on joue les touches. Voir commun/README.md, « Pages de cours ».
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     shell/pages/clavier/clavier.typ shell/pages/clavier/index.html
// Les gestes sont ceux du diaporama du module (shell/cm/clavier.typ), dans le même ordre, relevés touche par touche
// (shell/cm/rejouer-clavier.sh) ; commun/terminal/tester-vm.mjs rejoue chaque geste dans la VM, depuis l’état de
// départ, et compare la ligne, le curseur, l’écran et la sortie à ce que la page annonce.
// Différence voulue avec les diapos : Ctrl+W ferme l’onglet du navigateur ; la page fait jouer Alt+Retour arrière.

#import "../../../commun/theme-tp.typ": *

#let diaporama = "../../cm/clavier-projection.pdf"
#let index = yaml("../../progression.yaml")
#let ici = module-de(index, "clavier")
#let mod(id) = module-de(index, id)
#let vers(id) = "../../index.html#" + id
#let kj = "echo Katherine Johnson calcule la trajectoire"
#let hl = "echo Hedy Lamarr brevette un signal radio secret"

#show: page-web.with(
  titre: [#ici.titre],
  surtitre: [#index.titre · module #ici.numero · page de cours],
  sous-titre: [Compléter, retrouver, corriger une ligne sans la retaper],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tube",
  cours: true,
  terminal: ("vm", "host-shell-access"),
  depart: (script: "shell/tp/premiers-pas/preparer.sh", cree: "~/atelier", ici: "~"),
  liens: (
    ([Le cours], "../../index.html"),
    ([Diaporama du module], diaporama),
    ([Module suivant : #mod(ici.suivant).titre], vers(ici.suivant)),
  ),
)

= Avant de commencer <avant>

Cette page se joue au clavier : cliquez dans le terminal, à droite, puis tapez. Chaque geste dit ce qu’il faut taper,
les touches, et ce que le terminal doit montrer (le curseur en bloc clair) ; faites-les dans l’ordre, sans Entrée
sauf quand elle est écrite. Les lignes longues ont un bouton *Écrire*, qui les dépose à l’invite sans les valider.

#bloc(role: "question")[Ce que vous savez déjà][
  #let q = index.modules.find(m => m.id == "clavier").at("ouverture", default: ()).at(0, default: none)
  #if q != none [
    #eval(q.question, mode: "markup")
    #corrige(titre: [Réponse])[Une hésitation ? C’est le #nom-module(index, q.renvoi) :
      #link(vers(q.renvoi))[ses supports].]
  ]
]

#note(role: "precaution")[Dans le navigateur, #touche[Ctrl+W] ferme l’onglet : la page fait jouer
#touche[Alt+Retour arrière], qui coupe aussi le mot avant le curseur. Si l’onglet se ferme malgré tout, le navigateur
demande d’abord confirmation tant que le terminal tourne.]

= Compléter : Tab <completer>

#geste(tape: "whoa", touches: ("Tab",), ligne: "whoami ")[
  #regardez[Un seul nom de commande commence par `whoa` : #touche[Tab] l’achève, avec une espace.]
]
#geste(touches: ("Entrée",), sortie: "ada")[]
#geste(tape: "who", touches: ("Tab",), ligne: "who")[
  #regardez[Rien ne change : trois noms commencent par `who`, #touche[Tab] ne choisit pas.]
]
#geste(touches: ("Tab",), ecran: "who     whoami  whois", ligne: "who")[
  #regardez[Le second #touche[Tab] les montre, puis réaffiche la ligne.]
]
#geste(touches: ("Retour arrière", "Retour arrière", "Retour arrière"), ligne: "")[]
#geste(tape: "ls", touches: ("Entrée",), sortie: "atelier")[
  #regardez[Un nom de fichier se complète aussi : `ls` d’abord, pour voir ce qu’il y a.]
]
#geste(tape: "ls at", touches: ("Tab",), ligne: "ls atelier/")[
  #regardez[Le `/` final dit que `atelier` est un répertoire.]
]
#geste(touches: ("Entrée",), sortie: "journaux  notes  pionnieres.csv  projets  vieux")[]
#geste(tape: "date --ut", touches: ("Tab",), ligne: "date --utc ")[
  #regardez[Une option longue se complète : `--utc`, la forme longue de `-u`.]
]
#geste(touches: ("Entrée",))[
  #regardez[La date en UTC, par exemple `Fri Nov 27 23:18:28 UTC 2026` : la vôtre, à l’heure où vous tapez.]
]

= Retrouver : flèches, Ctrl+R, history <retrouver>

#geste(touches: ("↑",), ligne: "date --utc ")[
  #regardez[La ligne précédente revient, prête à relancer ou à corriger (avec l’espace que #touche[Tab] avait
  ajoutée).]
]
#geste(touches: ("↑",), ligne: "ls atelier/")[]
#geste(touches: ("↓", "↓"), ligne: "")[
  #regardez[#touche[↓] redescend, jusqu’à la ligne vide.]
]
#geste(touches: ("Ctrl+R", "w", "h"), voir: "(reverse-i-search)`wh': whoami", ligne: "whoami ", point: 0)[
  #regardez[La dernière ligne qui contient `wh`. #touche[Ctrl+R] encore : celle d’avant ; #touche[Ctrl+C] abandonne.]
]
#geste(touches: ("Entrée",), sortie: "ada")[]
#geste(tape: "history", touches: ("Entrée",), sortie: "    1  whoami\n    2  ls\n    3  ls atelier/\n    4  date --utc\n    5  whoami\n    6  history")[
  #regardez[Les lignes tapées, numérotées, de la plus ancienne à la plus récente.]
]

= Se déplacer dans la ligne <deplacer>

Katherine Johnson (1918-2020), mathématicienne de la NASA, calcule les trajectoires des premiers vols habités
américains : Alan Shepard en 1961, John Glenn en 1962.

#geste(ecrire: kj, touches: ("Ctrl+A",), ligne: kj, point: 0)[
  #regardez[#touche[Ctrl+A] : au début de la ligne.]
]
#geste(touches: ("Ctrl+E",), ligne: kj)[#regardez[#touche[Ctrl+E] : au bout.]]
#geste(touches: ("Ctrl+←",), ligne: kj, point: 34)[#regardez[#touche[Ctrl+←] : un mot en arrière, sur le `t` de `trajectoire`.]]
#geste(touches: ("Ctrl+←",), ligne: kj, point: 31)[#regardez[Encore : sur le `l` de `la`.]]
#geste(touches: ("Ctrl+→",), ligne: kj, point: 33)[#regardez[#touche[Ctrl+→] : un mot en avant, sur l’espace après `la`.]]

= Effacer et recoller <effacer>

#geste(touches: ("Ctrl+E", "Alt+Retour arrière"), ligne: "echo Katherine Johnson calcule la ")[
  #regardez[Le mot avant le curseur est coupé (#touche[Ctrl+W] dans un vrai terminal).]
]
#geste(touches: ("Ctrl+Y",), ligne: kj)[#regardez[#touche[Ctrl+Y] recolle la dernière coupe.]]
#geste(touches: ("Ctrl+←", "Ctrl+←", "Ctrl+K"), ligne: "echo Katherine Johnson calcule ")[
  #regardez[#touche[Ctrl+K] coupe du curseur à la fin.]
]
#geste(touches: ("Ctrl+Y",), ligne: kj)[]
#geste(touches: ("Ctrl+←", "Ctrl+←", "Ctrl+U"), ligne: "la trajectoire", point: 0)[
  #regardez[#touche[Ctrl+U] coupe du début au curseur.]
]

= L’écran et la session <session>

#geste(touches: ("Ctrl+L",), ligne: "la trajectoire", point: 0)[
  #regardez[L’écran se vide ; la ligne en cours reste, en haut.]
]
#geste(touches: ("Ctrl+E", "Ctrl+C"), ecran: "la trajectoire^C", ligne: "")[
  #regardez[#touche[Ctrl+C] abandonne la ligne : une invite vide revient.]
]
#geste(tape: "cat", touches: ("Entrée", "Ada", "Entrée", "Ctrl+D"), sortie: "Ada\nAda")[
  #regardez[`cat` attend ce que vous tapez et le recopie ; #touche[Ctrl+D] lui dit que la saisie est finie.]
]
#geste(touches: ("Ctrl+D",), ecran: "Session terminée ; nouvelle session.")[
  #regardez[Sur une ligne vide, #touche[Ctrl+D] ferme le shell. Ici, une nouvelle session s’ouvre aussitôt, dans le
  répertoire personnel, comme un terminal qu’on rouvre ; vos fichiers restent.]
]

= À vous : où est le curseur ? que reste-t-il ? <exercice>

Hedy Lamarr (1914-2000), actrice, brevette en 1942 avec George Antheil un système de communication secrète par saut
de fréquence, un principe qu’emploie aujourd’hui le Bluetooth. Le curseur au bout de la ligne, prédisez, touche après
touche :

#predire[#touche[Alt+Retour arrière] : que reste-t-il de la ligne ?][
  #geste(ecrire: hl, touches: ("Alt+Retour arrière",), ligne: "echo Hedy Lamarr brevette un signal radio ")[]
][`secret` est coupé.]
#predire[#touche[Ctrl+A] : où est le curseur ?][
  #geste(touches: ("Ctrl+A",), ligne: "echo Hedy Lamarr brevette un signal radio ", point: 0)[]
][Au début, sur le `e` de `echo`.]
#predire[#touche[Ctrl+→] : où est-il ?][
  #geste(touches: ("Ctrl+→",), ligne: "echo Hedy Lamarr brevette un signal radio ", point: 4)[]
][Sur l’espace après `echo`.]
#predire[#touche[Ctrl+K] : que reste-t-il ?][
  #geste(touches: ("Ctrl+K",), ligne: "echo")[]
][`echo` seul : tout ce qui suivait le curseur est coupé.]
#predire[#touche[Ctrl+Y], puis #touche[Entrée] : qu’affiche `echo` ?][
  #geste(touches: ("Ctrl+Y", "Entrée"), sortie: "Hedy Lamarr brevette un signal radio")[]
][#touche[Ctrl+Y] recolle la dernière coupe : `secret` est perdu.]

= Pour la suite <suite>

#bloc(role: "retenir")[À retenir][
  #table(columns: (auto, 1fr),
    [*Touche*], [*Effet*],
    [#touche[Tab], #touche[Tab] #touche[Tab]], [compléter ; voir les possibilités],
    [#touche[↑] #touche[↓], #touche[Ctrl+R]], [retrouver une ligne ; la chercher],
    [#touche[Ctrl+A] #touche[Ctrl+E]], [début, fin de la ligne],
    [#touche[Ctrl+←] #touche[Ctrl+→]], [un mot en arrière, en avant],
    [#touche[Ctrl+W] (ici #touche[Alt+Retour arrière]), #touche[Ctrl+K], #touche[Ctrl+U]], [couper le mot avant, jusqu’à la fin, depuis le début],
    [#touche[Ctrl+Y]], [recoller la dernière coupe],
    [#touche[Ctrl+L], #touche[Ctrl+C], #touche[Ctrl+D]], [vider l’écran ; abandonner ; fin de saisie, ou fermer le shell],
  )
]

#bloc(role: "pratique")[Ensuite][
  - Le #link(diaporama)[diaporama du module].
  - Module suivant : #link(vers(ici.suivant))[#mod(ici.suivant).titre] ; tous les modules : #link("../../index.html")[le cours].
]
