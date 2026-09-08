import os
import json
import requests
from ..config.firebase_config import db

try:
    from google import genai
    HAS_GENAI = True
except ImportError:
    HAS_GENAI = False

try:
    import google.generativeai as genai_legacy
    HAS_GENAI_LEGACY = True
except ImportError:
    HAS_GENAI_LEGACY = False

class GeminiModelManager:
    """Singleton Manager for Gemini API Orchestration."""
    _instance = None
    _client = None
    _api_key = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(GeminiModelManager, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def load_model(self):
        """Initializes the API key and client."""
        if self._api_key is not None:
            return self._api_key

        # 1. Try reading from environment variable
        api_key = os.environ.get("GEMINI_API_KEY")

        # 2. Try reading from Firestore config
        if not api_key and db is not None:
            try:
                doc = db.collection("configs").document("server").get()
                if doc.exists:
                    doc_dict = doc.to_dict()
                    if doc_dict:
                        api_key = doc_dict.get("gemini_api_key")
            except Exception as e:
                print(f"[WARN] Failed to read Gemini API key from Firestore: {e}")

        if api_key:
            self._api_key = api_key.strip()
            print("[INFO] Gemini API Key loaded successfully.")
            
            # Setup GenAI SDK client if available
            if HAS_GENAI:
                try:
                    self._client = genai.Client(api_key=self._api_key)
                    print("[INFO] Google GenAI SDK client initialized.")
                except Exception as e:
                    print(f"[WARN] Failed to initialize Google GenAI SDK: {e}")
            elif HAS_GENAI_LEGACY:
                try:
                    genai_legacy.configure(api_key=self._api_key)
                    print("[INFO] Google GenerativeAI (Legacy) SDK configured.")
                except Exception as e:
                    print(f"[WARN] Failed to configure Google GenerativeAI legacy SDK: {e}")
        else:
            print("[WARN] Gemini API Key not found. GEMINI_API_KEY environment variable or configs/server doc in Firestore must be set.")

        return self._api_key

    def generate_feedback(self, prompt: str) -> str:
        """Generates acting coach advice feedback based on prompt details using Gemini API."""
        api_key = self.load_model()
        if not api_key:
            raise RuntimeError("Gemini API Key is not configured.")

        # 1. Attempt using modern GenAI SDK
        if HAS_GENAI and self._client:
            try:
                response = self._client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt
                )
                if response and response.text:
                    return response.text.strip()
            except Exception as e:
                print(f"[ERROR] Gemini GenAI SDK generation failed: {e}. Falling back...")

        # 2. Attempt using legacy GenerativeAI SDK
        if HAS_GENAI_LEGACY:
            try:
                model = genai_legacy.GenerativeModel("gemini-1.5-flash")
                response = model.generate_content(prompt)
                if response and response.text:
                    return response.text.strip()
            except Exception as e:
                print(f"[ERROR] Gemini Legacy SDK generation failed: {e}. Falling back to REST...")

        # 3. Bulletproof fallback: Direct HTTP REST call to Gemini API
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
            headers = {"Content-Type": "application/json"}
            payload = {
                "contents": [
                    {
                        "parts": [
                            {"text": prompt}
                        ]
                    }
                ]
            }
            resp = requests.post(url, headers=headers, json=payload, timeout=10)
            if resp.status_code == 200:
                result_json = resp.json()
                text = result_json['candidates'][0]['content']['parts'][0]['text']
                return text.strip()
            else:
                print(f"[ERROR] Gemini HTTP REST failed: HTTP {resp.status_code} - {resp.text}")
        except Exception as e:
            print(f"[ERROR] Gemini HTTP REST exception: {e}")

        raise RuntimeError("Gemini generation failed across all clients and REST fallbacks.")
