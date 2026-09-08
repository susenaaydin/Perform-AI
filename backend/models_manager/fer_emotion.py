import os
import json
import math
import numpy as np

try:
    import tflite_runtime.interpreter as tflite
except ImportError:
    try:
        import tensorflow.lite as tflite
    except ImportError:
        tflite = None

SELECTED_LANDMARKS = [1, 2, 4, 5, 6, 7, 13, 14, 17, 19, 33, 46, 52, 53, 55, 58, 61, 63, 65, 66, 70, 78, 80, 81, 82, 84, 87, 88, 91, 93, 94, 95, 98, 105, 107, 132, 133, 136, 144, 145, 146, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160, 161, 163, 168, 172, 173, 176, 178, 181, 191, 195, 197, 234, 246, 249, 263, 276, 282, 283, 285, 288, 291, 293, 295, 296, 300, 308, 310, 311, 312, 314, 317, 318, 321, 323, 324, 327, 334, 336, 361, 362, 365, 373, 374, 375, 377, 378, 379, 380, 381, 382, 384, 385, 386, 387, 388, 390, 397, 398, 400, 402, 405, 415, 454, 466]
LEFT_EYE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 246, 161, 160, 159, 158, 157, 173]
RIGHT_EYE = [263, 249, 390, 373, 374, 380, 381, 382, 362, 466, 388, 387, 386, 385, 384, 398]
OUTER_LIP = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78]
INNER_LIP = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]
ANGLE_TRIPLES = [(61, 13, 291), (61, 14, 291), (78, 13, 308), (78, 14, 308), (61, 0, 291), (13, 61, 14), (13, 291, 14), (78, 61, 95), (308, 291, 324), (33, 159, 133), (33, 145, 133), (263, 386, 362), (263, 374, 362), (70, 105, 107), (336, 334, 300), (55, 65, 52), (285, 295, 282), (234, 1, 454), (93, 1, 323), (152, 17, 0)]
FACE_LABELS = ["neutral", "happy", "sad", "surprise", "fear", "disgust", "angry", "contempt"]

class FerModelManager:
    """Singleton Manager for Facial Emotion Recognition (FER) model."""
    _instance = None
    _interpreter = None
    _mean = None
    _std = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(FerModelManager, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def load_model(self):
        if self._interpreter is not None:
            return self._interpreter

        if tflite is None:
            print("[WARN] tflite-runtime or tensorflow not installed. FER model unavailable.")
            return None

        base_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
        
        # Search path for model
        tflite_fallbacks = [
            os.path.join(base_dir, "..", "assets", "models", "fer", "emotion_mlp_float32.tflite"),
            "assets/models/fer/emotion_mlp_float32.tflite",
            "../assets/models/fer/emotion_mlp_float32.tflite",
            "emotion_mlp_float32.tflite"
        ]
        
        selected_model = None
        for path in tflite_fallbacks:
            if os.path.exists(path):
                selected_model = path
                break

        # Search path for standardizer json
        json_fallbacks = [
            os.path.join(base_dir, "..", "assets", "models", "fer", "feature_standardizer.json"),
            "assets/models/fer/feature_standardizer.json",
            "../assets/models/fer/feature_standardizer.json",
            "feature_standardizer.json"
        ]
        
        selected_json = None
        for path in json_fallbacks:
            if os.path.exists(path):
                selected_json = path
                break

        if not selected_model or not selected_json:
            print(f"[WARN] FER model files not found (Model: {selected_model}, JSON: {selected_json}).")
            return None

        try:
            print(f"[INFO] Loading FER model from {selected_model}...")
            self._interpreter = tflite.Interpreter(model_path=selected_model)
            self._interpreter.allocate_tensors()

            with open(selected_json, "r") as f:
                standardizer = json.load(f)
                self._mean = np.array(standardizer["mean"], dtype=np.float32)
                self._std = np.array(standardizer["std"], dtype=np.float32)

            print("[INFO] FER model loaded successfully.")
        except Exception as e:
            print(f"[ERROR] Failed to load FER model: {e}")
            self._interpreter = None

        return self._interpreter

    def predict(self, face_landmarks_468x3: np.ndarray) -> str:
        """Predicts emotion from a 468x3 array of raw facial landmarks."""
        interpreter = self.load_model()
        if interpreter is None:
            return "neutral"

        try:
            features = self._extract_features(face_landmarks_468x3)
            # Standardize features
            standardized = (features - self._mean) / (self._std + 1e-8)
            standardized = standardized.reshape(1, -1).astype(np.float32)

            # Check head yaw proxy for reliability (same as Kotlin)
            yaw_proxy_index = 360  # Sliced coords yaw index
            yaw = features[yaw_proxy_index]
            if abs(yaw) > 0.6:
                return "neutral"

            # Run interpreter
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()

            interpreter.set_tensor(input_details[0]['index'], standardized)
            interpreter.invoke()

            output_data = interpreter.get_tensor(output_details[0]['index'])[0]
            # Softmax
            exp_data = np.exp(output_data - np.max(output_data))
            confidences = exp_data / (np.sum(exp_data) + 1e-8)
            max_idx = np.argmax(confidences)

            if confidences[max_idx] < 0.05:
                return "neutral"
            return FACE_LABELS[max_idx]
        except Exception as e:
            print(f"[ERROR] FER model prediction failed: {e}")
            return "neutral"

    def _extract_features(self, landmarks: np.ndarray) -> np.ndarray:
        pts = landmarks.copy().astype(np.float32)
        left_eye_center = pts[LEFT_EYE].mean(axis=0)
        right_eye_center = pts[RIGHT_EYE].mean(axis=0)

        eye_center = (left_eye_center + right_eye_center) / 2.0
        eye_vec = right_eye_center[:2] - left_eye_center[:2]

        eye_dist = float(np.linalg.norm(eye_vec) + 1e-6)
        roll = math.atan2(float(eye_vec[1]), float(eye_vec[0]))

        pts[:, 0] -= eye_center[0]
        pts[:, 1] -= eye_center[1]
        pts[:, 2] -= eye_center[2]

        c = math.cos(-roll)
        s = math.sin(-roll)

        x = pts[:, 0].copy()
        y = pts[:, 1].copy()

        pts[:, 0] = c * x - s * y
        pts[:, 1] = s * x + c * y
        pts = pts / eye_dist

        features = []
        # 1. Coordinates features (116 landmarks * 3 = 348 values)
        for idx in SELECTED_LANDMARKS:
            features.extend([pts[idx, 0], pts[idx, 1], pts[idx, 2]])

        # 2. Engineered features
        mouth_width = self._dist2d(pts, 61, 291)
        mouth_open_1 = self._dist2d(pts, 13, 14)
        mouth_open_2 = self._dist2d(pts, 82, 312)
        mouth_open_3 = self._dist2d(pts, 87, 317)
        mouth_open = np.mean([mouth_open_1, mouth_open_2, mouth_open_3])
        mar = mouth_open / (mouth_width + 1e-6)

        outer_mouth_area = self._polygon_area(pts, OUTER_LIP)
        inner_mouth_area = self._polygon_area(pts, INNER_LIP)

        mouth_center = (pts[61] + pts[291]) / 2.0
        left_corner_lift = pts[61, 1] - mouth_center[1]
        right_corner_lift = pts[291, 1] - mouth_center[1]
        corner_lift_mean = (left_corner_lift + right_corner_lift) / 2.0
        corner_lift_diff = abs(left_corner_lift - right_corner_lift)

        mouth_slope = math.atan2(
            float(pts[291, 1] - pts[61, 1]),
            float(pts[291, 0] - pts[61, 0] + 1e-6)
        ) / math.pi

        features.extend([
            mouth_width, mouth_open_1, mouth_open_2, mouth_open_3, mouth_open, mar,
            outer_mouth_area, inner_mouth_area, left_corner_lift, right_corner_lift,
            corner_lift_mean, corner_lift_diff, mouth_slope
        ])

        left_eye_width = self._dist2d(pts, 33, 133)
        right_eye_width = self._dist2d(pts, 263, 362)

        left_ear = (
            self._dist2d(pts, 159, 145) +
            self._dist2d(pts, 158, 153) +
            self._dist2d(pts, 160, 144)
        ) / (3.0 * left_eye_width + 1e-6)

        right_ear = (
            self._dist2d(pts, 386, 374) +
            self._dist2d(pts, 385, 380) +
            self._dist2d(pts, 387, 373)
        ) / (3.0 * right_eye_width + 1e-6)

        ear_mean = (left_ear + right_ear) / 2.0
        ear_diff = abs(left_ear - right_ear)

        features.extend([
            left_eye_width, right_eye_width, left_ear, right_ear, ear_mean, ear_diff
        ])

        left_eye_center_val = pts[LEFT_EYE].mean(axis=0)
        right_eye_center_val = pts[RIGHT_EYE].mean(axis=0)
        left_brow_center = pts[[70, 63, 105, 66, 107]].mean(axis=0)
        right_brow_center = pts[[336, 296, 334, 293, 300]].mean(axis=0)

        left_brow_raise = float(np.linalg.norm(left_brow_center[:2] - left_eye_center_val[:2]))
        right_brow_raise = float(np.linalg.norm(right_brow_center[:2] - right_eye_center_val[:2]))

        brow_raise_mean = (left_brow_raise + right_brow_raise) / 2.0
        brow_raise_diff = abs(left_brow_raise - right_brow_raise)
        inner_brow_distance = self._dist2d(pts, 107, 336)

        features.extend([
            left_brow_raise, right_brow_raise, brow_raise_mean, brow_raise_diff, inner_brow_distance
        ])

        left_cheek_nose = self._dist2d(pts, 234, 1)
        right_cheek_nose = self._dist2d(pts, 454, 1)
        cheek_diff = abs(left_cheek_nose - right_cheek_nose)

        chin_mouth = self._dist2d(pts, 152, 17)
        nose_mouth = self._dist2d(pts, 1, 13)
        nose_chin = self._dist2d(pts, 1, 152)

        yaw_proxy = (left_cheek_nose - right_cheek_nose) / (left_cheek_nose + right_cheek_nose + 1e-6)
        pitch_proxy = float(pts[1, 1] - ((pts[33, 1] + pts[263, 1]) / 2.0))

        features.extend([
            left_cheek_nose, right_cheek_nose, cheek_diff, chin_mouth, nose_mouth, nose_chin,
            yaw_proxy, pitch_proxy, roll / math.pi
        ])

        mouth_asymmetry = corner_lift_diff
        eye_asymmetry = ear_diff
        brow_asymmetry = brow_raise_diff

        features.extend([mouth_asymmetry, eye_asymmetry, brow_asymmetry])

        for a, b, c in ANGLE_TRIPLES:
            features.append(self._angle_feature(pts, a, b, c))

        res = np.array(features, dtype=np.float32)
        return np.nan_to_num(res, nan=0.0, posinf=0.0, neginf=0.0)

    def _dist2d(self, pts, a, b):
        return float(np.linalg.norm(pts[a, :2] - pts[b, :2]))

    def _angle_feature(self, pts, a, b, c):
        u = pts[a, :2] - pts[b, :2]
        v = pts[c, :2] - pts[b, :2]
        cross = abs(float(u[0] * v[1] - u[1] * v[0]))
        dot = float(np.dot(u, v))
        angle = math.atan2(cross, dot)
        return angle / math.pi

    def _polygon_area(self, pts, indices):
        xy = pts[indices, :2]
        x = xy[:, 0]
        y = xy[:, 1]
        area = 0.5 * abs(float(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1))))
        return area
