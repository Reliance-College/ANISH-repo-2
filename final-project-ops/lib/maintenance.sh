#!/bin/bash

run_backup() {
    local source_dir="$BASE_DIR"
    local backup_dir="${BACKUP_DIR:-$HOME/monitor-backups}"

    mkdir -p "$backup_dir"

    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')

    local backup_file="$backup_dir/monitor_backup_$timestamp.tar.gz"

    log "INFO" "Creating backup..."

    tar -czf "$backup_file" \
        --exclude="$backup_dir" \
        "$source_dir" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log "INFO" "Backup created: $backup_file"
    else
        log "ERROR" "Backup failed."
        return 1
    fi

    cleanup_backups
}

cleanup_backups() {
    local backup_dir="${BACKUP_DIR:-$HOME/monitor-backups}"
    local retention="${RETENTION_DAYS:-7}"

    if [[ ! -d "$backup_dir" ]]; then
        return 0
    fi

    log "INFO" "Removing backups older than $retention days."

    find "$backup_dir" \
        -type f \
        -name "monitor_backup_*.tar.gz" \
        -mtime +"$retention" \
        -delete
}

rotate_log() {
    if [[ -z "${LOG_FILE:-}" || ! -f "$LOG_FILE" ]]; then
        return 0
    fi

    local max_size=10485760
    local size

    size=$(stat -c%s "$LOG_FILE" 2>/dev/null)

    if (( size >= max_size )); then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"

        log "INFO" "Log file rotated."
    fi
}

run_maintenance() {
    log "INFO" "Starting maintenance."

    rotate_log
    cleanup_backups

    log "INFO" "Maintenance completed."
}
