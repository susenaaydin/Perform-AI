import asyncio
import io
import time
from typing import Dict, Any
import numpy as np
import soundfile as sf
from fastapi import WebSocket

from ..models_manager import whisper_manager, hubert_manager, gemini_manager

# Global active sessions memory state
ACTIVE_SESSIONS: Dict[str, Dict[str, Any]] = {}

def decode_audio_bytes(audio_bytes: bytes) -> np.ndarray:
    if not audio_bytes:
        return np.zeros(0, dtype=np.float32)

    # Check if we have a WAV header (RIFF) to avoid throwing soundfile exception on raw PCM streams
    if audio_bytes.startswith(b'RIFF'):
        try:
            with io.BytesIO(audio_bytes) as audio_file:
                data, samplerate = sf.read(audio_file)
                if samplerate != 16000:
                    import librosa
                    data = librosa.resample(data, orig_sr=samplerate, target_sr=16000)
                return data.astype(np.float32)
        except Exception as e:
            print(f"[WARN] Failed to decode WAV audio bytes: {e}")
            
    # Default / Fallback: Assume raw 16-bit PCM Mono (99% of streaming cases)
    try:
        raw_data = np.frombuffer(audio_bytes, dtype=np.int16)
        return raw_data.astype(np.float32) / 32768.0
    except Exception as e:
        print(f"[ERROR] Failed to decode raw PCM audio bytes: {e}")
        return np.zeros(16000, dtype=np.float32)


def merge_transcripts(old_text: str, new_text: str) -> str:
    if not old_text:
        return new_text
    if not new_text:
        return old_text
        
    old_words = old_text.strip().split()
    new_words = new_text.strip().split()
    
    # Clean words for comparison
    def clean_word(w):
        # Handle Turkish lowercase mapping explicitly
        mapping = {"I": "ı", "İ": "i", "Ğ": "ğ", "Ü": "ü", "Ş": "ş", "Ö": "ö", "Ç": "ç"}
        w_mapped = "".join(mapping.get(c, c.lower()) for c in w)
        return w_mapped.translate(str.maketrans("", "", ".,?!;:()\"'-*"))
        
    old_words_clean = [clean_word(w) for w in old_words]
    new_words_clean = [clean_word(w) for w in new_words]
    
    max_overlap = min(len(old_words), len(new_words), 15)
    best_overlap_len = 0
    
    for l in range(1, max_overlap + 1):
        suffix = old_words_clean[-l:]
        prefix = new_words_clean[:l]
        if suffix == prefix:
            best_overlap_len = l
            
    if best_overlap_len > 0:
        merged_words = old_words + new_words[best_overlap_len:]
    else:
        # Check if new text is fully contained inside the old text
        old_clean_str = " ".join(old_words_clean)
        new_clean_str = " ".join(new_words_clean)
        if new_clean_str in old_clean_str:
            return old_text
        merged_words = old_words + new_words
        
    return " ".join(merged_words)


async def run_whisper_transcription_loop(user_id: str, websocket: WebSocket):
    try:
        last_processed_total_bytes = 0
        while True:
            try:
                await asyncio.sleep(1.0)
                session = ACTIVE_SESSIONS.get(user_id)
                if not session:
                    break

                # Skip this interval if a transcription is already in progress to prevent queue buildup
                if session.get("is_transcribing", False):
                    continue

                total_received = session.get("total_audio_bytes_received", 0)
                
                # EĞER HİÇ SES VERİSİ GELMEDİYSE VEYA YENİ VERİ BİRİKMEDİYSE PAS GEÇ (Çökmeyi Önler)
                if total_received == 0 or total_received <= last_processed_total_bytes:
                    continue
                    
                # Whisper en azından küçük bir ses dilimi (örn: 16KB+ veri) görsün
                if total_received - last_processed_total_bytes < 16000:
                    continue

                session["is_transcribing"] = True
                try:
                    buffer_len = len(session["audio_byte_buffer"])
                    bytes_needed = 480000
                    if buffer_len >= bytes_needed:
                        buffer_bytes = bytes(session["audio_byte_buffer"][-bytes_needed:])
                    else:
                        buffer_bytes = bytes(session["audio_byte_buffer"])
                    
                    audio_array = decode_audio_bytes(buffer_bytes)
                    if audio_array is None or len(audio_array) == 0:
                        continue
                        
                    transcript = await asyncio.to_thread(whisper_manager.transcribe, audio_array)
                    
                    if transcript and transcript.strip():
                        session["transcript_accumulator"] = merge_transcripts(
                            session.get("transcript_accumulator", ""),
                            transcript
                        )
                        if "outbound_queue" in session:
                            session["outbound_queue"].append({
                                "type": "live_transcript",
                                "text": transcript
                            })
                    
                    # Update processed total bytes only after a run finishes
                    last_processed_total_bytes = total_received
                finally:
                    session["is_transcribing"] = False
            except Exception as inner_e:
                print(f"[LOOP ERROR] Whisper loop inner error: {inner_e}")
                await asyncio.sleep(0.5)
                continue
    except asyncio.CancelledError:
        pass


async def run_hubert_emotion_loop(user_id: str, websocket: WebSocket):
    try:
        while True:
            try:
                await asyncio.sleep(3.0)
                session = ACTIVE_SESSIONS.get(user_id)
                if not session:
                    break

                # Skip if emotion prediction is already in progress to prevent queue buildup
                if session.get("is_predicting_emotion", False):
                    continue

                buffer = session["audio_byte_buffer"]
                
                # Hubert ses duygu analizi için en az 3 saniyelik veri (96000 byte) birikmesini bekle
                if len(buffer) < 96000:
                    continue

                session["is_predicting_emotion"] = True
                try:
                    bytes_needed = 96000
                    sliced_bytes = bytes(buffer[-bytes_needed:])

                    audio_array = decode_audio_bytes(sliced_bytes)
                    if audio_array is None or len(audio_array) == 0:
                        continue
                        
                    predicted_emotion = await asyncio.to_thread(hubert_manager.predict, audio_array)
                    
                    elapsed_seconds = time.time() - session["session_start_time"]
                    session["audio_timeline"].append({
                        "timestamp_end": elapsed_seconds,
                        "emotion": predicted_emotion
                    })

                    if "outbound_queue" in session:
                        session["outbound_queue"].append({
                            "type": "audio_analysis",
                            "timestamp": elapsed_seconds,
                            "emotion": predicted_emotion
                        })
                finally:
                    session["is_predicting_emotion"] = False
            except Exception as inner_e:
                print(f"[LOOP ERROR] Hubert loop inner error: {inner_e}")
                await asyncio.sleep(0.5)
                continue
    except asyncio.CancelledError:
        pass


async def run_gemini_loop(user_id: str, websocket: WebSocket):
    """Loop running every 10 seconds to generate live acting suggestions (Mod A only)."""
    try:
        while True:
            await asyncio.sleep(10.0)
            session = ACTIVE_SESSIONS.get(user_id)
            if not session or session["session_mode"] != "live":
                continue

            elapsed_seconds = time.time() - session["session_start_time"]
            recent_v_items = [v for v in session["visual_timeline"] if v["timestamp"] >= elapsed_seconds - 10]
            recent_emotions = [v["emotion"] for v in recent_v_items]
            recent_postures = [v.get("posture", "neutral") for v in recent_v_items if v.get("posture", "neutral") != "neutral"]
            recent_gestures = [v.get("gesture", "none") for v in recent_v_items if v.get("gesture", "none") not in ["none", "natural"]]
            recent_audios = [a["emotion"] for a in session["audio_timeline"] if a["timestamp_end"] >= elapsed_seconds - 10]

            prompt = (
                f"Sen profesyonel bir tiyatro ve oyunculuk koçusun. Görevin oyuncunun son 10 saniyelik performansını analiz etmektir.\n\n"
                f"VERİLER:\n"
                f"- Sahnelenen Tiradın Kuralları: {session['triad_rules']}\n"
                f"- Son 10 Saniyede Tespit Edilen Yüz İfadeleri: {', '.join(recent_emotions) if recent_emotions else 'neutral'}\n"
                f"- Son 10 Saniyede Tespit Edilen Ses Tonları: {', '.join(recent_audios) if recent_audios else 'neutral'}\n"
                f"- Beden Duruş Sapmaları: {', '.join(set(recent_postures)) if recent_postures else 'Normal/Nötr'}\n"
                f"- Olağandışı El/Kol Hareketleri: {', '.join(set(recent_gestures)) if recent_gestures else 'Normal/Yok'}\n"
                f"- Son 10 Saniyede Konuşulan Replikler: '{session['transcript_accumulator']}'\n\n"
                f"YORUMLAMA REHBERİ (Ham etiketlerin sanatsal anlamları):\n"
                f"1. Yüz İfadeleri (0-7):\n"
                f"   - 'neutral' (nötr) / 'sad' (üzgün): İçsel odaklanma, melankoli, sessiz acı, tefekkür veya durağanlık.\n"
                f"   - 'happy' (mutlu): Sahnedeki hafiflik, neşe, umut, enerji veya canlılık.\n"
                f"   - 'surprise' (şaşkın): Şok, hayret veya ani farkındalık.\n"
                f"   - 'fear' (korku) / 'disgust' (iğrenme) / 'contempt' (küçümseme): Karakterin gerginliği, tiksinme veya üstünlük taslama.\n"
                f"   - 'angry' (öfkeli): Performansta yüksek tutku, çatışma, gerilim veya duygusal yoğunluk.\n"
                f"2. Ses Tonu (0-3):\n"
                f"   - 'neutral' (nötr) / 'sad' (üzgün): Sakinlik, hüzün veya durgun tonlama.\n"
                f"   - 'angry' (öfkeli): Yüksek perdeden çıkışlar, dramatik çatışma, öfke.\n"
                f"   - 'happy' (mutlu): Dinamik, neşeli, yüksek enerjili tonlama.\n"
                f"3. Beden Bilgileri (posture, gesture): Duruş kambursa ('slouched') dik durması, gerginse ('tense') rahatlaması yönünde ikincil önemde (daha az öncelikli) yapıcı geri bildirim verilebilir.\n\n"
                f"GÖREV VE KRİTİK KURAL:\n"
                f"Yukarıdaki verileri ve replikleri 'Tirad Kuralları' bağlamında değerlendir.\n"
                f"Mobil ekran canlı geri bildirimi için:\n"
                f"1. Kesinlikle EN FAZLA 1 veya 2 kısa cümle yaz (toplam en fazla 15-25 kelime). Aksi takdirde ekran taşar.\n"
                f"2. Doğrudan tavsiyeye geç, 'Son 10 saniyede...' gibi gereksiz giriş ifadeleri kullanma.\n"
                f"3. Yanıtı tamamen Türkçe dilinde, yapıcı, teşvik edici bir oyunculuk koçu olarak üret."
            )

            try:
                feedback = await asyncio.to_thread(gemini_manager.generate_feedback, prompt)
                
                # Post-processing: Force hard-limit to 2 sentences to prevent UI overflow
                if feedback:
                    # Replace common sentence end symbols with a standard dot for clean splitting
                    temp_feedback = feedback.replace('!', '.').replace('?', '.')
                    sentences = [s.strip() for s in temp_feedback.split('.') if s.strip()]
                    if len(sentences) > 2:
                        feedback = ". ".join(sentences[:2]) + "."

                if "outbound_queue" in session:
                    session["outbound_queue"].append({
                        "type": "coaching",
                        "timestamp": elapsed_seconds,
                        "message": feedback
                    })
            except Exception as e:
                print(f"[LOOP ERROR] Gemini feedback loop error: {e}")
                pass
    except asyncio.CancelledError:
        pass

