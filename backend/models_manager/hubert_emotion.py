import numpy as np
import torch

try:
    from transformers import pipeline
    HAS_TRANSFORMERS = True
except ImportError:
    HAS_TRANSFORMERS = False

class HubertModelManager:
    """Singleton Manager for Hubert Large Speech Emotion Recognition."""
    _instance = None
    _pipeline = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(HubertModelManager, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def load_model(self):
        if self._pipeline is not None:
            return self._pipeline
        
        if not HAS_TRANSFORMERS:
            print("[WARN] Transformers not installed. Hubert model will use fallback simulation.")
            return None

        model_name = "superb/hubert-large-superb-er"
        device = 0 if torch.cuda.is_available() else -1
        try:
            print(f"[INFO] Loading Hubert Large model: {model_name} on device {device}...")
            self._pipeline = pipeline(
                "audio-classification", 
                model=model_name, 
                device=device
            )
            print("[INFO] Hubert model loaded successfully.")
        except Exception as e:
            print(f"[ERROR] Failed to load Hubert model: {e}. Falling back to simulation.")
            self._pipeline = None
        return self._pipeline

    def predict(self, audio_data: np.ndarray, samplerate: int = 16000) -> str:
        """Predicts the emotion of a given audio segment."""
        pipe = self.load_model()
        if pipe is None:
            raise RuntimeError("Hubert model is not initialized/loaded.")

        try:
            results = pipe(audio_data)
            if results and len(results) > 0:
                best_match = max(results, key=lambda x: x["score"])
                label_mapping = {
                    "neu": "neutral",
                    "hap": "happy",
                    "ang": "angry",
                    "sad": "sad",
                    "sur": "surprise",
                    "neutral": "neutral",
                    "happy": "happy",
                    "angry": "angry",
                    "sad": "sad",
                    "surprise": "surprise"
                }
                raw_label = best_match["label"].lower()
                return label_mapping.get(raw_label, "neutral")
        except Exception as e:
            print(f"[ERROR] Hubert prediction failed: {e}")
        
        return "neutral"
