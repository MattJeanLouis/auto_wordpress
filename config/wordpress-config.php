<?php
define( 'DB_NAME', getenv('MYSQL_DATABASE') );
define( 'DB_USER', getenv('MYSQL_USER') );
define( 'DB_PASSWORD', getenv('MYSQL_PASSWORD') );
define( 'DB_HOST', getenv('WORDPRESS_DB_HOST') );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

define( 'AUTH_KEY',         getenv('WP_AUTH_KEY') );
define( 'SECURE_AUTH_KEY',  getenv('WP_SECURE_AUTH_KEY') );
define( 'LOGGED_IN_KEY',    getenv('WP_LOGGED_IN_KEY') );
define( 'NONCE_KEY',        getenv('WP_NONCE_KEY') );
define( 'AUTH_SALT',        getenv('WP_AUTH_SALT') );
define( 'SECURE_AUTH_SALT', getenv('WP_SECURE_AUTH_SALT') );
define( 'LOGGED_IN_SALT',   getenv('WP_LOGGED_IN_SALT') );
define( 'NONCE_SALT',       getenv('WP_NONCE_SALT') );

$table_prefix = getenv('WORDPRESS_TABLE_PREFIX');

define( 'WP_DEBUG', getenv('WORDPRESS_DEBUG') === 'true' );

// Désactiver l'éditeur de fichiers
define( 'DISALLOW_FILE_EDIT', true );

// Forcer HTTPS
define( 'FORCE_SSL_ADMIN', true );

// Limiter les révisions
define( 'WP_POST_REVISIONS', 3 );

// Augmenter la mémoire allouée si nécessaire
define( 'WP_MEMORY_LIMIT', '256M' );

// Désactiver les mises à jour automatiques des plugins et thèmes
define( 'AUTOMATIC_UPDATER_DISABLED', true );

// Définir le délai de la corbeille
define( 'EMPTY_TRASH_DAYS', 7 );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';