#!/bin/bash
# setup_n8n.sh
# Prepares Traefik and n8n for first launch
# Run after install.sh and after filling in .env

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo " YouTube Remaker — n8n + Traefik Setup"
echo "========================================"
echo ""

# ============================================
# Load .env and export all variables
# set -a exports every variable automatically
# required for docker compose to read them
# ============================================
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "ERROR: .env file not found!"
    echo "Run: cp .env.example .env and fill in your values"
    exit 1
fi

set -a
source "$PROJECT_ROOT/.env"
set +a

# ============================================
# Validate required variables
# ============================================
echo "[1/6] Validating .env variables..."

REQUIRED_VARS=(
    "ACME_EMAIL"
    "CF_API_TOKEN"
    "N8N_HOST"
    "N8N_ENCRYPTION_KEY"
    "N8N_BASIC_AUTH_USER"
    "N8N_BASIC_AUTH_PASSWORD"
    "POSTGRES_PASSWORD"
)

MISSING=0
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "  ERROR: $var is not set in .env"
        MISSING=1
    else
        echo "  [ok] $var"
    fi
done

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "Fill in missing variables in .env and run again."
    exit 1
fi
echo "  Done."

# ============================================
# Check docker compose plugin (not docker-compose)
# ============================================
echo "[2/6] Checking Docker..."

if ! docker compose version > /dev/null 2>&1; then
    echo "  ERROR: 'docker compose' plugin not found!"
    echo "  Run install.sh first to install Docker correctly."
    exit 1
fi

echo "  Docker: $(docker --version)"
echo "  Compose: $(docker compose version)"
echo "  Done."

# ============================================
# Setup Traefik
# ============================================
echo "[3/6] Setting up Traefik..."

# Check traefik.yml exists in repo
if [ ! -f "$PROJECT_ROOT/config/traefik.yml" ]; then
    echo "  ERROR: config/traefik.yml not found in repository!"
    echo "  Make sure traefik.yml is committed to the repo."
    exit 1
fi

mkdir -p /data/traefik

# Copy traefik.yml from repo
cp "$PROJECT_ROOT/config/traefik.yml" /data/traefik/traefik.yml
echo "  Copied config/traefik.yml → /data/traefik/traefik.yml"

# Create acme.json for Let's Encrypt certificates
# MUST be chmod 600 — Traefik refuses to start otherwise
if [ ! -f /data/traefik/acme.json ]; then
    touch /data/traefik/acme.json
    chmod 600 /data/traefik/acme.json
    echo "  Created acme.json (chmod 600)"
else
    chmod 600 /data/traefik/acme.json
    echo "  acme.json exists — permissions verified (chmod 600)"
fi

echo "  Done."

# ============================================
# Setup n8n directory
# ============================================
echo "[4/6] Setting up n8n directories..."

mkdir -p /data/n8n
chown -R 1000:1000 /data/n8n
echo "  /data/n8n ready (UID 1000)"
echo "  Done."

# ============================================
# Pull Docker images
# ============================================
echo "[5/6] Pulling Docker images..."
cd "$PROJECT_ROOT"
docker compose pull traefik postgres n8n
echo "  Done."

# ============================================
# Build custom images
# ============================================
echo "[6/6] Building pipeline and whisper images..."
docker compose build pipeline whisper
echo "  Done."

# ============================================
# Summary
# ============================================
echo ""
echo "========================================"
echo " Setup complete!"
echo "========================================"
echo ""
echo "Traefik:"
echo "  Config:    /data/traefik/traefik.yml"
echo "  SSL store: /data/traefik/acme.json (chmod 600)"
echo ""
echo "n8n:"
echo "  Data:      /data/n8n"
echo "  URL:       https://${N8N_HOST}"
echo "  User:      ${N8N_BASIC_AUTH_USER}"
echo ""
echo "Next step:"
echo "  cd $PROJECT_ROOT && make up"
echo ""
