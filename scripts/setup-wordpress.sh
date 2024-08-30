#!/bin/bash

set -eu

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Attendre que MySQL soit prêt
log "Attente de la disponibilité de MySQL..."
until mysqladmin ping -h"$WORDPRESS_DB_HOST" --silent; do
    sleep 1
done

# Vérifier si WordPress est déjà installé
if wp core is-installed; then
    log "WordPress est déjà installé. Mise à jour..."
    wp core update
    wp plugin update --all
    wp theme update --all
else
    log "Installation de WordPress..."
    wp core install --url="https://${DOMAIN}" \
                    --title="Mon site WordPress" \
                    --admin_user="${WP_ADMIN_USER}" \
                    --admin_password="${WP_ADMIN_PASSWORD}" \
                    --admin_email="${WP_ADMIN_EMAIL}"
fi

# Installer et activer les plugins essentiels
log "Installation et activation des plugins essentiels..."
plugins=(wordfence wp-super-cache autoptimize)
for plugin in "${plugins[@]}"; do
    wp plugin install "$plugin" --activate
done

# Configurer les permalinks
log "Configuration des permalinks..."
wp rewrite structure '/%postname%/' --hard

# Configurer les options de WordPress
log "Configuration des options de WordPress..."
wp option update blog_public 1  # Permettre l'indexation par les moteurs de recherche
wp option update timezone_string 'Europe/Paris'  # Définir le fuseau horaire (à adapter selon vos besoins)
wp option update date_format 'j F Y'  # Format de date
wp option update time_format 'H:i'  # Format d'heure
wp option update start_of_week 1  # Définir le début de la semaine (1 pour Lundi)

# Configurer Autoptimize
log "Configuration d'Autoptimize..."
wp option update autoptimize_css "on"
wp option update autoptimize_js "on"
wp option update autoptimize_html "on"

# Configurer WP Super Cache
log "Configuration de WP Super Cache..."
wp super-cache enable

# Supprimer les plugins non nécessaires
log "Suppression des plugins non nécessaires..."
wp plugin delete hello akismet

# Supprimer les thèmes par défaut sauf Twenty Twenty-One
log "Nettoyage des thèmes..."
wp theme delete twentynineteen twentytwenty

# Créer les pages essentielles
log "Création des pages essentielles..."
wp post create --post_type=page --post_title='Accueil' --post_status='publish'
wp post create --post_type=page --post_title='Blog' --post_status='publish'
wp post create --post_type=page --post_title='Contact' --post_status='publish'

# Définir la page d'accueil
log "Configuration de la page d'accueil..."
wp option update show_on_front 'page'
wp option update page_on_front $(wp post list --post_type=page --post_status=publish --title='Accueil' --field=ID --format=ids)
wp option update page_for_posts $(wp post list --post_type=page --post_status=publish --title='Blog' --field=ID --format=ids)

# Activer les mises à jour automatiques mineures
log "Activation des mises à jour automatiques mineures..."
wp config set WP_AUTO_UPDATE_CORE minor --raw

log "Configuration de WordPress terminée!"