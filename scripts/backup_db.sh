#!/usr/bin/env bash
# ==============================================================================
# Dolly Buyback - Production MariaDB Automated Backup & Rotation Script
# ==============================================================================
# Usage:
#   chmod +x scripts/backup_db.sh
#   ./scripts/backup_db.sh
#
# Recommended Crontab entry (runs every night at 2:30 AM):
#   30 2 * * * /data/home/mobile_resell/scripts/backup_db.sh >> /data/home/mobile_resell/backend/logs/backup.log 2>&1
# ==============================================================================

set -euo pipefail

BACKUP_DIR="/data/home/mobile_resell/backups"
ENV_FILE="/data/home/mobile_resell/backend/.env"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

# Read DB credentials from .env
if [ -f "$ENV_FILE" ]; then
    DB_NAME=$(grep -E '^DB_NAME=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    DB_USER=$(grep -E '^DB_USER=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    DB_PASSWORD=$(grep -E '^DB_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    DB_HOST=$(grep -E '^DB_HOST=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'" || echo "127.0.0.1")
    DB_PORT=$(grep -E '^DB_PORT=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'" || echo "3306")
else
    echo "[!] .env file not found at $ENV_FILE"
    exit 1
fi

if [ -z "${DB_NAME:-}" ]; then
    echo "[!] DB_NAME not set in $ENV_FILE"
    exit 1
fi

DB_USER=${DB_USER:-"mobilebuyback_user"}
DB_HOST=${DB_HOST:-"127.0.0.1"}
DB_PORT=${DB_PORT:-"3306"}

OUTPUT_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "[*] [$(date +"%Y-%m-%d %H:%M:%S")] Starting MariaDB backup for database: '${DB_NAME}'..."

# Zero-downtime, non-locking single transaction dump compressed with gzip
mysqldump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --password="$DB_PASSWORD" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    "$DB_NAME" | gzip -9 > "$OUTPUT_FILE"

FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "[+] Backup successfully created: $OUTPUT_FILE ($FILE_SIZE)"

# Rotate backups: remove files older than 7 days
echo "[*] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -type f -name "${DB_NAME}_*.sql.gz" -mtime +"$RETENTION_DAYS" -exec rm -vf {} \;

echo "[✓] [$(date +"%Y-%m-%d %H:%M:%S")] Backup and cleanup complete."
