#!/usr/bin/env bash
# ==============================================================================
# Dolly Buyback - Universal Automated Database Backup Script
# Supports both MariaDB / MySQL and SQLite3 with strict 2-file storage retention (~20MB max)
# Recommended Weekly Schedule: Run every Sunday at 2:30 AM
# ==============================================================================

set -o pipefail

# Find script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "================================================================="
echo "📦 DOLLY AUTOMATED DATABASE BACKUP"
echo "Timestamp: $(date +"%Y-%m-%d %H:%M:%S")"
echo "================================================================="

# Locate .env file
ENV_FILE=""
for candidate in "${PROJECT_ROOT}/backend/.env" "${PROJECT_ROOT}/.env"; do
    if [ -f "$candidate" ]; then
        ENV_FILE="$candidate"
        break
    fi
done

DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_HOST="127.0.0.1"
DB_PORT="3306"

if [ -n "$ENV_FILE" ]; then
    echo "[*] Reading configuration from: $ENV_FILE"
    DB_NAME=$(grep -E '^DB_NAME=' "$ENV_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || true)
    DB_USER=$(grep -E '^DB_USER=' "$ENV_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || true)
    DB_PASSWORD=$(grep -E '^DB_PASSWORD=' "$ENV_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || true)
    DB_HOST=$(grep -E '^DB_HOST=' "$ENV_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || echo "127.0.0.1")
    DB_PORT=$(grep -E '^DB_PORT=' "$ENV_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || echo "3306")
fi

# 1. If DB_NAME is set, perform MariaDB / MySQL dump
if [ -n "$DB_NAME" ]; then
    DB_USER=${DB_USER:-"root"}
    DB_HOST=${DB_HOST:-"127.0.0.1"}
    DB_PORT=${DB_PORT:-"3306"}
    OUTPUT_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

    echo "[*] Engine: MariaDB / MySQL"
    echo "[*] Database: '${DB_NAME}' (Host: ${DB_HOST}:${DB_PORT}, User: ${DB_USER})"
    echo "[*] Creating compressed dump..."

    PASS_ARG=""
    if [ -n "$DB_PASSWORD" ]; then
        PASS_ARG="--password=$DB_PASSWORD"
    fi

    mysqldump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --user="$DB_USER" \
        $PASS_ARG \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        "$DB_NAME" | gzip -9 > "$OUTPUT_FILE"

    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "[✓] MariaDB backup created: $OUTPUT_FILE ($FILE_SIZE)"

# 2. Fallback to SQLite3 backup if db.sqlite3 exists
elif [ -f "${PROJECT_ROOT}/backend/db.sqlite3" ] || [ -f "${PROJECT_ROOT}/db.sqlite3" ]; then
    SQLITE_PATH="${PROJECT_ROOT}/backend/db.sqlite3"
    if [ ! -f "$SQLITE_PATH" ]; then
        SQLITE_PATH="${PROJECT_ROOT}/db.sqlite3"
    fi
    OUTPUT_FILE="${BACKUP_DIR}/sqlite3_backup_${TIMESTAMP}.db.gz"

    echo "[*] Engine: SQLite3"
    echo "[*] Source: $SQLITE_PATH"
    echo "[*] Creating compressed backup..."

    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$SQLITE_PATH" ".backup '${BACKUP_DIR}/temp.db'"
        gzip -9 -c "${BACKUP_DIR}/temp.db" > "$OUTPUT_FILE"
        rm -f "${BACKUP_DIR}/temp.db"
    else
        gzip -9 -c "$SQLITE_PATH" > "$OUTPUT_FILE"
    fi

    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "[✓] SQLite backup created: $OUTPUT_FILE ($FILE_SIZE)"

else
    echo "[!] No active database configuration or SQLite file found."
    exit 1
fi

# 3. Space-saving cleanup: Keep only the latest 2 backups (max ~20MB total storage)
MAX_KEEP=2
echo "[*] Space conservation: Keeping only the latest ${MAX_KEEP} backups, purging older ones..."
cd "$BACKUP_DIR"
FILES_TO_REMOVE=$(ls -1t *.gz 2>/dev/null | tail -n +$((MAX_KEEP + 1)) || true)
if [ -n "$FILES_TO_REMOVE" ]; then
    echo "$FILES_TO_REMOVE" | while read -r old_file; do
        if [ -n "$old_file" ] && [ -f "$old_file" ]; then
            echo "[-] Deleted old backup to conserve disk space: $old_file"
            rm -f "$old_file"
        fi
    done
else
    echo "[*] Storage clean: Total backup count is within the ${MAX_KEEP}-file limit (~20MB max)."
fi

echo "================================================================="
echo "✅ BACKUP PROCESS FINISHED (DISK SPACE CONSERVED)"
echo "================================================================="
