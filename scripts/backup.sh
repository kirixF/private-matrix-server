#!/bin/bash
set -e

BACKUP_DIR="./backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p "$BACKUP_DIR"

echo "Dumping PostgreSQL database..."
docker exec synapse_postgres pg_dump -U synapse synapse > "$BACKUP_DIR/db_$DATE.sql"

echo "Archiving Synapse data (including media)..."
# We archive the whole synapse-data for a complete backup, or just media_store as requested
tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" ./synapse-data/media_store

echo "Archiving Database dump and Media into a single file..."
tar -czf "$BACKUP_DIR/matrix_backup_$DATE.tar.gz" "$BACKUP_DIR/db_$DATE.sql" "$BACKUP_DIR/media_$DATE.tar.gz"

# Optional: Clean up intermediate files
rm "$BACKUP_DIR/db_$DATE.sql" "$BACKUP_DIR/media_$DATE.tar.gz"

echo "Backup completed successfully: $BACKUP_DIR/matrix_backup_$DATE.tar.gz"
