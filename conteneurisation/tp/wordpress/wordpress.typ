// TP « Conteneuriser WordPress » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     conteneurisation/tp/wordpress/wordpress.typ build/wordpress.html
// Les corrigés sont les fichiers de corrige/, testés par tester.sh : la page les affiche tels quels.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/conteneurisation-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin) = fichier("corrige/" + chemin, read("corrige/" + chemin))

#show: page-web.with(
  titre: [Conteneuriser WordPress],
  surtitre: [Fondements de la conteneurisation · travaux pratiques],
  sous-titre: [Du Dockerfile écrit à la main à une application Compose qui passe à l’échelle],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("compagnon",),
  liens: (
    ([Diapos du cours], pdf),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/conteneurisation/tp/wordpress/corrige"),
  ),
)

= Avant de commencer <avant>

Ce TP construit un service WordPress en neuf étapes. Les cinq premières écrivent tout à la main : vous y
rencontrerez les mécanismes de Docker un par un, et les problèmes qu’ils posent. Les quatre dernières
utilisent Compose et les images officielles, qui emploient ces mêmes mécanismes.

#bloc(role: "precaution")[La première architecture est volontairement mauvaise][
  Les étapes 1 à 4 placent Apache, PHP et MariaDB dans un seul conteneur. Ce n’est pas une bonne méthode de
  travail : c’est le moyen de constater pourquoi le cours recommande
  #d("ephemere-un-service")[un service par conteneur]. L’étape 5 sépare les services.
]

#bloc(role: "pratique")[Prérequis][
  - Une machine Debian 13 avec les paquets `docker.io` et `docker-compose`, et votre compte dans le groupe
    `docker` : #d("installation")[Contexte d’utilisation et installation].
  - Un dossier de travail par étape : chaque étape part d’une copie du dossier de la précédente.
  - Le port 8080 de votre machine libre : le site se consulte sur #link("http://localhost:8080").
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Ouvrez-les après avoir cherché : chaque étape
  repose sur ce que vous avez compris de la précédente. Les corrigés sont des fichiers réels, construits et
  testés automatiquement à chaque modification.
]

#schema([Les deux architectures du TP : un conteneur pour tout (étapes 1 à 4), puis un conteneur par service (étapes 5 à 8).], ch => {
  let c = ch.c
  let conteneur(titre, ..cases) = boite(titre, fond: c.bleu-clair, trait: c.bleu, stack(spacing: 5pt, ..cases))
  let volume(nom) = case(fond: ch.roles.retenir.fond, [volume #nom])
  grid(columns: 2, column-gutter: 28pt,
    boite([Hôte · étapes 1 à 4], largeur: 200pt, stack(spacing: 8pt,
      conteneur([un conteneur], case(largeur: 150pt)[Apache + PHP + WordPress], case(largeur: 150pt)[MariaDB]),
      align(center, text(size: 9pt)[port 8080 de l’hôte → port 80]),
    )),
    boite([Hôte · étapes 5 à 8], largeur: 330pt, stack(spacing: 8pt,
      boite([réseau utilisateur · les noms se résolvent], trait: c.gris, tirets: "dashed", grid(columns: 2, column-gutter: 12pt,
        conteneur([conteneur `wordpress`], case(largeur: 120pt)[Apache + PHP + WordPress]),
        conteneur([conteneur `db`], case(largeur: 120pt)[MariaDB]),
      )),
      grid(columns: 2, column-gutter: 12pt, volume([du code]), volume([de la base])),
      align(center, text(size: 9pt)[port 8080 de l’hôte → port 80 de `wordpress` ; `db` n’est pas publié]),
    )),
  )
})

= Étape 1 : un premier Dockerfile <etape-1>

Vous écrivez un Dockerfile qui produit une image contenant tout le service, sans chercher à bien faire :
l’étape 2 reprendra ce fichier pour l’améliorer.

#bloc(role: "question")[Consignes][
  - Travaillez dans un dossier `1_wordpress_multiservice_dirty`.
  - Image de base : `debian:13`.
  - Installez Apache, PHP et MariaDB par leurs paquets Debian ; le paquet `wordpress` est interdit.
  - Téléchargez les #link("https://wordpress.org/latest.zip")[sources de WordPress] au format zip et placez-les
    dans `/var/www/html`.
  - Déclarez par une instruction `ENV` le nom de la base (`wordpress`), l’utilisateur de la base (`admin`) et
    son mot de passe (`tempo`).
  - Créez la base, puis l’utilisateur, qui a tous les droits sur cette seule base.
  - La commande par défaut du conteneur lance MariaDB et Apache.
  - Nommez l’image `mon_image_wordpress` et le conteneur `mon_conteneur_wordpress` ; publiez le port 80 du
    conteneur sur le port 8080 de l’hôte.
  - Terminez le Dockerfile par les commandes de construction et de lancement, en commentaire.
  - Vérifiez dans un navigateur que l’installation de WordPress va jusqu’au tableau de bord.
]

#note(role: "avertissement")[Un mot de passe dans `ENV` est un exemple d’école : il se lit dans l’image
  (`docker image history`, `docker image inspect`). Le cours montre la même fuite avec `ARG` :
  #d("secret-arg")[Un secret passé par ARG fuit].]

#indice(titre: [Indice : trouver les paquets])[
  `apt-get install --simulate paquet` montre ce qu’une installation ferait, `apt-cache depends paquet` liste
  les dépendances d’un paquet. WordPress demande un serveur web, PHP avec son module Apache et son extension
  MySQL, et un serveur de base de données. Pour décompresser l’archive : `unzip`.
]
#indice(titre: [Indice : `apt-get` dans un build])[
  Un build n’a pas de terminal : `apt-get install -y` répond oui à votre place, et la variable
  `DEBIAN_FRONTEND=noninteractive` fait taire les questions de configuration des paquets.
]
#indice(titre: [Indice : créer la base pendant le build])[
  Chaque instruction `RUN` s’exécute dans un conteneur neuf : un serveur démarré par un `RUN` n’existe plus au
  suivant. Démarrez donc MariaDB (`service mariadb start`) et passez vos commandes SQL dans le même `RUN`.
  #terminal[```console
  $ mariadb --execute "CREATE DATABASE nom_base"
  $ mariadb --execute "CREATE USER 'nom'@'%' IDENTIFIED BY 'mot_de_passe'"
  $ mariadb --execute "GRANT ALL PRIVILEGES ON nom_base.* TO 'nom'@'%'"
  ```]
]
#indice(titre: [Indice : deux services, une seule commande par défaut])[
  Un conteneur vit tant que son premier processus (PID 1) vit : #d("conteneurs-qui-surprennent")[À vous : des
  conteneurs qui surprennent]. La commande par défaut peut démarrer MariaDB, puis lancer Apache au premier plan :
  `apache2ctl -D FOREGROUND`. La documentation de Docker décrit ce cas :
  #link("https://docs.docker.com/engine/containers/multi-service_container/")[Run multiple processes in a container].
]
#indice(titre: [Indice : publier le port])[
  Vous l’avez fait avec nginx : #d("publier-nginx")[À vous : publier et interroger un serveur nginx].
]

#corrige[
  Ce premier corrigé extrait l’archive telle quelle : le site est sous
  #link("http://localhost:8080/wordpress"). À partir de l’étape 2, il est à la racine.
  #f("1_wordpress_multiservice_dirty/Dockerfile")
]

== Questions

+ Arrêtez le conteneur avec `docker container stop`. Combien de temps cela prend-il, et pourquoi ?
+ Que montre `docker container logs mon_conteneur_wordpress` ? Les journaux de MariaDB y sont-ils ?
+ Listez les couches avec `docker image history mon_image_wordpress`. Combien en comptez-vous, et combien pèse
  l’image ?

#corrige(titre: [Réponses])[
  + Environ dix secondes avec une commande par défaut en forme shell : le PID 1 est un shell, qui ne transmet
    pas le signal SIGTERM ; Docker attend, puis envoie SIGKILL. Voir #d("forme-exec")[Forme exec ou shell :
    l’arrêt]. Le corrigé de l’étape 2 s’arrête en moins d’une seconde.
  + La sortie standard et la sortie d’erreur du PID 1 et des processus qui en héritent. Un service qui écrit
    son journal dans un fichier n’y apparaît pas : c’est une des raisons de ne mettre qu’un service par conteneur.
  + Une couche par instruction qui modifie le système de fichiers. L’étape 2 les regroupe.
]

= Étape 2 : les bonnes pratiques <etape-2>

#bloc(role: "question")[Consignes][
  - Copiez `1_wordpress_multiservice_dirty` en `2_wordpress_multiservice_better`.
  - Appliquez au Dockerfile les règles de la diapositive #d("dockerfile-bonnes-pratiques")[Dockerfile : bonnes
    pratiques].
  - Construisez l’image sans le cache et en retéléchargeant l’image de base : `--no-cache --pull`.
  - Vérifiez que le site fonctionne, puis comparez le nombre de couches et la taille avec l’étape 1.
]

#note(role: "pratique")[Pour voir ce que le cache réutilise quand une instruction ou un fichier change, essayez
  l’artefact #link("../../artefacts/cache-de-build/")[Le cache de build].]

#indice(titre: [Indice : la liste des points à reprendre])[
  - `apt-get update` et `apt-get install` dans le même `RUN`, avec `--no-install-recommends`, puis la
    suppression de `/var/lib/apt/lists/*`.
  - `DEBIAN_FRONTEND=noninteractive` devant la commande `apt-get`, et non dans une instruction `ENV` : la
    variable resterait définie dans les conteneurs.
  - Les instructions stables d’abord : le #d("cache-buildkit")[cache de build] réutilise tout ce qui précède
    la première instruction modifiée.
  - `WORKDIR` pour changer de répertoire, plutôt que `RUN cd …`.
  - La commande par défaut en forme exec : #d("forme-exec")[Forme exec ou shell : l’arrêt] ; l’artefact
    #link("../../artefacts/cmd-entrypoint/")[CMD × ENTRYPOINT] montre ce que le conteneur lance dans chaque forme.
  - Un tag précis pour l’image de base : #d("tag-ou-digest")[Tag ou digest].
]

#corrige[
  #f("2_wordpress_multiservice_better/Dockerfile")
]

== Questions

+ Le cours présente le #d("multi-stage")[build multi-stage]. Serait-il utile ici ?
+ Avec `docker container top mon_conteneur_wordpress`, relevez l’utilisateur de chaque processus d’Apache et
  de MariaDB. Lesquels posent un problème ?

#corrige(titre: [Réponses])[
  + Non : rien n’est compilé dans cette image. Le build multi-stage sert à laisser les outils de construction
    hors de l’image finale.
  + Le processus principal d’Apache (PID 1) et le lanceur de MariaDB, `mariadbd-safe`, tournent en root ; seuls
    les processus qui servent les requêtes sont sous `www-data`, et `mariadbd` sous `mysql`. Or, sans _user
    namespace_, le root du conteneur est le root de l’hôte : #d("root-conteneur")[Root du conteneur = root de
    l’hôte]. L’étape 3 traite ce point.
  #note(role: "precaution")[`docker container top` nomme les utilisateurs d’après l’hôte : un utilisateur du
    conteneur que l’hôte ne connaît pas apparaît sous son numéro, ou sous le nom qu’a ce numéro sur l’hôte.]
]

= Étape 3 : plus aucun processus root <etape-3>

#bloc(role: "question")[Consignes][
  - Copiez `2_wordpress_multiservice_better` en `3_wordpress_multiservice_noroot`.
  - Une fois le conteneur démarré, plus aucun processus ne tourne en root : `docker container top` le montre.
  - Apache tourne sous `www-data` et porte le PID 1 ; MariaDB tourne sous `mysql`.
  - L’image ne contient aucun bit setuid ajouté.
  - Lancez le conteneur avec le moins de pouvoirs possible : #d("reduire-pouvoirs")[Réduire ses pouvoirs].
]

#indice(titre: [Indice : le modèle du cours])[
  Le cours appelle ce modèle « root au démarrage seulement » : #d("root-au-demarrage")[Root au démarrage
  seulement]. Un script d’entrée lancé en root prépare ce qui exige root (créer un dossier, changer un
  propriétaire), puis remplace son propre processus par le service, sous un utilisateur sans privilège :
  `exec setpriv …` ou `exec gosu …`. La commande `setpriv` est déjà dans `debian:13`. Ce script est l’`ENTRYPOINT` :
  il reçoit le `CMD` en arguments (artefact #link("../../artefacts/cmd-entrypoint/")[CMD × ENTRYPOINT]).
]
#indice(titre: [Indice : Apache sans root])[
  - Depuis Docker 20.10, un processus sans privilège peut écouter sur le port 80 dans un conteneur.
  - Apache écrit dans ses dossiers d’exécution, de verrou et de journaux : ils doivent appartenir à `www-data`.
    Leurs chemins sont dans `/etc/apache2/envvars`.
  - Lancé par `setpriv`, c’est le binaire `apache2` qu’il faut exécuter, avec les variables de
    `/etc/apache2/envvars` : `apache2ctl` est un script qui s’interpose.
]

#corrige[
  #f("3_wordpress_multiservice_noroot/Dockerfile")
  #f("3_wordpress_multiservice_noroot/entrypoint.sh")
]

== Questions

+ Une ancienne version de ce TP posait un bit setuid sur le lanceur d’Apache pour qu’il démarre avec les
  droits d’un autre utilisateur. Pourquoi est-ce une fausse bonne idée ?
+ Sur une machine classique, Apache démarre en root, puis confie les requêtes à des processus `www-data`.
  Faut-il interdire tout processus root dans un conteneur ?
+ Quelles capabilities votre script d’entrée exige-t-il ? Retirez-les une à une pour le vérifier.
+ Arrêtez le conteneur avec `docker container stop`, puis relancez-le. Comment MariaDB a-t-il vécu l’arrêt ?
+ Votre image ne sert que WordPress. Une image générique « Apache, PHP, MariaDB », dans laquelle on monterait
  le code du site, serait-elle préférable ?

#corrige(titre: [Réponses])[
  + Un binaire setuid donne les droits de son propriétaire à quiconque l’exécute : une faille de ce programme
    devient une élévation de privilèges, et l’option `no-new-privileges` ne peut plus être utilisée. De plus,
    Linux ignore le bit setuid sur un script. Le cours traite ce cas :
    #d("setuid-fausse-bonne-idee")[Fausse bonne idée : sshd setuid root].
  + Non. Ce qui compte est la durée et l’étendue des pouvoirs : root pour préparer le démarrage, puis plus
    jamais, avec les seules capabilities nécessaires. Un processus root qui reste en vie tout le long, lui,
    expose l’hôte.
  + Trois : `CHOWN` pour donner les dossiers à leurs utilisateurs, `SETUID` et `SETGID` pour changer
    d’utilisateur. Sans l’une d’elles, le script échoue.
  + Mal : seul le PID 1, Apache, reçoit SIGTERM. MariaDB est tué sans avoir fermé ses fichiers, et les répare au
    démarrage suivant. C’est une limite du conteneur à deux services, que l’étape 5 lève.
  + C’est une autre architecture, pas une meilleure : l’image contient alors moins, et le code vit sur l’hôte.
    Le choix dépend de ce que vous livrez : une application précise, ou un socle pour plusieurs sites.
]

= Étape 4 : faire persister les données <etape-4>

#bloc(role: "question")[Consignes][
  - Copiez `3_wordpress_multiservice_noroot` en `4_wordpress_multiservice_persistant`.
  - Constatez d’abord la perte : installez WordPress, supprimez le conteneur, relancez-en un.
  - Faites persister `/var/lib/mysql` et `/var/www/html` dans deux volumes nommés.
  - Documentez le port du service dans le Dockerfile avec `EXPOSE`.
  - Vérifiez : après suppression et recréation du conteneur, le site est toujours installé.
]

#indice[
  Un volume nommé se déclare au lancement : `-v nom_du_volume:/chemin/dans/le/conteneur`. Voir
  #d("persistance")[Persistance : montage de dossier ou volume]. Les corrigés nomment les deux volumes
  `data_wordpress` et `source_code_wordpress`.
]

#corrige[
  #f("4_wordpress_multiservice_persistant/Dockerfile")
  #f("4_wordpress_multiservice_persistant/entrypoint.sh")
]

== Questions

+ Au premier lancement, le volume de la base est vide. Pourquoi MariaDB y trouve-t-il pourtant la base créée
  pendant le build ?
+ Remplacez le volume nommé de la base par un dossier de l’hôte : `-v "$HOME/essai_base:/var/lib/mysql"`.
  Que se passe-t-il ?
+ Lancez un conteneur avec `-v /var/lib/mysql`, sans nom. Où sont les données ? Que deviennent-elles à la
  suppression du conteneur ?
+ Comment sauvegarder la base depuis l’hôte ?

#corrige(titre: [Réponses])[
  + À son premier montage, un volume nommé vide reçoit le contenu que l’image possède à cet endroit.
  + Le dossier de l’hôte masque le contenu de l’image, sans copie : MariaDB ne trouve plus sa base et ne démarre
    pas. Le conteneur reste pourtant en vie, puisque son PID 1 est Apache : le site répond par une erreur de
    connexion à la base. C’est le premier des #d("montages-pieges")[deux pièges des montages]. Les images officielles contournent
    ce piège par un script d’entrée qui initialise la base quand le dossier est vide : vous le verrez à l’étape 7.
  + Dans un volume anonyme, que `docker volume ls` désigne par une longue empreinte. Il survit au conteneur,
    sauf si celui-ci est lancé avec `--rm` ou supprimé avec `docker container rm -v`.
  + Par un export lancé depuis l’hôte, sans l’option `-t`, qui altérerait la sortie :
    #terminal[```console
    $ docker container exec mon_conteneur_wordpress \
        mariadb-dump --user=admin --password=tempo wordpress > "sauvegarde_$(date +%F).sql"
    ```]
    Un export complète le volume, il ne le remplace pas.
]

#bloc(role: "danger")[`docker volume prune` supprime des données][
  Cette commande supprime les volumes anonymes qu’aucun conteneur n’utilise ; avec `--all`, elle supprime aussi
  les volumes nommés inutilisés. Un volume n’est « utilisé » que s’il existe un conteneur qui le monte, même
  arrêté : après un `docker container rm`, plus rien ne protège vos données.
]

#note(role: "pratique")[Pour des données temporaires, `--tmpfs /chemin` monte un système de fichiers en
  mémoire : rien n’est écrit dans la couche inscriptible du conteneur.]

= Étape 5 : un conteneur par service <etape-5>

#bloc(role: "question")[Consignes][
  - Copiez `4_wordpress_multiservice_persistant` en `5_wordpress_microservice_persistant`.
  - Créez deux sous-dossiers, `wordpress` et `db`, avec un Dockerfile chacun : le premier pour Apache, PHP et
    les sources de WordPress, le second pour MariaDB.
  - Chaque image fixe son utilisateur par l’instruction `USER` : `www-data` pour l’une, `mysql` pour l’autre.
  - Écrivez un script `build_and_launch.sh` qui crée un réseau, construit les deux images et lance les deux
    conteneurs, nommés `wordpress` et `db`, sans aucune capability.
  - Les deux conteneurs se joignent par leur nom ; la base n’est pas publiée sur l’hôte.
  - Les données de la base et le code persistent comme à l’étape 4.
  - Vérifiez le site. Dans l’assistant d’installation de WordPress, l’adresse de la base est `db`.
]

#indice(titre: [Indice : le réseau])[
  Sur le réseau `bridge` par défaut, les conteneurs ne se connaissent pas par leur nom. Sur un réseau que vous
  créez, Docker fournit un serveur de noms : #d("reseaux-utilisateur")[Réseaux utilisateur et DNS].
]
#indice(titre: [Indice : MariaDB n’écoute que localement])[
  Par défaut, le MariaDB de Debian n’accepte que les connexions de la machine locale : c’est la ligne
  `bind-address` de `/etc/mysql/mariadb.conf.d/50-server.cnf`. Dans un conteneur à part, il doit écouter sur
  toutes ses interfaces : l’option `--bind-address` de `mariadbd` l’emporte sur le fichier.
]

#corrige[
  #f("5_wordpress_microservice_persistant/wordpress/Dockerfile")
  #f("5_wordpress_microservice_persistant/db/Dockerfile")
  #f("5_wordpress_microservice_persistant/build_and_launch.sh")
]

== Questions

+ Pourquoi le script d’entrée de l’étape 3 n’est-il plus nécessaire ?
+ Depuis le conteneur `wordpress`, comment le nom `db` est-il résolu ?
+ D’anciens tutoriels relient deux conteneurs par l’option `--link`. Pourquoi ne pas l’employer ?
+ Votre application compte deux services. Que deviendrait `build_and_launch.sh` avec vingt-cinq services ?

#corrige(titre: [Réponses])[
  + Chaque conteneur n’a plus qu’un service : `USER` suffit à lui donner son utilisateur dès le premier
    processus, et aucune capability n’est requise. Le service porte le PID 1 : il reçoit SIGTERM, donc MariaDB
    s’arrête proprement, et `docker container logs` montre son journal.
  + Par le serveur de noms que Docker fournit sur les réseaux utilisateur, à l’adresse 127.0.0.11 dans chaque
    conteneur : `docker container exec wordpress cat /etc/resolv.conf`.
  + `--link` est un mécanisme hérité du réseau par défaut, que la documentation de Docker déconseille : les
    réseaux utilisateur le remplacent et isolent en plus chaque application dans son réseau.
  + Un script difficile à maintenir : ordre de lancement, mises à jour, nettoyage, tout est à écrire.
    Compose décrit l’application au lieu de la lancer pas à pas : #d("pourquoi-compose")[Pourquoi Compose ?].
]

= Étape 6 : décrire l’application avec Compose <etape-6>

#bloc(role: "question")[Consignes][
  - Copiez `5_wordpress_microservice_persistant` en `6_wordpress_microservice_compose`.
  - Remplacez `build_and_launch.sh` par un fichier `compose.yaml` équivalent : deux services, `wordpress` et
    `db`, construits depuis vos deux Dockerfile, avec leurs volumes nommés.
  - Lancez l’application, consultez l’état des services et leurs journaux, vérifiez le site, puis arrêtez tout.
]

#indice[
  La syntaxe est dans #d("compose-decrire")[Compose : décrire l’application], les commandes dans
  #d("compose-cycle")[Compose : le cycle de vie d’un projet]. `docker compose config` valide votre fichier.
]

#corrige[
  #f("6_wordpress_microservice_compose/compose.yaml")
  Les deux Dockerfile sont ceux de l’étape 5.
]

== Questions

+ Listez les réseaux avec `docker network ls`. Lequel Compose a-t-il créé, et pourquoi `db` se résout-il sans
  que vous ayez déclaré de réseau ?
+ `depends_on` garantit-il que la base est prête quand WordPress démarre ?
+ Quelle différence entre `docker compose down` et `docker compose down -v` ?

#corrige(titre: [Réponses])[
  + Un réseau utilisateur nommé d’après le projet, `<projet>_default`. Tous les services y sont reliés, et le
    nom de chaque service s’y résout.
  + Non : `depends_on` n’ordonne que les démarrages. Pour attendre que la base réponde, il faut un
    `healthcheck` sur `db` et la condition `service_healthy`.
  + `down` supprime les conteneurs et le réseau ; `down -v` supprime aussi les volumes, donc les données.
]

#bloc(role: "retenir")[Ce que vous savez faire à la main][
  Variables d’environnement, script d’entrée, abandon des privilèges, volumes, réseau : vous avez écrit chaque
  mécanisme. Les images officielles emploient les mêmes ; les étapes suivantes s’en servent.
]

= Étape 7 : les images officielles <etape-7>

#bloc(role: "question")[Consignes][
  - Créez un dossier `7_wordpress_official_stack` contenant le fichier `compose.yaml` ci-dessous.
  - Lancez l’application, suivez les journaux de chaque service, vérifiez le site.
]

#f("7_wordpress_official_stack/compose.yaml")

== Questions

+ Vous n’avez écrit aucun Dockerfile. Où est passé le travail des étapes 1 à 5 ?
+ Ce fichier ne déclare aucun volume. Que montre `docker volume ls` après le lancement, et après
  `docker compose down` ?
+ Pourquoi le fichier fixe-t-il un tag pour chaque image ?

#corrige(titre: [Réponses])[
  + Dans les images. Le script d’entrée de `mariadb` crée la base et l’utilisateur au premier démarrage, d’après
    les variables d’environnement, puis lance le serveur sans privilège : ce que vous avez fait pendant le build
    et dans `entrypoint.sh`. Celui de `wordpress` copie les sources et écrit la configuration. Dans cette image,
    le processus principal d’Apache reste root : `docker compose top` le montre.
  + Des volumes anonymes : chaque image en déclare pour ses données. `down` les laisse orphelins, et un nouveau
    `up` en crée d’autres : le site est à réinstaller. L’étape 8 nomme l’emplacement des données.
  + Sans tag, Docker prend `latest`, qui change avec le temps : deux lancements à six mois d’écart ne
    donneraient pas la même application. Voir #d("tag-ou-digest")[Tag ou digest].
]

= Étape 8 : adapter l’application à votre besoin <etape-8>

#bloc(role: "question")[Consignes][
  - Copiez `7_wordpress_official_stack` en `8_my_final_wordpress`.
  - Créez deux dossiers, `$HOME/data_wordpress` et `$HOME/source_code_wordpress`, et faites-y persister la base
    et le code de WordPress.
  - Fixez l’image de WordPress à une version qui n’est pas la dernière, par exemple `wordpress:7.0`.
  - Installez WordPress, puis mettez-le à jour depuis son interface d’administration.
  - Supprimez l’application avec `docker compose down`, relancez-la, et relevez la version de WordPress.
]

#corrige[
  #f("8_my_final_wordpress/compose.yaml")
]

== Questions

+ À qui appartiennent les fichiers de `$HOME/data_wordpress` ? Pouvez-vous les supprimer ?
+ Après la mise à jour, l’image annonce une version de WordPress et le site en exécute une autre. Est-ce un
  problème ?

#corrige(titre: [Réponses])[
  + Aux utilisateurs des conteneurs, que votre machine ne connaît que par leurs numéros. Il faut `sudo` pour
    les supprimer : c’est le second des #d("montages-pieges")[deux pièges des montages].
  + Oui : le conteneur n’est plus #d("ephemere-un-service")[éphémère]. Son code ne vient plus de l’image mais
    du dossier monté, et relancer l’application ailleurs avec le même fichier ne redonne pas le même site. La
    méthode cohérente avec Docker : changer le tag de l’image, et ne faire persister que les contenus
    (`wp-content`).
]

= Étape 9 : passer à l’échelle <etape-9>

Un jour de forte affluence, un seul conteneur WordPress ne suffit plus. Vous en lancez plusieurs derrière un
proxy, comme dans le cours : #d("compose-echelle")[Compose : passer à l’échelle].

#schema([Étape 9 : le proxy répartit les requêtes entre les instances de `wordpress` ; la base reste unique.], ch => {
  let c = ch.c
  let conteneur(titre, corps) = boite(titre, fond: c.bleu-clair, trait: c.bleu, corps)
  let fleche = text(size: 14pt)[→]
  boite([Hôte · réseau du projet], largeur: 480pt, grid(columns: 6, column-gutter: 10pt, align: horizon,
    stack(spacing: 4pt, text(size: 9pt)[port 8080], fleche),
    conteneur([conteneur `proxy`], case(largeur: 70pt)[Traefik]),
    fleche,
    stack(spacing: 5pt, ..range(1, 4).map(i => conteneur([conteneur `wordpress-`#str(i)], case(largeur: 110pt)[Apache + PHP]))),
    fleche,
    conteneur([conteneur `db`], case(largeur: 70pt)[MariaDB]),
  ))
})

#bloc(role: "question")[Consignes][
  - Créez un dossier `9_wordpress_scale` : reprenez le fichier de l’étape 7, ajoutez un service `proxy`
    (Traefik) et retirez la publication de port du service `wordpress`.
  - Faites partager aux instances le code de WordPress et sa configuration, par un volume nommé.
  - Lancez l’application et installez WordPress, puis passez à trois instances :
    `docker compose up -d --scale wordpress=3`.
  - Montrez que des requêtes successives sont servies par des conteneurs différents.
  - Passez à cinq instances sans rien arrêter.
]

#indice[
  Le service `wordpress` ne peut plus publier le port 8080 : trois conteneurs ne se partagent pas un port de
  l’hôte. Seul le proxy publie un port ; il trouve les instances par leurs _labels_.
  `docker compose logs --follow wordpress` préfixe chaque ligne du nom de l’instance qui a répondu.
]

#corrige[
  #f("9_wordpress_scale/compose.yaml")
]

== Questions

+ Pourquoi ne pas lancer aussi `--scale db=2` ?
+ Les trois instances de WordPress partagent-elles tout ce qu’il faut pour se comporter comme un seul site ?
+ Les cinq instances tournent sur la même machine. Que se passe-t-il si elle tombe en panne ?

#corrige(titre: [Réponses])[
  + Deux serveurs de base de données sur les mêmes fichiers les corrompent : #d("compose-limite")[La limite :
    deux PostgreSQL sur un même volume]. Une base passe à l’échelle par sa réplication.
  + Elles partagent la base. Elles doivent aussi partager les fichiers que WordPress écrit : médias, extensions,
    et `wp-config.php`, qui contient les clés signant les cookies de connexion. Sans volume commun, chaque
    instance aurait ses clés, et l’utilisateur serait déconnecté d’une requête à l’autre. Ce volume commun ne
    vaut que sur une seule machine.
  + Tout s’arrête : Compose ne gère qu’une machine. Répartir des conteneurs sur plusieurs machines et les
    relancer ailleurs en cas de panne est le rôle d’un orchestrateur, que le cours présente ensuite :
    #d("orchestrateurs")[La limite de Compose : une seule machine].
]

= Pour finir <fin>

#bloc(role: "retenir")[Ce que ce TP a montré][
  - Un Dockerfile décrit une image ; ses bonnes pratiques tiennent en une diapositive.
  - Un conteneur vit par son PID 1, sans root dès que possible, et ne garde aucune donnée : elles vont dans des
    volumes.
  - Un service par conteneur, reliés par un réseau utilisateur.
  - Compose décrit l’application entière dans un fichier ; les images officielles évitent d’écrire les Dockerfile.
]

Pour s’entraîner sans rien installer : #link("https://labs.iximiuz.com/")[iximiuz Labs], des machines Linux
dans le navigateur.
