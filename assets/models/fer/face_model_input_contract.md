# Face Emotion Model Input Contract

## Model

Use this contract for the face model trained in `Face_deneme_2`.

Required runtime files:

- `emotion_mlp_float32.tflite`
- `feature_standardizer.npz` or exported JSON equivalent
- `label_map.json`
- This feature extraction implementation

The TFLite model does **not** accept raw MediaPipe landmarks directly.

## Input and output

Model input shape:

```txt
[1, 404]
```

Model output shape:

```txt
[1, 8]
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
7 contempt
```

## MediaPipe input

Use MediaPipe FaceLandmarker or MediaPipe Holistic face landmarks.

Required landmark input:

```txt
face_landmarks: [468, 3]
x, y, z
```

If Holistic returns more than 468 points, use the first 468 face mesh points consistently with MediaPipe FaceMesh indices.

## Normalization

1. Compute left eye center from `LEFT_EYE`.
2. Compute right eye center from `RIGHT_EYE`.
3. `eye_center = (left_eye_center + right_eye_center) / 2`
4. `eye_dist = distance(left_eye_center, right_eye_center)`
5. `roll = atan2(right_eye_center.y - left_eye_center.y, right_eye_center.x - left_eye_center.x)`
6. Subtract `eye_center` from every landmark.
7. Rotate x/y by `-roll`.
8. Divide all x/y/z coordinates by `eye_dist`.

Do not change this order.

## Selected landmarks

Selected landmark count:

```txt
116
```

Selected landmark indices:

```python
SELECTED_LANDMARKS = [1, 2, 4, 5, 6, 7, 13, 14, 17, 19, 33, 46, 52, 53, 55, 58, 61, 63, 65, 66, 70, 78, 80, 81, 82, 84, 87, 88, 91, 93, 94, 95, 98, 105, 107, 132, 133, 136, 144, 145, 146, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160, 161, 163, 168, 172, 173, 176, 178, 181, 191, 195, 197, 234, 246, 249, 263, 276, 282, 283, 285, 288, 291, 293, 295, 296, 300, 308, 310, 311, 312, 314, 317, 318, 321, 323, 324, 327, 334, 336, 361, 362, 365, 373, 374, 375, 377, 378, 379, 380, 381, 382, 384, 385, 386, 387, 388, 390, 397, 398, 400, 402, 405, 415, 454, 466]
```

Feature order for this section:

```txt
for idx in SELECTED_LANDMARKS:
    append normalized_x
    append normalized_y
    append normalized_z
```

This produces:

```txt
116 * 3 = 348 features
```

## Engineered feature order

The engineered section has 56 features.

### Mouth features, 13

1. `mouth_width = dist2d(61, 291)`
2. `mouth_open_1 = dist2d(13, 14)`
3. `mouth_open_2 = dist2d(82, 312)`
4. `mouth_open_3 = dist2d(87, 317)`
5. `mouth_open = mean([mouth_open_1, mouth_open_2, mouth_open_3])`
6. `mar = mouth_open / (mouth_width + 1e-6)`
7. `outer_mouth_area = polygon_area(OUTER_LIP)`
8. `inner_mouth_area = polygon_area(INNER_LIP)`
9. `left_corner_lift = pts[61,1] - mouth_center[1]`
10. `right_corner_lift = pts[291,1] - mouth_center[1]`
11. `corner_lift_mean`
12. `corner_lift_diff`
13. `mouth_slope = atan2(pts[291,y] - pts[61,y], pts[291,x] - pts[61,x] + 1e-6) / pi`

Where:

```python
OUTER_LIP = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78]
INNER_LIP = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]
```

### Eye features, 6

14. `left_eye_width = dist2d(33, 133)`
15. `right_eye_width = dist2d(263, 362)`
16. `left_ear`
17. `right_ear`
18. `ear_mean`
19. `ear_diff = abs(left_ear - right_ear)`

### Eyebrow features, 5

20. `left_brow_raise`
21. `right_brow_raise`
22. `brow_raise_mean`
23. `brow_raise_diff`
24. `inner_brow_distance = dist2d(107, 336)`

Brow raise is 2D distance between brow center and eye center.

### Cheek / jaw / nose proxy features, 9

25. `left_cheek_nose = dist2d(234, 1)`
26. `right_cheek_nose = dist2d(454, 1)`
27. `cheek_diff = abs(left_cheek_nose - right_cheek_nose)`
28. `chin_mouth = dist2d(152, 17)`
29. `nose_mouth = dist2d(1, 13)`
30. `nose_chin = dist2d(1, 152)`
31. `yaw_proxy = (left_cheek_nose - right_cheek_nose) / (left_cheek_nose + right_cheek_nose + 1e-6)`
32. `pitch_proxy = pts[1,1] - ((pts[33,1] + pts[263,1]) / 2)`
33. `roll / pi`

### Symmetry features, 3

34. `mouth_asymmetry = corner_lift_diff`
35. `eye_asymmetry = ear_diff`
36. `brow_asymmetry = brow_raise_diff`

### Angle features, 20

Each angle is computed with:

```txt
angle = atan2(abs(cross(u, v)), dot(u, v)) / pi
```

Angle triples:

```python
ANGLE_TRIPLES = [(61, 13, 291), (61, 14, 291), (78, 13, 308), (78, 14, 308), (61, 0, 291), (13, 61, 14), (13, 291, 14), (78, 61, 95), (308, 291, 324), (33, 159, 133), (33, 145, 133), (263, 386, 362), (263, 374, 362), (70, 105, 107), (336, 334, 300), (55, 65, 52), (285, 295, 282), (234, 1, 454), (93, 1, 323), (152, 17, 0)]
```

Features 37-56 are appended in exactly this order.

## Final feature vector

```txt
348 selected landmark coordinate features
+ 56 engineered features
= 404 features
```

## Standardization

Load `feature_standardizer.npz`.

Expected:

```txt
mean shape: (404,)
std shape:  (404,)
```

Runtime:

```python
x = (feature_404 - mean) / std
x = x.astype("float32").reshape(1, 404)
```

Then run `emotion_mlp_float32.tflite`.

## Runtime quality gates

Recommended before prediction:

- If no face landmarks: `face_status = no_face`
- If face angle/yaw is too high: `face_status = insufficient_face_angle`
- If confidence below threshold after softmax smoothing: `face_status = uncertain`

Use raw per-frame result only for debug. For UI/reporting, use per-second averaging or EMA smoothing.
