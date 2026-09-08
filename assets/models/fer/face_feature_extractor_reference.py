"""
Reference feature extractor for emotion_mlp_float32.tflite.

This is a runtime reference extracted from the face training notebook.
It expects MediaPipe face landmarks as a numpy array with shape [468, 3].
"""

import math
import numpy as np

SELECTED_LANDMARKS = [1, 2, 4, 5, 6, 7, 13, 14, 17, 19, 33, 46, 52, 53, 55, 58, 61, 63, 65, 66, 70, 78, 80, 81, 82, 84, 87, 88, 91, 93, 94, 95, 98, 105, 107, 132, 133, 136, 144, 145, 146, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160, 161, 163, 168, 172, 173, 176, 178, 181, 191, 195, 197, 234, 246, 249, 263, 276, 282, 283, 285, 288, 291, 293, 295, 296, 300, 308, 310, 311, 312, 314, 317, 318, 321, 323, 324, 327, 334, 336, 361, 362, 365, 373, 374, 375, 377, 378, 379, 380, 381, 382, 384, 385, 386, 387, 388, 390, 397, 398, 400, 402, 405, 415, 454, 466]

LEFT_EYE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 246, 161, 160, 159, 158, 157, 173]
RIGHT_EYE = [263, 249, 390, 373, 374, 380, 381, 382, 362, 466, 388, 387, 386, 385, 384, 398]

OUTER_LIP = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78]
INNER_LIP = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]

ANGLE_TRIPLES = [(61, 13, 291), (61, 14, 291), (78, 13, 308), (78, 14, 308), (61, 0, 291), (13, 61, 14), (13, 291, 14), (78, 61, 95), (308, 291, 324), (33, 159, 133), (33, 145, 133), (263, 386, 362), (263, 374, 362), (70, 105, 107), (336, 334, 300), (55, 65, 52), (285, 295, 282), (234, 1, 454), (93, 1, 323), (152, 17, 0)]

FACE_LABELS = ["neutral", "happy", "sad", "surprise", "fear", "disgust", "angry", "contempt"]


def normalize_landmarks(landmarks):
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

    return pts, {
        "eye_dist": eye_dist,
        "roll": roll,
    }


def dist2d(pts, a, b):
    return float(np.linalg.norm(pts[a, :2] - pts[b, :2]))


def angle_feature(pts, a, b, c):
    u = pts[a, :2] - pts[b, :2]
    v = pts[c, :2] - pts[b, :2]

    cross = abs(float(u[0] * v[1] - u[1] * v[0]))
    dot = float(np.dot(u, v))

    angle = math.atan2(cross, dot)
    return angle / math.pi


def polygon_area(pts, indices):
    xy = pts[indices, :2]
    x = xy[:, 0]
    y = xy[:, 1]

    area = 0.5 * abs(
        float(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))
    )
    return area


def compute_engineered_features(pts, meta):
    features = []

    mouth_width = dist2d(pts, 61, 291)

    mouth_open_1 = dist2d(pts, 13, 14)
    mouth_open_2 = dist2d(pts, 82, 312)
    mouth_open_3 = dist2d(pts, 87, 317)
    mouth_open = np.mean([mouth_open_1, mouth_open_2, mouth_open_3])

    mar = mouth_open / (mouth_width + 1e-6)

    outer_mouth_area = polygon_area(pts, OUTER_LIP)
    inner_mouth_area = polygon_area(pts, INNER_LIP)

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
        mouth_width,
        mouth_open_1,
        mouth_open_2,
        mouth_open_3,
        mouth_open,
        mar,
        outer_mouth_area,
        inner_mouth_area,
        left_corner_lift,
        right_corner_lift,
        corner_lift_mean,
        corner_lift_diff,
        mouth_slope,
    ])

    left_eye_width = dist2d(pts, 33, 133)
    right_eye_width = dist2d(pts, 263, 362)

    left_ear = (
        dist2d(pts, 159, 145) +
        dist2d(pts, 158, 153) +
        dist2d(pts, 160, 144)
    ) / (3.0 * left_eye_width + 1e-6)

    right_ear = (
        dist2d(pts, 386, 374) +
        dist2d(pts, 385, 380) +
        dist2d(pts, 387, 373)
    ) / (3.0 * right_eye_width + 1e-6)

    ear_mean = (left_ear + right_ear) / 2.0
    ear_diff = abs(left_ear - right_ear)

    features.extend([
        left_eye_width,
        right_eye_width,
        left_ear,
        right_ear,
        ear_mean,
        ear_diff,
    ])

    left_eye_center = pts[LEFT_EYE].mean(axis=0)
    right_eye_center = pts[RIGHT_EYE].mean(axis=0)

    left_brow_center = pts[[70, 63, 105, 66, 107]].mean(axis=0)
    right_brow_center = pts[[336, 296, 334, 293, 300]].mean(axis=0)

    left_brow_raise = float(np.linalg.norm(left_brow_center[:2] - left_eye_center[:2]))
    right_brow_raise = float(np.linalg.norm(right_brow_center[:2] - right_eye_center[:2]))

    brow_raise_mean = (left_brow_raise + right_brow_raise) / 2.0
    brow_raise_diff = abs(left_brow_raise - right_brow_raise)

    inner_brow_distance = dist2d(pts, 107, 336)

    features.extend([
        left_brow_raise,
        right_brow_raise,
        brow_raise_mean,
        brow_raise_diff,
        inner_brow_distance,
    ])

    left_cheek_nose = dist2d(pts, 234, 1)
    right_cheek_nose = dist2d(pts, 454, 1)
    cheek_diff = abs(left_cheek_nose - right_cheek_nose)

    chin_mouth = dist2d(pts, 152, 17)
    nose_mouth = dist2d(pts, 1, 13)
    nose_chin = dist2d(pts, 1, 152)

    yaw_proxy = (left_cheek_nose - right_cheek_nose) / (left_cheek_nose + right_cheek_nose + 1e-6)
    pitch_proxy = float(pts[1, 1] - ((pts[33, 1] + pts[263, 1]) / 2.0))

    features.extend([
        left_cheek_nose,
        right_cheek_nose,
        cheek_diff,
        chin_mouth,
        nose_mouth,
        nose_chin,
        yaw_proxy,
        pitch_proxy,
        meta["roll"] / math.pi,
    ])

    mouth_asymmetry = corner_lift_diff
    eye_asymmetry = ear_diff
    brow_asymmetry = brow_raise_diff

    features.extend([
        mouth_asymmetry,
        eye_asymmetry,
        brow_asymmetry,
    ])

    for a, b, c in ANGLE_TRIPLES:
        features.append(angle_feature(pts, a, b, c))

    return np.array(features, dtype=np.float32)


def extract_face_feature_from_landmarks(face_landmarks_468x3):
    landmarks = np.asarray(face_landmarks_468x3, dtype=np.float32)

    if landmarks.shape[0] < 468 or landmarks.shape[1] < 3:
        raise ValueError("Expected face landmarks with shape [468, 3].")

    landmarks = landmarks[:468, :3]

    norm_pts, meta = normalize_landmarks(landmarks)

    selected_coords = norm_pts[SELECTED_LANDMARKS].reshape(-1)
    engineered = compute_engineered_features(norm_pts, meta)

    feature = np.concatenate([selected_coords, engineered], axis=0)
    feature = np.nan_to_num(feature, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32)

    if feature.shape[0] != 404:
        raise ValueError(f"Expected feature dim 404, got {feature.shape[0]}.")

    return feature
