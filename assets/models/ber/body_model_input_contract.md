# Body Motion Emotion Model Input Contract

## Runtime model

Use this contract for the **new body motion model**, not the old static body model.

Required runtime files:

```txt
body_motion_tcn_float32.tflite
body_meed_motion_standardizer.npz
body_label_map.json
```

Recommended mobile-friendly extras:

```txt
body_meed_motion_standardizer.json
body_model_input_contract.md
body_feature_extractor_reference.py
body_runtime_manifest.json
body_motion_tcn_training_info.json
```

## Important distinction

Old body model:

```txt
body_emotion_combined_cnn_float32.tflite
input: [1, 15, 92]
feature: static upper-body only
standardizer: body_combined_standardizer.npz
```

New body motion model:

```txt
body_motion_tcn_float32.tflite
input: [1, 30, 279]
feature: static + velocity + acceleration + view one-hot
standardizer: body_meed_motion_standardizer.npz
```

Do not mix these files.

## Model input

```txt
Input shape:  [1, 30, 279]
Output shape: [1, 7]
```

Label order:

```txt
0 neutral
1 happy
2 sad
3 surprise
4 fear
5 disgust
6 angry
```

## Landmark source

Use MediaPipe Pose / Holistic pose landmarks.

Required raw pose landmark format:

```txt
pose_landmarks: [33, 4]
each landmark: x, y, z, visibility
```

If the library gives presence too, ignore it for feature extraction.

## Upper-body landmarks used

```txt
0  nose
7  left ear
8  right ear
11 left shoulder
12 right shoulder
13 left elbow
14 right elbow
15 left wrist
16 right wrist
23 left hip
24 right hip
```

## Per-frame static feature

For each frame, produce a 92-dimensional static feature vector.

Static feature order:

```txt
0-43   upper body landmark x,y,z,visibility for 11 landmarks
44-53  bone length features
54-60  joint angle features
61-67  shoulder / hip / torso geometry
68-77  left-right asymmetry
78-86  arm openness / contraction
87-91  visibility features
```

## Normalization

For each frame:

```txt
mid_shoulder = average(left_shoulder, right_shoulder)
mid_hip = average(left_hip, right_hip)
center = average(mid_shoulder, mid_hip)

shoulder_width = distance2d(left_shoulder, right_shoulder)
torso_len = average(
  distance2d(left_shoulder, left_hip),
  distance2d(right_shoulder, right_hip)
)

scale = average(shoulder_width, torso_len)

x = (x - center.x) / scale
y = (y - center.y) / scale
z = (z - center.z) / scale
```

Do not apply roll normalization. Do not mirror or swap left/right.

## Motion features

Keep a rolling buffer of 30 static feature vectors:

```txt
static_seq: [30, 92]
```

Calculate:

```txt
velocity[0] = zeros(92)
velocity[t] = static[t] - static[t-1]

acceleration[0] = zeros(92)
acceleration[t] = velocity[t] - velocity[t-1]
```

View one-hot per frame:

```txt
front   = [1, 0, 0]
left    = [0, 1, 0]
right   = [0, 0, 1]
unknown = [0, 0, 0]
```

For each frame:

```txt
frame_feature_279 = concat(static_92, velocity_92, acceleration_92, view_one_hot_3)
```

Final model input:

```txt
sequence_feature = [30, 279]
model_input = [1, 30, 279]
```

## Standardization

Load `body_meed_motion_standardizer.npz`:

```txt
mean shape: [279]
std shape:  [279]
```

For every frame:

```txt
x[t] = (x[t] - mean) / std
```

Then feed:

```txt
[1, 30, 279] float32
```

## Quality gate

Only run the body model when enough upper-body landmarks are visible. For chest-up videos, hips/wrists may be missing; in that case return:

```txt
body_status = insufficient_body_visibility
body_emotion = uncertain
body_confidence = 0
```

Suggested minimum checks:

```txt
shoulders visible
at least one or both elbows reasonably visible
hips visible enough for stable center/scale
at least 15-20 usable frames inside the 30-frame buffer
```
