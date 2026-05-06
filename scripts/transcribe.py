# transcribe.py
# FastAPI transcription service for YouTube Remaker pipeline
# Called by n8n via HTTP Request node
# Endpoint: POST http://whisper:8080/transcribe

import os
import shutil
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel

# ============================================
# Logging
# ============================================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================
# Config from environment
# ============================================
WHISPER_MODEL = os.getenv("WHISPER_MODEL", "medium")
WHISPER_DEVICE = os.getenv("WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")
TEMP_DIR = "/data/temp"

# ============================================
# Load model once at startup
# ============================================
model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    logger.info(f"Loading Whisper model: {WHISPER_MODEL} ({WHISPER_DEVICE}, {WHISPER_COMPUTE_TYPE})")
    model = WhisperModel(
        WHISPER_MODEL,
        device=WHISPER_DEVICE,
        compute_type=WHISPER_COMPUTE_TYPE,
        # After first download — use local cache only (no HuggingFace calls)
        local_files_only=False
    )
    logger.info("Whisper model loaded and ready!")
    yield
    logger.info("Shutting down Whisper service")

# ============================================
# FastAPI app
# ============================================
app = FastAPI(
    title="Whisper Transcription Service",
    description="Audio transcription for YouTube Remaker pipeline",
    version="1.0.0",
    lifespan=lifespan
)

# ============================================
# Health check endpoint
# ============================================
@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model": WHISPER_MODEL,
        "device": WHISPER_DEVICE,
        "compute_type": WHISPER_COMPUTE_TYPE
    }

# ============================================
# Transcription endpoint
# ============================================
@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    # Save uploaded file to temp directory
    temp_path = os.path.join(TEMP_DIR, file.filename)

    try:
        logger.info(f"Transcribing: {file.filename}")

        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Transcribe with faster-whisper
        segments, info = model.transcribe(
            temp_path,
            beam_size=5,
            language="en",
            vad_filter=True,           # Filter out silence
            vad_parameters=dict(
                min_silence_duration_ms=500
            )
        )

        # Collect all segments into clean text
        text = " ".join([segment.text.strip() for segment in segments])

        logger.info(f"Transcription complete: {len(text.split())} words, language: {info.language}")

        return JSONResponse(content={
            "text": text,
            "language": info.language,
            "duration": info.duration,
            "word_count": len(text.split())
        })

    except Exception as e:
        logger.error(f"Transcription failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        # Always clean up temp file
        if os.path.exists(temp_path):
            os.remove(temp_path)
            logger.info(f"Cleaned up temp file: {temp_path}")
