#!/bin/bash
set -e

# Load environment variables (to get BACKUP_PASSWORD if set)
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

BACKUP_DIR="./backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p "$BACKUP_DIR"

# Ensure the backup directory is only readable by the owner
chmod 700 "$BACKUP_DIR"

echo "Dumping PostgreSQL database..."
docker exec synapse_postgres pg_dump -U synapse_user synapse > "$BACKUP_DIR/db_$DATE.sql"
chmod 600 "$BACKUP_DIR/db_$DATE.sql"

echo "Archiving Synapse data (including media)..."
tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" ./synapse-data/media_store
chmod 600 "$BACKUP_DIR/media_$DATE.tar.gz"

echo "Archiving Database dump and Media into a single file..."
tar -czf "$BACKUP_DIR/matrix_backup_$DATE.tar.gz" "$BACKUP_DIR/db_$DATE.sql" "$BACKUP_DIR/media_$DATE.tar.gz"
chmod 600 "$BACKUP_DIR/matrix_backup_$DATE.tar.gz"

# Clean up intermediate files
rm "$BACKUP_DIR/db_$DATE.sql" "$BACKUP_DIR/media_$DATE.tar.gz"

# Abort if no encryption password is set
if [ -z "$BACKUP_PASSWORD" ]; then
    echo "ERROR: BACKUP_PASSWORD is not set in .env. Refusing to save an unencrypted backup."
    rm -f "$BACKUP_DIR/matrix_backup_$DATE.tar.gz"
    exit 1
fi

echo "Encrypting backup..."
gpg --symmetric --cipher-algo AES256 --batch --passphrase "$BACKUP_PASSWORD" -o "$BACKUP_DIR/matrix_backup_$DATE.tar.gz.gpg" "$BACKUP_DIR/matrix_backup_$DATE.tar.gz"
chmod 600 "$BACKUP_DIR/matrix_backup_$DATE.tar.gz.gpg"
rm "$BACKUP_DIR/matrix_backup_$DATE.tar.gz"
echo "Backup completed and encrypted: $BACKUP_DIR/matrix_backup_$DATE.tar.gz.gpg"

# Rotate old backups (delete files older than 30 days)
echo "Cleaning up backups older than 30 days..."
find "$BACKUP_DIR" -type f -name "matrix_backup_*" -mtime +30 -exec rm {} \;
echo "Cleanup done."
