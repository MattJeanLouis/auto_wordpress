#!/bin/bash

set -euo pipefail

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check DNS propagation
check_dns_propagation() {
    local domain="$1"
    local expected_ip="$2"
    local max_attempts=30
    local wait_time=60

    log "Checking DNS propagation for $domain..."
    for ((i=1; i<=max_attempts; i++)); do
        local resolved_ip=$(dig +short $domain @1.1.1.1)
        if [[ "$resolved_ip" == "$expected_ip" ]]; then
            log "DNS has propagated successfully for $domain"
            return 0
        fi
        log "Attempt $i/$max_attempts: DNS not propagated yet. Waiting $wait_time seconds..."
        sleep $wait_time
    done

    log "DNS propagation check failed after $max_attempts attempts"
    return 1
}

# Check for required commands
for cmd in curl openssl dig certbot; do
    if ! command_exists $cmd; then
        log "Error: $cmd is required but not installed. Aborting."
        exit 1
    fi
done

# Check for required environment variables
required_vars=(DOMAIN EMAIL CLOUDFLARE_API_TOKEN CLOUDFLARE_ZONE_ID WP_ADMIN_USER WP_ADMIN_PASSWORD WP_ADMIN_EMAIL SERVER_IP)
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        log "Error: $var is not set. Please check your .env file."
        exit 1
    fi
done

# Configure DNS
log "Configuring DNS..."
if ! /scripts/configure-dns.sh; then
    log "DNS configuration failed. Check the Cloudflare API credentials and permissions."
    exit 1
fi

# Check DNS propagation
if ! check_dns_propagation "$DOMAIN" "$SERVER_IP"; then
    log "DNS propagation check failed. Please check your DNS configuration."
    exit 1
fi

# Generate self-signed SSL certificate for Nginx
log "Generating self-signed SSL certificate for Nginx..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/self-signed.key \
    -out /etc/nginx/self-signed.crt \
    -subj "/CN=${DOMAIN}" || { log "Failed to generate self-signed certificate"; exit 1; }

# Setup Nginx configuration
log "Setting up Nginx configuration..."
if ! envsubst < /nginx.conf.template > /etc/nginx/nginx.conf; then
    log "Failed to generate Nginx configuration."
    exit 1
fi

# Restart Nginx to apply new configuration
log "Restarting Nginx..."
nginx -s reload || { log "Failed to restart Nginx"; exit 1; }

# Wait for WordPress to be ready
log "Waiting for WordPress to be ready..."
max_attempts=30
wait_time=10
for ((i=1; i<=max_attempts; i++)); do
    if curl -s -o /dev/null -w "%{http_code}" http://wordpress | grep -q "200"; then
        log "WordPress is ready"
        break
    fi
    if [[ $i == $max_attempts ]]; then
        log "WordPress failed to start after $max_attempts attempts"
        exit 1
    fi
    log "Attempt $i/$max_attempts: WordPress not ready. Waiting $wait_time seconds..."
    sleep $wait_time
done

# Setup WordPress
log "Setting up WordPress..."
if ! /scripts/setup-wordpress.sh; then
    log "WordPress setup failed. Check the WordPress container logs for more information."
    exit 1
fi

# Initial SSL certificate request
log "Requesting initial SSL certificate..."
if certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --email ${EMAIL} --agree-tos --no-eff-email -d ${DOMAIN} -d *.${DOMAIN} --deploy-hook "nginx -s reload"; then
    log "SSL certificate obtained successfully"
else
    log "Failed to obtain SSL certificate. Check the Certbot logs for more information."
    log "The system will continue to use the self-signed certificate."
fi

# Setup backup cron job
log "Setting up backup cron job..."
if ! echo "0 2 * * * /scripts/backup.sh" | crontab -; then
    log "Failed to set up backup cron job."
    exit 1
fi

log "Initialization complete!"