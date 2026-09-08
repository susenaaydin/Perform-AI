"""
Reference feature extractor for the new body motion TCN model.

This is a Python reference for mobile implementation.
The runtime model expects:
    [1, 30, 279]

Per frame:
    92 static upper-body features
    92 velocity features
    92 acceleration features
    3 view one-hot features
"""

import math
import numpy as np

NOSE = 0
LEFT_EAR = 7
RIGHT_EAR = 8
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24

UPPER_BODY_LMS = [
    NOSE,
    LEFT_EAR,
    RIGHT_EAR,
    LEFT_SHOULDER,
    RIGHT_SHOULDER,
    LEFT_ELBOW,
    RIGHT_ELBOW,
    LEFT_WRIST,
    RIGHT_WRIST,
    LEFT_HIP,
    RIGHT_HIP,
]

LEFT_SIDE = [
    LEFT_SHOULDER,
    LEFT_ELBOW,
    LEFT_WRIST,
    LEFT_HIP,
]

RIGHT_SIDE = [
    RIGHT_SHOULDER,
    RIGHT_ELBOW,
    RIGHT_WRIST,
    RIGHT_HIP,
]

BODY_BONES = [
    (LEFT_SHOULDER, RIGHT_SHOULDER),
    (LEFT_SHOULDER, LEFT_ELBOW),
    (LEFT_ELBOW, LEFT_WRIST),
    (RIGHT_SHOULDER, RIGHT_ELBOW),
    (RIGHT_ELBOW, RIGHT_WRIST),
    (LEFT_SHOULDER, LEFT_HIP),
    (RIGHT_SHOULDER, RIGHT_HIP),
    (LEFT_HIP, RIGHT_HIP),
    (NOSE, LEFT_SHOULDER),
    (NOSE, RIGHT_SHOULDER),
]

ANGLE_TRIPLES_BODY = [
    (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
    (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
    (LEFT_ELBOW, LEFT_SHOULDER, LEFT_HIP),
    (RIGHT_ELBOW, RIGHT_SHOULDER, RIGHT_HIP),
    (LEFT_SHOULDER, NOSE, RIGHT_SHOULDER),
    (LEFT_HIP, LEFT_SHOULDER, RIGHT_SHOULDER),
    (RIGHT_HIP, RIGHT_SHOULDER, LEFT_SHOULDER),
]

VIEW_TO_ONEHOT = {
    "front": np.array([1.0, 0.0, 0.0], dtype=np.float32),
    "left": np.array([0.0, 1.0, 0.0], dtype=np.float32),
    "right": np.array([0.0, 0.0, 1.0], dtype=np.float32),
    "unknown": np.array([0.0, 0.0, 0.0], dtype=np.float32),
}


def dist2d(pts: np.ndarray, a: int, b: int) -> float:
    return float(np.linalg.norm(pts[a, :2] - pts[b, :2]))


def angle_2d_over_pi(pts: np.ndarray, a: int, b: int, c: int) -> float:
    u = pts[a, :2] - pts[b, :2]
    v = pts[c, :2] - pts[b, :2]

    cross = abs(float(u[0] * v[1] - u[1] * v[0]))
    dot = float(np.dot(u, v))

    angle = math.atan2(cross, dot)
    return angle / math.pi


def normalize_upper_body_pose(landmarks: np.ndarray):
    """
    landmarks input shape: [33, 4] or [33, 5]
    columns: x, y, z, visibility, optional presence

    Returns normalized points with same columns.
    """
    pts = landmarks.copy().astype(np.float32)

    l_sh = pts[LEFT_SHOULDER, :3]
    r_sh = pts[RIGHT_SHOULDER, :3]
    l_hip = pts[LEFT_HIP, :3]
    r_hip = pts[RIGHT_HIP, :3]

    mid_shoulder = (l_sh + r_sh) / 2.0
    mid_hip = (l_hip + r_hip) / 2.0
    center = (mid_shoulder + mid_hip) / 2.0

    shoulder_width = np.linalg.norm(l_sh[:2] - r_sh[:2])
    left_torso = np.linalg.norm(l_sh[:2] - l_hip[:2])
    right_torso = np.linalg.norm(r_sh[:2] - r_hip[:2])
    torso_len = (left_torso + right_torso) / 2.0

    scale = float(np.mean([shoulder_width, torso_len]) + 1e-6)

    pts[:, 0] = (pts[:, 0] - center[0]) / scale
    pts[:, 1] = (pts[:, 1] - center[1]) / scale
    pts[:, 2] = (pts[:, 2] - center[2]) / scale

    meta = {
        "scale": scale,
        "shoulder_width": float(shoulder_width / scale),
        "torso_len": float(torso_len / scale),
    }

    return pts, meta


def compute_body_engineered_features(pts: np.ndarray, meta: dict) -> np.ndarray:
    features = []

    # 1) Bone lengths: 10
    for a, b in BODY_BONES:
        features.append(dist2d(pts, a, b))

    # 2) Joint angles: 7
    for a, b, c in ANGLE_TRIPLES_BODY:
        features.append(angle_2d_over_pi(pts, a, b, c))

    # 3) Shoulder / hip / torso geometry: 7
    shoulder_vec = pts[RIGHT_SHOULDER, :2] - pts[LEFT_SHOULDER, :2]
    hip_vec = pts[RIGHT_HIP, :2] - pts[LEFT_HIP, :2]

    shoulder_angle = math.atan2(float(shoulder_vec[1]), float(shoulder_vec[0] + 1e-6)) / math.pi
    hip_angle = math.atan2(float(hip_vec[1]), float(hip_vec[0] + 1e-6)) / math.pi

    mid_shoulder = (pts[LEFT_SHOULDER, :2] + pts[RIGHT_SHOULDER, :2]) / 2.0
    mid_hip = (pts[LEFT_HIP, :2] + pts[RIGHT_HIP, :2]) / 2.0

    torso_vec = mid_shoulder - mid_hip
    torso_lean = math.atan2(float(torso_vec[0]), float(-torso_vec[1] + 1e-6)) / math.pi

    head_vec = pts[NOSE, :2] - mid_shoulder
    head_offset_x = float(head_vec[0])
    head_offset_y = float(head_vec[1])

    features.extend([
        shoulder_angle,
        hip_angle,
        torso_lean,
        head_offset_x,
        head_offset_y,
        meta["shoulder_width"],
        meta["torso_len"],
    ])

    # 4) Signed left/right asymmetry: 10
    signed_wrist_y_diff = float(pts[LEFT_WRIST, 1] - pts[RIGHT_WRIST, 1])
    signed_wrist_x_diff = float(pts[LEFT_WRIST, 0] - pts[RIGHT_WRIST, 0])
    signed_elbow_y_diff = float(pts[LEFT_ELBOW, 1] - pts[RIGHT_ELBOW, 1])
    signed_elbow_x_diff = float(pts[LEFT_ELBOW, 0] - pts[RIGHT_ELBOW, 0])
    signed_shoulder_y_diff = float(pts[LEFT_SHOULDER, 1] - pts[RIGHT_SHOULDER, 1])

    left_elbow_angle = angle_2d_over_pi(pts, LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST)
    right_elbow_angle = angle_2d_over_pi(pts, RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST)

    left_shoulder_angle = angle_2d_over_pi(pts, LEFT_ELBOW, LEFT_SHOULDER, LEFT_HIP)
    right_shoulder_angle = angle_2d_over_pi(pts, RIGHT_ELBOW, RIGHT_SHOULDER, RIGHT_HIP)

    features.extend([
        signed_wrist_y_diff,
        signed_wrist_x_diff,
        signed_elbow_y_diff,
        signed_elbow_x_diff,
        signed_shoulder_y_diff,
        abs(signed_wrist_y_diff),
        abs(signed_elbow_y_diff),
        abs(signed_shoulder_y_diff),
        float(left_elbow_angle - right_elbow_angle),
        float(left_shoulder_angle - right_shoulder_angle),
    ])

    # 5) Arm openness / contraction: 9
    wrist_distance = dist2d(pts, LEFT_WRIST, RIGHT_WRIST)
    elbow_distance = dist2d(pts, LEFT_ELBOW, RIGHT_ELBOW)
    shoulder_distance = dist2d(pts, LEFT_SHOULDER, RIGHT_SHOULDER)

    left_hand_to_torso = float(np.linalg.norm(pts[LEFT_WRIST, :2] - mid_shoulder))
    right_hand_to_torso = float(np.linalg.norm(pts[RIGHT_WRIST, :2] - mid_shoulder))

    left_elbow_to_torso = float(np.linalg.norm(pts[LEFT_ELBOW, :2] - mid_shoulder))
    right_elbow_to_torso = float(np.linalg.norm(pts[RIGHT_ELBOW, :2] - mid_shoulder))

    features.extend([
        wrist_distance,
        elbow_distance,
        shoulder_distance,
        left_hand_to_torso,
        right_hand_to_torso,
        left_elbow_to_torso,
        right_elbow_to_torso,
        abs(left_hand_to_torso - right_hand_to_torso),
        abs(left_elbow_to_torso - right_elbow_to_torso),
    ])

    # 6) Visibility: 5
    upper_visibility = pts[UPPER_BODY_LMS, 3]
    left_visibility = pts[LEFT_SIDE, 3].mean()
    right_visibility = pts[RIGHT_SIDE, 3].mean()

    features.extend([
        float(upper_visibility.mean()),
        float(upper_visibility.min()),
        float(left_visibility),
        float(right_visibility),
        float(abs(left_visibility - right_visibility)),
    ])

    return np.array(features, dtype=np.float32)


def extract_static_frame_body_feature(pose_landmarks: np.ndarray) -> np.ndarray:
    """
    Input:
      pose_landmarks: [33, 4] or [33, 5]
    Output:
      static feature: [92]
    """
    pts, meta = normalize_upper_body_pose(pose_landmarks)
    selected = pts[UPPER_BODY_LMS][:, [0, 1, 2, 3]].reshape(-1)
    engineered = compute_body_engineered_features(pts, meta)
    feature = np.concatenate([selected, engineered], axis=0)
    return np.nan_to_num(feature, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32)


def build_body_motion_sequence(static_seq: np.ndarray, view: str = "front") -> np.ndarray:
    """
    Input:
      static_seq: [30, 92]
      view: "front", "left", "right", or "unknown"
    Output:
      model feature sequence: [30, 279]
    """
    static_seq = static_seq.astype(np.float32)

    velocity = np.zeros_like(static_seq)
    velocity[1:] = static_seq[1:] - static_seq[:-1]

    acceleration = np.zeros_like(static_seq)
    acceleration[1:] = velocity[1:] - velocity[:-1]

    view_key = str(view).lower().strip()
    view_onehot = VIEW_TO_ONEHOT.get(view_key, VIEW_TO_ONEHOT["unknown"])
    view_seq = np.repeat(view_onehot.reshape(1, -1), static_seq.shape[0], axis=0)

    final_seq = np.concatenate([static_seq, velocity, acceleration, view_seq], axis=1)
    return np.nan_to_num(final_seq, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32)


def standardize_body_sequence(sequence_30x279: np.ndarray, mean_279: np.ndarray, std_279: np.ndarray) -> np.ndarray:
    """
    Output shape remains [30, 279].
    Add batch dimension before TFLite inference.
    """
    return ((sequence_30x279 - mean_279.reshape(1, -1)) / std_279.reshape(1, -1)).astype(np.float32)
