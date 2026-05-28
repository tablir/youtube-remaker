# YouTube Remaker — Master Plan

## Goal
Fully automated pipeline that takes a YouTube video URL and produces
a completely remade video — new script, new voiceover, new thumbnail,
stock footage — assembled and published to YouTube.

Zero manual intervention after triggering the pipeline.

---

## Infrastructure (DONE ✅)

```
Server:     Hetzner CX43 — 178.104.218.174
Domain:     ops.serial.tv (Cloudflare DNS)
SSL:        Let's Encrypt via DNS-01 challenge (Cloudflare API)
Access:     IP whitelist 92.40.110.0/24
```

### Running containers
| Container | Purpose | Status |
|-----------|---------|--------|
| traefik | Reverse proxy + SSL | ✅ Running |
| postgres | n8n database | ✅ Running (healthy) |
| n8n | Workflow orchestrator | ✅ Running |
| pipeline | CLI tools (yt-dlp, ffmpeg, edge-tts, gallery-dl, ImageMagick) | ✅ Running |
| whisper | Audio transcription FastAPI (faster-whisper medium) | ✅ Running |

### Installed tools in pipeline container
| Tool | Version | Purpose |
|------|---------|---------|
| yt-dlp | 2026.03.17 | YouTube download |
| ffmpeg | 7.1.4 | Video assembly |
| edge-tts | 7.2.8 | Free voiceover |
| gallery-dl | 1.32.1 | Archival footage |
| ImageMagick | 7.1.1 | Thumbnail processing |

### GitHub
```
Repo:    github.com/tablir/youtube-remaker
Branch:  main
Tags:    v1.0.0 → v1.1.0 → v1.2.0
Auditor: G:\CLAUDE-AGENT-FOLDER\YT-Repo-Auditor\
```

---

## Pipeline — 7 Steps

### Step 1: Research ← BUILD NEXT
**Goal:** Extract transcript + metadata + thumbnail from YouTube URL

```
Trigger: Webhook (YouTube URL)
         ↓
n8n Execute Command → yt-dlp on pipeline container
         ↓
Extract: transcript.txt, metadata.json, thumbnail.jpg
         ↓
Save to: /data/output/01_research/
```

**n8n nodes needed:**
- Webhook (trigger)
- Execute Command (yt-dlp)
- Code (parse SRT → clean text)
- Write Binary File (save files)

**Fallback:** If no subtitles → send audio to whisper:8080/transcribe

---

### Step 2: Writer
**Goal:** Rewrite transcript into fresh script via Claude API

```
Read: /data/output/01_research/transcript.txt
      ↓
HTTP Request → Claude API
Prompt: config/prompts/rewrite_script.txt
      ↓
Save: /data/output/02_script/rewritten_script.txt
```

**n8n nodes needed:**
- Read Binary File
- HTTP Request (Claude API)
- Write Binary File

---

### Step 3: Voice
**Goal:** Generate voiceover from rewritten script

```
Read: /data/output/02_script/rewritten_script.txt
      ↓
Switch node: edge-tts (free) OR ElevenLabs API (premium)
      ↓
Execute Command → edge-tts on pipeline container
      ↓
Save: /data/output/03_voice/voiceover.mp3
```

**n8n nodes needed:**
- Read Binary File
- Switch (voice engine selector)
- Execute Command (edge-tts)
- HTTP Request (ElevenLabs — optional)
- Write Binary File

---

### Step 4: Thumbnail
**Goal:** Generate new thumbnail from original + script

```
Read: /data/output/01_research/thumbnail.jpg
Read: /data/output/02_script/rewritten_script.txt
      ↓
HTTP Request → Gemini API (Nano Banana 2) → img2img
Prompt: config/prompts/thumbnail_gen.txt
      ↓
Execute Command → ImageMagick (add text overlay)
      ↓
Save: /data/output/04_thumbnail/thumbnail_final.png
```

**n8n nodes needed:**
- Read Binary File (×2)
- HTTP Request (Gemini API)
- Execute Command (ImageMagick)
- Write Binary File

---

### Step 5: Footage
**Goal:** Find and download stock footage clips matching script scenes

```
Read: /data/output/02_script/rewritten_script.txt
      ↓
HTTP Request → Claude API → generate search queries
Prompt: config/prompts/generate_queries.txt
      ↓
Switch: content type routing
  travel/lifestyle → Pexels API + Pixabay API
  historical       → gallery-dl (archive.org, Wikipedia Commons)
  educational      → Pexels + Pixabay + Storyblocks
      ↓
SQLite cache check → avoid duplicate downloads
      ↓
Download clips in batches of 50
      ↓
Execute Command → FFmpeg (normalize each clip)
      ↓
Save: /data/output/05_footage/clip_001.mp4 ... clip_NNN.mp4
```

**n8n nodes needed:**
- HTTP Request (Claude API — queries)
- Switch (content type)
- HTTP Request (Pexels API)
- HTTP Request (Pixabay API)
- Execute Command (gallery-dl)
- Execute Command (FFmpeg normalize)
- Loop (batch processing)
- SQLite node (cache)

---

### Step 6: Editor
**Goal:** Assemble final video from clips + voiceover

```
Input: /data/output/05_footage/clip_*.mp4
       /data/output/03_voice/voiceover.mp3
      ↓
Execute Command → FFmpeg:
  1. Normalize all clips (1920x1080, 30fps, h264)
  2. Concatenate clips
  3. Trim/loop to match voiceover duration
  4. Merge video + voiceover
      ↓
Save: /data/output/06_edit/final_video.mp4
```

**n8n nodes needed:**
- Execute Command (FFmpeg — normalize)
- Execute Command (FFmpeg — concatenate)
- Execute Command (FFmpeg — merge audio)
- Write Binary File

---

### Step 7: Publisher
**Goal:** Generate metadata and publish to YouTube

```
Read: /data/output/02_script/rewritten_script.txt
      ↓
HTTP Request → Claude API → generate title, description, tags
Prompt: config/prompts/generate_metadata.txt
      ↓
YouTube Data API → upload video + thumbnail + metadata
      ↓
Save: /data/output/07_publish/publish_report.txt
```

**n8n nodes needed:**
- HTTP Request (Claude API — metadata)
- HTTP Request (YouTube API — upload)
- HTTP Request (YouTube API — set thumbnail)
- Write Binary File

---

## Content Type Routing

| Content Type | Footage Sources |
|---|---|
| travel / lifestyle | Pexels + Pixabay |
| historical | gallery-dl + archive.org + Wikipedia Commons |
| educational | Pexels + Pixabay + Storyblocks |
| news | Pexels + Pixabay + archive.org |
| mixed | All sources combined |

Detection: HTTP Request → Claude API → config/prompts/content_type_detect.txt

---

## API Keys Status

| Key | Status | Used in |
|-----|--------|---------|
| GEMINI_API_KEY | ✅ Set | Step 4 — Thumbnail |
| ELEVENLABS_API_KEY | ✅ Set | Step 3 — Voice (premium) |
| PEXELS_API_KEY | ✅ Set | Step 5 — Footage |
| PIXABAY_API_KEY | ✅ Set | Step 5 — Footage |
| UNSPLASH_ACCESS_KEY | ✅ Set | Step 5 — Footage (photos) |
| CF_API_TOKEN | ✅ Set | Traefik SSL |
| CLAUDE_API_KEY | ⏳ Pending | Steps 2, 4, 5, 7 |
| YOUTUBE_CLIENT_ID | ⏳ Pending | Step 7 — Publishing |
| YOUTUBE_CLIENT_SECRET | ⏳ Pending | Step 7 — Publishing |
| STORYBLOCKS_API_KEY | ⏳ Pending | Step 5 — Premium footage |

---

## Build Order

```
Phase 1 — Core pipeline (no Claude API needed):
  [x] Infrastructure
  [ ] Workflow 01: Research     ← START HERE
  [ ] Workflow 03: Voice        (edge-tts, free)
  [ ] Workflow 06: Editor       (FFmpeg only)

Phase 2 — AI features (needs Claude API):
  [ ] Workflow 02: Writer       (Claude API)
  [ ] Workflow 04: Thumbnail    (Gemini API — already have key)
  [ ] Workflow 05: Footage      (Claude API for queries)
  [ ] content_type_detect       (Claude API)

Phase 3 — Publishing:
  [ ] Workflow 07: Publisher    (YouTube Data API)

Phase 4 — Main pipeline:
  [ ] main_pipeline.json        (orchestrates all 7 workflows)
```

---

## Versioning

| Tag | Description |
|-----|-------------|
| v1.0.0 | Initial stable release — infrastructure ready |
| v1.1.0 | All services running, SSL active, tools verified |
| v1.2.0 | Medium issues fixed, deployment docs updated |
| v2.0.0 | Target — all 7 workflows complete, end-to-end working |

---

## Key Paths on Server

```
Project:  /opt/youtube-remaker
Data:     /data/output/ (01-07)
Cache:    /data/cache/footage_cache.db
Models:   /data/models/whisper/
Refs:     /data/references/ (travel, historical, educational...)
Logs:     /data/logs/
```

## Whisper API (internal)

```
POST http://whisper:8080/transcribe
Body: multipart/form-data — audio file

GET  http://whisper:8080/health
Response: {"status":"ok","model":"medium","device":"cpu"}
```
