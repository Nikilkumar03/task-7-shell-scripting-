#!/bin/bash

# === CONFIGURATION ===

BACKUP_DIR="./backups"                 # Local backup folder
LOG_FILE="./backup.log"                # Log file
REMOTE_USER="user"                     # Remote username
REMOTE_HOST="example.com"        # Remote host
REMOTE_PATH="/home/user/remote_backups"
RETENTION_DAYS=7                       # Delete backups older than this
MODIFIED_WITHIN=2                      # Backup only files modified in last X days

# === DEFAULT OPTIONS ===
COMPRESS=false
ENABLE_LOG=false
INPUT_FILES=()

# === FUNCTIONS ===

log() {
    if $ENABLE_LOG; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
    fi
}

usage() {
    echo "Usage: $0 [-c] [-l] file1 [file2 ...]"
    echo "  -c    Enable compression (.tar.gz)"
    echo "  -l    Enable logging"
    exit 1
}

# === PARSE ARGUMENTS ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) COMPRESS=true ;;
        -l) ENABLE_LOG=true ;;
        -h|--help) usage ;;
        *) INPUT_FILES+=("$1") ;;
    esac
    shift
done

# === CHECK INPUT FILES ===
if [ ${#INPUT_FILES[@]} -eq 0 ]; then
    echo " No input files provided."
    usage
fi

# === CREATE BACKUP DIRECTORY ===
mkdir -p "$BACKUP_DIR"
log "Created backup directory: $BACKUP_DIR"

# === FILTER RECENTLY MODIFIED FILES ===
RECENT_FILES=()
for file in "${INPUT_FILES[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        MODIFIED=$(find "$file" -type f -mtime -"$MODIFIED_WITHIN")
        if [ ! -z "$MODIFIED" ]; then
            RECENT_FILES+=("$file")
        fi
    fi
done

if [ ${#RECENT_FILES[@]} -eq 0 ]; then
    echo " No recently modified files to back up."
    log "No recent files found. Exiting."
    exit 0
fi

# === SMART BACKUP FILE NAME ===
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="backup_$TIMESTAMP"

if $COMPRESS; then
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
else
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME"
fi

# === CREATE BACKUP ===
if $COMPRESS; then
    tar -czf "$BACKUP_FILE" "${RECENT_FILES[@]}"
else
    mkdir -p "$BACKUP_FILE"
    cp -r "${RECENT_FILES[@]}" "$BACKUP_FILE/"
fi

log "Created backup: $BACKUP_FILE"
echo " Backup created at $BACKUP_FILE"

# === REMOTE BACKUP ===
scp "$BACKUP_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
if [ $? -eq 0 ]; then
    log "Sent backup to remote: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
    echo "🚀 Remote backup complete."
else
    log "❌ Failed remote backup"
    echo "❌ Remote backup failed."
fi

# === DELETE OLD BACKUPS ===
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -exec rm {} \;
log "Deleted backups older than $RETENTION_DAYS days"

