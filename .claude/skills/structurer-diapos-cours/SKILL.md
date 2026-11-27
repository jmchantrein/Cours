---
name: "structurer-diapos-cours"
description: "Règles de structure pédagogique pour créer ou réviser les diapos de cours techniques de l'utilisateur (progression, exercices, terminaux, animations), hors couleurs."
---

# Structurer mes diapos de cours

Applique ces règles à toute création ou révision de diapos de cours. Elles portent sur la structure, pas sur les couleurs : suis la charte graphique du deck.

## Progression et découpage
- Définis chaque terme avant sa première utilisation ; développe chaque sigle à sa première apparition.
- Écris une phrase explicite à la place du jargon.
- Regroupe sur une seule diapo une démarche qui se fait d'un seul tenant.
- Scinde une diapo trop dense en plusieurs diapos ; garde une taille de texte lisible.
- Introduis un outil par un cas réel qui montre son intérêt, puis ses limites, démontrées.
- Suis un fil rouge : un même exemple qui traverse les diapos.
- Vérifie qu'aucune diapo n'en contredit une autre.
- Signale un exemple d'école qui s'écarte des bonnes pratiques et place la bonne pratique à côté.
- Présente des bonnes pratiques à jour et sourcées (documentation officielle, référentiels reconnus).
- Cite la source de chaque fait et de chaque bonne pratique, et fais un lien vers la documentation officielle.
- Place les approfondissements en annexe et les récapitulatifs en toute fin (« Pour rappel · liste non exhaustive »).
- Supprime les redites dans le corps du cours.
- Dis explicitement quand un sujet sort du cadre du cours.

## Schémas et mise en scène
- Dessine un schéma dès qu'il remplace un paragraphe ou une liste : objets, relations, états.
- Montre une transformation : l'état de départ, l'action, l'état d'arrivée ; le clic fait avancer l'action.
- Fais évoluer le schéma au clic, sur la même diapo : la commande s'exécute, l'état dessiné change.
- Fais avancer ensemble le terminal et le schéma qu'il modifie.
- Sur une commande ou une sortie, relie chaque morceau à son explication : souligne, encadre ou pose une flèche légendée, un morceau par clic.
- Avant de manipuler un fichier, montre qu'il existe, puis son contenu, puis la commande.
- Avant d'introduire un concept, montre ceux qui le composent ; tiens pour acquis les prérequis annoncés du cours.
- Affiche le contexte de l'action — où l'on est dans l'arborescence, sur quelle machine, sous quel compte — toujours au même endroit de la diapo.
- Garde une légende passée, grisée, quand la suite s'y rattache ; sinon efface-la au clic suivant.
- Limite la charge : au plus cinq légendes à l'écran en même temps, la courante comprise ; au-delà, scinde la diapo.
- Trace sans chevauchement : ni trait qui en croise un autre, ni texte recouvert.
- Quand un croisement est inévitable, décompose en étapes numérotées et marque l'étape en cours, par son numéro et par une mise en valeur.
- Réserve les puces à ce qui décompose une explication ou une argumentation ; un sommaire, un titre ou une énumération courte s'en passent.

## Exercices et corrigés
- Mets l'énoncé (« À vous ») sur une diapo et le corrigé sur la suivante.
- Rappelle la question sur la diapo de réponse.
- Révèle la réponse en deux temps : la question d'abord, puis la réponse avec sa démonstration.
- Fais apparaître chaque réponse en même temps que la ligne qui la démontre.

## Terminaux et code
- Montre des sorties réelles, rejouées et complètes ; signale tout extrait inévitable par « # … ».
- Note dans les notes de l'orateur la version de l'outil employée.
- Affiche le fichier source (Dockerfile, script, configuration) à côté de la commande qui l'utilise.
- Montre d'où vient chaque donnée utilisée par une commande.
- Explique chaque sortie affichée.
- Écris une commande par ligne ; coupe les commandes longues avec `\`.
- Donne des noms parlants aux variables.
- Liste tous les prérequis (paquets, fichiers, droits).
- Utilise la syntaxe actuelle recommandée de l'outil ; réserve l'ancienne syntaxe à la diapo qui en parle.
- Présente une commande dans un cartouche de terminal, distinct des objets qu'elle produit.
- Place ce qui s'exécute dans un environnement imbriqué (conteneur, VM, session distante) dans un cadre imbriqué.
- Commente dans le terminal chaque ligne non évidente.

## Animations
- Fais avancer un schéma ou une annotation plutôt qu'une liste ; quand une diapo reste une liste, révèle-la bloc par bloc, puis puce par puce.
- Fais apparaître les étapes séquentielles l'une après l'autre et la synthèse en dernier.
- Synchronise chaque explication avec l'élément qu'elle explique.
- Aligne chaque étiquette en face de l'élément qu'elle désigne.
- Encadre uniquement ce qui apparaît au clic en cours.
- Ajoute une loupe sur un détail clé, avec son explication.
- Rejoue fidèlement un affichage qui se met à jour en direct.
- Garde des animations exportables en PDF et en Typst/Beamer : uniquement des apparitions et disparitions.

## Texte et métadonnées
- Donne à chaque diapo un titre qui dit ce qu'on y apprend.
- Garde un encadré « À retenir » court.
- Emploie les termes français, avec l'équivalent anglais quand il est utile.
- Écris les unités exactes (Mio, Go…).
- Mets versions et détails dans les notes de l'orateur ; place les liens vers la documentation officielle sur la diapo elle-même quand c'est possible, sinon dans les notes.
- N'écris jamais « vérifié », « testé » ni « confirmé » : un fait affiché est présumé vérifié. Vérifie réellement, puis énonce le fait directement, sans le label.
- Pied de page : auteur | titre | n/N ; renumérote après chaque ajout ou déplacement de diapo.
