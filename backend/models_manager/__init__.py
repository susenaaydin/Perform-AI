from .whisper_speech import WhisperModelManager
from .hubert_emotion import HubertModelManager
from .gemini_llm import GeminiModelManager
from .fer_emotion import FerModelManager

whisper_manager = WhisperModelManager()
hubert_manager = HubertModelManager()
gemini_manager = GeminiModelManager()
fer_manager = FerModelManager()

__all__ = [
    "whisper_manager",
    "hubert_manager",
    "gemini_manager",
    "fer_manager",
    "WhisperModelManager",
    "HubertModelManager",
    "GeminiModelManager",
    "FerModelManager"
]
