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

# Load environment variables
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    else
        log "Error: $ENV_FILE not found. Please make sure it exists."
        exit 1
    fi
}

# Test Docker services
test_docker_services() {
    log "Testing Docker services..."
    local services=(db wordpress nginx)
    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            log "Service $service is running"
        else
            log "Error: Service $service is not running"
            return 1
        fi
    done
}

# Test WordPress accessibility
test_wordpress_accessibility() {
    log "Testing WordPress accessibility..."
    local url="https://${DOMAIN}"
    if curl -sSf -o /dev/null "$url"; then
        log "WordPress is accessible at $url"
    else
        log "Error: WordPress is not accessible at $url"
        return 1
    fi
}

# Test database connection
test_database_connection() {
    log "Testing database connection..."
    if docker-compose -f "$COMPOSE_FILE" exec wordpress wp db check; then
        log "Database connection successful"
    else
        log "Error: Database connection failed"
        return 1
    fi
}

# Test SSL configuration
test_ssl_configuration() {
    log "Testing SSL configuration..."
    local domain="$DOMAIN"
    if openssl s_client -connect "${domain}:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -dates | grep -q "notAfter"; then
        log "SSL certificate is valid for $domain"
    else
        log "Error: SSL certificate check failed for $domain"
        return 1
    fi
}

# Test WordPress functionality
test_wordpress_functionality() {
    log "Testing WordPress functionality..."
    
    # Check if we can log in
    if ! docker-compose -f "$COMPOSE_FILE" exec wordpress wp user list --role=administrator; then
        log "Error: Unable to list WordPress users"
        return 1
    fi
    
    # Create a test post
    local post_id=$(docker-compose -f "$COMPOSE_FILE" exec -T wordpress wp post create --post_title='Test Post' --post_status=publish --porcelain)
    if [[ -n "$post_id" ]]; then
        log "Successfully created test post with ID: $post_id"
        # Delete the test post
        docker-compose -f "$COMPOSE_FILE" exec wordpress wp post delete "$post_id" --force
    else
        log "Error: Failed to create test post"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    test_docker_services
    test_wordpress_accessibility
    test_database_connection
    test_ssl_configuration
    test_wordpress_functionality
}

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --docker         Test Docker services only"
    echo "  --wp             Test WordPress functionality only"
    echo "  --db             Test database connection only"
    echo "  --ssl            Test SSL configuration only"
    echo "  --help           Show this help message"
    echo "Without options, the script runs all tests."
}

# Main execution
main() {
    load_env

    if [[ $# -eq 0 ]]; then
        run_all_tests
    else
        case "$1" in
            --docker)
                test_docker_services
                ;;
            --wp)
                test_wordpress_functionality
                ;;
            --db)
                test_database_connection
                ;;
            --ssl)
                test_ssl_configuration
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

    log "All specified tests completed successfully!"
}

# Check for required commands
for cmd in docker docker-compose curl openssl; do
    if ! command_exists "$cmd"; then
        log "Error: $cmd is required but not installed. Aborting."
        exit 1
    fi
done

# Run main function
main "$@"