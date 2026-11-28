// Page « host-shell-access » : relier les pages de TP au vrai shell de l’étudiant, par le programme host-shell-access.
// La CI la compile en commun/terminal/host-shell-access/index.html ; les pages à terminal y renvoient.
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     commun/terminal/host-shell-access/host-shell-access.typ commun/terminal/host-shell-access/index.html

#import "../../theme-tp.typ": *

#show: page-web.with(
  titre: [host-shell-access : relier la page à votre shell],
  surtitre: [Pages de travaux pratiques · terminal],
  sous-titre: [Exécuter les commandes d’une page dans votre vrai shell, d’un clic],
  auteur: [Jean-Mathieu Chantrein],
  racine: "../../../",
  terminal: ("host-shell-access",),
  liens: (
    ([Code de `host-shell-access`], "https://github.com/jmchantrein/Cours/tree/main/commun/terminal/host-shell-access"),
    ([Licences], "https://github.com/jmchantrein/Cours/blob/main/commun/terminal/LICENCES.md"),
  ),
)

= Ce que fait `host-shell-access` <principe>

Les pages de TP proposent un bouton « Exécuter » à côté de chaque commande. Avec `host-shell-access`, un clic envoie
la commande à votre propre shell, qui l’exécute. `host-shell-access` est un petit programme, un seul fichier à
télécharger, qui tourne sur l’ordinateur où s’ouvre votre navigateur : il ouvre votre shell et le relie à la page.

#bloc(role: "danger")[Un clic lance la commande dans votre vrai shell][
  - La commande s’exécute sur votre machine, avec vos droits et sur vos fichiers, comme si vous l’aviez tapée.
  - Certaines commandes des TP suppriment des conteneurs, des volumes ou des VM : lisez chaque commande avant de
    cliquer.
  - Dans le doute, copiez la commande (bouton « Copier ») et tapez-la vous-même.
]

#bloc(role: "pratique")[Ce qui protège votre shell][
  - `host-shell-access` n’écoute que sur votre machine (`127.0.0.1`) : aucun autre ordinateur ne peut le joindre.
  - Il affiche une adresse qui porte un jeton tiré au hasard, valable pour une seule connexion.
  - Il n’accepte que les pages du site des cours (`https://jmchantrein.github.io`), et un seul client à la fois.
  - Il s’arrête quand la page se ferme, ou dès qu’une connexion est refusée.
]

#note(role: "precaution")[Toutes les pages publiées sous `jmchantrein.github.io` partagent la même origine. Ne
  collez l’adresse de `host-shell-access` que dans la page du cours que vous suivez.]

= Télécharger `host-shell-access` <installer>

Une commande le télécharge dans le dossier courant et le rend exécutable ; rien d’autre n’est installé.
`host-shell-access` fonctionne sous Linux (dont WSL sous Windows) ; choisissez la commande de votre processeur
(`uname -m` l’affiche) :

#let base = "https://jmchantrein.github.io/Cours/commun/terminal/host-shell-access/dist/"
#let telecharger(cible) = raw("$ curl -fLo host-shell-access " + base + "host-shell-access-" + cible + " && chmod +x host-shell-access", lang: "console", block: true)

#table(columns: 2,
  [*Système*], [*Commande*],
  [Linux x86_64, et WSL sous Windows], terminal(telecharger("linux-amd64")),
  [Linux arm64 (aarch64)], terminal(telecharger("linux-arm64")),
)

#indice(titre: [Vérifier la somme SHA-256 du fichier téléchargé])[
  Le site publie la somme de chaque exécutable dans
  #link(base + "SHA256SUMS")[`SHA256SUMS`]. Comparez la ligne de votre système avec la somme du fichier :
  #terminal[```console
  $ curl -fsSL https://jmchantrein.github.io/Cours/commun/terminal/host-shell-access/dist/SHA256SUMS | grep linux-amd64
  $ sha256sum host-shell-access
  ```]
  Les deux sommes doivent être identiques ; sinon, supprimez le fichier et signalez-le.
]

= Relier une page à votre shell <connecter>

+ Dans un terminal, lancez `host-shell-access`. Il affiche l’adresse à coller dans la page :
  #terminal[```console
  $ ./host-shell-access local
  # Adresse à coller dans la page :
  # ws://localhost:41234/?token=…
  ```]
+ Dans la page du TP, ouvrez « Terminal », en haut à droite du bandeau, collez l’adresse, puis « Connecter ».
+ Le navigateur peut demander l’autorisation d’accéder aux appareils de votre réseau local : acceptez. C’est
  ainsi que la page joint `host-shell-access`, sur votre machine.
+ Cliquez sur « Exécuter » à côté d’une commande : elle s’exécute dans votre shell, et sa sortie s’affiche dans
  le terminal de la page.

Essayez ici, une fois `host-shell-access` connecté :

#terminal[```console
$ echo "Bonjour depuis $(hostname)"
$ pwd
```]

#note(role: "pratique")[Chaque adresse ne sert qu’une fois : après avoir fermé ou rechargé la page, relancez
  `./host-shell-access local` et collez la nouvelle adresse.]

= Travailler sur une machine distante <ssh>

`host-shell-access` peut aussi lancer votre client `ssh` : les commandes cliquées s’exécutent alors sur la machine
distante. `host-shell-access` reste sur votre ordinateur ; vos clés et votre `~/.ssh/config` servent comme d’habitude.

#terminal[```console
$ ./host-shell-access ssh utilisateur@machine
```]

= Si la connexion échoue <depannage>

- « Connexion impossible » : `host-shell-access` s’est arrêté (adresse déjà utilisée, page rechargée). Relancez-le.
- Le navigateur a refusé l’accès au réseau local : rétablissez-le dans les paramètres du site (l’icône à gauche de
  l’adresse de la page), puis reconnectez.
- `host-shell-access` affiche « Connexion refusée » : l’adresse collée est incomplète, ou la page n’est pas celle du site
  des cours.
- Navigateur vérifié : Chromium (et donc Chrome). Les autres navigateurs n’ont pas encore été essayés.

Pour désinstaller `host-shell-access`, supprimez le fichier `host-shell-access`.
