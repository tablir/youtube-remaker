# ============================================
# YouTube Remaker — Makefile
# ============================================

# Start the entire system
up:
	docker-compose up -d

# Start with image rebuild
up-build:
	docker-compose up -d --build

# Stop the entire system
down:
	docker-compose down

# Restart the entire system
restart:
	docker-compose down && docker-compose up -d

# ============================================
# Updates and deployment
# ============================================

# Pull latest code from GitHub and restart
pull:
	git pull
	docker-compose up -d --build

# Update yt-dlp and gallery-dl only
update-tools:
	docker-compose exec pipeline pip install -U yt-dlp gallery-dl

# Update n8n only
update-n8n:
	docker-compose pull n8n
	docker-compose up -d n8n

# ============================================
# Logs
# ============================================

# Logs for all containers
logs:
	docker-compose logs -f

# Logs for n8n only
logs-n8n:
	docker-compose logs -f n8n

# Logs for pipeline only
logs-pipeline:
	docker-compose logs -f pipeline

# Logs for whisper only
logs-whisper:
	docker-compose logs -f whisper

# Logs for postgres only
logs-db:
	docker-compose logs -f postgres

# ============================================
# Status and monitoring
# ============================================

# Status of all containers
status:
	docker-compose ps

# CPU and RAM usage
stats:
	docker stats

# Run pipeline health check
health:
	docker-compose exec pipeline python scripts/healthcheck.py

# Disk usage
disk:
	df -h /data

# ============================================
# Data management
# ============================================

# Clean temporary files
clean-temp:
	rm -rf /data/temp/*

# Clean all output folders (use with caution!)
clean-output:
	rm -rf /data/output/*/

# Clean footage SQLite cache
clean-cache:
	rm -f /data/cache/footage_cache.db

# Show size of all data folders
size:
	du -sh /data/*/

# ============================================
# Backup
# ============================================

# Full backup of all data
backup:
	tar -czf /data/backup_$(shell date +%Y%m%d_%H%M%S).tar.gz \
		/data/n8n \
		/data/postgres \
		/data/cache

# Export all n8n workflows to JSON
backup-workflows:
	docker-compose exec n8n n8n export:workflow \
		--all \
		--output=/data/backup/workflows_$(shell date +%Y%m%d).json

# ============================================
# Database
# ============================================

# Connect to PostgreSQL
db:
	docker-compose exec postgres psql -U n8n -d n8n

# Backup PostgreSQL database
backup-db:
	docker-compose exec postgres pg_dump -U n8n n8n > \
		/data/backup/postgres_$(shell date +%Y%m%d_%H%M%S).sql

# ============================================
# Setup and installation
# ============================================

# Initial server setup
install:
	bash setup/install.sh

# Create required data folder structure
dirs:
	bash setup/setup_dirs.sh

# Copy .env.example to .env
env:
	cp .env.example .env
	@echo "Fill in your API keys in .env file!"

# ============================================
# n8n workflows
# ============================================

# Import all workflows into n8n
import-workflows:
	for f in workflows/*.json; do \
		docker-compose exec n8n n8n import:workflow --input=$$f; \
	done

# Export all workflows from n8n
export-workflows:
	docker-compose exec n8n n8n export:workflow \
		--all \
		--output=/home/node/workflows/

# ============================================
# Help
# ============================================

help:
	@echo ""
	@echo "YouTube Remaker — available commands:"
	@echo ""
	@echo "  make up               — start the system"
	@echo "  make down             — stop the system"
	@echo "  make restart          — restart the system"
	@echo "  make pull             — update from GitHub and restart"
	@echo "  make status           — show container status"
	@echo "  make logs             — show all container logs"
	@echo "  make health           — run health check"
	@echo "  make disk             — show disk usage"
	@echo "  make stats            — show CPU and RAM usage"
	@echo "  make backup           — backup all data"
	@echo "  make clean-temp       — clean temp folder"
	@echo "  make update-tools     — update yt-dlp and gallery-dl"
	@echo "  make import-workflows — import workflows into n8n"
	@echo "  make export-workflows — export workflows from n8n"
	@echo ""

.PHONY: up up-build down restart pull update-tools update-n8n \
	logs logs-n8n logs-pipeline logs-whisper logs-db \
	status stats health disk clean-temp clean-output clean-cache size \
	backup backup-workflows backup-db db install dirs env \
	import-workflows export-workflows help
