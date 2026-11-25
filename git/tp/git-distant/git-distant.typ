// TP « Git à plusieurs, sans forge » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     git/tp/git-distant/git-distant.typ build/git/git-distant.html
// Les corrigés sont les fichiers de corrige/, exécutés et vérifiés par tester.sh --up : la page les affiche tels quels.
// Sorties des terminaux : relevées par tester.sh --releve (Git 2.43.0, identités et dates fixées, messages en anglais).
// Dans un terminal, les commandes « cd » sont écrites sans le « || exit 1 » des scripts : un cd raté ne ferme pas le shell.
// Les lignes de progression de git push et git fetch (« Enumerating objects… ») sont abrégées en « # … (n lignes de progression) » ;
// le dossier personnel du relevé est remplacé par /root, celui de la VM de la page.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/git-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin) = fichier("corrige/" + chemin, read("corrige/" + chemin))

#show: page-web.with(
  titre: [Git à plusieurs, sans forge],
  surtitre: [Git : versionner et collaborer · travaux pratiques],
  sous-titre: [Un dépôt central et deux clones : publier, récupérer, diverger, résoudre un conflit, rebaser],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("vm", "compagnon"),
  liens: (
    ([Diapos du cours], pdf),
    ([TP précédent : Git en local], "../git-local/index.html"),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/git/tp/git-distant/corrige"),
    ([Pro Git], "https://git-scm.com/book/fr/v2"),
  ),
)

= Avant de commencer <avant>

Deux personnes, Ada et Grace, tiennent ensemble le petit site d’un club. Vous jouez les deux : chacune a son
dossier de travail, un clone du même dépôt central. Il n’y a ni forge ni réseau : le dépôt central est un dépôt nu,
un simple dossier de votre disque, et `git push`, `git fetch` et `git pull` s’y adressent comme à un serveur.
Chaque étape reprend une notion du cours : #d("distants")[Un dépôt distant et ses branches de suivi],
#d("push-refuse")[Push refusé : le distant a avancé], #d("pull-divergent")[Pull sur une histoire divergente],
#d("rebasage")[Rebaser : rejouer ses commits ailleurs].

#schema([Ce que vous aurez construit à l’étape 3 : un dépôt central, que personne n’édite directement, et deux clones.], ch => {
  let c = ch.c
  stack(spacing: 14pt,
    boite([`~/collab/depot-central.git` · dépôt nu, `origin` pour les deux clones], fond: c.distant-clair, trait: c.distant,
      align(center, case[branche `main`])),
    text(size: 9pt)[`git push` ↑ ↓ `git fetch`, `git pull`],
    grid(columns: 2, column-gutter: 16pt,
      boite([`~/collab/ada` · Ada Lovelace], fond: c.appli, trait: c.bleu,
        grid(columns: 2, column-gutter: 8pt, case[`main`], case[`origin/main`])),
      boite([`~/collab/grace` · Grace Hopper], fond: c.appli, trait: c.bleu,
        grid(columns: 2, column-gutter: 8pt, case[`main`], case[`origin/main`])),
    ),
  )
})

#bloc(role: "pratique")[Prérequis][
  - Le TP #link("../git-local/index.html")[Git en local] : dépôt, commit, branche, fusion, conflit.
  - Git 2.28 ou plus récent, pour `git init -b main`.
  - Un terminal : celui de cette page (une VM Linux dans le navigateur, rien à installer, tout s’efface à la
    fermeture de la page), ou le vôtre. Un seul terminal suffit : vous passez d’un dossier à l’autre par `cd`.
  - Un éditeur dans le terminal, Vim ou nano, pour résoudre le conflit de l’étape 7.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Chaque corrigé est un script réel, que le harnais du
  TP exécute dans un dossier jetable, étape après étape, en vérifiant l’état du dépôt central et des deux clones
  (branches, historique, contenu des fichiers). Les étapes se suivent : chacune part de l’état où la précédente
  s’est arrêtée. Les sorties montrées viennent de Git 2.43.0, en anglais.
]

#note(role: "precaution")[
  Les sorties ci-dessous diffèrent un peu des vôtres : les lignes de progression de `git push` et `git fetch`
  (`Enumerating objects…`, débit, nombre de fils) sont abrégées en « `# … (n lignes de progression)` » ; les chemins
  sont ceux du dossier personnel de la VM de la page, `/root`, et le message d’un commit de fusion contient le
  chemin du dépôt central. Vos identifiants de commit ne seront pas ceux du corrigé, et aucune étape ne vous demande
  d’en recopier un : lisez les vôtres avec `git log --oneline`
  (#d("empreinte")[Un identifiant est l’empreinte du contenu]).
]

= Étape 1 : le dépôt central <etape-1>

#bloc(role: "question")[Consignes][
  - Créez le dossier `~/collab`, et dedans un dépôt _nu_ nommé `depot-central.git`, dont la branche s’appelle `main`.
  - Que contient ce dépôt ? Par où diffère-t-il du dépôt `mon_projet` du TP précédent ?
]

#indice(titre: [Indice : la commande])[
  `git init --bare -b main` crée un dépôt sans répertoire de travail : c’est la forme d’un dépôt sur un serveur, et ce
  que le cours emploie pour simuler une forge (#d("publier")[Publier : git remote add, puis git push]).
  Le suffixe `.git` du nom est la convention pour un dépôt nu.
]

#corrige[
  #terminal[```console
  $ mkdir -p ~/collab
  $ cd ~/collab
  $ git init --bare -b main depot-central.git
  Initialized empty Git repository in /root/collab/depot-central.git/
  $ ls depot-central.git
  HEAD  branches	config	description  hooks  info  objects  refs
  ```]
  Il n’y a pas de sous-dossier `.git` : les fichiers de Git (`HEAD`, `objects`, `refs`) sont à la racine, et rien
  n’est « extrait » dans un répertoire de travail. Personne n’y édite de fichier : on y publie, on y récupère. C’est
  aussi pourquoi on le veut nu : Git refuse par défaut qu’on pousse vers la branche extraite d’un dépôt qui a un
  répertoire de travail, il écraserait les fichiers de celui qui y travaille. Le dépôt est vide : `HEAD` désigne
  `main`, qui n’existe pas encore.
  #f("01-depot-nu.sh")
]

= Étape 2 : Ada clone et publie <etape-2>

#bloc(role: "question")[Consignes][
  - Dans `~/collab`, clonez `depot-central.git` dans un dossier `ada`. Que dit Git, et pourquoi ?
  - Dans ce clone, donnez à Git le nom « Ada Lovelace » et l’adresse `ada@example.org`, pour ce dépôt seulement :
    Grace travaille sur le même compte.
  - Créez `README.md` de trois lignes : `Site du club`, une ligne vide, `Responsable : Ada.`, puis enregistrez le commit
    « Ajout du README ».
  - Publiez `main` de façon que `git push` suffise ensuite, sans argument, puis lisez `git status`.
]

#indice(titre: [Indice : l’identité])[
  `git config` sans `--global` écrit dans `.git/config` du dépôt courant : #d("se-presenter")[Installer Git et se présenter].
  `printf '%s\n' 'a' '' 'b'` écrit une ligne par argument.
]
#indice(titre: [Indice : publier])[
  `git push -u origin main` envoie `main` et enregistre que la branche locale suit `origin/main` :
  #d("cloner")[Cloner, puis publier un commit]. `origin` est le nom que `git clone` donne au dépôt cloné.
]

#corrige[
  #terminal[```console
  $ cd ~/collab
  $ git clone depot-central.git ada
  Cloning into 'ada'...
  warning: You appear to have cloned an empty repository.
  done.
  $ cd ada
  # sans --global : l'identité de ce dépôt seulement
  $ git config user.name "Ada Lovelace"
  $ git config user.email ada@example.org
  $ printf '%s\n' 'Site du club' '' 'Responsable : Ada.' > README.md
  $ git add README.md
  $ git commit -m "Ajout du README"
  [main (root-commit) a22363e] Ajout du README
   1 file changed, 3 insertions(+)
   create mode 100644 README.md
  $ git push -u origin main
  # … (4 lignes de progression)
  To /root/collab/depot-central.git
   * [new branch]      main -> main
  branch 'main' set up to track 'origin/main'.
  $ git status
  On branch main
  Your branch is up to date with 'origin/main'.

  nothing to commit, working tree clean
  ```]
  Git prévient que le dépôt cloné est vide : il n’y a encore rien à récupérer, mais `origin` est déjà configuré.
  Sans `--global`, l’identité est celle de ce clone ; le clone de Grace aura la sienne. Le premier `git push` nomme
  la branche (`origin main`) parce que le dépôt central n’a pas encore de `main` : `-u` fait suivre
  `origin/main` à `main`. `Your branch is up to date with 'origin/main'` : Ada et le dépôt central ont le même `main`.
  #f("02-ada-clone.sh")
]

= Étape 3 : Grace clone à son tour <etape-3>

#bloc(role: "question")[Consignes][
  - Dans `~/collab`, clonez le même dépôt central dans un dossier `grace`, et donnez à ce clone l’identité
    « Grace Hopper », `grace@example.org`.
  - Listez toutes les branches, locales et de suivi, puis l’historique. Que reçoit Grace ?
]

#indice(titre: [Indice : les branches])[
  `git branch -a` montre aussi les branches de suivi, préfixées `remotes/` :
  #d("distants")[Un dépôt distant et ses branches de suivi].
]

#corrige[
  #terminal[```console
  $ cd ~/collab
  $ git clone depot-central.git grace
  Cloning into 'grace'...
  done.
  $ cd grace
  $ git config user.name "Grace Hopper"
  $ git config user.email grace@example.org
  $ git branch -a
  * main
    remotes/origin/HEAD -> origin/main
    remotes/origin/main
  $ git log --oneline
  a22363e (HEAD -> main, origin/main, origin/HEAD) Ajout du README
  ```]
  Grace reçoit tout l’historique d’Ada, et une branche locale `main` déjà placée sur le dernier commit.
  `remotes/origin/main` est la branche de suivi : la dernière position connue de `main` sur `origin`.
  `origin/HEAD` désigne la branche par défaut du dépôt central. Les deux clones n’ont rien de partagé que le dépôt
  central : ce sont deux copies complètes, indépendantes.
  #f("03-grace-clone.sh")
]

= Étape 4 : fetch, puis pull <etape-4>

#bloc(role: "question")[Consignes][
  - Dans le clone de Grace, ajoutez à la fin de `README.md` la ligne `Contact : grace@example.org`, enregistrez
    « Adresse de contact » et publiez.
  - Dans le clone d’Ada, lisez `git status` : que sait-il du commit de Grace ?
  - Faites `git fetch`, puis relisez `git status` et `git log --oneline --all`. Qu’est-ce qui a changé, et qu’est-ce
    qui n’a pas bougé ?
  - Intégrez le commit de Grace avec `git pull`. De quelle sorte d’intégration s’agit-il ?
]

#indice(titre: [Indice : ce qui parle au réseau])[
  Seuls `fetch`, `pull` et `push` parlent au dépôt distant : #d("distants")[Un dépôt distant et ses branches de suivi].
  `git commit -a` enregistre les fichiers déjà suivis sans passer par `git add`.
]

#corrige[
  #terminal[```console
  $ cd ~/collab/grace
  $ echo 'Contact : grace@example.org' >> README.md
  $ git commit -am "Adresse de contact"
  [main 461c264] Adresse de contact
   1 file changed, 1 insertion(+)
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     a22363e..461c264  main -> main
  $ cd ~/collab/ada
  # git status ne parle pas au dépôt central : il ne sait rien encore
  $ git status
  On branch main
  Your branch is up to date with 'origin/main'.

  nothing to commit, working tree clean
  $ git fetch
  # … (5 lignes de progression)
  From /root/collab/depot-central
     a22363e..461c264  main       -> origin/main
  $ git status
  On branch main
  Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded.
    (use "git pull" to update your local branch)

  nothing to commit, working tree clean
  $ git log --oneline --all
  a22363e (HEAD -> main) Ajout du README
  461c264 (origin/main) Adresse de contact
  $ git pull
  Updating a22363e..461c264
  Fast-forward
   README.md | 1 +
   1 file changed, 1 insertion(+)
  $ git log --oneline
  461c264 (HEAD -> main, origin/main) Adresse de contact
  a22363e Ajout du README
  ```]
  Avant `git fetch`, `git status` d’Ada ne sait rien : il compare `main` à `origin/main` telle qu’elle était à la dernière
  communication, sans interroger le dépôt central. `git fetch` rapatrie le commit de Grace et ne met à jour que
  `origin/main` : `main` d’Ada, son répertoire de travail et son index n’ont pas bougé ; `git status` voit alors le
  retard (`behind … by 1 commit`). `git pull` fait un `fetch`, puis intègre `origin/main` dans `main` : ici,
  `Fast-forward`, `main` n’a qu’à avancer, sans commit de fusion.
  #f("04-fetch-pull.sh")
]

= Étape 5 : publier une branche <etape-5>

#bloc(role: "question")[Consignes][
  - Dans le clone d’Ada, créez la branche `horaires` et sur elle un fichier `horaires.md` d’une ligne,
    `Ouvert le lundi, de 9 h à 17 h.`, enregistré dans « Horaires d’ouverture ». Publiez la branche.
  - Dans le clone de Grace, récupérez la branche, puis lisez `horaires.md` depuis une branche `horaires` locale.
    Revenez sur `main`.
  - Dans le clone d’Ada, fusionnez `horaires` dans `main`, publiez, puis mettez le clone de Grace à jour.
]

#indice(titre: [Indice : une branche locale qui suit le distant])[
  Après un `git fetch`, `git switch horaires` crée à partir de `origin/horaires` une branche locale du même nom, qui
  la suit. `git branch -a` montre `origin/horaires` : #d("pointeurs")[Branches et HEAD : de simples pointeurs].
]

#corrige[
  #terminal[```console
  $ cd ~/collab/ada
  $ git switch -c horaires
  Switched to a new branch 'horaires'
  $ echo 'Ouvert le lundi, de 9 h à 17 h.' > horaires.md
  $ git add horaires.md
  $ git commit -m "Horaires d'ouverture"
  [horaires bf8773c] Horaires d'ouverture
   1 file changed, 1 insertion(+)
   create mode 100644 horaires.md
  $ git push -u origin horaires
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
   * [new branch]      horaires -> horaires
  branch 'horaires' set up to track 'origin/horaires'.
  $ cd ~/collab/grace
  $ git fetch
  # … (5 lignes de progression)
  From /root/collab/depot-central
   * [new branch]      horaires   -> origin/horaires
  $ git branch -a
  * main
    remotes/origin/HEAD -> origin/main
    remotes/origin/horaires
    remotes/origin/main
  # une branche locale horaires, qui suit origin/horaires
  $ git switch horaires
  branch 'horaires' set up to track 'origin/horaires'.
  Switched to a new branch 'horaires'
  $ cat horaires.md
  Ouvert le lundi, de 9 h à 17 h.
  $ git switch main
  Switched to branch 'main'
  Your branch is up to date with 'origin/main'.
  $ cd ~/collab/ada
  $ git switch main
  Switched to branch 'main'
  Your branch is up to date with 'origin/main'.
  $ git merge horaires
  Updating 461c264..bf8773c
  Fast-forward
   horaires.md | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 horaires.md
  $ git push
  # … (1 lignes de progression)
  To /root/collab/depot-central.git
     461c264..bf8773c  main -> main
  $ cd ~/collab/grace
  $ git pull
  From /root/collab/depot-central
     461c264..bf8773c  main       -> origin/main
  Updating 461c264..bf8773c
  Fast-forward
   horaires.md | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 horaires.md
  $ git log --oneline -3
  bf8773c (HEAD -> main, origin/main, origin/horaires, origin/HEAD, horaires) Horaires d'ouverture
  461c264 Adresse de contact
  a22363e Ajout du README
  ```]
  `git push -u origin horaires` crée la branche sur le dépôt central. Grace ne la voit pas avant `git fetch`, qui
  ajoute `origin/horaires` ; `git switch horaires` crée alors une branche locale qui la suit
  (`set up to track 'origin/horaires'`). Côté Ada, `main` n’avait pas bougé : la fusion avance le pointeur
  (`Fast-forward`, #d("fusion")[Fusionner : avance rapide ou commit de fusion]). Le dernier `git log` de Grace montre
  les quatre étiquettes sur le même commit : `main`, `horaires` et leurs branches de suivi coïncident.
  #f("05-branche-poussee.sh")
]

= Étape 6 : deux commits en parallèle <etape-6>

#bloc(role: "question")[Consignes][
  - Dans le clone de Grace, créez `agenda.md` (`Réunion le jeudi.`), enregistrez « Agenda des réunions » et publiez.
  - Dans le clone d’Ada, sans rien récupérer d’abord, ajoutez à la fin de `horaires.md` la ligne
    `Fermé le dimanche.` et enregistrez « Fermeture du dimanche ». Essayez de publier : que répond Git, et pourquoi ?
  - Récupérez, puis lisez `git status` et le graphe de toutes les branches, limité à quatre commits.
  - Lancez `git pull` : que répond Git ? Intégrez ensuite par une fusion, en gardant le message proposé, puis publiez.
  - Mettez le clone de Grace à jour. Le commit de Grace a-t-il disparu de l’historique ?
]

#indice(titre: [Indice : le refus])[
  Un push n’est accepté que s’il fait avancer la branche distante en ligne droite : #d("push-refuse")[Push refusé : le distant a avancé].
  Ne forcez jamais (`--force`) sur une branche partagée : le commit de Grace disparaîtrait du dépôt central.
]
#indice(titre: [Indice : fusionner])[
  `git pull` refuse de choisir à votre place entre fusion et rebasage : #d("pull-divergent")[Pull sur une histoire divergente].
  `git pull --no-rebase` fusionne ; `--no-edit` garde le message de fusion proposé. `git log --oneline --graph --all -4`
  dessine le graphe : #d("log-graph")[Une branche se voit dans git log --graph].
]

#corrige[
  #terminal[```console
  $ cd ~/collab/grace
  $ echo 'Réunion le jeudi.' > agenda.md
  $ git add agenda.md
  $ git commit -m "Agenda des réunions"
  [main 802eae3] Agenda des réunions
   1 file changed, 1 insertion(+)
   create mode 100644 agenda.md
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     bf8773c..802eae3  main -> main
  $ cd ~/collab/ada
  $ echo 'Fermé le dimanche.' >> horaires.md
  $ git commit -am "Fermeture du dimanche"
  [main 72282e3] Fermeture du dimanche
   1 file changed, 1 insertion(+)
  # refus attendu : le dépôt central a un commit qu'Ada n'a pas
  $ git push
  To /root/collab/depot-central.git
   ! [rejected]        main -> main (fetch first)
  error: failed to push some refs to '/root/collab/depot-central.git'
  hint: Updates were rejected because the remote contains work that you do not
  hint: have locally. This is usually caused by another repository pushing to
  hint: the same ref. If you want to integrate the remote changes, use
  hint: 'git pull' before pushing again.
  hint: See the 'Note about fast-forwards' in 'git push --help' for details.
  $ git fetch
  # … (5 lignes de progression)
  From /root/collab/depot-central
     bf8773c..802eae3  main       -> origin/main
  $ git status
  On branch main
  Your branch and 'origin/main' have diverged,
  and have 1 and 1 different commits each, respectively.
    (use "git pull" if you want to integrate the remote branch with yours)

  nothing to commit, working tree clean
  $ git log --oneline --graph --all -4
  * 72282e3 (HEAD -> main) Fermeture du dimanche
  | * 802eae3 (origin/main) Agenda des réunions
  |/
  * bf8773c (origin/horaires, horaires) Horaires d'ouverture
  * 461c264 Adresse de contact
  # refus attendu : Git veut savoir s'il doit fusionner ou rebaser
  $ git pull
  hint: You have divergent branches and need to specify how to reconcile them.
  hint: You can do so by running one of the following commands sometime before
  hint: your next pull:
  hint:
  hint:   git config pull.rebase false  # merge
  hint:   git config pull.rebase true   # rebase
  hint:   git config pull.ff only       # fast-forward only
  hint:
  hint: You can replace "git config" with "git config --global" to set a default
  hint: preference for all repositories. You can also pass --rebase, --no-rebase,
  hint: or --ff-only on the command line to override the configured default per
  hint: invocation.
  fatal: Need to specify how to reconcile divergent branches.
  $ git pull --no-rebase --no-edit
  Merge made by the 'ort' strategy.
   agenda.md | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 agenda.md
  $ git log --oneline --graph -4
  *   5431269 (HEAD -> main) Merge branch 'main' of /root/collab/depot-central
  |\
  | * 802eae3 (origin/main) Agenda des réunions
  * | 72282e3 Fermeture du dimanche
  |/
  * bf8773c (origin/horaires, horaires) Horaires d'ouverture
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     802eae3..5431269  main -> main
  $ cd ~/collab/grace
  $ git pull
  # … (5 lignes de progression)
  From /root/collab/depot-central
     802eae3..5431269  main       -> origin/main
  Updating 802eae3..5431269
  Fast-forward
   horaires.md | 1 +
   1 file changed, 1 insertion(+)
  ```]
  Le dépôt central a un commit que le clone d’Ada n’a pas : le publier tel quel le ferait disparaître, Git refuse
  (`rejected … (fetch first)`). Après `git fetch`, le graphe montre la divergence : un commit de chaque côté de
  `Horaires d’ouverture`, et `git status` le dit en mots (`have diverged`). `git pull` s’arrête : depuis Git 2.27,
  il exige de choisir. `--no-rebase` fusionne : le commit de fusion a deux parents, celui d’Ada et celui de Grace ;
  rien n’est perdu. Les deux commits portent sur deux fichiers différents, donc aucun conflit. Le chemin du dépôt
  central dans le message de fusion (`of /root/collab/depot-central`) est celui d’ici ; sur une forge, ce serait son adresse.
  #f("06-divergence.sh")
]

= Étape 7 : un conflit <etape-7>

#bloc(role: "question")[Consignes][
  - Dans le clone de Grace, remplacez la ligne `Site du club` de `README.md` par `Site du club de lecture`,
    enregistrez « Titre précisé » et publiez.
  - Dans le clone d’Ada, remplacez cette même ligne par `Site du club de code`, enregistrez « Titre complété »,
    publiez : refus. Intégrez par une fusion. Que se passe-t-il ? Lisez `git status --short` et `README.md`.
  - Résolvez en gardant les deux intentions : `Site des clubs de lecture et de code`, les autres lignes inchangées.
    Terminez la fusion en gardant le message proposé, publiez, puis mettez le clone de Grace à jour.
]

#indice(titre: [Indice : lire le conflit])[
  Entre `<<<<<<< HEAD` et `=======`, la version de la branche courante, celle d’Ada ; entre `=======` et
  `>>>>>>>`, celle que l’on fusionne, ici le commit de Grace, désigné par son identifiant :
  #d("conflit")[Conflit : deux modifications de la même ligne]. `sed -i 's/avant/après/' fichier` fait un remplacement.
]
#indice(titre: [Indice : résoudre])[
  Éditer le fichier (avec Vim, supprimez les trois lignes de marqueurs et la version que vous ne gardez pas, puis
  réécrivez le titre), `git add`, `git commit` : #d("resoudre")[Résoudre un conflit, puis terminer la fusion].
  `git commit --no-edit` garde le message proposé ; `git merge --abort` abandonnerait la fusion.
]

#corrige[
  #terminal[```console
  $ cd ~/collab/grace
  $ sed -i 's/^Site du club$/Site du club de lecture/' README.md
  $ git commit -am "Titre précisé"
  [main 778d4fa] Titre précisé
   1 file changed, 1 insertion(+), 1 deletion(-)
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     5431269..778d4fa  main -> main
  $ cd ~/collab/ada
  $ sed -i 's/^Site du club$/Site du club de code/' README.md
  $ git commit -am "Titre complété"
  [main 0bec319] Titre complété
   1 file changed, 1 insertion(+), 1 deletion(-)
  $ git push
  To /root/collab/depot-central.git
   ! [rejected]        main -> main (fetch first)
  error: failed to push some refs to '/root/collab/depot-central.git'
  hint: Updates were rejected because the remote contains work that you do not
  hint: have locally. This is usually caused by another repository pushing to
  hint: the same ref. If you want to integrate the remote changes, use
  hint: 'git pull' before pushing again.
  hint: See the 'Note about fast-forwards' in 'git push --help' for details.
  # conflit attendu : la première ligne de README.md a changé des deux côtés
  $ git pull --no-rebase --no-edit
  # … (5 lignes de progression)
  From /root/collab/depot-central
     5431269..778d4fa  main       -> origin/main
  Auto-merging README.md
  CONFLICT (content): Merge conflict in README.md
  Automatic merge failed; fix conflicts and then commit the result.
  $ git status --short
  UU README.md
  $ cat README.md
  <<<<<<< HEAD
  Site du club de code
  =======
  Site du club de lecture
  >>>>>>> 778d4fa4299715d1ca1ca779466b0fa5dc58ffc1

  Responsable : Ada.
  Contact : grace@example.org
  # on édite README.md (avec Vim…) : un seul titre, sans marqueurs ; ici, printf réécrit le fichier
  $ printf '%s\n' 'Site des clubs de lecture et de code' '' 'Responsable : Ada.' 'Contact : grace@example.org' > README.md
  $ cat README.md
  Site des clubs de lecture et de code

  Responsable : Ada.
  Contact : grace@example.org
  $ git add README.md
  $ git commit --no-edit
  [main 0458e2c] Merge branch 'main' of /root/collab/depot-central
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     778d4fa..0458e2c  main -> main
  $ git log --oneline --graph -4
  *   0458e2c (HEAD -> main, origin/main) Merge branch 'main' of /root/collab/depot-central
  |\
  | * 778d4fa Titre précisé
  * | 0bec319 Titre complété
  |/
  *   5431269 Merge branch 'main' of /root/collab/depot-central
  |\
  $ cd ~/collab/grace
  $ git pull
  # … (5 lignes de progression)
  From /root/collab/depot-central
     778d4fa..0458e2c  main       -> origin/main
  Updating 778d4fa..0458e2c
  Fast-forward
   README.md | 2 +-
   1 file changed, 1 insertion(+), 1 deletion(-)
  ```]
  Le conflit est le même qu’au TP précédent ; seule diffère l’origine de la branche fusionnée : `origin/main`, récupérée
  par `git pull`. Le push d’Ada est refusé, comme à l’étape 6 ; `git pull` fait `fetch` puis fusion, et s’arrête sur la
  ligne modifiée des deux côtés (`UU`). Après résolution, `git add` puis `git commit` terminent la fusion, que
  le `git push` publie. Le clone de Grace n’a plus qu’à avancer. Dans le corrigé, un `printf` réécrit le fichier ; vous
  l’aurez édité à la main.
  #f("07-conflit.sh")
]

= Étape 8 : rebaser avant de publier <etape-8>

#bloc(role: "question")[Consignes][
  - Dans le clone de Grace, changez `agenda.md` en `Réunion le jeudi, à 18 h.`, enregistrez « Heure des réunions »
    et publiez.
  - Dans le clone d’Ada, ajoutez à la fin de `horaires.md` la ligne `Fermé les jours fériés.`, enregistrez
    « Jours fériés », publiez : refus, comme aux étapes 6 et 7.
  - Cette fois, au lieu de fusionner, rejouez le commit d’Ada au-dessus de celui de Grace, en une seule commande.
    Lisez le graphe : y a-t-il un commit de fusion de plus ? Comparez l’identifiant du commit « Jours fériés » avant
    et après.
  - Publiez, puis mettez le clone de Grace à jour.
]

#indice(titre: [Indice : la commande])[
  `git pull --rebase` fait `fetch`, puis rejoue vos commits locaux au-dessus de `origin/main` :
  #d("rebasage")[Rebaser : rejouer ses commits ailleurs]. Le commit d’Ada n’a jamais quitté son clone : la
  règle de #d("fusionner-ou-rebaser")[Fusionner ou rebaser ?] (ne jamais rebaser ce qui est publié) est respectée.
]

#corrige[
  #terminal[```console
  $ cd ~/collab/grace
  $ echo 'Réunion le jeudi, à 18 h.' > agenda.md
  $ git commit -am "Heure des réunions"
  [main 222b577] Heure des réunions
   1 file changed, 1 insertion(+), 1 deletion(-)
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     0458e2c..222b577  main -> main
  $ cd ~/collab/ada
  $ echo 'Fermé les jours fériés.' >> horaires.md
  $ git commit -am "Jours fériés"
  [main d091dab] Jours fériés
   1 file changed, 1 insertion(+)
  $ git push
  To /root/collab/depot-central.git
   ! [rejected]        main -> main (fetch first)
  error: failed to push some refs to '/root/collab/depot-central.git'
  hint: Updates were rejected because the remote contains work that you do not
  hint: have locally. This is usually caused by another repository pushing to
  hint: the same ref. If you want to integrate the remote changes, use
  hint: 'git pull' before pushing again.
  hint: See the 'Note about fast-forwards' in 'git push --help' for details.
  $ git pull --rebase
  # … (5 lignes de progression)
  From /root/collab/depot-central
     0458e2c..222b577  main       -> origin/main
  Successfully rebased and updated refs/heads/main.
  $ git log --oneline --graph -3
  * 90e0701 (HEAD -> main) Jours fériés
  * 222b577 (origin/main) Heure des réunions
  *   0458e2c Merge branch 'main' of /root/collab/depot-central
  |\
  $ git push
  # … (6 lignes de progression)
  To /root/collab/depot-central.git
     222b577..90e0701  main -> main
  $ cd ~/collab/grace
  $ git pull
  # … (5 lignes de progression)
  From /root/collab/depot-central
     222b577..90e0701  main       -> origin/main
  Updating 222b577..90e0701
  Fast-forward
   horaires.md | 1 +
   1 file changed, 1 insertion(+)
  $ git log --oneline --graph -3
  * 90e0701 (HEAD -> main, origin/main, origin/HEAD) Jours fériés
  * 222b577 Heure des réunions
  *   0458e2c Merge branch 'main' of /root/collab/depot-central
  |\
  ```]
  Git retire le commit d’Ada, avance sur `origin/main`, puis le rejoue au-dessus : l’historique reste une ligne droite,
  sans commit de fusion. Le commit a un nouvel identifiant (`7648e07` à l’enregistrement, `e6156f1` après le
  rebasage, dans le relevé) : même contenu, même message, mais un autre parent, donc une autre empreinte. Le push
  qui suit est une avance rapide. Un rebasage qui rencontre un conflit s’arrête sur le commit en cause : on résout,
  `git add`, puis `git rebase --continue` (ou `git rebase --abort`).

  Fusion ou rebasage ? L’un garde l’histoire telle qu’elle s’est déroulée, l’autre la rend linéaire ; chaque équipe
  fixe sa règle, et `git config --global pull.rebase true` la fait appliquer par défaut à `git pull`.
  #f("08-rebasage.sh")
]

= Étape 9 (facultative) : et sur une forge ? <etape-9>

Sur GitHub, GitLab ou Codeberg, le dépôt central est hébergé et les deux collaboratrices n’ont pas de dossier commun
sur le disque. Les commandes sont les mêmes ; seule l’adresse change. La différence est ailleurs : on ne pousse plus
sur `main`, on publie une branche, puis on ouvre une _demande de fusion_, qu’un collègue relit
(#d("demande-de-fusion")[Branches et demandes de fusion]).

#bloc(role: "question")[Consignes][
  - Créez un dépôt vide sur la forge de votre choix, et copiez son adresse. Sans compte, remplacez-le par un second
    dépôt nu, `~/forge.git`, comme au début de l’étape 1 : l’adresse est alors son chemin.
  - Dans le clone d’Ada, déclarez ce dépôt comme second distant, nommé `forge`, et publiez-y `main`.
  - Créez la branche `presentation`, ajoutez à `README.md` la ligne `Le club se réunit pour lire, coder et partager.`,
    enregistrez « Présentation du club », et publiez la branche sur `forge`.
  - Revenez sur `main`. Dans l’interface de la forge, ouvrez une demande de fusion de `presentation` vers `main`.
]

#indice(titre: [Indice : deux distants])[
  `git remote add` peut ajouter autant de distants que l’on veut, chacun avec son nom : `origin` reste le dépôt central.
  `git push -u forge presentation` nomme le distant.
]

#corrige[
  #terminal[```console
  $ git init --bare -b main ~/forge.git
  Initialized empty Git repository in /root/forge.git/
  $ cd ~/collab/ada
  $ git remote add forge ~/forge.git
  $ git remote -v
  forge	/root/forge.git (fetch)
  forge	/root/forge.git (push)
  origin	/root/collab/depot-central.git (fetch)
  origin	/root/collab/depot-central.git (push)
  $ git push forge main
  # … (6 lignes de progression)
  To /root/forge.git
   * [new branch]      main -> main
  $ git switch -c presentation
  Switched to a new branch 'presentation'
  $ echo 'Le club se réunit pour lire, coder et partager.' >> README.md
  $ git commit -am "Présentation du club"
  [presentation 463ae89] Présentation du club
   1 file changed, 1 insertion(+)
  $ git push -u forge presentation
  # … (6 lignes de progression)
  To /root/forge.git
   * [new branch]      presentation -> presentation
  branch 'presentation' set up to track 'forge/presentation'.
  $ git switch main
  Switched to branch 'main'
  Your branch is up to date with 'origin/main'.
  # puis, dans l'interface web de la forge : ouvrir une demande de fusion de presentation vers main
  ```]
  Le dépôt a maintenant deux distants : `origin` n’a pas changé et ne reçoit pas `presentation`. `main` suit toujours
  `origin/main`, et `presentation` suit `forge/presentation`. La demande de fusion n’est pas une commande Git :
  c’est une fonction de la forge, qui montre les différences, recueille la relecture et lance les tests.
  Sans réseau (la VM de cette page), seul le second dépôt nu est possible ; une vraie forge demande aussi une
  authentification, de préférence par clé SSH (cours Accès distants). Le script du corrigé prend l’adresse en
  argument : `./09-forge.sh ~/forge.git`, ou celle de la forge.
  #f("09-forge.sh")
]

#bloc(role: "retenir")[Ce que ce TP a montré][
  - Un dépôt nu fait office de dépôt central ; chaque clone est complet, avec `origin` et des branches de suivi.
  - `fetch` récupère sans toucher à vos branches ; `pull` récupère, puis intègre ; `push` publie, s’il avance en ligne droite.
  - Un push refusé n’est pas une panne : le dépôt central a avancé. On intègre d’abord, par fusion ou par rebasage, puis on publie.
  - On rebase ses propres commits avant de les publier, jamais ceux que d’autres ont déjà.
  - Sur une forge, on publie une branche et on demande sa fusion.
]

Retour au #link("../git-local/index.html")[TP Git en local], ou aux #d("annuler")[diapos sur l’annulation] avant de défaire ce que d’autres ont déjà reçu.
