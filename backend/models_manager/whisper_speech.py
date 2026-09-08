import numpy as np
import torch

try:
    from faster_whisper import WhisperModel
    HAS_WHISPER = True
except ImportError:
    HAS_WHISPER = False

class WhisperModelManager:
    """Singleton Manager for faster-whisper Speech-to-Text."""
    _instance = None
    _model = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(WhisperModelManager, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def load_model(self):
        if self._model is not None:
            return self._model

        if not HAS_WHISPER:
            print("[WARN] faster-whisper not installed. Using fallback simulation.")
            return None

        model_size = "small"
        device = "cuda" if torch.cuda.is_available() else "cpu"
        compute_type = "float16" if device == "cuda" else "int8"

        try:
            print(f"[INFO] Loading Faster Whisper model: {model_size} on {device} ({compute_type})...")
            self._model = WhisperModel(model_size, device=device, compute_type=compute_type)
            print("[INFO] Whisper model loaded successfully.")
        except Exception as e:
            print(f"[ERROR] Failed to load Whisper model: {e}. Falling back to simulation.")
            self._model = None
        return self._model

    def transcribe(self, audio_data: np.ndarray) -> str:
        model = self.load_model()
        if model is None:
            raise RuntimeError("Whisper model is not initialized/loaded.")

        try:
            segments, info = model.transcribe(audio_data, beam_size=1, language="tr")
            text = " ".join([segment.text for segment in segments])
            return text.strip()
        except Exception as e:
            print(f"[ERROR] Whisper transcription failed: {e}")
            err_str = str(e).lower()
            if "libcublas" in err_str or "cuda" in err_str or "cublas" in err_str:
                print("[INFO] Attempting to re-initialize Whisper model on CPU to bypass CUDA errors...")
                try:
                    self._model = WhisperModel("small", device="cpu", compute_type="int8")
                    segments, info = self._model.transcribe(audio_data, beam_size=1, language="tr")
                    text = " ".join([segment.text for segment in segments])
                    return text.strip()
                except Exception as ex:
                    print(f"[ERROR] Whisper CPU fallback transcription also failed: {ex}")
            return ""

