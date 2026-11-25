// TP « Un tunnel WireGuard » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     acces-distants/tp/wireguard/wireguard.typ build/wireguard.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/acces-distants-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin, lang: auto) = fichier("corrige/" + chemin, read("corrige/" + chemin), lang: lang)
// Fichier du labo.
#let l(chemin) = fichier("labo/" + chemin, read("labo/" + chemin))

#show: page-web.with(
  titre: [Un tunnel WireGuard],
  surtitre: [Accès distants · travaux pratiques],
  sous-titre: [Deux machines, deux configurations, une poignée de main ; puis le rôle d’AllowedIPs et un troisième pair],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "tunnel",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/acces-distants/tp/wireguard/corrige"),
    ([Démarrage rapide de WireGuard], "https://www.wireguard.com/quickstart/"),
  ),
)

= Avant de commencer <avant>

Un VPN relie des réseaux comme s’ils étaient branchés l’un à l’autre : #d("wireguard-modele")[Le modèle : des pairs, des clés,
une interface]. Vous montez ici un tunnel entre deux machines, vous regardez ce qu’il laisse voir sur le réseau,
vous mettez `AllowedIPs` à l’épreuve, puis vous ajoutez un troisième pair.

#bloc(role: "pratique")[Prérequis][
  - Docker avec le plugin Compose v2, et un accès au réseau (l’image Debian et ses paquets se téléchargent).
  - Un système où les conteneurs peuvent créer une interface réseau : le labo demande la capacité `NET_ADMIN`
    et le périphérique `/dev/net/tun`, et il est lancé sur *votre* machine, pas sur un hébergement partagé qui les refuse.
  - Le labo (dossier #link("https://github.com/jmchantrein/Cours/tree/main/acces-distants/tp/wireguard/labo")[`labo/`] : un
    `Dockerfile` et un `compose.yaml`) et les corrigés (dossier `corrige/`, à n’ouvrir qu’une fois l’étape faite) :
    la commande ci-dessous les extrait de l’archive du dépôt des cours, dans `~/tp-wireguard`.
  - Trois terminaux ouverts dans `~/tp-wireguard/labo` : un par pair. Toutes les commandes `docker compose` du TP
    se tapent depuis ce dossier.
]

#terminal[```console
$ mkdir -p ~/tp-wireguard && cd ~/tp-wireguard
$ curl -fsSL https://github.com/jmchantrein/Cours/archive/refs/heads/main.tar.gz | tar -xz --strip-components=4 Cours-main/acces-distants/tp/wireguard/labo Cours-main/acces-distants/tp/wireguard/corrige
$ cd labo
```]

#bloc(role: "precaution")[Un labo, pas une architecture][
  Trois conteneurs *jetables* avec `NET_ADMIN` jouent trois machines sur un réseau ordinaire, le réseau
  « porteur » `172.20.0.0/24` ; les adresses `10.9.9.x` n’existent que dans le tunnel. En production, donner
  `NET_ADMIN` à un conteneur est un privilège à justifier. WireGuard est dans le noyau Linux depuis la version 5.6 :
  si le module manque sur votre machine, `wg-quick` le dit (« Falling back to slow userspace implementation ») et se
  rabat sur `wireguard-go`, la même chose en espace utilisateur, plus lente ; les commandes du TP ne changent pas.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Les corrigés sont des fichiers réels, rejoués à
  chaque modification dans un labo neuf : les clés, les deux configurations, `wg-quick up`, le ping, la
  poignée de main, la capture du réseau porteur, les deux cas d’`AllowedIPs`, le troisième pair et le relais. Les
  configurations du corrigé portent des chevrons `<clé privée de pair-a>` : ce sont les clés *de votre labo*, que
  vous lisez dans `/etc/wireguard`, et que vous écrivez à leur place.
]

#schema([Le labo : trois pairs sur le réseau porteur ; les adresses 10.9.9.x vivent dans le tunnel.], ch => {
  let c = ch.c
  let pair(nom, ext, tun) = case(fond: c.invite-clair, largeur: 130pt, [*#nom* \ #text(size: 8.5pt)[eth0 : #ext \ wg0 : #tun]])
  boite([Réseau porteur `172.20.0.0/24`], trait: c.gris, tirets: "dashed", grid(columns: 3, column-gutter: 14pt,
    pair[pair-a][172.20.0.2][10.9.9.1],
    pair[pair-b][172.20.0.3][10.9.9.2],
    pair[pair-c][172.20.0.4][10.9.9.3],
  ))
})

= Étape 1 : monter le labo <etape-1>

#bloc(role: "question")[Consignes][
  - Construisez l’image et démarrez les trois pairs.
  - Ouvrez un shell *root* dans chacun, dans trois terminaux. Quelles adresses portent leurs interfaces ?
  - Votre noyau offre-t-il WireGuard ? Comment le savoir sans configurer quoi que ce soit ?
]

#indice(titre: [Indice : la capacité et le module])[
  `docker compose up -d --build` dans `labo/`, puis `docker compose exec pair-a bash` (et `pair-b`, `pair-c`).
  Créer une interface de type `wireguard` réussit si le noyau a le module : `ip link add essai type wireguard`,
  puis `ip link del essai`.
]

#corrige[
  #terminal[```console
  $ docker compose up -d --build
  $ docker compose exec pair-a bash
  # dans le pair :
  $ hostname -I
  172.20.0.2
  $ ip link add essai type wireguard && ip link del essai
  ```]
  Les adresses sont `172.20.0.2`, `.3` et `.4`. Si `ip link add` répond `Error: Unknown device type.`, votre noyau
  n’a pas le module : `wg-quick` utilisera `wireguard-go`. (`Operation not permitted` signalerait plutôt une
  capacité `NET_ADMIN` absente : le conteneur n’a pas été lancé par ce `compose.yaml`.) Le labo :
  #l("compose.yaml") #l("Dockerfile")
  `cap_add: [NET_ADMIN]` permet de créer l’interface, `/dev/net/tun` sert au repli en espace utilisateur, et
  `pair-a` relaiera des paquets à l’étape 7 (`ip_forward`).
]

= Étape 2 : une paire de clés par pair <etape-2>

#bloc(role: "question")[Consignes][
  - Sur chaque pair, en root, créez une paire de clés dans `/etc/wireguard`, lisible par root seul.
  - Quels fichiers, quels droits ? Laquelle des deux clés se communique aux autres pairs ?
  - Notez les trois clés publiques : vous en aurez besoin à l’étape 3.
]

#indice(titre: [Indice : genkey et pubkey])[
  #d("wireguard-cles")[Générer les clés : wg genkey, wg pubkey] : `wg genkey` produit la clé privée, `wg pubkey` en calcule la
  clé publique. `umask 077` fait créer des fichiers en `600`. `tee` écrit la clé privée dans un fichier et la
  passe à `wg pubkey`.
]

#corrige[
  #f("generer-cles.sh")
  #terminal[```console
  # sur votre machine, dans ~/tp-wireguard/labo : copier le script (dans ../corrige), le lancer
  $ for p in pair-a pair-b pair-c; do docker compose cp ../corrige/generer-cles.sh "$p:/usr/local/bin/"; docker compose exec "$p" generer-cles.sh; done
  ```]
  `prive.key` et `public.key` sont en `rw-------` (600), à root. La clé publique se donne aux autres pairs ; la
  privée ne quitte jamais la machine. C’est l’idée de SSH, avec d’autres clés (Curve25519).
]

= Étape 3 : deux configurations <etape-3>

#bloc(role: "question")[Consignes][
  - Donnez à `pair-a` l’adresse `10.9.9.1/24` dans le tunnel, à `pair-b` `10.9.9.2/24`, tous deux sur le port UDP 51820.
  - Chacun connaît l’autre par sa *clé publique*. `pair-a` sait où joindre `pair-b` ; `pair-b` ne connaît *pas* l’adresse de
    `pair-a`. Quelles adresses le tunnel doit-il laisser passer vers l’autre pair ?
  - Écrivez les deux fichiers `/etc/wireguard/wg0.conf`, lisibles par root seul.
]

#indice(titre: [Indice : la structure d’un fichier])[
  #d("wireguard-labo")[wg0.conf et wg-quick : monter le tunnel]. Une section `[Interface]` (`PrivateKey`, `Address`, `ListenPort`)
  décrit la machine ; un bloc `[Peer]` (`PublicKey`, `AllowedIPs`, `Endpoint` facultatif) décrit chaque pair.
  `Address` n’est lu que par `wg-quick`.
]
#indice(titre: [Indice : remplir les valeurs])[
  La clé privée est dans `prive.key` du pair ; la clé publique de l’autre se copie depuis son `public.key`.
  Éditez avec `nano`, puis `chmod 600 /etc/wireguard/wg0.conf` : `wg-quick` avertit d’un fichier lisible par tous.
  `AllowedIPs = 10.9.9.2/32` pour un pair qui est la seule machine d’adresse `10.9.9.2`.
]

#corrige[
  #f("pair-a.conf")
  #f("pair-b.conf")
  #terminal[```console
  # sur chaque pair, une fois wg0.conf écrit
  $ chmod 600 /etc/wireguard/wg0.conf
  ```]
  Chaque pair a une `[Interface]` (sa clé privée, son adresse) et un `[Peer]` (la clé publique de l’autre). `pair-b`
  n’a pas d’`Endpoint` : il apprendra l’adresse de `pair-a` à son premier paquet authentifié. Les `AllowedIPs` sont
  au plus étroit : un `/32`, une seule adresse.
]

= Étape 4 : monter le tunnel et le regarder <etape-4>

#bloc(role: "question")[Consignes][
  - Montez `wg0` sur les deux pairs avec `wg-quick`. Quelle interface, quelle adresse, quelle route sont apparues ?
  - Depuis `pair-a`, faites un ping vers `10.9.9.2`. Que dit `wg show` ? Qu’est-ce qu’une « poignée de main » ?
  - Sur `pair-b`, retrouvez l’adresse de `pair-a`, alors que le fichier de `pair-b` n’en contient aucune.
  - Pendant un ping, capturez le trafic de `eth0` sur `pair-b` : que voit le réseau porteur ?
]

#indice(titre: [Indice : les commandes])[
  `wg-quick up wg0` lit `/etc/wireguard/wg0.conf` ; `ip addr show wg0` et `ip route show dev wg0` montrent le
  résultat. #d("wireguard-tunnel")[Le tunnel fonctionne, et ce que voit le réseau]. `wg show wg0 endpoints` donne l’adresse apprise
  de chaque pair. Pour capturer : `tcpdump -lni eth0 -c 6`, lancé *avant* le ping, dans un autre terminal.
]

#corrige[
  #terminal[```console
  # sur pair-a, puis sur pair-b
  $ wg-quick up wg0
  $ ip -4 -brief address show wg0
  $ ip route show dev wg0
  # sur pair-b, dans un second terminal (docker compose exec pair-b bash)
  $ tcpdump -lni eth0 -c 6
  # sur pair-a
  $ ping -c 3 10.9.9.2
  $ wg show wg0
  # sur pair-b
  $ wg show wg0 endpoints
  ```]
  `wg-quick` a créé `wg0`, lui a donné `10.9.9.1/24` et une route `10.9.9.0/24` par `wg0`. Sur le réseau porteur,
  `tcpdump` ne montre que de l’UDP entre les ports 51820 : une poignée de main (148 octets puis 92), puis des
  datagrammes de 128 octets par paquet de ping. Aucun ICMP, aucune adresse `10.9.9.x` : le contenu est chiffré.
  `wg show` indique `latest handshake` : la poignée de main est l’échange où les deux pairs s’authentifient
  par leurs clés et en tirent une clé de session. `pair-b` a *appris* `172.20.0.2:51820` à ce premier paquet : il
  suffit qu’un des deux pairs sache où joindre l’autre.
]

= Étape 5 : `AllowedIPs`, à l’épreuve <etape-5>

#bloc(role: "question")[Consignes][
  - Sur `pair-a`, faites en sorte que `pair-b` ne soit plus le pair de `10.9.9.2`, sans toucher au fichier : le ping
    échoue-t-il ? Pourquoi ? Rétablissez.
  - Sur `pair-b`, dites que `pair-a` n’a le droit d’envoyer que depuis `10.9.9.100`. Relevez les compteurs
    d’octets avant et après un ping de `pair-a` : que s’est-il passé de chaque côté ? Rétablissez.
  - Quels deux rôles `AllowedIPs` joue-t-il ?
]

#indice(titre: [Indice : modifier à chaud])[
  `wg set wg0 peer <clé publique> allowed-ips <liste>` change l’interface en marche, sans toucher au fichier.
  `wg show wg0 transfer` affiche, par pair, les octets reçus puis envoyés.
  #d("wireguard-epreuve")[AllowedIPs à l’épreuve : sortant, puis entrant].
]

#corrige[
  #terminal[```console
  # sur pair-a : pair-b ne couvre plus 10.9.9.2 (pair-b est son seul pair)
  $ wg set wg0 peer "$(wg show wg0 peers)" allowed-ips 10.9.9.3/32
  $ ping -c 2 -W 1 10.9.9.2
  $ wg set wg0 peer "$(wg show wg0 peers)" allowed-ips 10.9.9.2/32
  # sur pair-b : pair-a ne peut plus émettre que depuis 10.9.9.100
  $ wg set wg0 peer "$(wg show wg0 peers)" allowed-ips 10.9.9.100/32
  $ wg show wg0 transfer
  # sur pair-a
  $ ping -c 2 -W 1 10.9.9.2
  # sur pair-b
  $ wg show wg0 transfer
  $ wg set wg0 peer "$(wg show wg0 peers)" allowed-ips 10.9.9.1/32
  ```]
  `wg show wg0 peers` liste les clés publiques des pairs de l’interface : un seul ici, donc la commande sert à la place de la clé. *Sortant* : aucun pair ne couvre `10.9.9.2`, le paquet n’est pas envoyé. *Entrant* :
  `pair-b` reçoit les paquets (son compteur « reçu » augmente) mais leur source `10.9.9.1` n’est pas dans les
  `AllowedIPs` de `pair-a` : il les jette, rien ne repart (son compteur « envoyé » ne bouge pas). `AllowedIPs`
  sert deux fois : *routage* des paquets sortants, *filtrage* des paquets entrants, tous deux attachés à une clé publique :
  #d("wireguard-allowedips")[AllowedIPs : une table de routage et un filtre].
]

= Étape 6 : un troisième pair <etape-6>

#bloc(role: "question")[Consignes][
  - Ajoutez `pair-c` (`10.9.9.3/24`), qui ne connaît que `pair-a`. Sur `pair-a`, ajoutez son bloc `[Peer]`, et
    appliquez le fichier *sans couper* `pair-b`.
  - `pair-a` joint-il `pair-c` ? `pair-b` toujours ? `pair-b` joint-il `pair-c` ? Pourquoi ?
]

#indice(titre: [Indice : appliquer sans couper])[
  `wg-quick down` puis `up` coupe tous les pairs. `wg syncconf wg0 <fichier>` compare et n’applique que la différence ;
  mais `wg` ne lit pas les clés propres à `wg-quick` (`Address`) : `wg-quick strip wg0` les enlève,
  d’où `wg syncconf wg0 <(wg-quick strip wg0)`.
]

#corrige[
  #f("pair-a-trois-pairs.conf")
  #f("pair-c.conf")
  #terminal[```console
  # sur pair-a, après avoir ajouté le bloc [Peer] de pair-c à wg0.conf
  $ wg syncconf wg0 <(wg-quick strip wg0)
  $ wg show wg0 peers
  # sur pair-c
  $ wg-quick up wg0
  # sur pair-a
  $ ping -c 2 10.9.9.3
  $ ping -c 1 10.9.9.2
  # sur pair-b
  $ ping -c 1 -W 1 10.9.9.3
  ```]
  `pair-a` joint `pair-c` et `pair-b` répond toujours : la synchronisation n’a rien coupé. `pair-b` ne joint pas
  `pair-c` : aucun de ses pairs ne couvre `10.9.9.3` (il n’a que `pair-a`, pour `10.9.9.1/32`). Un VPN en étoile
  ne relaie pas tout seul : c’est l’étape suivante.
]

= Étape 7 : `pair-a` relaie <etape-7>

#bloc(role: "question")[Consignes][
  - Faites que `pair-b` joigne `pair-c` en passant par `pair-a`. De quoi `pair-a` a-t-il besoin pour relayer des
    paquets ? Que faut-il changer chez `pair-b` et chez `pair-c` ?
  - Comment voir, dans la réponse du ping, qu’un routeur a été traversé ?
]

#indice(titre: [Indice : relais et AllowedIPs])[
  Linux ne transmet pas les paquets d’une interface à l’autre sans `net.ipv4.ip_forward=1` ; le `compose.yaml` du
  labo l’a déjà réglé pour `pair-a` (`sysctls`) : vérifiez-le dans `/proc/sys/net/ipv4/ip_forward`. Pour `pair-b` et `pair-c`,
  `pair-a` doit couvrir tout le tunnel, pas seulement sa propre adresse. Le champ qui diminue à chaque
  routeur est le TTL.
]

#corrige[
  #terminal[```console
  # sur pair-a
  $ cat /proc/sys/net/ipv4/ip_forward
  1
  # sur pair-b, puis sur pair-c : pair-a (leur seul pair) couvre tout le tunnel
  $ wg set wg0 peer "$(wg show wg0 peers)" allowed-ips 10.9.9.0/24
  # sur pair-b
  $ ping -c 2 -W 2 10.9.9.3
  ```]
  Le ping de `pair-b` à `pair-c` aboutit, avec `ttl=63` : 64 moins un routeur traversé, `pair-a`. `pair-a` relaie
  parce que `ip_forward` vaut 1, et parce que chaque `AllowedIPs` accepte les adresses de l’autre. Au plus étroit : le
  `/24` n’est à donner qu’au pair qui relaie vraiment.
]

= Nettoyer <nettoyer>

#corrige(titre: [Corrigé : supprimer le labo])[
  #terminal[```console
  $ docker compose down --volumes --rmi local
  ```]
  Les interfaces `wg0` disparaissent avec les conteneurs : rien n’est resté sur votre machine.
]
