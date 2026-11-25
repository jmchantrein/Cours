# Un seul TP Incus, rangé sous le cours de virtualisation

Statut : acceptée (25 novembre 2026)

## Contexte

Incus gère sous une même commande des machines virtuelles (QEMU/KVM) et des conteneurs système (LXC). Le dépôt compte deux cours, virtualisation et conteneurisation ; ranger les machines virtuelles dans le premier et les conteneurs système dans le second était possible. Certaines promotions ne suivent que le cours de conteneurisation.

## Décision

Un seul TP, `virtualisation/tp/incus/`, va de la machine virtuelle au conteneur système, puis, par une étape facultative, à Docker dans une VM Incus ; il vient après le mini TP QEMU/KVM des diapos, qui reste en place. Le TP WordPress du cours de conteneurisation reste autonome et ne fait que mentionner le TP Incus. La raison : `incus launch images:debian/13 v1 --vm` et la même commande sans `--vm` ne diffèrent que par l'isolation, et scinder le TP ferait perdre cette comparaison toutes choses égales par ailleurs.

## Conséquences

Les conteneurs système sont enseignés dans le cours de virtualisation, ce qui peut surprendre. Le TP WordPress du cours de conteneurisation y renvoie par un lien, sans dupliquer ; les diapos de conteneurisation n'y renvoient pas. Le TP cible l'Incus de Debian 13 (6.0.4).

## Options écartées

- Deux TP, un par cours : perd la comparaison et double l'installation.
- Un troisième cours « Incus » : un dossier de cours pour une seule séance.
