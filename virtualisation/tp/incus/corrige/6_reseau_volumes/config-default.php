<?php
// Réglages du WordPress de Debian : /usr/share/wordpress/wp-config.php charge ce
// fichier, /etc/wordpress/config-default.php, quel que soit le nom du site.
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'tempo');
// La base est dans une autre instance, jointe par son nom sur le pont.
define('DB_HOST', 'db.incus');
