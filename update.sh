#!/bin/bash

set -euo pipefail

# Configuration
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
BACKUP_SCRIPT="./scripts/backup.sh"

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to perform backup
perform_backup() {
    log "Performing backup before update..."
    if ! $BACKUP_SCRIPT; then
        log "Error: Backup failed. Aborting update."
        exit 1
    fi
}

# Function to update Docker images
update_docker_images() {
    log "Updating Docker images..."
    if ! docker-compose -f "$COMPOSE_FILE" pull; then
        log "Error: Failed to pull updated Docker images."
        return 1
    fi
}

# Function to restart services
restart_services() {
    log "Restarting services with updated images..."
    if ! docker-compose -f "$COMPOSE_FILE" up -d; then
        log "Error: Failed to restart services."
        return 1
    fi
}

# Function to update WordPress core, plugins, and themes
update_wordpress() {
    log "Updating WordPress core, plugins, and themes..."
    if ! docker-compose -f "$COMPOSE_FILE" exec wordpress wp core update; then
        log "Error: Failed to update WordPress core."
        return 1
    fi
    if ! docker-compose -f "$COMPOSE_FILE" exec wordpress wp plugin update --all; then
        log "Error: Failed to update WordPress plugins."
        return 1
    fi
    if ! docker-compose -f "$COMPOSE_FILE" exec wordpress wp theme update --all; then
        log "Error: Failed to update WordPress themes."
        return 1
    fi
}

# Function to check WordPress integrity
check_wordpress_integrity() {
    log "Checking WordPress integrity..."
    if ! docker-compose -f "$COMPOSE_FILE" exec wordpress wp core verify-checksums; then
        log "Warning: WordPress core integrity check failed. Please investigate."
    fi
}

# Main update function
do_update() {
    perform_backup
    update_docker_images
    restart_services
    update_wordpress
    check_wordpress_integrity
    log "Update completed successfully!"
}

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --docker-only    Update only Docker images"
    echo "  --wp-only        Update only WordPress core, plugins, and themes"
    echo "  --help           Show this help message"
    echo "Without options, the script performs a full update."
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        do_update
    else
        case "$1" in
            --docker-only)
                perform_backup
                update_docker_images
                restart_services
                ;;
            --wp-only)
                perform_backup
                update_wordpress
                check_wordpress_integrity
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log "Error: Unknown option $1"
                show_help
                exit 1
                ;;
        esac
    fi
}

# Check for required commands
for cmd in docker docker-compose; do
    if ! command_exists "$cmd"; then
        log "Error: $cmd is required but not installed. Aborting."
        exit 1
    fi
done

# Source .env file
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    log "Error: $ENV_FILE not found. Please make sure it exists."
    exit 1
fi

# Run main function
main "$@"