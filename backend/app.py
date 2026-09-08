import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .models_manager import whisper_manager, hubert_manager, gemini_manager, fer_manager

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[STARTUP] Pre-loading AI models to GPU...")
    # Load Whisper
    try:
        await asyncio.to_thread(whisper_manager.load_model)
    except Exception as e:
        print(f"[STARTUP ERROR] Failed pre-loading Whisper: {e}")
        
    # Load Hubert
    try:
        await asyncio.to_thread(hubert_manager.load_model)
    except Exception as e:
        print(f"[STARTUP ERROR] Failed pre-loading Hubert: {e}")
        
    # Initialize Gemini API configuration
    try:
        await asyncio.to_thread(gemini_manager.load_model)
    except Exception as e:
        print(f"[STARTUP ERROR] Failed initializing Gemini: {e}")

    # Load FER
    try:
        await asyncio.to_thread(fer_manager.load_model)
    except Exception as e:
        print(f"[STARTUP ERROR] Failed pre-loading FER: {e}")
        
    print("[STARTUP] Models and API configurations loaded successfully.")
    yield

app = FastAPI(
    title="PerformAi Acting Analysis Server",
    description="Asynchronous AI orchestration server for multi-user acting coach feedback",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes router to register all endpoints
from .routes import router
app.include_router(router)
