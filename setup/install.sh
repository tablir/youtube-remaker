#!/bin/bash
# install.sh
# Initial server setup for YouTube Remaker pipeline
# Run from project root: bash setup/install.sh

set -e

# Detect project root (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo " YouTube Remaker — Server Setup"
echo "========================================"
echo " Project root: $PROJECT_ROOT"
echo ""

# ============================================
# System update
# ============================================
echo "[1/8] Updating system packages..."
apt update && apt upgrade -y
echo "  Done."

# ============================================
# Install base dependencies
# ============================================
echo "[2/8] Installing base dependencies..."
apt install -y \
    curl \
    wget \
    git \
    unzip \
    tree \
    htop \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https
echo "  Done."

# ============================================
# Install Docker
# ============================================
echo "[3/8] Installing Docker..."

# Remove old versions if any
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add current user to docker group (no sudo needed for docker commands)
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "  Added $SUDO_USER to docker group"
else
    usermod -aG docker "$USER"
    echo "  Added $USER to docker group"
fi

echo "  Docker version: $(docker --version)"
echo "  Done."

# ============================================
# Install Make
# ============================================
echo "[4/8] Installing Make..."
apt install -y make
echo "  Make version: $(make --version | head -1)"
echo "  Done."

# ============================================
# Install Python and pip
# ============================================
echo "[5/8] Installing Python..."
apt install -y python3 python3-pip python3-venv
echo "  Python version: $(python3 --version)"
echo "  Done."

# ============================================
# Install ImageMagick + fix policy
# ============================================
echo "[6/8] Installing ImageMagick..."
apt install -y imagemagick

# Fix ImageMagick security policy
# By default Ubuntu restricts PDF and large files — we need full access for thumbnails
POLICY_FILE="/etc/ImageMagick-6/policy.xml"
if [ -f "$POLICY_FILE" ]; then
    # Allow PDF operations
    sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' "$POLICY_FILE"
    # Remove memory/disk limits that block large image processing
    sed -i 's/<policy domain="resource" name="memory" value=".*"\/>/<policy domain="resource" name="memory" value="2GiB"\/>/' "$POLICY_FILE"
    sed -i 's/<policy domain="resource" name="disk" value=".*"\/>/<policy domain="resource" name="disk" value="8GiB"\/>/' "$POLICY_FILE"
    echo "  ImageMagick policy updated for thumbnail processing"
fi

echo "  ImageMagick version: $(convert --version | head -1)"
echo "  Done."

# ============================================
# Create directory structure
# ============================================
echo "[7/8] Creating directory structure..."
bash "$PROJECT_ROOT/setup/setup_dirs.sh"
echo "  Done."

# ============================================
# Copy .env.example to .env if not exists
# ============================================
echo "[8/8] Setting up environment file..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    echo "  Created .env from .env.example"
    echo "  IMPORTANT: Fill in your API keys in .env before running make up"
else
    echo "  .env already exists — skipping"
fi

# ============================================
# Final summary
# ============================================
echo ""
echo "========================================"
echo " Installation complete!"
echo "========================================"
echo ""
echo "Installed:"
echo "  Docker:       $(docker --version)"
echo "  Compose:      $(docker compose version)"
echo "  Python:       $(python3 --version)"
echo "  ImageMagick:  $(convert --version | head -1)"
echo "  Make:         $(make --version | head -1)"
echo ""
echo "Next steps:"
echo "  1. Fill in API keys: nano $PROJECT_ROOT/.env"
echo "  2. Start services:   cd $PROJECT_ROOT && make up"
echo "  3. Open dashboard:   https://ops.serial.tv"
echo ""
echo "NOTE: Log out and back in for docker group changes to take effect."
echo ""
