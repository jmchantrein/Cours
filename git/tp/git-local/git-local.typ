// TP « Git en local » — page web compilée par Typst (voir commun/README.md, « Pages web »).
// Compilation (depuis la racine du dépôt) :
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     git/tp/git-local/git-local.typ build/git/git-local.html
// Les corrigés sont les fichiers de corrige/, exécutés et vérifiés par tester.sh --up : la page les affiche tels quels.
// Sorties des terminaux : relevées par tester.sh --releve dans debian:13-slim (Git 2.47.3, identité et dates fixées, messages en anglais ; dossier personnel remplacé par /root).
// Dans un terminal, les commandes « cd » sont écrites sans le « || exit 1 » des scripts : un cd raté ne ferme pas le shell.

#import "../../../commun/theme-tp.typ": *

#let pdf = "../../cm/git-projection.pdf"
// Renvoi vers une diapositive du cours, par l’étiquette de son titre.
#let d(ancre, corps) = diapo(pdf, ancre, corps)
// Fichier du corrigé.
#let f(chemin) = fichier("corrige/" + chemin, read("corrige/" + chemin))

#show: page-web.with(
  titre: [Git en local],
  surtitre: [Git : versionner et collaborer · travaux pratiques],
  sous-titre: [Un dépôt, des commits, des branches, un conflit, puis toutes les façons de revenir en arrière],
  auteur: [Jean-Mathieu Chantrein],
  date: [novembre 2026],
  illustration-couverture: "couches",
  terminal: ("vm", "compagnon"),
  depart: (ici: "~"),   // état de départ : la VM l’installe à son démarrage
  liens: (
    ([Diapos du cours], pdf),
    ([TP suivant : Git à plusieurs], "../git-distant/index.html"),
    ([Corrigés], "https://github.com/jmchantrein/Cours/tree/main/git/tp/git-local/corrige"),
    ([Pro Git], "https://git-scm.com/book/fr/v2"),
  ),
)

= Avant de commencer <avant>

Vous versionnez un petit site web, `mon_projet`, de son premier fichier à son premier conflit, puis vous
défaites votre travail de toutes les façons que Git connaît. Chaque étape reprend une notion du cours :
#d("trois-zones")[Trois zones : travail, index, dépôt], #d("graphe")[Le graphe des commits],
#d("annuler")[Annuler : quelle commande pour quoi ?].

#bloc(role: "pratique")[Prérequis][
  - Git 2.28 ou plus récent, pour `git init -b main`.
  - Un terminal : celui de cette page (une VM Linux dans le navigateur, rien à installer, tout s’efface à la
    fermeture de la page), ou le vôtre.
  - Un éditeur dans le terminal, Vim ou nano, pour écrire les fichiers et résoudre le conflit.
]

#bloc[Indices et corrigés][
  Chaque étape propose des indices, puis un corrigé, repliés. Chaque corrigé est un script réel, que le harnais du
  TP exécute dans un dossier jetable, étape après étape, en vérifiant l’état du dépôt (`git status`,
  `git log`, contenu des fichiers, branches). Les sorties montrées viennent de Git 2.47.3, en anglais.
]

#note(role: "precaution")[
  Vos identifiants de commit ne seront pas ceux du corrigé : un identifiant est l’empreinte du contenu, de
  l’auteur et de la date (#d("empreinte")[Un identifiant est l’empreinte du contenu]). Aucune étape ne vous
  demande de recopier un identifiant du corrigé : lisez les vôtres avec `git log --oneline`. Le corrigé a les
  identifiants des diapos parce que son identité et ses dates sont fixées.
]

= Étape 1 : se présenter à Git, créer le dépôt <etape-1>

#bloc(role: "question")[Consignes][
  - Vérifiez la version de Git.
  - Inscrivez votre nom et votre adresse dans la configuration globale de Git, puis affichez cette configuration.
  - Dans votre dossier personnel, créez le répertoire `mon_projet` et faites-en un dépôt Git dont la branche
    s’appelle `main`.
  - Que contient ce répertoire ? Où en est le dépôt ?
]

#indice(titre: [Indice : l’identité])[
  `git config --global` écrit dans `~/.gitconfig` : #d("se-presenter")[Installer Git et se présenter]. Le nom et
  l’adresse figurent dans chaque commit, que d’autres liront.
]
#indice(titre: [Indice : le dépôt])[
  `git init -b main` : #d("git-init")[Créer un dépôt : git init]. `ls -A` montre aussi les fichiers cachés ;
  `git status` dit où en est le dépôt. Sans `-b main`, Git 2.47 crée une branche `master` et affiche des
  conseils : #d("sans-b-main")[Sans -b main].
]

#corrige[
  #terminal[```console
  $ git --version
  git version 2.47.3
  $ git config --global user.name "Ada Lovelace"
  $ git config --global user.email ada@example.org
  $ git config --global --list
  user.name=Ada Lovelace
  user.email=ada@example.org
  $ cd ~
  $ mkdir mon_projet
  $ cd mon_projet
  $ git init -b main
  Initialized empty Git repository in /root/mon_projet/.git/
  $ ls -A
  .git
  $ git status
  On branch main

  No commits yet

  nothing to commit (create/copy files and use "git add" to track)
  ```]
  Le dépôt, c’est le dossier caché `.git` : historique, index et configuration du dépôt. Le supprimer retire le
  suivi de versions ; les fichiers restent. Le chemin affiché est celui du relevé ; chez vous, votre dossier
  personnel (`/root` dans la VM de la page).
  #f("01-identite-depot.sh")
]

= Étape 2 : le premier commit <etape-2>

#bloc(role: "question")[Consignes][
  - Avec Vim, ou avec `echo`, créez dans `mon_projet` un fichier `index.html` d’une ligne :
    `<h1>Bienvenue sur mon site</h1>`.
  - Affichez l’état du dépôt au format court, ajoutez le fichier à l’index, puis affichez de nouveau l’état :
    que signifient les deux codes ?
  - Enregistrez un commit de message « Ajout de la page d’accueil ». Que dit `git status` ensuite ?
]

#indice(titre: [Indice : le cycle])[
  Modifier, indexer, enregistrer : #d("cycle")[Le cycle : modifier, indexer, enregistrer]. Le format court :
  `git status --short`.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ echo '<h1>Bienvenue sur mon site</h1>' > index.html
  $ git status --short
  ?? index.html
  $ git add index.html
  $ git status --short
  A  index.html
  $ git commit -m "Ajout de la page d'accueil"
  [main (root-commit) 30b6212] Ajout de la page d'accueil
   1 file changed, 1 insertion(+)
   create mode 100644 index.html
  $ git status
  On branch main
  nothing to commit, working tree clean
  ```]
  `??` : fichier non suivi, que Git voit sans l’enregistrer ; `A` : ajouté à l’index (première colonne).
  `root-commit` : le premier commit, sans parent. `working tree clean` : le répertoire de travail, l’index et le
  dernier commit ont le même contenu.
  #f("02-premier-commit.sh")
]

= Étape 3 : l’index <etape-3>

#bloc(role: "question")[Consignes][
  - Ajoutez à la fin de `index.html` la ligne `<p>Ceci est un paragraphe.</p>`, puis affichez l’état court.
  - Sans `git add`, tentez `git commit -m "Ajout d'un paragraphe"`. Que se passe-t-il, et pourquoi ?
  - Enregistrez ce commit pour de bon. Quelle colonne de `git status --short` a changé entre-temps ?
]

#indice(titre: [Indice : ce qu’un commit enregistre])[
  Un commit enregistre l’index, pas le répertoire de travail : #d("trois-zones")[Trois zones]. `>>` ajoute une
  ligne à la fin d’un fichier ; `>` le remplacerait.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ echo '<p>Ceci est un paragraphe.</p>' >> index.html
  $ git status --short
   M index.html
  # sans git add, l'index n'a pas changé : git commit refuse, rien n'est enregistré
  $ git commit -m "Ajout d'un paragraphe"
  On branch main
  Changes not staged for commit:
    (use "git add <file>..." to update what will be committed)
    (use "git restore <file>..." to discard changes in working directory)
  	modified:   index.html

  no changes added to commit (use "git add" and/or "git commit -a")
  $ git add index.html
  $ git status --short
  M  index.html
  $ git commit -m "Ajout d'un paragraphe"
  [main 286f82b] Ajout d'un paragraphe
   1 file changed, 1 insertion(+)
  ```]
  ` M` (seconde colonne) : modifié dans le répertoire de travail, pas dans l’index. L’index contient encore la
  version du premier commit : il n’y a rien de nouveau à enregistrer. Après `git add`, `M ` (première colonne) :
  la modification est dans l’index, prête pour le commit. `git add` indexe un état du fichier : il faut le
  refaire après chaque modification.

  La forme `git commit index.html -m "…"` du cours d’origine enregistre directement le contenu actuel du fichier
  nommé, sans passer par l’index (#link("https://git-scm.com/docs/git-commit")[git-commit(1)]) ; le cours sépare
  `git add` et `git commit`, qui rend l’index visible.
  #f("03-index.sh")
]

= Étape 4 : voir ce qui change <etape-4>

#bloc(role: "question")[Consignes][
  - Ajoutez à la fin de `index.html` un lien vers la future page de contact :
    `<p><a href="contact.html">Contact</a></p>`.
  - Affichez l’écart entre le répertoire de travail et l’index. Lisez la sortie : que signifient `+` et
    `@@ -1,2 +1,3 @@` ?
  - Indexez le fichier, puis refaites la même commande : que voyez-vous ? Quelle commande montre ce qui entrera
    dans le prochain commit ?
  - Enregistrez le commit « Lien vers la page contact ».
]

#indice(titre: [Indice : deux écarts])[
  `git diff` compare le répertoire de travail à l’index ; `git diff --staged`, l’index au dernier commit :
  #d("diff")[Voir ce qui change : git diff].
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ echo '<p><a href="contact.html">Contact</a></p>' >> index.html
  $ git diff
  diff --git a/index.html b/index.html
  index 1031066..03d2992 100644
  --- a/index.html
  +++ b/index.html
  @@ -1,2 +1,3 @@
   <h1>Bienvenue sur mon site</h1>
   <p>Ceci est un paragraphe.</p>
  +<p><a href="contact.html">Contact</a></p>
  $ git add index.html
  # plus rien entre le répertoire de travail et l'index
  $ git diff
  $ git diff --staged
  diff --git a/index.html b/index.html
  index 1031066..03d2992 100644
  --- a/index.html
  +++ b/index.html
  @@ -1,2 +1,3 @@
   <h1>Bienvenue sur mon site</h1>
   <p>Ceci est un paragraphe.</p>
  +<p><a href="contact.html">Contact</a></p>
  $ git commit -m "Lien vers la page contact"
  [main edde4ea] Lien vers la page contact
   1 file changed, 1 insertion(+)
  ```]
  `+` marque une ligne ajoutée, `-` une ligne retirée ; `@@ -1,2 +1,3 @@` : les lignes 1 et 2 avant, les lignes 1 à
  3 après. Après `git add`, `git diff` ne montre plus rien : la modification est passée dans l’index, et
  `git diff --staged` la montre à l’identique. Relire `git diff --staged` avant chaque commit, c’est relire ce
  qu’on enregistre.
  #f("04-diff.sh")
]

= Étape 5 : lire l’historique <etape-5>

#bloc(role: "question")[Consignes][
  - Affichez l’historique complet, puis un commit par ligne.
  - Combien de commits compte-t-il ? Dans quel ordre sont-ils affichés ?
  - Notez l’identifiant court de votre premier commit : vous vous en servirez à l’étape 10 d.
  - Vos identifiants sont-ils ceux du corrigé ? Pourquoi ?
]

#indice(titre: [Indice : les commandes])[
  `git log`, puis `git log --oneline` : #d("log")[Lire l’historique : git log]. Dans un terminal, `git log`
  ouvre un afficheur : la touche `q` le quitte. `wc -l` compte des lignes.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ git log
  commit edde4ead519f2d6f5cc968fb419fab7908a2e817 (HEAD -> main)
  Author: Ada Lovelace <ada@example.org>
  Date:   Wed Nov 25 10:00:00 2026 +0100

      Lien vers la page contact

  commit 286f82be85f6361d95d0469b15e617bb42f376e0
  Author: Ada Lovelace <ada@example.org>
  Date:   Wed Nov 25 10:00:00 2026 +0100

      Ajout d'un paragraphe

  commit 30b62123f5f917cc83446434c6e38aa37bc55223
  Author: Ada Lovelace <ada@example.org>
  Date:   Wed Nov 25 10:00:00 2026 +0100

      Ajout de la page d'accueil
  $ git log --oneline
  edde4ea (HEAD -> main) Lien vers la page contact
  286f82b Ajout d'un paragraphe
  30b6212 Ajout de la page d'accueil
  # le premier commit : la dernière ligne
  $ git log --oneline | tail -n 1
  30b6212 Ajout de la page d'accueil
  $ git log --oneline | wc -l
  3
  ```]
  Trois commits, du plus récent au plus ancien. Vos identifiants diffèrent : l’identifiant d’un commit est
  l’empreinte de son contenu, qui comprend votre nom, votre adresse, la date et l’identifiant du parent
  (#d("objets")[Trois objets : blob, arbre, commit]). Le relevé du corrigé fixe identité et dates : il retrouve les
  identifiants des diapos.
  #f("05-log.sh")
]

= Étape 6 : ignorer des fichiers <etape-6>

#bloc(role: "question")[Consignes][
  - Créez un journal vide `acces.log`, et un fichier `secrets/bdd.txt` qui contient un mot de passe factice.
    Affichez l’état court.
  - Écrivez un `.gitignore` qui écarte les fichiers en `.log` et le répertoire `secrets/`, avec un commentaire
    au-dessus de chaque règle. Affichez de nouveau l’état court.
  - Faites dire à Git quelle règle ignore chacun des deux fichiers.
  - Enregistrez le `.gitignore` dans le commit « Fichiers à ignorer ».
]

#indice(titre: [Indice : .gitignore])[
  Un motif par ligne, `#` pour un commentaire, `/` final pour un répertoire ; `git check-ignore -v` nomme la règle :
  #d("gitignore")[.gitignore : ne pas suivre ce qui ne doit pas l’être]. `printf '%s\n' …` écrit une ligne par
  argument.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ touch acces.log
  $ mkdir -p secrets
  $ echo "mot-de-passe" > secrets/bdd.txt
  $ git status --short
  ?? acces.log
  ?? secrets/
  $ printf '%s\n' '# journaux' '*.log' '# jamais de secret dans le dépôt' 'secrets/' > .gitignore
  $ git status --short
  ?? .gitignore
  $ git check-ignore -v acces.log secrets/bdd.txt
  .gitignore:2:*.log	acces.log
  .gitignore:4:secrets/	secrets/bdd.txt
  $ git add .gitignore
  $ git commit -m "Fichiers à ignorer"
  [main 3722911] Fichiers à ignorer
   1 file changed, 4 insertions(+)
   create mode 100644 .gitignore
  ```]
  Les deux fichiers restent sur le disque ; Git ne les propose plus. Le `.gitignore` se versionne : ses règles
  valent pour quiconque clone le dépôt. Il n’agit que sur les fichiers non suivis : un fichier déjà enregistré
  le reste. Un vrai secret n’a rien à faire dans le répertoire du projet.
  #f("06-gitignore.sh")
]

= Étape 7 : une branche <etape-7>

#bloc(role: "question")[Consignes][
  - Créez la branche `contact` et placez-vous dessus.
  - Créez `contact.html`, d’une ligne : `<p>Écrire à ada@example.org</p>` (ou votre adresse), et enregistrez le
    commit « Ajout de la page contact ».
  - Listez les branches. Dessinez sur papier le graphe des commits et la place de `main`, `contact` et `HEAD`,
    puis comparez avec le graphe que dessine Git, toutes branches comprises.
  - Revenez sur `main`. Où est passé `contact.html` ?
]

#indice(titre: [Indice : les commandes])[
  `git switch -c` crée une branche et s’y place : #d("pointeurs")[Branches et HEAD : de simples pointeurs].
  `git branch`, puis `git log --oneline --graph --all` : #d("log-graph")[Une branche se voit dans git log --graph].
  L’artefact #link("../../artefacts/graphe-git/")[Le graphe des commits] dessine le graphe et les pointeurs à chaque commande.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ git switch -c contact
  Switched to a new branch 'contact'
  $ echo '<p>Écrire à ada@example.org</p>' > contact.html
  $ git add contact.html
  $ git commit -m "Ajout de la page contact"
  [contact 9678ee5] Ajout de la page contact
   1 file changed, 1 insertion(+)
   create mode 100644 contact.html
  $ git branch
  * contact
    main
  $ git log --oneline --graph --all
  * 9678ee5 (HEAD -> contact) Ajout de la page contact
  * 3722911 (main) Fichiers à ignorer
  * edde4ea Lien vers la page contact
  * 286f82b Ajout d'un paragraphe
  * 30b6212 Ajout de la page d'accueil
  $ git switch main
  Switched to branch 'main'
  $ ls
  acces.log  index.html  secrets
  ```]
  Le commit a fait avancer la branche courante, `contact`, et elle seule ; `main` est resté sur « Fichiers à
  ignorer ». `git switch main` remet dans le répertoire de travail les fichiers du commit de `main` :
  `contact.html` disparaît du disque, pas du dépôt.
  #f("07-branche.sh")
]

= Étape 8 : fusionner <etape-8>

#bloc(role: "question")[Consignes][
  - Fusionnez `contact` dans `main`. Quelle sorte de fusion Git fait-il, et pourquoi ? Supprimez la branche
    `contact`.
  - Créez la branche `style`, et sur elle un fichier `style.css` d’une ligne, `h1 { color: navy; }`, enregistré
    dans « Ajout d’une feuille de style ».
  - Revenez sur `main`, ajoutez à `contact.html` la ligne `<p>Réponse sous 48 h.</p>` et enregistrez « Délai de
    réponse ». Affichez le graphe de toutes les branches.
  - Fusionnez `style` dans `main`, avec le message « Fusion de la branche style ». Combien de parents a ce
    commit ? Supprimez la branche `style`.
]

#indice(titre: [Indice : deux fusions])[
  Avance rapide quand la branche courante est un ancêtre de l’autre, commit de fusion sinon :
  #d("fusion")[Fusionner : avance rapide ou commit de fusion]. `git commit -am` indexe d’abord les fichiers déjà
  suivis ; `git merge -m` donne le message du commit de fusion ; `git branch -d` supprime une branche fusionnée.
  Les deux fusions se manipulent dans l’artefact #link("../../artefacts/graphe-git/")[Le graphe des commits].
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ git merge contact
  Updating 3722911..9678ee5
  Fast-forward
   contact.html | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 contact.html
  $ git branch -d contact
  Deleted branch contact (was 9678ee5).
  $ git switch -c style
  Switched to a new branch 'style'
  $ echo 'h1 { color: navy; }' > style.css
  $ git add style.css
  $ git commit -m "Ajout d'une feuille de style"
  [style ce686bd] Ajout d'une feuille de style
   1 file changed, 1 insertion(+)
   create mode 100644 style.css
  $ git switch main
  Switched to branch 'main'
  $ echo '<p>Réponse sous 48 h.</p>' >> contact.html
  $ git commit -am "Délai de réponse"
  [main 3f667f2] Délai de réponse
   1 file changed, 1 insertion(+)
  $ git log --oneline --graph --all
  * 3f667f2 (HEAD -> main) Délai de réponse
  | * ce686bd (style) Ajout d'une feuille de style
  |/
  * 9678ee5 Ajout de la page contact
  * 3722911 Fichiers à ignorer
  * edde4ea Lien vers la page contact
  * 286f82b Ajout d'un paragraphe
  * 30b6212 Ajout de la page d'accueil
  $ git merge style -m "Fusion de la branche style"
  Merge made by the 'ort' strategy.
   style.css | 1 +
   1 file changed, 1 insertion(+)
   create mode 100644 style.css
  $ git log --oneline --graph
  *   ceb297b (HEAD -> main) Fusion de la branche style
  |\
  | * ce686bd (style) Ajout d'une feuille de style
  * | 3f667f2 Délai de réponse
  |/
  * 9678ee5 Ajout de la page contact
  * 3722911 Fichiers à ignorer
  * edde4ea Lien vers la page contact
  * 286f82b Ajout d'un paragraphe
  * 30b6212 Ajout de la page d'accueil
  $ git branch -d style
  Deleted branch style (was ce686bd).
  ```]
  `main` n’avait pas bougé depuis la création de `contact` : Git avance le pointeur (`Fast-forward`), sans
  nouveau commit. Pour `style`, chaque branche a un commit depuis l’ancêtre commun : Git crée un commit de fusion
  à deux parents, `Délai de réponse` et `Ajout d'une feuille de style`. Supprimer une branche fusionnée ne
  supprime que le pointeur ; ses commits restent dans l’historique de `main`.
  #f("08-fusion.sh")
]

= Étape 9 : un conflit, résolu <etape-9>

#bloc(role: "question")[Consignes][
  - Sur une branche `titre`, remplacez « sur mon site » par « chez Ada » dans le titre de `index.html`, et
    enregistrez « Titre personnel ».
  - Sur `main`, remplacez « sur mon site » par « sur notre site », et enregistrez « Titre collectif ».
  - Fusionnez `titre` dans `main`. Que se passe-t-il ? Lisez `git status` et `index.html`.
  - Résolvez en gardant les deux intentions : `<h1>Bienvenue chez Ada et ses amis</h1>`. Terminez la fusion en
    gardant le message proposé par Git, puis supprimez la branche `titre`.
]

#indice(titre: [Indice : lire le conflit])[
  Entre `<<<<<<< HEAD` et `=======`, la version de la branche courante ; entre `=======` et `>>>>>>> titre`, celle
  de la branche fusionnée : #d("conflit")[Conflit : deux modifications de la même ligne].
  `sed -i 's/avant/après/' fichier` fait un remplacement.
]
#indice(titre: [Indice : résoudre])[
  Éditer, `git add`, `git commit` : #d("resoudre")[Résoudre un conflit, puis terminer la fusion].
  `git commit --no-edit` garde le message proposé ; `git merge --abort` annulerait toute la fusion.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ git switch -c titre
  Switched to a new branch 'titre'
  $ sed -i 's/sur mon site/chez Ada/' index.html
  $ git commit -am "Titre personnel"
  [titre 2bdce28] Titre personnel
   1 file changed, 1 insertion(+), 1 deletion(-)
  $ git switch main
  Switched to branch 'main'
  $ sed -i 's/sur mon site/sur notre site/' index.html
  $ git commit -am "Titre collectif"
  [main 0e72a0d] Titre collectif
   1 file changed, 1 insertion(+), 1 deletion(-)
  # conflit attendu : git merge s'arrête, avec un code de sortie non nul
  $ git merge titre
  Auto-merging index.html
  CONFLICT (content): Merge conflict in index.html
  Automatic merge failed; fix conflicts and then commit the result.
  $ git status
  On branch main
  You have unmerged paths.
    (fix conflicts and run "git commit")
    (use "git merge --abort" to abort the merge)

  Unmerged paths:
    (use "git add <file>..." to mark resolution)
  	both modified:   index.html

  no changes added to commit (use "git add" and/or "git commit -a")
  $ cat index.html
  <<<<<<< HEAD
  <h1>Bienvenue sur notre site</h1>
  =======
  <h1>Bienvenue chez Ada</h1>
  >>>>>>> titre
  <p>Ceci est un paragraphe.</p>
  <p><a href="contact.html">Contact</a></p>
  # on édite index.html (avec Vim…) : une seule ligne h1, sans marqueurs ; ici, printf réécrit le fichier
  $ printf '%s\n' '<h1>Bienvenue chez Ada et ses amis</h1>' '<p>Ceci est un paragraphe.</p>' '<p><a href="contact.html">Contact</a></p>' > index.html
  $ git add index.html
  $ git status --short
  M  index.html
  $ git commit --no-edit
  [main 055df61] Merge branch 'titre'
  $ git log --oneline --graph -4
  *   055df61 (HEAD -> main) Merge branch 'titre'
  |\
  | * 2bdce28 (titre) Titre personnel
  * | 0e72a0d Titre collectif
  |/
  *   ceb297b Fusion de la branche style
  |\
  $ git branch -d titre
  Deleted branch titre (was 2bdce28).
  ```]
  Git a fusionné ce qu’il pouvait (les deux autres lignes) et s’arrête sur la ligne modifiée des deux côtés : il
  refuse de choisir entre deux intentions. La résolution peut ne ressembler à aucune des deux versions. Après
  `git add`, le fichier est marqué résolu (`M ` au lieu de `UU`), et le commit termine la fusion. `-4` limite
  l’affichage aux quatre derniers commits : le `|\` final est le début de la fusion précédente.
  #f("09-conflit.sh")
]

= Étape 10 a : défaire une modification non enregistrée <etape-10a>

Les quatre dernières étapes défont du travail, de quatre façons : #d("annuler")[Annuler : quelle commande pour
quoi ?].

#bloc(role: "question")[Consignes][
  - Ajoutez « une erreur » à la fin de `index.html` (la ligne `<p>une erreur`), constatez-la avec `git status` et
    `git diff`, puis annulez cette modification, qui n’a jamais été enregistrée.
  - Recommencez, mais ajoutez l’erreur à l’index avant de vous en apercevoir. Il faut alors deux commandes :
    lesquelles, et dans quel ordre ?
]

#indice(titre: [Indice : restore])[
  `git restore` remet dans le fichier la version de l’index ; `git restore --staged`, dans l’index, la version du
  dernier commit : #d("restore")[restore : défaire une modification non enregistrée]. Le cours d’origine employait
  `git checkout`, l’ancienne forme : #d("checkout")[Ancienne syntaxe].
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ echo '<p>une erreur' >> index.html
  $ git status --short
   M index.html
  $ git diff
  diff --git a/index.html b/index.html
  index 1a21370..9f997f7 100644
  --- a/index.html
  +++ b/index.html
  @@ -1,3 +1,4 @@
   <h1>Bienvenue chez Ada et ses amis</h1>
   <p>Ceci est un paragraphe.</p>
   <p><a href="contact.html">Contact</a></p>
  +<p>une erreur
  $ git restore index.html
  $ git status --short
  $ echo '<p>une erreur' >> index.html
  $ git add index.html
  $ git status --short
  M  index.html
  $ git restore --staged index.html
  $ git status --short
   M index.html
  $ git restore index.html
  $ git status --short
  ```]
  Une sortie vide de `git status --short` : rien à signaler, le fichier est revenu à la version enregistrée.
  `--staged` défait seulement le `git add` (le `M` repasse dans la seconde colonne) ; le second `git restore`
  efface l’erreur du fichier. Une modification ainsi effacée n’a jamais été enregistrée : aucune commande ne la
  rendra.
  #f("10a-restore.sh")
]

= Étape 10 b : annuler un commit par un autre commit <etape-10b>

#bloc(role: "question")[Consignes][
  - Ajoutez à `index.html` la ligne `<p>Promotion : -50 % ce jour</p>` et enregistrez « Bandeau de promotion ».
  - Lisez l’identifiant de ce commit dans `git log --oneline -1`, et passez-le à `git revert` pour l’annuler, en
    gardant le message proposé.
  - Observez l’historique et `index.html` : que constatez-vous ?
]

#indice(titre: [Indice : revert])[
  #d("revert")[revert : annuler en ajoutant un commit]. `--no-edit` garde le message proposé par Git. `HEAD`
  désigne le dernier commit de la branche courante : il vaut ici l’identifiant que vous avez lu.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ echo '<p>Promotion : -50 % ce jour</p>' >> index.html
  $ git commit -am "Bandeau de promotion"
  [main 2a9743d] Bandeau de promotion
   1 file changed, 1 insertion(+)
  $ git log --oneline -1
  2a9743d (HEAD -> main) Bandeau de promotion
  # git revert prend l'identifiant lu ci-dessus ; HEAD désigne le même commit, le dernier
  $ git revert --no-edit HEAD
  [main 90923a0] Revert "Bandeau de promotion"
   Date: Wed Nov 25 10:00:00 2026 +0100
   1 file changed, 1 deletion(-)
  $ git log --oneline -3
  90923a0 (HEAD -> main) Revert "Bandeau de promotion"
  2a9743d Bandeau de promotion
  055df61 Merge branch 'titre'
  $ cat index.html
  <h1>Bienvenue chez Ada et ses amis</h1>
  <p>Ceci est un paragraphe.</p>
  <p><a href="contact.html">Contact</a></p>
  ```]
  Rien n’est supprimé : un nouveau commit défait les lignes du commit visé. Le bandeau a disparu du fichier, mais
  l’historique garde l’erreur et sa correction. `revert` fait avancer la branche sans réécrire l’historique :
  c’est la façon d’annuler un commit déjà publié. Avec votre identifiant, la commande s’écrit par exemple
  `git revert --no-edit 2a9743d`, et donne le même résultat.
  #f("10b-revert.sh")
]

= Étape 10 c : reset et ses trois modes <etape-10c>

#bloc(role: "question")[Consignes][
  - Ajoutez à `contact.html` la ligne `<p>Brouillon</p>` et enregistrez « Brouillon ».
  - Défaites ce commit par `git reset --soft HEAD~1`. Où est passée la modification ? Refaites le commit.
  - Défaites-le par `git reset HEAD~1` (le mode `--mixed`, par défaut). Même question ; refaites le commit.
  - Défaites-le par `git reset --hard HEAD~1`. Même question. Que reste-t-il dans `contact.html` ?
]

#indice(titre: [Indice : les trois modes])[
  Les trois modes déplacent la branche ; ils diffèrent par les zones qu’ils remettent à l’état du commit visé :
  #d("reset-modes")[reset : trois modes]. `HEAD~1` est le parent de `HEAD` ; `tail -n 1` affiche la dernière
  ligne d’un fichier. L’artefact #link("../../artefacts/graphe-git/")[Le graphe des commits] montre où va la branche, et ce que chaque mode fait de l’index et du répertoire.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ echo '<p>Brouillon</p>' >> contact.html
  $ git commit -am "Brouillon"
  [main 11019a7] Brouillon
   1 file changed, 1 insertion(+)
  # HEAD~1 : le parent de HEAD
  $ git reset --soft HEAD~1
  $ git status --short
  M  contact.html
  $ git commit -m "Brouillon"
  [main 11019a7] Brouillon
   1 file changed, 1 insertion(+)
  $ git reset HEAD~1
  Unstaged changes after reset:
  M	contact.html
  $ git status --short
   M contact.html
  $ git commit -am "Brouillon"
  [main 11019a7] Brouillon
   1 file changed, 1 insertion(+)
  $ git reset --hard HEAD~1
  HEAD is now at 90923a0 Revert "Bandeau de promotion"
  $ git status --short
  $ tail -n 1 contact.html
  <p>Réponse sous 48 h.</p>
  ```]
  `--soft` : la modification reste indexée (`M` à gauche) ; `--mixed` : elle reste dans le fichier, plus dans
  l’index (`M` à droite) ; `--hard` : elle a disparu, le fichier est celui du commit visé. Dans le relevé, le
  commit refait a chaque fois le même identifiant, `11019a7` : même contenu, même parent, même auteur et même
  date, fixée. Chez vous, la date change d’une seconde à l’autre, et l’identifiant avec elle.
  #f("10c-reset-modes.sh")
]

= Étape 10 d : revenir au premier commit, puis tout retrouver <etape-10d>

#bloc(role: "question")[Consignes][
  - Comptez les commits de l’historique.
  - Revenez au tout premier commit avec `git reset --hard`, en lui donnant l’identifiant noté à l’étape 5 (ou lu
    sur la dernière ligne de `git log --oneline`).
  - Observez l’historique et le répertoire : que constatez-vous ? Pourquoi `git status --short` montre-t-il de
    nouveau `acces.log` ?
  - Le reflog garde les positions passées de `HEAD` : retrouvez-y celle d’avant le `reset`, et revenez-y.
  - Quelle différence entre `git revert` et `git reset` ?
]

#indice(titre: [Indice : reflog])[
  `git reflog -3` affiche les trois dernières positions de `HEAD` ; `HEAD@{1}` désigne la position précédente :
  #d("reflog")[reflog : retrouver un commit « perdu »]. Le premier commit est le seul sans parent :
  `git rev-list --max-parents=0 HEAD` donne son identifiant sans le recopier.
]

#corrige[
  #terminal[```console
  $ cd ~/mon_projet
  $ git log --oneline | wc -l
  13
  # le premier commit est le seul sans parent : son identifiant, sans le recopier
  $ git rev-list --max-parents=0 HEAD
  30b62123f5f917cc83446434c6e38aa37bc55223
  $ git reset --hard "$(git rev-list --max-parents=0 HEAD)"
  HEAD is now at 30b6212 Ajout de la page d'accueil
  $ git log --oneline
  30b6212 (HEAD -> main) Ajout de la page d'accueil
  $ ls -A
  .git  acces.log  index.html  secrets
  $ git status --short
  ?? acces.log
  ?? secrets/
  $ git reflog -3
  30b6212 (HEAD -> main) HEAD@{0}: reset: moving to 30b62123f5f917cc83446434c6e38aa37bc55223
  90923a0 HEAD@{1}: reset: moving to HEAD~1
  11019a7 HEAD@{2}: commit: Brouillon
  # HEAD@{1} : la position de HEAD avant ce reset
  $ git reset --hard "HEAD@{1}"
  HEAD is now at 90923a0 Revert "Bandeau de promotion"
  $ git log --oneline | wc -l
  13
  $ git status --short
  ```]
  Avec l’identifiant que vous avez noté, la commande s’écrit par exemple `git reset --hard 30b6212`. Les douze
  commits suivants ont disparu de l’historique de `main`, sans trace du retour en arrière ; les fichiers suivis
  sont revenus à l’état du premier commit : `contact.html`, `style.css` et `.gitignore` ont disparu. `acces.log` et
  `secrets/` restent : `reset --hard` ne touche pas aux fichiers non suivis, et sans `.gitignore` plus rien ne les
  écarte. Les commits n’étaient pourtant pas perdus : le reflog les désigne encore, et `HEAD@{1}` ramène tout.

  `git revert` crée un nouveau commit qui annule les changements d’un commit précédent, sans altérer
  l’historique ; `git reset` déplace la branche et réécrit l’historique : intéressant si l’on ne veut pas garder
  trace du retour en arrière, mais destructeur, à réserver aux commits qui n’ont pas été publiés. L’un comme
  l’autre agit sur des commits entiers : si un commit touche plusieurs fichiers, tous sont concernés.
  #f("10d-reset-reflog.sh")
]

#bloc(role: "retenir")[Ce que ce TP a montré][
  - Un commit enregistre l’index : `git add` à chaque modification, `git diff --staged` pour relire.
  - Une branche est un pointeur ; une fusion avance le pointeur, ou crée un commit à deux parents.
  - Un conflit se résout à la main, puis `git add` et `git commit`.
  - `restore` défait des fichiers, `revert` ajoute un commit, `reset` déplace la branche, `reflog` retrouve.
  - On ne recopie pas d’identifiant : on lit le sien, ou on désigne un commit par sa position (`HEAD~1`, `HEAD@{1}`).
]

Suite : #link("../git-distant/index.html")[Git à plusieurs, sans forge], deux personnes autour d’un même dépôt.
