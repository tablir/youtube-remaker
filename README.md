# YouTube Remaker Pipeline

Automated YouTube video remake pipeline running on Hetzner CX43.
Takes a YouTube URL → produces a fully remade video → publishes to YouTube.

---

## Server

```
Host:     ops.serial.tv
IP:       178.104.218.174
SSH:      ssh root@178.104.218.174
Location: Falkenstein, Germany
Specs:    8 vCPU / 16GB RAM / 160GB SSD / 8GB swap
```

---

## Quick Start

```bash
# Connect to server
ssh root@178.104.218.174

# Go to project
cd /opt/youtube-remaker

# Pull latest changes
make pull

# Check status
make status

# View logs
make logs
```

---

## First Deploy (fresh server)

```bash
# Clone repo
git clone git@github.com:tablir/youtube-remaker.git /opt/youtube-remaker
cd /opt/youtube-remaker

# Setup environment
cp .env.example .env
nano .env  # fill in all API keys

# Generate n8n encryption key
openssl rand -hex 32  # paste result into .env as N8N_ENCRYPTION_KEY

# Install everything
bash setup/install.sh

# Setup Traefik + n8n
bash setup/setup_n8n.sh

# Start all services
make up

# Open n8n
# https://ops.serial.tv
```

---

## Pipeline Steps

| Step | Tool | Input | Output |
|------|------|-------|--------|
| 1. Research | yt-dlp | YouTube URL | transcript.txt, metadata.json, thumbnail.jpg |
| 2. Writer | Claude API | transcript.txt | rewritten_script.txt |
| 3. Voice | edge-tts / ElevenLabs | rewritten_script.txt | voiceover.mp3 |
| 4. Thumbnail | Gemini API + ImageMagick | script + thumbnail.jpg | thumbnail_final.png |
| 5. Footage | Pexels + Pixabay + gallery-dl | search queries | clip_001.mp4 ... |
| 6. Editor | FFmpeg | clips + voiceover | final_video.mp4 |
| 7. Publisher | YouTube Data API | final_video.mp4 | published URL |

---

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| n8n | https://ops.serial.tv | Workflow orchestrator |
| Whisper | http://whisper:8080 | Audio transcription (internal) |
| Pipeline | internal | CLI tools container |
| PostgreSQL | internal | n8n database |
| Traefik | :80/:443 | Reverse proxy + SSL |

---

## Data Directories (on server)

```
/data/
  output/
    01_research/    → transcript, metadata, thumbnail
    02_script/      → original + rewritten script
    03_voice/       → voiceover MP3
    04_thumbnail/   → base image + final thumbnail
    05_footage/     → downloaded clips
    06_edit/        → final_video.mp4
    07_publish/     → publish report
  cache/            → footage SQLite cache
  temp/             → temporary files
  models/whisper/   → faster-whisper model (downloaded once)
  references/       → style reference thumbnails by content type
  n8n/              → n8n data and workflows
  postgres/         → database files
  backup/           → backups
```

---

## API Keys

All keys stored in `/opt/youtube-remaker/.env` on server only.

| Key | Used for | Where to get |
|-----|----------|--------------|
| CLAUDE_API_KEY | Script rewriting | console.anthropic.com |
| GEMINI_API_KEY | Thumbnail generation | aistudio.google.com |
| ELEVENLABS_API_KEY | Premium voiceover | elevenlabs.io |
| PEXELS_API_KEY | Stock footage | pexels.com/api |
| PIXABAY_API_KEY | Stock footage | pixabay.com/api |
| STORYBLOCKS_API_KEY | Premium footage | storyblocks.com |
| YOUTUBE_CLIENT_ID | Publishing | console.cloud.google.com |
| YOUTUBE_CLIENT_SECRET | Publishing | console.cloud.google.com |

---

## Make Commands

```bash
make up              # start all services
make down            # stop all services
make restart         # restart all services
make pull            # git pull + rebuild
make status          # container status
make logs            # all logs
make logs-n8n        # n8n logs only
make logs-whisper    # whisper logs only
make health          # pipeline health check
make disk            # disk usage
make stats           # CPU + RAM usage
make backup          # backup n8n + postgres + cache
make backup-workflows # export n8n workflows to JSON
make import-workflows # import workflows into n8n
make update-tools    # update yt-dlp + gallery-dl
make clean-temp      # clean /data/temp
make clean-cache     # clean footage cache DB
```

---

## Whisper API

Internal service — called by n8n HTTP Request node.

```
POST http://whisper:8080/transcribe
Body: multipart/form-data, field: file (audio file)

Response:
{
  "text": "full transcript text",
  "language": "en",
  "duration": 847.3,
  "word_count": 2341
}

GET http://whisper:8080/health
Response: {"status": "ok", "model": "medium"}
```

---

## Footage Cache

SQLite database at `/data/cache/footage_cache.db`

Stores all found clip URLs to avoid duplicate API calls.
n8n checks cache before searching Pexels/Pixabay.

```bash
# View cache stats
make cache-stats

# Clear cache
make clean-cache
```

---

## Reference Thumbnails

Store style reference images in `/data/references/` by content type:

```
/data/references/
  travel/         → reference thumbnails for travel content
  historical/     → reference thumbnails for historical content
  educational/    → reference thumbnails for educational content
  lifestyle/      → reference thumbnails for lifestyle content
  news/           → reference thumbnails for news content
  entertainment/  → reference thumbnails for entertainment content
```

n8n picks the right reference based on `content_type_detect.txt` classification.

---

## Troubleshooting

**n8n not accessible:**
```bash
make logs-n8n
make status
```

**SSL certificate issues:**
```bash
# Check acme.json permissions (must be 600)
ls -la /data/traefik/acme.json
chmod 600 /data/traefik/acme.json
make restart
```

**Whisper not responding:**
```bash
make logs-whisper
# First run downloads model (~1.5GB) — wait for it
```

**Disk full:**
```bash
make disk
make clean-temp
# If footage folder is huge:
ls -lh /data/output/05_footage/ | tail
```

**yt-dlp fails (YouTube blocks):**
```bash
make update-tools  # update to latest yt-dlp
```
