#!/bin/bash
# setup_dirs.sh
# Creates required directory structure for YouTube Remaker pipeline
# Sets correct permissions for Docker containers

set -e

echo "Creating directory structure for YouTube Remaker..."

# n8n runs as user 'node' (UID 1000, GID 1000)
# PostgreSQL runs as UID 999
# All shared directories use 775 for security (not 777)
N8N_UID=1000
N8N_GID=1000
POSTGRES_UID=999

# Full list of required directories
DIRS=(
    "/data/n8n"
    "/data/postgres"
    "/data/models/whisper"
    "/data/output/01_research"
    "/data/output/02_script"
    "/data/output/03_voice"
    "/data/output/04_thumbnail"
    "/data/output/05_footage"
    "/data/output/06_edit"
    "/data/output/07_publish"
    "/data/cache"
    "/data/temp"
    "/data/backup"
    "/data/logs"
    "/data/references/travel"
    "/data/references/historical"
    "/data/references/educational"
    "/data/references/lifestyle"
    "/data/references/news"
    "/data/references/entertainment"
)

# Create directories (skip if already exists)
for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "  [created] $dir"
    else
        echo "  [exists]  $dir"
    fi
done

echo ""
echo "Setting permissions..."

# n8n data — owned by node user (UID 1000)
chown -R ${N8N_UID}:${N8N_GID} /data/n8n
chmod -R 755 /data/n8n

# PostgreSQL data — owned by postgres user (UID 999)
chown -R ${POSTGRES_UID}:${POSTGRES_UID} /data/postgres
chmod -R 700 /data/postgres

# Shared pipeline directories — writable by all containers
chmod -R 775 /data/output
chmod -R 775 /data/cache
chmod -R 775 /data/temp
chmod -R 775 /data/logs
chmod -R 775 /data/models
chmod -R 755 /data/backup
chmod -R 775 /data/references

echo ""
echo "Permissions summary:"
echo "  /data/n8n        → UID 1000 (n8n container)      755"
echo "  /data/postgres   → UID 999  (postgres container)  700"
echo "  /data/output     → all containers                 775"
echo "  /data/cache      → all containers                 775"
echo "  /data/temp       → all containers                 775"
echo "  /data/logs       → all containers                 775"
echo "  /data/models     → all containers                 775"
echo "  /data/backup     → root only                      755"
echo ""
echo "Directory structure:"
find /data -type d | sort
echo ""
echo "Done! Directory structure created successfully."
