#!/bin/bash

set -euo pipefail

# Configuration
BACKUP_DIR="/backups"
MYSQL_HOST="db"
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
WORDPRESS_DIR="/var/www/html"
MAX_BACKUPS=7
DATE=$(date +"%Y%m%d_%H%M%S")

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in mysqldump tar gzip; do
    if ! command_exists $cmd; then
        log "Error: $cmd is required but not installed. Aborting."
        exit 1
    fi
done

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}

# Backup function
perform_backup() {
    local backup_file="${BACKUP_DIR}/wordpress_${DATE}"
    
    # Backup MySQL database
    log "Backing up MySQL database..."
    if ! mysqldump -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} | gzip > "${backup_file}.sql.gz"; then
        log "Error: MySQL backup failed"
        return 1
    fi

    # Backup WordPress files
    log "Backing up WordPress files..."
    if ! tar -czf "${backup_file}.tar.gz" -C ${WORDPRESS_DIR} .; then
        log "Error: WordPress files backup failed"
        return 1
    fi

    # Create checksum files
    md5sum "${backup_file}.sql.gz" > "${backup_file}.sql.gz.md5"
    md5sum "${backup_file}.tar.gz" > "${backup_file}.tar.gz.md5"

    log "Backup completed successfully: ${backup_file}.sql.gz and ${backup_file}.tar.gz"
}

# Restore function
perform_restore() {
    local backup_date="$1"
    local sql_backup="${BACKUP_DIR}/wordpress_${backup_date}.sql.gz"
    local files_backup="${BACKUP_DIR}/wordpress_${backup_date}.tar.gz"

    # Check if backup files exist
    if [[ ! -f "$sql_backup" || ! -f "$files_backup" ]]; then
        log "Error: Backup files for date $backup_date not found"
        return 1
    fi

    # Verify checksums
    log "Verifying backup integrity..."
    if ! md5sum -c "${sql_backup}.md5" && md5sum -c "${files_backup}.md5"; then
        log "Error: Backup integrity check failed"
        return 1
    fi

    # Restore database
    log "Restoring MySQL database..."
    if ! zcat "$sql_backup" | mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}; then
        log "Error: Database restore failed"
        return 1
    fi

    # Restore WordPress files
    log "Restoring WordPress files..."
    if ! tar -xzf "$files_backup" -C ${WORDPRESS_DIR}; then
        log "Error: WordPress files restore failed"
        return 1
    fi

    log "Restore completed successfully"
}

# Rotate old backups
rotate_backups() {
    local backups=($(ls -t ${BACKUP_DIR}/wordpress_*.sql.gz))
    if [[ ${#backups[@]} -gt $MAX_BACKUPS ]]; then
        for old_backup in "${backups[@]:$MAX_BACKUPS}"; do
            log "Removing old backup: $old_backup"
            rm "$old_backup" "${old_backup%.*}.tar.gz" "${old_backup}.md5" "${old_backup%.*}.tar.gz.md5"
        done
    fi
}

# Main execution
case "${1:-backup}" in
    backup)
        log "Starting backup process..."
        perform_backup
        rotate_backups
        log "Backup process completed"
        ;;
    restore)
        if [[ -z "${2:-}" ]]; then
            log "Error: Restore date not provided. Usage: $0 restore YYYYMMDD_HHMMSS"
            exit 1
        fi
        log "Starting restore process..."
        perform_restore "$2"
        log "Restore process completed"
        ;;
    *)
        log "Error: Invalid option. Usage: $0 [backup|restore YYYYMMDD_HHMMSS]"
        exit 1
        ;;
esac