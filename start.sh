#!/bin/bash

set -euo pipefail

# Configuration
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check required environment variables
check_env_vars() {
    local required_vars=(
        "MYSQL_DATABASE" "MYSQL_USER" "MYSQL_PASSWORD" "WORDPRESS_DB_HOST"
        "WORDPRESS_TABLE_PREFIX" "WORDPRESS_DEBUG" "NGINX_HTTP_PORT" "NGINX_HTTPS_PORT"
        "DOMAIN" "EMAIL" "CLOUDFLARE_API_TOKEN" "CLOUDFLARE_ZONE_ID"
        "WP_ADMIN_USER" "WP_ADMIN_PASSWORD" "WP_ADMIN_EMAIL"
    )

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$ENV_FILE"; then
            log "Error: ${var} is not set in ${ENV_FILE}"
            return 1
        fi
    done
}

# Function to check Docker and Docker Compose installation
check_docker() {
    if ! command_exists docker; then
        log "Error: Docker is not installed. Please install Docker and try again."
        return 1
    fi

    if ! command_exists docker-compose; then
        log "Error: Docker Compose is not installed. Please install Docker Compose and try again."
        return 1
    fi
}

# Function to check if Docker daemon is running
check_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        log "Error: Docker daemon is not running. Please start Docker and try again."
        return 1
    fi
}

# Function to create or check Docker network
create_or_check_network() {
    local network_name="web"
    if ! docker network inspect "$network_name" >/dev/null 2>&1; then
        log "Creating Docker network: $network_name"
        docker network create "$network_name"
    else
        log "Docker network '$network_name' already exists"
    fi
}

# Function to start Docker Compose services
start_services() {
    log "Starting Docker Compose services..."
    if ! docker-compose -f "$COMPOSE_FILE" up -d; then
        log "Error: Failed to start Docker Compose services"
        return 1
    fi
}

# Function to check service health
check_service_health() {
    local service_name="$1"
    local max_attempts=30
    local wait_time=10

    for ((i=1; i<=max_attempts; i++)); do
        if docker-compose -f "$COMPOSE_FILE" exec "$service_name" healthcheck >/dev/null 2>&1; then
            log "Service $service_name is healthy"
            return 0
        fi
        log "Waiting for $service_name to be healthy (attempt $i/$max_attempts)..."
        sleep "$wait_time"
    done

    log "Error: Service $service_name failed to become healthy"
    return 1
}

# Main execution
main() {
    log "Starting WordPress deployment..."

    # Check for .env file
    if [[ ! -f "$ENV_FILE" ]]; then
        log "Error: $ENV_FILE not found. Please create it from .env-example"
        exit 1
    fi

    # Source .env file
    set -a
    source "$ENV_FILE"
    set +a

    # Perform checks
    check_docker || exit 1
    check_docker_running || exit 1
    check_env_vars || exit 1
    create_or_check_network || exit 1

    # Start services
    start_services || exit 1

    # Check service health
    check_service_health "db" || exit 1
    check_service_health "wordpress" || exit 1
    check_service_health "nginx" || exit 1

    log "WordPress deployment completed successfully!"
    log "You can access your site at: https://${DOMAIN}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            set -x
            ;;
        --help)
            echo "Usage: $0 [--debug] [--help]"
            echo "  --debug    Enable debug mode"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            log "Error: Unknown option $1"
            exit 1
            ;;
    esac
    shift
done

main