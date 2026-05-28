# Deployment Guide

## Server

Hetzner CX43 — Ubuntu 24.04 LTS
- 8 vCPU / 16GB RAM / 160GB SSD / 8GB swap
- Docker + Docker Compose plugin
- Traefik reverse proxy + Let's Encrypt SSL
- Domain: ops.serial.tv

---

## Prerequisites

Before deploying, make sure you have:

- [ ] Hetzner CX43 server running Ubuntu 24.04
- [ ] DNS record: `ops.serial.tv` → server IP
- [ ] SSH key added to server
- [ ] GitHub SSH key added (`~/.ssh/github`)
- [ ] All API keys ready (see README.md → API Keys)

---

## Deploy Steps

### Step 1 — Connect to server
```bash
ssh root@178.104.218.174
```

### Step 2 — Clone repository
```bash
git clone git@github.com:tablir/youtube-remaker.git /opt/youtube-remaker
cd /opt/youtube-remaker
```

### Step 3 — Configure environment
```bash
cp .env.example .env
nano .env
```

Fill in all values. Generate encryption key:
```bash
openssl rand -hex 32
```
Paste result as `N8N_ENCRYPTION_KEY` in `.env`.

### Step 4 — Install server dependencies
```bash
bash setup/install.sh
```

Installs: Docker, Docker Compose, Make, Python 3, ImageMagick.

### Step 5 — Setup Traefik and n8n
```bash
bash setup/setup_n8n.sh
```

Creates:
- `/data/` directory structure
- `/data/traefik/acme.json` (chmod 600)
- `/data/traefik/traefik.yml`
- Pulls Docker images
- Builds pipeline and whisper containers

### Step 6 — Start all services
```bash
make up
```

### Step 7 — Verify
```bash
make status     # all containers running
make health     # pipeline tools OK
make logs-n8n   # n8n started without errors
```

### Step 8 — Open n8n
```
https://ops.serial.tv
Login: admin / (your N8N_BASIC_AUTH_PASSWORD)
```

### Step 9 — Import workflows
```bash
make import-workflows
```

---

## Update (after git changes)

```bash
cd /opt/youtube-remaker
make pull
```

This runs `git pull` + rebuilds containers automatically.

---

## Backup

```bash
make backup           # backup n8n + postgres + cache
make backup-workflows # export n8n workflows to JSON → git commit
```

---

## Rollback

```bash
cd /opt/youtube-remaker
git log --oneline     # find commit to rollback to
git checkout [commit]
make up
```

---

## Whisper First Run

On first start, Whisper downloads the `medium` model (~1.5GB).
This takes 5-10 minutes depending on server connection.
Model is cached in `/data/models/whisper/` — only downloaded once.

Monitor progress:
```bash
make logs-whisper
```

---

## SSL Certificate

Traefik obtains SSL certificate from Let's Encrypt automatically on first start.
Certificate stored in `/data/traefik/acme.json`.

**Important:** `acme.json` must always have `chmod 600` or Traefik refuses to start.

---

## Firewall Rules (Hetzner)

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | 92.40.110.0/24 | SSH access |
| 80 | TCP | Any | HTTP (redirects to HTTPS) |
| 443 | TCP | Any | HTTPS (Traefik) |

IP whitelist for n8n is handled by Traefik middleware (set via `ALLOWED_IPS` in `.env`).
